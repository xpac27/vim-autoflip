vim9script

if exists('g:loaded_autoflip')
  finish
endif
g:loaded_autoflip = true

g:autoflip_enabled_by_default = get(g:, 'autoflip_enabled_by_default', false)
g:autoflip_mode = get(g:, 'autoflip_mode', 'prefer-auto')
g:autoflip_debounce_ms = get(g:, 'autoflip_debounce_ms', 300)
g:autoflip_reveal_on_insert = get(g:, 'autoflip_reveal_on_insert', true)
g:autoflip_reveal_under_cursor = get(g:, 'autoflip_reveal_under_cursor', true)
g:autoflip_max_visible_lines = get(g:, 'autoflip_max_visible_lines', 300)
g:autoflip_type_name_limit = get(g:, 'autoflip_type_name_limit', 80)
g:autoflip_prefer_auto_level = get(g:, 'autoflip_prefer_auto_level', 'conservative')
g:autoflip_max_ast_requests = get(g:, 'autoflip_max_ast_requests', 40)

import autoload 'autoflip/core.vim' as core
import autoload 'autoflip/lsp.vim' as lsp

# Register before clangd can publish diagnostics for a startup buffer. The
# lsp_setup and Enable() calls below remain idempotent fallbacks.
lsp.Initialize()

command! -bar AutoFlipEnable core.Enable()
command! -bar AutoFlipDisable core.Disable()
command! -bar AutoFlipToggle core.Toggle()
command! -bar -nargs=1 -complete=customlist,autoflip#ModeComplete AutoFlipMode core.SetMode(<q-args>)
command! -bar -nargs=1 -complete=customlist,autoflip#PreferAutoLevelComplete AutoFlipPreferAutoLevel core.SetPreferAutoLevel(<q-args>)
command! -bar AutoFlipRefresh core.Refresh(true)
command! -bar AutoFlipReveal core.Reveal()
command! -bar AutoFlipStatus echo core.Status()

highlight default link AutoFlipAuto Type
highlight default link AutoFlipDeducedType Type

augroup autoflip
  autocmd!
  autocmd FileType c,cpp if g:autoflip_enabled_by_default | core.Enable() | endif
  autocmd BufEnter,WinEnter * core.OnWindowEnter()
  autocmd TextChanged,TextChangedI * core.OnBufferChanged()
  autocmd InsertEnter * core.OnInsertEnter()
  autocmd InsertLeave * core.OnInsertLeave()
  autocmd CursorMoved * core.OnCursorMoved()
  autocmd WinLeave * core.OnWindowLeave()
  autocmd BufWipeout * core.OnBufferWipeout(str2nr(expand('<abuf>')))
  autocmd WinClosed * core.OnWindowClosed(str2nr(expand('<amatch>')))
  autocmd User lsp_buffer_enabled,lsp_diagnostics_updated core.OnLspEvent()
  autocmd User lsp_setup lsp.Initialize()
augroup END
