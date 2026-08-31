vim9script

import autoload 'autoflip/range.vim' as rangeutil
import autoload 'autoflip/syntax.vim' as syntax
import autoload 'autoflip/types.vim' as types

const SIMPLE_COPY = '^\(\s*\)\([_a-zA-Z][_a-zA-Z0-9:<> ]*\)\s\+\(\h\w*\)\s*=\s*\(\h\w*\)\s*;\s*$'
const AST_PROVEN_LOCAL = '^\(\s*\)\([_a-zA-Z][_a-zA-Z0-9:<> ]*\)\s*\(\*\|&\)\s*\(\h\w*\)\s*=\s*\([^;]\+\)\s*;\s*$'
const AST_PROVEN_VALUE = '^\(\s*\)\(const\s\+\)\?\(\%(\h\|::\)[_a-zA-Z0-9:<> ]*\)\s\+\(\h\w*\)\s*=\s*\([^;]\+\)\s*;\s*$'
const AST_PROVEN_VALUE_PREFIX = '^\(\s*\)\(const\s\+\)\?\(\%(\h\|::\)[_a-zA-Z0-9:<> ]*\)\s\+\(\h\w*\)\s*=\s*$'
const AST_PROVEN_VALUE_CONTINUATION = '^\(\s*\)\([^;]\+\)\s*;\s*$'
const DISALLOWED_TYPE_WORDS = ['auto', 'const', 'volatile', 'static', 'thread_local',
  'constexpr', 'constinit', 'extern', 'register', 'mutable', 'typedef', 'using']
const DISALLOWED_VALUE_TYPE_WORDS = ['auto', 'volatile', 'static', 'thread_local',
  'constexpr', 'constinit', 'extern', 'register', 'mutable', 'typedef', 'using']

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

def PlainType(type_text: string): bool
  for word in DISALLOWED_TYPE_WORDS
    if type_text =~# '\C\<' .. word .. '\>'
      return false
    endif
  endfor
  return true
enddef

def PlainValueType(type_text: string): bool
  for word in DISALLOWED_VALUE_TYPE_WORDS
    if type_text =~# '\C\<' .. word .. '\>'
      return false
    endif
  endfor
  return true
enddef

export def Candidates(
    bufnr: number,
    requested: dict<any>,
    maximum: number): list<dict<any>>
  if maximum <= 0 || type(get(requested, 'start', 0)) != v:t_dict
      || type(get(requested, 'end', 0)) != v:t_dict
    return []
  endif
  var first = max([1, get(requested.start, 'line', 0) + 1])
  var info = getbufinfo(bufnr)
  if empty(info)
    return []
  endif
  var last = min([info[0].linecount, get(requested.end, 'line', -1) + 1])
  if last < first
    return []
  endif
  var result: list<dict<any>> = []
  for lnum in range(first, last)
    var line = syntax.SafeDeclarationLine(bufnr, lnum)
    if empty(line)
      continue
    endif
    var matched = matchlist(line, SIMPLE_COPY)
    if empty(matched) || !PlainType(matched[2])
      continue
    endif
    var type_start = strlen(matched[1])
    var type_end = type_start + strlen(matched[2])
    var semicolon = match(line, ';\s*$')
    if semicolon < 0 || !syntax.IsLocal(bufnr, lnum, type_start + 1)
      continue
    endif
    add(result, {
      lnum: lnum,
      identifier: matched[3],
      initializer: matched[4],
      type_range: {
        start: {line: lnum - 1, character: rangeutil.Utf16Length(strpart(line, 0, type_start))},
        end: {line: lnum - 1, character: rangeutil.Utf16Length(strpart(line, 0, type_end))},
      },
      range: {
        start: {line: lnum - 1, character: rangeutil.Utf16Length(strpart(line, 0, type_start))},
        end: {line: lnum - 1, character: rangeutil.Utf16Length(strpart(line, 0, semicolon))},
      },
    })
    if len(result) >= maximum
      break
    endif
  endfor
  return result
enddef

