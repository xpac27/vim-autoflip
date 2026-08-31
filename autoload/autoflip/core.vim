vim9script

import autoload 'autoflip/render.vim' as render
import autoload 'autoflip/actions.vim' as actions
import autoload 'autoflip/copies.vim' as copies
import autoload 'autoflip/hints.vim' as hints
import autoload 'autoflip/lsp.vim' as lsp
import autoload 'autoflip/range.vim' as rangeutil
import autoload 'autoflip/types.vim' as types

const MODES = ['prefer-auto', 'show-deduced-types']
const PREFER_AUTO_LEVELS = ['conservative', 'same-type-copies', 'ast-proven-locals']
const CPP_FILETYPES = ['c', 'cpp']
const CPP_EXTENSIONS = ['cc', 'cpp', 'cxx', 'h', 'hh', 'hpp', 'hxx']

def NewState(bufnr: number): dict<any>
  return {
    enabled: false,
    mode: get(g:, 'autoflip_mode', 'prefer-auto'),
    generation: 0,
    changedtick: getbufvar(bufnr, 'changedtick'),
    pending_timer: -1,
    views: {},
    windows: {},
    revealed: false,
    revealed_view_id: '',
    reveal_source: '',
    reveal_timer: -1,
    status: 'disabled',
    debug: [],
  }
enddef

export def State(bufnr: number = bufnr('%')): dict<any>
  var state = getbufvar(bufnr, 'autoflip_state', {})
  if empty(state) && bufexists(bufnr)
    state = NewState(bufnr)
    setbufvar(bufnr, 'autoflip_state', state)
  endif
  return state
enddef

def SupportedFeatures(): bool
  return has('vim9script') && has('textprop') && has('conceal') && has('channel') && has('job')
enddef

def SupportedBuffer(): bool
  if index(CPP_FILETYPES, &filetype) < 0
    return false
  endif
  var extension = tolower(expand('%:e'))
  # An unnamed cpp buffer is useful for scratch work and deterministic tests.
  return empty(extension) ? &filetype ==# 'cpp' : index(CPP_EXTENSIONS, extension) >= 0
enddef

def StopTimer(state: dict<any>, key: string)
  var timer = get(state, key, -1)
  if timer > 0
    timer_stop(timer)
  endif
  state[key] = -1
enddef

export def Enable()
  var bufnr = bufnr('%')
  var state = State(bufnr)
  if state.enabled
    render.CaptureWindow(win_getid(), state)
    return
  endif
  if !SupportedFeatures()
    state.status = 'unavailable: Vim requires +vim9script +textprop +conceal +channel +job'
    echohl ErrorMsg | echomsg 'AutoFlip: ' .. state.status | echohl None
    return
  endif
  if !SupportedBuffer()
    state.status = 'unavailable: current buffer is not a supported C++ source/header'
    echohl ErrorMsg | echomsg 'AutoFlip: ' .. state.status | echohl None
    return
  endif
  if index(MODES, state.mode) < 0
    state.mode = 'prefer-auto'
  endif
  state.enabled = true
  state.revealed = false
  state.revealed_view_id = ''
  state.reveal_source = ''
  state.generation += 1
  state.changedtick = b:changedtick
  state.status = 'enabled; waiting for refresh'
  render.CaptureWindow(win_getid(), state)
  lsp.Initialize()
  Refresh(false)
enddef

export def Disable()
  var bufnr = bufnr('%')
  var state = State(bufnr)
  StopTimer(state, 'pending_timer')
  StopTimer(state, 'reveal_timer')
  state.generation += 1
  render.Cleanup(bufnr, state)
  state.enabled = false
  state.revealed = false
  state.revealed_view_id = ''
  state.reveal_source = ''
  state.views = {}
  state.status = 'disabled'
enddef

export def Toggle()
  if State().enabled
    Disable()
  else
    Enable()
  endif
enddef

export def SetMode(mode: string)
  if index(MODES, mode) < 0
    echohl ErrorMsg | echomsg 'AutoFlip: invalid mode: ' .. mode | echohl None
    return
  endif
  var state = State()
  if state.mode ==# mode
    return
  endif
  state.mode = mode
  state.views = {}
  state.revealed = false
  state.revealed_view_id = ''
  state.reveal_source = ''
  state.generation += 1
  if state.enabled
    Refresh(true)
  endif
