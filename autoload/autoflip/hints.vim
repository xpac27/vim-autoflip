vim9script

import autoload 'autoflip/range.vim' as rangeutil
import autoload 'autoflip/syntax.vim' as syntax
import autoload 'autoflip/types.vim' as types

def LabelText(label: any): string
  if type(label) == v:t_string
    return label
  endif
  if type(label) != v:t_list
    return ''
  endif
  var result = ''
  for part in label
    if type(part) != v:t_dict || type(get(part, 'value', 0)) != v:t_string
      return ''
    endif
    result ..= part.value
  endfor
  return result
enddef

export def TypeLabel(label: any, limit: number): string
  var text = LabelText(label)
  if text =~# '^:\s*'
    text = substitute(text, '^:\s*', '', '')
  endif
  text = trim(text)
  if empty(text) || strlen(text) > limit || text =~# '[\r\n\t]' || text =~# '\.\.\.'
    return ''
  endif
  if text =~# '\<auto\>' || text !~# '^[-+_a-zA-Z0-9:<> ,*&()\[\]]\+$'
    return ''
  endif
  return text
enddef

def DeclarationAt(bufnr: number, lnum: number, hint_col: number): dict<any>
  var line = syntax.SafeDeclarationLine(bufnr, lnum)
  if empty(line)
    return {}
  endif
  var pattern = '\C\%(^\s*\|[;{}]\s*\)\zs\%\(const\s\+\)\?\%\(volatile\s\+\)\?auto\%\(\s*\*\)*\s*\%\(&&\|&\)\?\ze\s\+\h\w*\s*='
  var candidates: list<dict<any>> = []
  var start = 0
  while start < strlen(line)
    var found = matchstrpos(line, pattern, start)
    if found[1] < 0
      break
    endif
    var type_start = found[1]
    var type_end = found[2]
    var after = strpart(line, type_end)
    var identifier = matchstr(after, '^\s\+\zs\h\w*\ze\s*=')
    var relative = match(after, '\h\w*')
    if !empty(identifier) && relative >= 0
      var id_col = type_end + relative + 1
      var hint_at_start = hint_col == id_col
      var hint_at_end = hint_col == id_col + strlen(identifier)
      if (hint_at_start || hint_at_end) && syntax.IsLocal(bufnr, lnum, type_start + 1)
        add(candidates, {
          lnum: lnum,
          col: type_start + 1,
          length: type_end - type_start,
          identifier: identifier,
        })
      endif
    endif
    start = max([type_end, start + 1])
  endwhile
  return len(candidates) == 1 ? candidates[0] : {}
enddef

export def Validate(
    bufnr: number,
    requested: dict<any>,
    hint: any,
    limit: number): dict<any>
  if type(hint) != v:t_dict || get(hint, 'kind', 0) != 1
      || !rangeutil.PositionIn(requested, get(hint, 'position', {}))

    return {}
  endif
  var replacement = TypeLabel(get(hint, 'label', ''), limit)
  if empty(replacement)
    return {}
  endif
  var position = hint.position
  var hint_col = rangeutil.ByteCol(bufnr, position.line, position.character)
  if hint_col <= 0
    return {}
  endif
  var declaration = DeclarationAt(bufnr, position.line + 1, hint_col)
  if empty(declaration)
    return {}
  endif
  return types.NewView('show-deduced-types', declaration.lnum, declaration.col,
    declaration.length, replacement)
enddef

export def Normalize(
    bufnr: number,
    requested: dict<any>,
    hints: any,
    limit: number): list<dict<any>>
  if type(hints) != v:t_list
    return []
  endif
  var by_location: dict<any> = {}
  var ambiguous: dict<bool> = {}
  for hint in hints
    var view = Validate(bufnr, requested, hint, limit)
    if empty(view)
      continue
    endif
    var location = printf('%d:%d:%d', view.lnum, view.col, view.length)
    if has_key(by_location, location) && by_location[location].replacement !=# view.replacement
      ambiguous[location] = true
    else
      by_location[location] = view
    endif
  endfor
  for location in keys(ambiguous)
    remove(by_location, location)
  endfor
  return types.SortViews(values(by_location))
enddef