export def AstProvenCandidates(
    bufnr: number,
    requested: dict<any>,
    maximum: number): list<dict<any>>
  if maximum <= 0 || type(get(requested, 'start', 0)) != v:t_dict
      || type(get(requested, 'end', 0)) != v:t_dict
    return []
  endif
  var first = max([1, get(requested.start, 'line', 0) + 1])
  var info = getbufinfo(bufnr)
  if empty(info)
    return []
  endif
  var last = min([info[0].linecount, get(requested.end, 'line', -1) + 1])
  if last < first
    return []
  endif
  var result = Candidates(bufnr, requested, maximum)
  if len(result) >= maximum
    return result
  endif
  for lnum in range(first, last)
    var line = syntax.SafeDeclarationLine(bufnr, lnum)
    if empty(line)
      continue
    endif
    var matched = matchlist(line, AST_PROVEN_LOCAL)
    if empty(matched) || !PlainType(matched[2])
      continue
    endif
    var type_start = strlen(matched[1])
    var type_end = type_start + strlen(matched[2])
    var declarator_end = type_end + strlen(matched[3])
    var semicolon = match(line, ';\s*$')
    if semicolon < 0 || !syntax.IsLocal(bufnr, lnum, type_start + 1)
      continue
    endif
    var initializer = trim(matched[5])
    var initializer_start = match(line, '=\s*\zs')
    if empty(initializer) || initializer_start < 0
      continue
    endif
    var replacement = matched[3] ==# '*' ? 'auto*' : 'auto&'
    add(result, {
      lnum: lnum,
      identifier: matched[4],
      type_range: {
        start: {line: lnum - 1, character: rangeutil.Utf16Length(strpart(line, 0, type_start))},
        end: {line: lnum - 1, character: rangeutil.Utf16Length(strpart(line, 0, declarator_end))},
      },
      range: {
        start: {line: lnum - 1, character: rangeutil.Utf16Length(strpart(line, 0, type_start))},
        end: {line: lnum - 1, character: rangeutil.Utf16Length(strpart(line, 0, semicolon))},
      },
      initializer: initializer,
      initializer_range: {
        start: {line: lnum - 1, character: rangeutil.Utf16Length(strpart(line, 0, initializer_start))},
        end: {line: lnum - 1, character: rangeutil.Utf16Length(strpart(line, 0, initializer_start + strlen(initializer)))},
      },
      declarator: matched[3],
      replacement: replacement,
    })
    if len(result) >= maximum
      break
    endif
  endfor
  for lnum in range(first, last)
    if len(result) >= maximum
      break
    endif
    var line = syntax.SafeDeclarationLine(bufnr, lnum)
    if empty(line)
      continue
    endif
    var matched = matchlist(line, AST_PROVEN_VALUE)
    if empty(matched) || !PlainValueType(matched[3])
      continue
    endif
    var initializer = trim(matched[5])
    if empty(initializer) || initializer =~# '^\h\w*$'
        || initializer =~# '^\h\w*\s*,'
      continue
    endif
    var type_start = strlen(matched[1])
    var base_type_start = type_start + strlen(matched[2])
    var type_end = base_type_start + strlen(matched[3])
    var semicolon = match(line, ';\s*$')
    var initializer_start = match(line, '=\s*\zs')
    if semicolon < 0 || initializer_start < 0 || !syntax.IsLocal(bufnr, lnum, type_start + 1)
      continue
    endif
    add(result, {
      lnum: lnum,
      identifier: matched[4],
      type_range: {
        start: {line: lnum - 1, character: rangeutil.Utf16Length(strpart(line, 0, base_type_start))},
        end: {line: lnum - 1, character: rangeutil.Utf16Length(strpart(line, 0, type_end))},
      },
      replacement_range: {
        start: {line: lnum - 1, character: rangeutil.Utf16Length(strpart(line, 0, type_start))},
        end: {line: lnum - 1, character: rangeutil.Utf16Length(strpart(line, 0, type_end))},
      },
      range: {
        start: {line: lnum - 1, character: rangeutil.Utf16Length(strpart(line, 0, type_start))},
        end: {line: lnum - 1, character: rangeutil.Utf16Length(strpart(line, 0, semicolon))},
      },
      initializer: initializer,
      initializer_range: {
        start: {line: lnum - 1, character: rangeutil.Utf16Length(strpart(line, 0, initializer_start))},
        end: {line: lnum - 1, character: rangeutil.Utf16Length(strpart(line, 0, initializer_start + strlen(initializer)))},
      },
      declarator: 'value',
      replacement: empty(matched[2]) ? 'auto' : 'const auto',
    })
  endfor
  for lnum in range(first, last - 1)
    if len(result) >= maximum
      break
    endif
    var line = syntax.SafeDeclarationLine(bufnr, lnum)
    var continuation = syntax.SafeDeclarationLine(bufnr, lnum + 1)
    var matched = matchlist(line, AST_PROVEN_VALUE_PREFIX)
    var continued = matchlist(continuation, AST_PROVEN_VALUE_CONTINUATION)
    if empty(matched) || empty(continued) || !PlainValueType(matched[3])
      continue
    endif
    var initializer = trim(continued[2])
    if empty(initializer) || initializer =~# '^\h\w*$'
        || initializer =~# '^\h\w*\s*,'
      continue
    endif
    var type_start = strlen(matched[1])
    var base_type_start = type_start + strlen(matched[2])
    var type_end = base_type_start + strlen(matched[3])
    var semicolon = match(continuation, ';\s*$')
    var initializer_start = strlen(continued[1])
    if semicolon < 0 || !syntax.IsLocal(bufnr, lnum, type_start + 1)
      continue
    endif
    add(result, {
      lnum: lnum,
      identifier: matched[4],
      type_range: {
        start: {line: lnum - 1, character: rangeutil.Utf16Length(strpart(line, 0, base_type_start))},
        end: {line: lnum - 1, character: rangeutil.Utf16Length(strpart(line, 0, type_end))},
      },
      replacement_range: {
        start: {line: lnum - 1, character: rangeutil.Utf16Length(strpart(line, 0, type_start))},
        end: {line: lnum - 1, character: rangeutil.Utf16Length(strpart(line, 0, type_end))},
      },
      range: {
        start: {line: lnum - 1, character: rangeutil.Utf16Length(strpart(line, 0, type_start))},
        end: {line: lnum, character: rangeutil.Utf16Length(strpart(continuation, 0, semicolon))},
      },
      initializer: initializer,
      initializer_range: {
        start: {line: lnum, character: rangeutil.Utf16Length(strpart(continuation, 0, initializer_start))},
        end: {line: lnum, character: rangeutil.Utf16Length(strpart(continuation, 0, initializer_start + strlen(initializer)))},
      },
      declarator: 'value',
      replacement: empty(matched[2]) ? 'auto' : 'const auto',
    })
  endfor
  return result
