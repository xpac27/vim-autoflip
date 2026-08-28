vim9script

import autoload 'autoflip/range.vim' as rangeutil
import autoload 'autoflip/syntax.vim' as syntax
import autoload 'autoflip/types.vim' as types

export def IsAutoSpelling(text: string): bool
  var spelling = trim(text)
  if spelling =~# '[\r\n\t]'
    return false
  endif
  return spelling =~# '^\%(const\s\+\)\?\%(volatile\s\+\)\?auto\%(\s*\*\)*\s*\%(&&\|&\)\?\s*$'
enddef

export def IsModernizeDiagnostic(diagnostic: any): bool
  if type(diagnostic) != v:t_dict
    return false
  endif
  var code = get(diagnostic, 'code', '')
  if type(code) == v:t_dict
    code = get(code, 'value', '')
  endif
  var source = get(diagnostic, 'source', '')
  var message = get(diagnostic, 'message', '')
  return (type(code) == v:t_string && code ==# 'modernize-use-auto')
      || (source ==# 'clang-tidy' && type(message) == v:t_string
        && message =~# '\[modernize-use-auto\]')
enddef

def OneEdit(action: dict<any>, current_uri: string): dict<any>
  var edit = get(action, 'edit', {})
  if type(edit) != v:t_dict || empty(edit)
    return {}
  endif
  if has_key(edit, 'changes') && has_key(edit, 'documentChanges')
    return {}
  endif
  if has_key(edit, 'changes')
    if type(edit.changes) != v:t_dict || len(keys(edit.changes)) != 1
        || !has_key(edit.changes, current_uri)
        || type(edit.changes[current_uri]) != v:t_list
        || len(edit.changes[current_uri]) != 1
      return {}
    endif
    return edit.changes[current_uri][0]
  endif
  if has_key(edit, 'documentChanges')
    if type(edit.documentChanges) != v:t_list || len(edit.documentChanges) != 1
      return {}
    endif
    var document_edit = edit.documentChanges[0]
    if type(document_edit) != v:t_dict
        || get(get(document_edit, 'textDocument', {}), 'uri', '') !=# current_uri
        || type(get(document_edit, 'edits', 0)) != v:t_list
        || len(document_edit.edits) != 1
      return {}
    endif
    return document_edit.edits[0]
  endif
  return {}
enddef

def LexicallySafe(bufnr: number, bytes: dict<any>): bool
  var line = syntax.SafeDeclarationLine(bufnr, bytes.lnum)
  if empty(line) || bytes.col + bytes.length - 1 > strlen(line)
    return false
  endif
  var original = strpart(line, bytes.col - 1, bytes.length)
  if empty(trim(original)) || original =~# '[{};=]'
    return false
  endif
  var before = strpart(line, 0, bytes.col - 1)
  var after = strpart(line, bytes.col - 1 + bytes.length)
  if before =~# '\<\%(using\|typedef\|template\|return\)\>\s*$'
    return false
  endif
  if after !~# '^\s\+\h\w*\s*\%(=\|{\)'
    return false
  endif
  return syntax.IsLocal(bufnr, bytes.lnum, bytes.col)
enddef

export def Validate(
    bufnr: number,
    current_uri: string,
    requested: dict<any>,
    action: any): dict<any>
  if type(action) != v:t_dict
      || has_key(action, 'disabled')
      || type(get(action, 'diagnostics', 0)) != v:t_list
      || empty(action.diagnostics->filter((_, diagnostic) => IsModernizeDiagnostic(diagnostic)))
    return {}
  endif
  var edit = OneEdit(action, current_uri)
  if empty(edit) || type(get(edit, 'range', 0)) != v:t_dict
      || type(get(edit, 'newText', 0)) != v:t_string
      || !rangeutil.Contains(requested, edit.range)
      || !IsAutoSpelling(edit.newText)
    return {}
  endif
  var bytes = rangeutil.ByteRange(bufnr, edit.range)
  if empty(bytes) || !LexicallySafe(bufnr, bytes)
    return {}
  endif
  return types.NewView('prefer-auto', bytes.lnum, bytes.col, bytes.length, trim(edit.newText))
enddef

export def Normalize(
    bufnr: number,
    current_uri: string,
    requested: dict<any>,
    actions: any): list<dict<any>>
  if type(actions) != v:t_list
    return []
  endif
  var by_id: dict<any> = {}
  var ambiguous: dict<bool> = {}
  for action in actions
    var view = Validate(bufnr, current_uri, requested, action)
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
