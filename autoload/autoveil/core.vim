vim9script

import autoload 'autoveil/render.vim' as render

const MODES = ['prefer-auto', 'show-deduced-types']
const CPP_FILETYPES = ['c', 'cpp']

def NewState(): dict<any>
  return {
    enabled: false,
    mode: get(g:, 'autoveil_mode', 'prefer-auto'),
    generation: 0,
    changedtick: b:changedtick,
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
    state = NewState()
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

def CurrentWindowFor(bufnr: number): number
  return bufnr == bufnr('%') ? win_getid() : -1
enddef

export def Enable()
  var bufnr = bufnr('%')
  var state = State(bufnr)
  if state.enabled
    render.CaptureWindow(win_getid(), state)
    render.ConfigureWindow(win_getid(), state)
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
  render.ConfigureWindow(win_getid(), state)
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
  var state = State()
  if !state.enabled
    return
  endif
  StopTimer(state, 'pending_timer')
  state.revealed = false
  state.status = force ? 'enabled; refresh requested' : 'enabled; refresh scheduled'
  # The LSP request pipeline is installed in the adapter phase.
  render.Render(bufnr('%'), state, values(state.views))
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
  render.ConfigureWindow(win_getid(), state)
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
  return printf('AutoVeil: %s; mode=%s; generation=%d; changedtick=%d; substitutions=%d; windows=%d',
    state.status, state.mode, state.generation, state.changedtick, len(state.views), len(state.windows))
enddef

export def SetViewsForTest(views: list<dict<any>>)
  var state = State()
  state.views = {}
  for view in views
    state.views[view.id] = view
  endfor
  render.Render(bufnr('%'), state, views)
enddef