enddef

def ValidDeclaration(candidate: dict<any>, node: dict<any>): bool
  return get(node, 'role', '') ==# 'declaration'
      && get(node, 'kind', '') ==# 'Var'
      && get(node, 'detail', '') ==# get(candidate, 'identifier', 0)
      && RangeEqual(get(node, 'range', 0), get(candidate, 'range', 1))
enddef

def ValidType(candidate: dict<any>, type_node: dict<any>): bool
  return !empty(type_node)
      && RangeEqual(get(type_node, 'range', 0), get(candidate, 'type_range', 1))
      && get(type_node, 'kind', '') !=# 'Auto'
      && type(get(type_node, 'detail', '')) == v:t_string
enddef

def ExpressionRange(candidate: dict<any>): dict<any>
  var line = getline(get(candidate, 'lnum', 0))
  var start = match(line, '=\s*\zs')
  var initializer = get(candidate, 'initializer', '')
  if start < 0 || type(initializer) != v:t_string || empty(initializer)
    return {}
  endif
  return {
    start: {line: get(candidate.range.start, 'line', -1),
      character: rangeutil.Utf16Length(strpart(line, 0, start))},
    end: {line: get(candidate.range.start, 'line', -1),
      character: rangeutil.Utf16Length(strpart(line, 0, start + strlen(initializer)))},
  }
enddef

def NewAstProvenView(bufnr: number, candidate: dict<any>, type_node: dict<any>): dict<any>
  var bytes = rangeutil.ByteRange(bufnr, get(candidate, 'replacement_range', type_node.range))
  if empty(bytes) || bytes.lnum != get(candidate, 'lnum', 0)
    return {}
  endif
  return types.NewView('prefer-auto', bytes.lnum, bytes.col, bytes.length,
    get(candidate, 'replacement', 'auto'))
enddef

