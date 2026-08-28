vim9script

import autoload 'autoveil/range.vim' as rangeutil
import autoload 'autoveil/syntax.vim' as syntax
import autoload 'autoveil/types.vim' as types

const SIMPLE_COPY = '^\(\s*\)\([_a-zA-Z][_a-zA-Z0-9:<> ]*\)\s\+\(\h\w*\)\s*=\s*\(\h\w*\)\s*;\s*$'
const DISALLOWED_TYPE_WORDS = ['auto', 'const', 'volatile', 'static', 'thread_local',
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
