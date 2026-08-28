vim9script

export def NewView(
    kind: string,
    lnum: number,
    col: number,
    length: number,
    replacement: string): dict<any>
  return {
    id: printf('%s:%d:%d:%d:%s', kind, lnum, col, length, replacement),
    kind: kind,
    lnum: lnum,
    col: col,
    length: length,
    replacement: replacement,
  }
enddef

export def IsView(value: any): bool
  if type(value) != v:t_dict
    return false
  endif
  for key in ['id', 'kind', 'lnum', 'col', 'length', 'replacement']
    if !has_key(value, key)
      return false
    endif
  endfor
  return index(['prefer-auto', 'show-deduced-types'], value.kind) >= 0
      && type(value.lnum) == v:t_number && value.lnum > 0
      && type(value.col) == v:t_number && value.col > 0
      && type(value.length) == v:t_number && value.length > 0
      && type(value.replacement) == v:t_string && !empty(value.replacement)
enddef

export def SortViews(views: list<dict<any>>): list<dict<any>>
  return views->sort((a, b) => a.lnum == b.lnum ? a.col - b.col : a.lnum - b.lnum)
enddef