def ValidateCallResult(bufnr: number, candidate: dict<any>, node: dict<any>): dict<any>
  if !ValidDeclaration(candidate, node)
    return {}
  endif
  var type_node = OneChild(node, 'type')
  var expression = OneChild(node, 'expression')
  if !ValidType(candidate, type_node)
      || !DirectCall(expression, get(candidate, 'initializer_range', 0))
    return {}
  endif
  return NewAstProvenView(bufnr, candidate, type_node)
enddef

def DirectCall(expression: dict<any>, expected_range: dict<any>): bool
  if empty(expression) || !RangeEqual(get(expression, 'range', 0), expected_range)
    return false
  endif
  if index(['Call', 'CXXMemberCall'], get(expression, 'kind', '')) >= 0
    return true
  endif
  if get(expression, 'kind', '') !=# 'ExprWithCleanups'
    return false
  endif
  var cast = OneChild(expression, 'expression')
  if empty(cast) || get(cast, 'kind', '') !=# 'ImplicitCast'
      || get(cast, 'detail', '') !=# 'NoOp'
      || !RangeEqual(get(cast, 'range', 0), expected_range)
    return false
  endif
  var temporary = OneChild(cast, 'expression')
  if empty(temporary) || get(temporary, 'kind', '') !=# 'CXXBindTemporary'
      || !RangeEqual(get(temporary, 'range', 0), expected_range)
    return false
  endif
  var call = OneChild(temporary, 'expression')
  return !empty(call)
      && get(call, 'kind', '') ==# 'CXXMemberCall'
      && RangeEqual(get(call, 'range', 0), expected_range)
enddef

def ValidateCopyConstruction(bufnr: number, candidate: dict<any>, node: dict<any>): dict<any>
  if !ValidDeclaration(candidate, node)
    return {}
  endif
  var type_node = OneChild(node, 'type')
  var expression = OneChild(node, 'expression')
  if !ValidType(candidate, type_node) || empty(expression)
      || get(expression, 'kind', '') !=# 'CXXConstruct'
    return {}
  endif
  var cast = OneChild(expression, 'expression')
  if empty(cast) || get(cast, 'kind', '') !=# 'ImplicitCast'
      || get(cast, 'detail', '') !=# 'NoOp'
    return {}
  endif
  var source = OneChild(cast, 'expression')
  var expected_range = ExpressionRange(candidate)
  if empty(source) || empty(expected_range)
      || get(source, 'kind', '') !=# 'DeclRef'
      || get(source, 'detail', '') !=# get(candidate, 'initializer', '')
      || !RangeEqual(get(source, 'range', 0), expected_range)
      || !RangeEqual(get(cast, 'range', 0), expected_range)
      || !RangeEqual(get(expression, 'range', 0), expected_range)
    return {}
  endif
  return NewAstProvenView(bufnr, candidate, type_node)
enddef

def ValidateLvalueSubscript(bufnr: number, candidate: dict<any>, node: dict<any>): dict<any>
  if !ValidDeclaration(candidate, node)
    return {}
  endif
  var type_node = OneChild(node, 'type')
  var expression = OneChild(node, 'expression')
  if !ValidType(candidate, type_node)
      || get(type_node, 'kind', '') !=# 'LValueReference'
      || empty(expression)
      || get(expression, 'kind', '') !=# 'CXXOperatorCall'
      || !RangeEqual(get(expression, 'range', 0), get(candidate, 'initializer_range', 0))
      || get(expression, 'arcana', '') !~# '\<lvalue\>'
      || get(expression, 'arcana', '') !~# "'.*\\[\\]'"
    return {}
  endif
  return NewAstProvenView(bufnr, candidate, type_node)
enddef

def ValidatePointer(bufnr: number, candidate: dict<any>, node: dict<any>): dict<any>
  if !ValidDeclaration(candidate, node)
    return {}
  endif
  var type_node = OneChild(node, 'type')
  var expression = OneChild(node, 'expression')
  if !ValidType(candidate, type_node)
      || get(type_node, 'kind', '') !=# 'Pointer'
      || empty(expression)
      || get(expression, 'kind', '') !=# 'ImplicitCast'
      || get(expression, 'detail', '') !=# 'LValueToRValue'
    return {}
  endif
  var source = OneChild(expression, 'expression')
  if empty(source) || get(source, 'kind', '') !=# 'DeclRef'
      || get(source, 'detail', '') !=# get(candidate, 'initializer', '')
      || !RangeEqual(get(source, 'range', 0), get(candidate, 'initializer_range', 1))
      || !RangeEqual(get(expression, 'range', 0), get(candidate, 'initializer_range', 1))
    return {}
  endif
  return NewAstProvenView(bufnr, candidate, type_node)
