vim9script

import autoload 'autoveil/render.vim' as render
import autoload 'autoveil/actions.vim' as actions
import autoload 'autoveil/hints.vim' as hints
import autoload 'autoveil/lsp.vim' as lsp
import autoload 'autoveil/range.vim' as rangeutil

const MODES = ['prefer-auto', 'show-deduced-types']
const CPP_FILETYPES = ['c', 'cpp']

def NewState(bufnr: number): dict<any>
  return {
    enabled: false,
    mode: get(g:, 'autoveil_mode', 'prefer-auto'),
    generation: 0,
    changedtick: getbufvar(bufnr, 'changedtick'),
    pending_timer: -1,
    views: {},
    windows: {},
    revealed: false,
    reveal_timer: -1,
    status: 'disabled',
    debug: [],
  }
enddef

export def State(bufnr: number = bufnr('%')): dict<any>
  var state = getbufvar(bufnr, 'autoveil_state', {})
  if empty(state) && bufexists(bufnr)
    state = NewState(bufnr)
    setbufvar(bufnr, 'autoveil_state', state)
  endif
  return state
enddef

def SupportedFeatures(): bool
  return has('vim9script') && has('textprop') && has('conceal') && has('channel') && has('job')
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
    echohl ErrorMsg | echomsg 'AutoVeil: ' .. state.status | echohl None
    return
  endif
  if index(CPP_FILETYPES, &filetype) < 0
    state.status = 'unavailable: current buffer is not C or C++'
    echohl ErrorMsg | echomsg 'AutoVeil: ' .. state.status | echohl None
    return
  endif
  if index(MODES, state.mode) < 0
    state.mode = 'prefer-auto'
  endif
  state.enabled = true
  state.revealed = false
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
    echohl ErrorMsg | echomsg 'AutoVeil: invalid mode: ' .. mode | echohl None
    return
  endif
  var state = State()
  if state.mode ==# mode
    return
  endif
  state.mode = mode
  state.views = {}
  state.generation += 1
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
  StopTimer(state, 'pending_timer')
  state.revealed = false
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
    request_mode, requested, response)
  if request_mode ==# 'prefer-auto'
    lsp.RequestCodeActions(bufnr, requested, Callback)
  else
    lsp.RequestInlayHints(bufnr, requested, Callback)
  endif
enddef

def VisibleRange(): dict<any>
  var first = max([1, line('w0') - 5])
  var last = min([line('$'), line('w$') + 5])
  var maximum = max([1, get(g:, 'autoveil_max_visible_lines', 300)])
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

    add(state.debug, 'discarded stale ' .. request_mode .. ' response')
    return
  endif
  if type(response) != v:t_dict || !get(response, 'ok', false)
    state.status = 'error: ' .. get(response, 'error', 'malformed LSP response')
    return
  endif
  var fresh: list<dict<any>>
  if request_mode ==# 'prefer-auto'
    fresh = actions.Normalize(bufnr, lsp.CurrentUri(bufnr), requested, get(response, 'result', []))
  else
    fresh = hints.Normalize(bufnr, requested, get(response, 'result', []),
      get(g:, 'autoveil_type_name_limit', 80))
  endif
  for id in keys(copy(state.views))
    if ViewInside(state.views[id], requested)
      remove(state.views, id)
    endif
  endfor
  for view in fresh
    state.views[view.id] = view
  endfor
  state.status = printf('enabled; clangd response accepted (%d substitutions)', len(fresh))
  render.Render(bufnr, state, values(state.views))
enddef

export def Reveal()
  var state = State()
  if !state.enabled
    return
  endif
  StopTimer(state, 'reveal_timer')
  render.Reveal(bufnr('%'), state)
  var delay = max([get(g:, 'autoveil_debounce_ms', 300), 50])
  state.reveal_timer = timer_start(delay, (_) => EndReveal(bufnr('%'), state.generation))
enddef

def EndReveal(bufnr: number, generation: number)
  if !bufexists(bufnr)
    return
  endif
  var state = State(bufnr)
  state.reveal_timer = -1
  if !state.enabled || state.generation != generation
    return
  endif
  state.revealed = false
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
  var state = get(b:, 'autoveil_state', {})
  if empty(state) || !state.enabled
    return
  endif
  state.generation += 1
  state.changedtick = b:changedtick
  state.views = {}
  render.ClearBufferProperties(bufnr('%'))
  render.ClearMatches(state)
  StopTimer(state, 'pending_timer')
  var generation = state.generation
  state.pending_timer = timer_start(get(g:, 'autoveil_debounce_ms', 300),
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
  var state = get(b:, 'autoveil_state', {})
  if !empty(state) && state.enabled && get(g:, 'autoveil_reveal_on_insert', true)
    StopTimer(state, 'reveal_timer')
    render.Reveal(bufnr('%'), state)
  endif
enddef

export def OnInsertLeave()
  var state = get(b:, 'autoveil_state', {})
  if !empty(state) && state.enabled
    state.revealed = false
    OnBufferChanged()
  endif
enddef

export def OnCursorMoved()
  var state = get(b:, 'autoveil_state', {})
  if empty(state) || !state.enabled || !get(g:, 'autoveil_reveal_under_cursor', true)
    return
  endif
  for view in values(state.views)
    if line('.') == view.lnum && col('.') >= view.col && col('.') < view.col + view.length
      Reveal()
      return
    endif
  endfor
enddef

export def OnLspEvent()
  var state = get(b:, 'autoveil_state', {})
  if !empty(state) && state.enabled
    OnBufferChanged()
  endif
enddef

export def OnWindowClosed(winid: number)
  for bufnr in range(1, bufnr('$'))
    var state = getbufvar(bufnr, 'autoveil_state', {})
    if !empty(state) && has_key(state.windows, string(winid))
      render.RestoreWindow(winid, state)
    endif
  endfor
enddef

export def OnBufferWipeout(bufnr: number)
  var state = getbufvar(bufnr, 'autoveil_state', {})
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
  return printf('AutoVeil: %s; mode=%s; generation=%d; changedtick=%d; substitutions=%d; windows=%d; stale=%d',
    state.status, state.mode, state.generation, state.changedtick, len(state.views), len(state.windows),
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
