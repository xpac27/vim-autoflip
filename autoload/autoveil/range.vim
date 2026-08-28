vim9script

export def ByteCol(bufnr: number, line0: number, utf16_col: number): number
  if line0 < 0 || utf16_col < 0
    return -1
  endif
  var lines = getbufline(bufnr, line0 + 1)
  if empty(lines)
    return -1
  endif
  var text = lines[0]
  var charidx = 0
  var byteidx = 0
  var units = 0
  while byteidx < strlen(text)
    if units == utf16_col
      return byteidx + 1
    endif
    var char = strcharpart(text, charidx, 1)
    var width = char2nr(char) > 0xffff ? 2 : 1
    if units + width > utf16_col
      return -1
    endif
    units += width
    byteidx += strlen(char)
    charidx += 1
  endwhile
  return units == utf16_col ? strlen(text) + 1 : -1
enddef

export def ByteRange(bufnr: number, lsp_range: dict<any>): dict<any>
  if type(lsp_range) != v:t_dict
      || type(get(lsp_range, 'start', 0)) != v:t_dict
      || type(get(lsp_range, 'end', 0)) != v:t_dict
    return {}
  endif
  var start = lsp_range.start
  var finish = lsp_range.end
  if type(get(start, 'line', '')) != v:t_number
      || type(get(start, 'character', '')) != v:t_number
      || type(get(finish, 'line', '')) != v:t_number
      || type(get(finish, 'character', '')) != v:t_number
      || start.line != finish.line
  
    return {}
  endif
  var start_col = ByteCol(bufnr, start.line, start.character)
  var end_col = ByteCol(bufnr, finish.line, finish.character)
  if start_col <= 0 || end_col <= start_col
    return {}
  endif
  return {lnum: start.line + 1, col: start_col, end_col: end_col, length: end_col - start_col}
enddef

export def Contains(outer: dict<any>, inner: dict<any>): bool
  if empty(outer) || empty(inner)
    return false
  endif
  var outer_start = outer.start
  var outer_end = outer.end
  var inner_start = inner.start
  var inner_end = inner.end
  return (inner_start.line > outer_start.line
      || (inner_start.line == outer_start.line && inner_start.character >= outer_start.character))
      && (inner_end.line < outer_end.line
      || (inner_end.line == outer_end.line && inner_end.character <= outer_end.character))
enddef

export def PositionIn(requested: dict<any>, position: dict<any>): bool
  if type(position) != v:t_dict
      || type(get(position, 'line', '')) != v:t_number
      || type(get(position, 'character', '')) != v:t_number
      || empty(requested)
    return false
  endif
  return Contains(requested, {start: position, end: position})
enddef

