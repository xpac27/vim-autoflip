vim9script

import autoload 'autoflip/range.vim' as rangeutil
import autoload 'autoflip/syntax.vim' as syntax
import autoload 'autoflip/types.vim' as types

const DECLARATION = '^\(\s*\%(\%(if\|while\)\s*(\s*\)\?\)\(.\{-}\)\s*=\s*\(.*\)$'
const DIRECT_EXPRESSIONS = ['DeclRef', 'Call', 'CXXMemberCall', 'CXXOperatorCall',
  'UnaryOperator', 'BinaryOperator', 'ConditionalOperator', 'ArraySubscript', 'Member']
const DISALLOWED_TYPE_WORDS = ['auto', 'consteval', 'constexpr', 'constinit', 'extern',
  'mutable', 'register', 'static', 'thread_local', 'typedef', 'using', 'volatile']

def PositionEqual(left: any, right: any): bool
  return type(left) == v:t_dict && type(right) == v:t_dict
      && get(left, 'line', -1) == get(right, 'line', -2)
      && get(left, 'character', -1) == get(right, 'character', -2)
enddef

def RangeEqual(left: any, right: any): bool
  return type(left) == v:t_dict && type(right) == v:t_dict
      && PositionEqual(get(left, 'start', 0), get(right, 'start', 1))
      && PositionEqual(get(left, 'end', 0), get(right, 'end', 1))
enddef

def CandidateLines(bufnr: number, requested: dict<any>): list<dict<any>>
  if type(get(requested, 'start', 0)) != v:t_dict
      || type(get(requested, 'end', 0)) != v:t_dict
    return []
  endif
  var first = max([1, get(requested.start, 'line', 0) + 1])
  var info = getbufinfo(bufnr)
  if empty(info)
    return []
  endif
  var last = min([info[0].linecount, get(requested.end, 'line', -1) + 1])
  return last < first ? [] : syntax.LocalDeclarationLines(bufnr, first, last)
enddef

def EndOfInitializer(lines: list<dict<any>>, index: number, start: number): dict<any>
  var initial = strpart(get(lines[index], 'line', ''), start)
  var first = index
  var first_col = start
  if empty(trim(initial))
    first += 1
    while first < len(lines) && empty(trim(get(lines[first], 'line', '')))
      first += 1
    endwhile
    if first >= len(lines)
      return {}
    endif
    first_col = match(get(lines[first], 'line', ''), '\S')
    if first_col < 0
      return {}
    endif
  endif
  for current in range(first, len(lines) - 1)
    var line = get(lines[current], 'line', '')
    var semicolon = match(line, ';\s*$')
    if semicolon >= 0
      var initializer_end = match(line, '\s*;\s*$')
      return {
        start: {line: get(lines[first], 'lnum', 0) - 1,
          character: rangeutil.Utf16Length(strpart(get(lines[first], 'line', ''), 0, first_col))},
        end: {line: get(lines[current], 'lnum', 0) - 1,
          character: rangeutil.Utf16Length(strpart(line, 0, initializer_end))},
        declaration_end: {line: get(lines[current], 'lnum', 0) - 1,
          character: rangeutil.Utf16Length(strpart(line, 0, semicolon))},
      }
    endif
  endfor
  return {}
enddef

