vim9script

const AUTO_PROP = 'autoveil_auto'
const DEDUCED_PROP = 'autoveil_deduced'

def EnsureTypes(bufnr: number)
  if empty(prop_type_get(AUTO_PROP, {bufnr: bufnr}))
    prop_type_add(AUTO_PROP, {bufnr: bufnr, highlight: 'AutoVeilAuto'})
  endif
  if empty(prop_type_get(DEDUCED_PROP, {bufnr: bufnr}))
    prop_type_add(DEDUCED_PROP, {bufnr: bufnr, highlight: 'AutoVeilDeducedType'})
  endif
enddef

export def CaptureWindow(winid: number, state: dict<any>)
  if winid <= 0 || win_id2win(winid) == 0 || has_key(state.windows, string(winid))
    return
  endif
  var conceallevel = getwinvar(winid, '&conceallevel')
  var concealcursor = getwinvar(winid, '&concealcursor')
  # A split made from an already-rendering window inherits our temporary
  # values.  Its restoration baseline must be the source window's baseline.
  if !empty(state.windows) && conceallevel == 3 && concealcursor ==# 'niv'
    var baseline = values(state.windows)[0]
    conceallevel = baseline.conceallevel
    concealcursor = baseline.concealcursor
  endif
  state.windows[string(winid)] = {
    conceallevel: conceallevel,
    concealcursor: concealcursor,
    match_ids: [],
  }
enddef

export def ConfigureWindow(winid: number, state: dict<any>)
  CaptureWindow(winid, state)
  if !has_key(state.windows, string(winid))
    return
  endif
  setwinvar(winid, '&conceallevel', 3)
  setwinvar(winid, '&concealcursor', 'niv')
enddef

def DeleteMatches(winid: number, winstate: dict<any>)
  if win_id2win(winid) != 0
    for id in get(winstate, 'match_ids', [])
      try
        matchdelete(id, winid)
      catch /^Vim\%((\a\+)\)\=:E803:/
      endtry
    endfor
  endif
  winstate.match_ids = []
enddef

export def ClearBufferProperties(bufnr: number)
  if !bufexists(bufnr)
    return
  endif
  for name in [AUTO_PROP, DEDUCED_PROP]
    if !empty(prop_type_get(name, {bufnr: bufnr}))
      prop_remove({bufnr: bufnr, type: name, all: true})
    endif
  endfor
enddef

export def ClearMatches(state: dict<any>)
  for [key, winstate] in items(state.windows)
    DeleteMatches(str2nr(key), winstate)
  endfor
enddef

export def Render(bufnr: number, state: dict<any>, views: list<dict<any>>)
  ClearBufferProperties(bufnr)
  ClearMatches(state)
  if state.revealed || empty(views) || !bufexists(bufnr)
    return
  endif
  var hidden_id = get(state, 'revealed_view_id', '')
  var rendered = views->copy()->filter((_, view) => view.id !=# hidden_id)
  if empty(rendered)
    return
  endif
  EnsureTypes(bufnr)
  for view in rendered
    var propname = view.kind ==# 'prefer-auto' ? AUTO_PROP : DEDUCED_PROP
    prop_add(view.lnum, view.col, {
      bufnr: bufnr,
      type: propname,
      text: view.replacement,
    })
  endfor
  for [key, winstate] in items(state.windows)
    var winid = str2nr(key)
    if win_id2win(winid) == 0 || winbufnr(winid) != bufnr
      continue
    endif
    ConfigureWindow(winid, state)
    for view in rendered
      var id = matchaddpos('Conceal', [[view.lnum, view.col, view.length]], 100, -1,
        {conceal: '', window: winid})
      if id > 0
        add(winstate.match_ids, id)
      endif
    endfor
  endfor
enddef

export def Reveal(bufnr: number, state: dict<any>)
  state.revealed = true
  state.revealed_view_id = ''
  ClearBufferProperties(bufnr)
  ClearMatches(state)
enddef

export def RestoreWindow(winid: number, state: dict<any>)
  var key = string(winid)
  if !has_key(state.windows, key)
    return
  endif
  var winstate = state.windows[key]
  DeleteMatches(winid, winstate)
  if win_id2win(winid) != 0
    setwinvar(winid, '&conceallevel', winstate.conceallevel)
    setwinvar(winid, '&concealcursor', winstate.concealcursor)
  endif
  remove(state.windows, key)
enddef

export def Cleanup(bufnr: number, state: dict<any>)
  ClearBufferProperties(bufnr)
  for key in keys(copy(state.windows))
    RestoreWindow(str2nr(key), state)
  endfor
enddef

export def PropertyNames(): list<string>
  return [AUTO_PROP, DEDUCED_PROP]
enddef