enddef

def PreferAutoLevel(): string
  return get(g:, 'autoflip_prefer_auto_level', 'conservative')
enddef

export def SetPreferAutoLevel(level: string)
  if index(PREFER_AUTO_LEVELS, level) < 0
    echohl ErrorMsg | echomsg 'AutoFlip: invalid prefer-auto level: ' .. level | echohl None
    return
  endif
  g:autoflip_prefer_auto_level = level
  var state = State()
  if state.mode !=# 'prefer-auto'
    return
  endif
  state.views = {}
  state.revealed = false
  state.revealed_view_id = ''
  state.reveal_source = ''
  state.generation += 1
  render.Render(bufnr('%'), state, [])
  if state.enabled
    Refresh(true)
  endif
enddef

export def Refresh(force: bool = false)
  var bufnr = bufnr('%')
  var state = State()
  if !state.enabled
    return
  endif
  var prefer_auto_level = PreferAutoLevel()
  if state.mode ==# 'prefer-auto' && index(PREFER_AUTO_LEVELS, prefer_auto_level) < 0
    state.status = 'error: invalid prefer-auto level: ' .. prefer_auto_level
    return
  endif
  StopTimer(state, 'pending_timer')
  if state.reveal_source !=# 'cursor'
    state.revealed = false
    state.revealed_view_id = ''
    state.reveal_source = ''
  endif
  if mode() =~# '^i' || pumvisible()
    state.status = 'paused: insert or completion menu active'
    return
  endif
  if !lsp.DependencyAvailable()
    state.status = 'waiting: vim-lsp is not installed'
    render.Render(bufnr, state, values(state.views))
    return
  endif
  lsp.Initialize()
  if !lsp.IsAttached(bufnr)
    state.status = 'waiting: no running clangd server is attached'
    render.Render(bufnr, state, values(state.views))
    return
  endif
  if state.mode ==# 'prefer-auto' && !lsp.SupportsCodeAction(bufnr)
    state.status = 'waiting: clangd does not advertise code actions'
    return
  endif
  if state.mode ==# 'prefer-auto' && prefer_auto_level !=# 'conservative'
      && !lsp.SupportsAst(bufnr)
    state.status = 'waiting: clangd does not advertise AST support'
    return
  endif
  if state.mode ==# 'show-deduced-types' && !lsp.SupportsInlayHints(bufnr)
    state.status = 'waiting: clangd does not advertise inlay hints'
    return
  endif
  var requested = VisibleRange()
  state.generation += 1
  state.changedtick = b:changedtick
  var generation = state.generation
  var changedtick = state.changedtick
  var request_mode = state.mode
  state.status = force ? 'enabled; refresh requested' : 'enabled; request pending'
  var Callback = (response) => HandleReply(bufnr, generation, changedtick,
    request_mode, prefer_auto_level, requested, response)
  if request_mode ==# 'prefer-auto'
    if prefer_auto_level !=# 'conservative'
      var candidates = prefer_auto_level ==# 'same-type-copies'
        ? copies.Candidates(bufnr, requested,
          max([0, get(g:, 'autoflip_max_ast_requests', 40)]))
        : copies.AstProvenCandidates(bufnr, requested,
        max([0, get(g:, 'autoflip_max_ast_requests', 40)]))
      lsp.RequestPreferAuto(bufnr, requested, candidates, Callback)
    else
      lsp.RequestCodeActions(bufnr, requested, Callback)
    endif
  else
    lsp.RequestInlayHints(bufnr, requested, Callback)
  endif
enddef

def VisibleRange(): dict<any>
  var first = max([1, line('w0') - 5])
  var last = min([line('$'), line('w$') + 5])
  var maximum = max([1, get(g:, 'autoflip_max_visible_lines', 300)])
  if last - first + 1 > maximum
    last = first + maximum - 1
  endif
  var last_line = getline(last)
  return {
    start: {line: first - 1, character: 0},
    end: {line: last - 1, character: rangeutil.Utf16Length(last_line)},
  }
enddef

def ViewInside(view: dict<any>, requested: dict<any>): bool
  var line0 = view.lnum - 1
  return line0 >= requested.start.line && line0 <= requested.end.line
enddef