def ParseLeft(prefix: string, left: string): dict<any>
  var identifier = matchstr(left, '\h\w*\s*$')
  var identifier_start = match(left, '\h\w*\s*$')
  if empty(identifier) || identifier_start < 0
    return {}
  endif
  var before_identifier = strpart(left, 0, identifier_start)
  var declarator_start = match(before_identifier, '\%(\*\|&\)\s*$')
  var declarator = declarator_start >= 0 ? strpart(before_identifier, declarator_start, 1) : ''
  var type_text = trim(strpart(before_identifier, 0,
    declarator_start >= 0 ? declarator_start : strlen(before_identifier)))
  if empty(type_text) || type_text !~# '^\%(\h\|::\)[_a-zA-Z0-9:<> ,]*$'
    return {}
  endif
  for word in DISALLOWED_TYPE_WORDS
    if type_text =~# '\<\C' .. word .. '\>'
      return {}
    endif
  endfor
  var const_prefix = type_text =~# '^const\s\+'
  var type_start = strlen(prefix)
  var semantic_type_start = type_start + (const_prefix ? strlen(matchstr(type_text, '^const\s\+')) : 0)
  var type_end = type_start + strlen(type_text)
  var declarator_end = declarator_start >= 0
    ? type_start + declarator_start + 1
    : type_end
  return {
    identifier: identifier,
    declarator: empty(declarator) ? 'value' : declarator,
    type_start: type_start,
    semantic_type_start: semantic_type_start,
    declarator_end: declarator_end,
    replacement: const_prefix
      ? 'const ' .. (declarator ==# '*' ? 'auto*' : declarator ==# '&' ? 'auto&' : 'auto')
      : declarator ==# '*' ? 'auto*' : declarator ==# '&' ? 'auto&' : 'auto',
  }
enddef

export def Candidates(
    bufnr: number,
    requested: dict<any>,
    maximum: number): list<dict<any>>
  if maximum <= 0
    return []
  endif
  var lines = CandidateLines(bufnr, requested)
  var result: list<dict<any>> = []
  for index in range(0, len(lines) - 1)
    var line = get(lines[index], 'line', '')
    var matched = matchlist(line, DECLARATION)
    if empty(matched) || !get(lines[index], 'is_local', false)
      continue
    endif
    var left = ParseLeft(matched[1], matched[2])
    if empty(left)
      continue
    endif
    var initializer_start = match(line, '=\s*\zs')
    var initializer = initializer_start >= 0
      ? EndOfInitializer(lines, index, initializer_start)
      : {}
    if empty(initializer)
      continue
    endif
    var lnum = get(lines[index], 'lnum', 0)
    add(result, {
      lnum: lnum,
      identifier: left.identifier,
      declarator: left.declarator,
      semantic_type_range: {
        start: {line: lnum - 1,
          character: rangeutil.Utf16Length(strpart(line, 0, left.semantic_type_start))},
        end: {line: lnum - 1,
          character: rangeutil.Utf16Length(strpart(line, 0, left.declarator_end))},
      },
      replacement_range: {
        start: {line: lnum - 1,
          character: rangeutil.Utf16Length(strpart(line, 0, left.type_start))},
        end: {line: lnum - 1,
          character: rangeutil.Utf16Length(strpart(line, 0, left.declarator_end))},
      },
      range: {
        start: {line: lnum - 1,
          character: rangeutil.Utf16Length(strpart(line, 0, left.type_start))},
        end: initializer.declaration_end,
      },
      initializer_range: {start: initializer.start, end: initializer.end},
      replacement: left.replacement,
    })
    if len(result) >= maximum
      break
    endif
  endfor
  return result
enddef

def OneChild(node: dict<any>, role: string): dict<any>
  var children = get(node, 'children', 0)
  if type(children) != v:t_list
    return {}
  endif
  var found = children->copy()->filter((_, child) =>
    type(child) == v:t_dict && get(child, 'role', '') ==# role)
  return len(found) == 1 ? found[0] : {}
enddef

def CanonicalType(node: dict<any>): string
  var arcana = get(node, 'arcana', '')
  var quoted = type(arcana) == v:t_string ? matchstr(arcana, "'[^']*'") : ''
  return strlen(quoted) >= 2 ? strpart(quoted, 1, strlen(quoted) - 2) : ''
enddef

def DeclarationTypeSpellings(node: dict<any>): list<string>
  var result: list<string> = []
  var spelling = CanonicalType(node)
  if !empty(spelling)
    add(result, spelling)
  endif
  var children = get(node, 'children', 0)
  if type(children) != v:t_list
    return result
  endif
  for child in children
    if type(child) == v:t_dict && get(child, 'role', '') ==# 'type'
      result += DeclarationTypeSpellings(child)
    endif
  endfor
  return result
enddef

def CompactType(type_name: string): string
  return substitute(type_name, '\s\+', '', 'g')
enddef

def ReferenceBase(type_name: string): string
  var compact = CompactType(type_name)
  compact = substitute(compact, '^const', '', '')
  compact = substitute(compact, '^volatile', '', '')
  return substitute(compact, '\(&&\|&\)$', '', '')
enddef

def CompatibleTypes(candidate: dict<any>, type_node: dict<any>, expression: dict<any>): bool
  var inferred = CanonicalType(expression)
  if empty(inferred)
    return false
  endif
  for declared in DeclarationTypeSpellings(type_node)
    if get(candidate, 'declarator', '') ==# '&'
        || get(candidate, 'declarator', '') ==# 'value'
      if ReferenceBase(declared) ==# ReferenceBase(inferred)
        return true
      endif
    elseif CompactType(declared) ==# CompactType(inferred)
      return true
    endif
  endfor
  return false
enddef

def DirectIdentity(expression: dict<any>, candidate: dict<any>): bool
  var expected = get(candidate, 'initializer_range', {})
  if !RangeEqual(get(expression, 'range', 0), expected)
    return false
  endif
  var kind = get(expression, 'kind', '')
  if kind ==# 'ExprWithCleanups' || kind ==# 'CXXBindTemporary'
    var child = OneChild(expression, 'expression')
    return !empty(child) && DirectIdentity(child, candidate)
  endif
  if kind ==# 'ImplicitCast'
    var detail = get(expression, 'detail', '')
    if detail !=# 'NoOp'
        && !(detail ==# 'LValueToRValue' && get(candidate, 'declarator', '') !=# '&')
      return false
    endif
    var child = OneChild(expression, 'expression')
    return !empty(child) && DirectIdentity(child, candidate)
  endif
  if kind ==# 'CXXConstruct'
    if get(candidate, 'declarator', '') !=# 'value'
      return false
    endif
    var cast = OneChild(expression, 'expression')
    if empty(cast) || get(cast, 'kind', '') !=# 'ImplicitCast'
        || get(cast, 'detail', '') !=# 'NoOp'
      return false
    endif
    return DirectIdentity(cast, candidate)
  endif
  if index(DIRECT_EXPRESSIONS, kind) < 0
    return false
  endif
  return get(candidate, 'declarator', '') !=# '&'
      || get(expression, 'arcana', '') =~# '\<lvalue\>'
enddef

def ValidType(candidate: dict<any>, type_node: dict<any>): bool
  if empty(type_node) || get(type_node, 'kind', '') ==# 'Auto'
    return false
  endif
  var declarator = get(candidate, 'declarator', '')
  if (declarator ==# '*' && get(type_node, 'kind', '') !=# 'Pointer')
      || (declarator ==# '&' && get(type_node, 'kind', '') !=# 'LValueReference')
      || (declarator ==# 'value'
        && index(['Pointer', 'LValueReference', 'RValueReference'], get(type_node, 'kind', '')) >= 0)
    return false
  endif
  return RangeEqual(get(type_node, 'range', 0), get(candidate, 'semantic_type_range', {}))
      || RangeEqual(get(type_node, 'range', 0), get(candidate, 'replacement_range', {}))
enddef

export def Validate(bufnr: number, candidate: any, node: any): dict<any>
  if type(candidate) != v:t_dict || type(node) != v:t_dict
      || get(node, 'role', '') !=# 'declaration'
      || get(node, 'kind', '') !=# 'Var'
      || get(node, 'detail', '') !=# get(candidate, 'identifier', '')
      || !RangeEqual(get(node, 'range', 0), get(candidate, 'range', {}))
    return {}
  endif
  var type_node = OneChild(node, 'type')
  var expression = OneChild(node, 'expression')
  if !ValidType(candidate, type_node) || empty(expression)
      || !CompatibleTypes(candidate, type_node, expression)
      || !DirectIdentity(expression, candidate)
    return {}
  endif
  var bytes = rangeutil.ByteRange(bufnr, get(candidate, 'replacement_range', {}))
  if empty(bytes) || bytes.lnum != get(candidate, 'lnum', 0)
    return {}
  endif
  return types.NewView('prefer-auto', bytes.lnum, bytes.col, bytes.length,
    get(candidate, 'replacement', ''))
enddef

export def Normalize(bufnr: number, responses: any): list<dict<any>>
  if type(responses) != v:t_list
    return []
  endif
  var views: list<dict<any>> = []
  for response in responses
    var view = type(response) == v:t_dict
      ? Validate(bufnr, get(response, 'candidate', {}), get(response, 'node', {}))
      : {}
    if !empty(view)
      add(views, view)
    endif
  endfor
  return types.SortViews(views)
enddef