enddef

export def ValidateAstProven(bufnr: number, candidate: any, node: any): dict<any>
  if type(candidate) != v:t_dict || type(node) != v:t_dict
    return {}
  endif
  var declarator = get(candidate, 'declarator', '')
  if declarator ==# '&'
    return ValidateLvalueSubscript(bufnr, candidate, node)
  endif
  if declarator ==# '*'
    return ValidatePointer(bufnr, candidate, node)
  endif
  if declarator ==# 'value'
    return ValidateCallResult(bufnr, candidate, node)
  endif
  var view = Validate(bufnr, candidate, node)
  return !empty(view) ? view : ValidateCopyConstruction(bufnr, candidate, node)
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

export def Validate(bufnr: number, candidate: any, node: any): dict<any>
  if type(candidate) != v:t_dict || type(node) != v:t_dict
      || get(node, 'role', '') !=# 'declaration'
      || get(node, 'kind', '') !=# 'Var'
      || get(node, 'detail', '') !=# get(candidate, 'identifier', 0)
      || !RangeEqual(get(node, 'range', 0), get(candidate, 'range', 1))
    return {}
  endif
  var type_node = OneChild(node, 'type')
  var expression = OneChild(node, 'expression')
  if empty(type_node) || empty(expression)
      || !RangeEqual(get(type_node, 'range', 0), get(candidate, 'type_range', 1))
      || get(type_node, 'kind', '') ==# 'Auto'
      || type(get(type_node, 'detail', 0)) != v:t_string
      || empty(type_node.detail)
      || get(expression, 'kind', '') !=# 'ImplicitCast'
      || get(expression, 'detail', '') !=# 'LValueToRValue'
    return {}
  endif
  var source = OneChild(expression, 'expression')
  if empty(source) || get(source, 'kind', '') !=# 'DeclRef'
      || get(source, 'detail', '') !=# get(candidate, 'initializer', 0)
      || !RangeEqual(get(source, 'range', 0), get(expression, 'range', 1))
    return {}
  endif
  var bytes = rangeutil.ByteRange(bufnr, type_node.range)
  if empty(bytes) || bytes.lnum != get(candidate, 'lnum', 0)
    return {}
  endif
  return types.NewView('prefer-auto', bytes.lnum, bytes.col, bytes.length, 'auto')
enddef

export def Normalize(bufnr: number, responses: any): list<dict<any>>
  if type(responses) != v:t_list
    return []
  endif
  var by_id: dict<any> = {}
  var ambiguous: dict<bool> = {}
  for response in responses
    if type(response) != v:t_dict
      continue
    endif
    var view = Validate(bufnr, get(response, 'candidate', 0), get(response, 'node', 0))
    if empty(view)
      continue
    endif
    var location = printf('%d:%d:%d', view.lnum, view.col, view.length)
    if has_key(by_id, location) && by_id[location].replacement !=# view.replacement
      ambiguous[location] = true
    else
      by_id[location] = view
    endif
  endfor
  for location in keys(ambiguous)
    remove(by_id, location)
  endfor
  return types.SortViews(values(by_id))
enddef

export def NormalizeAstProven(bufnr: number, responses: any): list<dict<any>>
  if type(responses) != v:t_list
    return []
  endif
  var by_id: dict<any> = {}
  var ambiguous: dict<bool> = {}
  for response in responses
    if type(response) != v:t_dict
      continue
    endif
    var view = ValidateAstProven(bufnr, get(response, 'candidate', 0), get(response, 'node', 0))
    if empty(view)
      continue
    endif
    var location = printf('%d:%d:%d', view.lnum, view.col, view.length)
    if has_key(by_id, location) && by_id[location].replacement !=# view.replacement
      ambiguous[location] = true
    else
      by_id[location] = view
    endif
  endfor
  for location in keys(ambiguous)
    remove(by_id, location)
  endfor
  return types.SortViews(values(by_id))
enddef