def HandleReply(
    bufnr: number,
    generation: number,
    changedtick: number,
    request_mode: string,
    prefer_auto_level: string,
    requested: dict<any>,
    response: any)
  if !bufexists(bufnr)
    return
  endif
  var state = State(bufnr)
  if !state.enabled || state.generation != generation
      || state.changedtick != changedtick
      || getbufvar(bufnr, 'changedtick') != changedtick
      || state.mode !=# request_mode
      || (request_mode ==# 'prefer-auto' && PreferAutoLevel() !=# prefer_auto_level)

    add(state.debug, 'discarded stale ' .. request_mode .. ' response')
    return
  endif
  if type(response) != v:t_dict || !get(response, 'ok', false)
    state.status = 'error: ' .. get(response, 'error', 'malformed LSP response')
    return
  endif
  var fresh: list<dict<any>>
  var ast_errors = 0
  if request_mode ==# 'prefer-auto'
    if prefer_auto_level !=# 'conservative'
      var result = get(response, 'result', 0)
      if type(result) != v:t_dict
        state.status = 'error: malformed combined prefer-auto response'
        return
      endif
      fresh = MergeViews([
        actions.Normalize(bufnr, lsp.CurrentUri(bufnr), requested, get(result, 'actions', [])),
        prefer_auto_level ==# 'same-type-copies'
          ? copies.Normalize(bufnr, get(result, 'copies', []))
          : copies.NormalizeAstProven(bufnr, get(result, 'copies', [])),
      ])
      ast_errors = get(result, 'ast_errors', 0)
    else
      fresh = actions.Normalize(bufnr, lsp.CurrentUri(bufnr), requested, get(response, 'result', []))
    endif
  else
    fresh = hints.Normalize(bufnr, requested, get(response, 'result', []),
      get(g:, 'autoflip_type_name_limit', 80))
  endif
  for id in keys(copy(state.views))
    if ViewInside(state.views[id], requested)
      remove(state.views, id)
    endif
  endfor
  for view in fresh
    state.views[view.id] = view
  endfor
  state.status = printf('enabled; clangd response accepted (%d substitutions%s)', len(fresh),
    ast_errors > 0 ? printf('; %d malformed AST replies skipped', ast_errors) : '')
  render.Render(bufnr, state, values(state.views))
enddef

def MergeViews(groups: list<list<dict<any>>>): list<dict<any>>
  var by_location: dict<any> = {}
  var ambiguous: dict<bool> = {}
  for group in groups
    for view in group
      var location = printf('%d:%d:%d', view.lnum, view.col, view.length)
      if has_key(by_location, location) && by_location[location].replacement !=# view.replacement
        ambiguous[location] = true
      else
        by_location[location] = view
      endif
    endfor
  endfor
  for location in keys(ambiguous)
    remove(by_location, location)
  endfor
  return types.SortViews(values(by_location))
enddef

export def Reveal()
  var reveal_bufnr = bufnr('%')
  var state = State()
  if !state.enabled
    return
  endif
  StopTimer(state, 'reveal_timer')
  state.reveal_source = 'timer'
  render.Reveal(reveal_bufnr, state)
  var delay = max([get(g:, 'autoflip_debounce_ms', 300), 50])
  var generation = state.generation
  state.reveal_timer = timer_start(delay, (_) => EndReveal(reveal_bufnr, generation))
enddef

def EndReveal(bufnr: number, generation: number)
  if !bufexists(bufnr)
    return
  endif
  var state = State(bufnr)
  state.reveal_timer = -1
  if !state.enabled || state.generation != generation || state.reveal_source !=# 'timer'
    return
  endif
  state.revealed = false
  state.revealed_view_id = ''
  state.reveal_source = ''
  render.Render(bufnr, state, values(state.views))
enddef

export def OnWindowEnter()
  if index(CPP_FILETYPES, &filetype) < 0
    return
  endif
  var state = State()
  if !state.enabled
    return
  endif
  render.CaptureWindow(win_getid(), state)
  render.Render(bufnr('%'), state, values(state.views))
enddef

export def OnBufferChanged()
  var state = get(b:, 'autoflip_state', {})
  if empty(state) || !state.enabled
    return
  endif
  state.generation += 1
  state.changedtick = b:changedtick
  state.views = {}
  if state.reveal_source ==# 'cursor'
    state.revealed = false
    state.revealed_view_id = ''
    state.reveal_source = ''
  endif
  render.ClearBufferProperties(bufnr('%'))
  render.ClearMatches(state)
  StopTimer(state, 'pending_timer')
  var generation = state.generation
  state.pending_timer = timer_start(get(g:, 'autoflip_debounce_ms', 300),
    (_) => DebouncedRefresh(bufnr('%'), generation))
enddef

def DebouncedRefresh(bufnr: number, generation: number)
  if !bufexists(bufnr)
    return
  endif
  var state = State(bufnr)
  state.pending_timer = -1
  if !state.enabled || state.generation != generation || getbufvar(bufnr, 'changedtick') != state.changedtick
    return
  endif
  if bufnr == bufnr('%')
    Refresh(false)
  endif
enddef

export def OnInsertEnter()
  var state = get(b:, 'autoflip_state', {})
  if !empty(state) && state.enabled && get(g:, 'autoflip_reveal_on_insert', true)
    StopTimer(state, 'reveal_timer')
    state.reveal_source = 'insert'
    state.revealed_view_id = ''
    render.Reveal(bufnr('%'), state)
  endif
enddef

export def OnInsertLeave()
  var state = get(b:, 'autoflip_state', {})
  if !empty(state) && state.enabled
    state.revealed = false
    state.revealed_view_id = ''
    state.reveal_source = ''
    OnBufferChanged()
  endif
enddef

def ViewUnderCursor(state: dict<any>): dict<any>
  for view in values(state.views)
    if line('.') == view.lnum && col('.') >= view.col && col('.') < view.col + view.length
      return view
    endif
  endfor
  return {}
enddef

export def OnCursorMoved()
  var state = get(b:, 'autoflip_state', {})
  if empty(state) || !state.enabled || !get(g:, 'autoflip_reveal_under_cursor', true)
    return
  endif
  var view = ViewUnderCursor(state)
  if !empty(view)
    StopTimer(state, 'reveal_timer')
    state.reveal_source = 'cursor'
    if state.revealed || state.revealed_view_id !=# view.id
      state.revealed = false
      state.revealed_view_id = view.id
      render.Render(bufnr('%'), state, values(state.views))
    endif
    return
  endif
  if state.reveal_source ==# 'cursor'
    state.revealed = false
    state.revealed_view_id = ''
    state.reveal_source = ''
    render.Render(bufnr('%'), state, values(state.views))
  endif
enddef

export def OnWindowLeave()
  var state = get(b:, 'autoflip_state', {})
  if !empty(state) && state.enabled && state.reveal_source ==# 'cursor'
    state.revealed = false
    state.revealed_view_id = ''
    state.reveal_source = ''
    render.Render(bufnr('%'), state, values(state.views))
  endif
enddef

export def OnLspEvent()
  var state = get(b:, 'autoflip_state', {})
  if !empty(state) && state.enabled
    OnBufferChanged()
  endif
enddef

export def OnWindowClosed(winid: number)
  for bufnr in range(1, bufnr('$'))
    var state = getbufvar(bufnr, 'autoflip_state', {})
    if !empty(state) && has_key(state.windows, string(winid))
      render.RestoreWindow(winid, state)
    endif
  endfor
enddef

export def OnBufferWipeout(bufnr: number)
  var state = getbufvar(bufnr, 'autoflip_state', {})
  if empty(state)
    return
  endif
  StopTimer(state, 'pending_timer')
  StopTimer(state, 'reveal_timer')
  state.generation += 1
  render.Cleanup(bufnr, state)
enddef

export def Status(): string
  var state = State()
  return printf('AutoFlip: %s; mode=%s; prefer-auto-level=%s; generation=%d; changedtick=%d; substitutions=%d; windows=%d; stale=%d',
    state.status, state.mode, PreferAutoLevel(), state.generation, state.changedtick, len(state.views), len(state.windows),
    state.debug->filter((_, entry) => entry =~# '^discarded stale')->len())
enddef

export def SetViewsForTest(views: list<dict<any>>)
  var state = State()
  state.views = {}
  for view in views
    state.views[view.id] = view
  endfor
  render.Render(bufnr('%'), state, views)
enddef
