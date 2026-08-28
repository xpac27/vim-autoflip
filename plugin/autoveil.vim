vim9script

if exists('g:loaded_autoveil')
  finish
endif
g:loaded_autoveil = true

g:autoveil_enabled_by_default = get(g:, 'autoveil_enabled_by_default', false)
g:autoveil_mode = get(g:, 'autoveil_mode', 'prefer-auto')
g:autoveil_debounce_ms = get(g:, 'autoveil_debounce_ms', 300)
g:autoveil_reveal_on_insert = get(g:, 'autoveil_reveal_on_insert', true)
g:autoveil_reveal_under_cursor = get(g:, 'autoveil_reveal_under_cursor', true)
g:autoveil_max_visible_lines = get(g:, 'autoveil_max_visible_lines', 300)
g:autoveil_type_name_limit = get(g:, 'autoveil_type_name_limit', 80)

import autoload 'autoveil/core.vim' as core
import autoload 'autoveil/lsp.vim' as lsp

command! -bar AutoVeilEnable core.Enable()
command! -bar AutoVeilDisable core.Disable()
command! -bar AutoVeilToggle core.Toggle()
command! -bar -nargs=1 -complete=customlist,autoveil#ModeComplete AutoVeilMode core.SetMode(<q-args>)
command! -bar AutoVeilRefresh core.Refresh(true)
command! -bar AutoVeilReveal core.Reveal()
command! -bar AutoVeilStatus echo core.Status()

highlight default link AutoVeilAuto Type
highlight default link AutoVeilDeducedType Type

augroup autoveil
  autocmd!
  autocmd FileType c,cpp if g:autoveil_enabled_by_default | core.Enable() | endif
  autocmd BufEnter,WinEnter * core.OnWindowEnter()
  autocmd TextChanged,TextChangedI * core.OnBufferChanged()
  autocmd InsertEnter * core.OnInsertEnter()
  autocmd InsertLeave * core.OnInsertLeave()
  autocmd CursorMoved * core.OnCursorMoved()
  autocmd BufWipeout * core.OnBufferWipeout(str2nr(expand('<abuf>')))
  autocmd WinClosed * core.OnWindowClosed(str2nr(expand('<amatch>')))
  autocmd User lsp_buffer_enabled,lsp_diagnostics_updated core.OnLspEvent()
  autocmd User lsp_setup lsp.Initialize()
augroup END
