set nocompatible
set nomore
set noswapfile
set encoding=utf-8
execute 'set runtimepath^=' .. fnameescape($AUTOFLIP_VIM_LSP)
execute 'set runtimepath^=' .. fnameescape($AUTOFLIP_TEST_ROOT)
let g:lsp_inlay_hints_enabled = 0
runtime plugin/lsp.vim
runtime plugin/autoflip.vim

call lsp#register_server({
      \ 'name': 'clangd-autoflip-integration',
      \ 'cmd': {server_info -> ['clangd', '--clang-tidy', '--background-index=0']},
      \ 'allowlist': ['cpp'],
      \ })

execute 'edit ' .. fnameescape($AUTOFLIP_TEST_ROOT .. '/test/fixtures/integration.cpp')
setlocal filetype=cpp
let s:before = getline(1, '$')
setlocal nomodified
let g:autoflip_integration_diagnostics_ready = 0
augroup autoflip_integration_diagnostics
  autocmd!
  autocmd User lsp_diagnostics_updated let g:autoflip_integration_diagnostics_ready = 1
augroup END
call lsp#activate()

let s:remaining = 500
while s:remaining > 0 && !lsp#is_server_running('clangd-autoflip-integration')
  sleep 20m
  let s:remaining -= 1
endwhile
if !lsp#is_server_running('clangd-autoflip-integration')
  call writefile(['FAIL: clangd did not attach'], '/dev/stderr')
  cquit
endif

let s:remaining = 500
while s:remaining > 0 && !g:autoflip_integration_diagnostics_ready
  sleep 20m
  let s:remaining -= 1
endwhile
if !g:autoflip_integration_diagnostics_ready
  call writefile(['FAIL: clangd did not publish diagnostics before delayed enable'], '/dev/stderr')
  cquit
endif

" Enabling after diagnostics were published must retain the cached clang-tidy
" authority needed by the later prefer-auto request.
AutoFlipMode show-deduced-types
AutoFlipEnable
AutoFlipRefresh
let s:remaining = 500
while s:remaining > 0 && len(get(get(b:, 'autoflip_state', {}), 'views', {})) == 0
  sleep 20m
  let s:remaining -= 1
endwhile

if len(get(get(b:, 'autoflip_state', {}), 'views', {})) == 0
  call writefile(['FAIL: no real clangd type view; ' .. execute('AutoFlipStatus')->trim()], '/dev/stderr')
  cquit
endif
let s:deduced = values(b:autoflip_state.views)
if empty(filter(copy(s:deduced), {_, view -> view.replacement ==# 'int'}))
  call writefile(['FAIL: real clangd deduced type was not int'], '/dev/stderr')
  cquit
endif

AutoFlipMode prefer-auto
let s:remaining = 500
while s:remaining > 0 && len(get(get(b:, 'autoflip_state', {}), 'views', {})) == 0
  sleep 20m
  let s:remaining -= 1
endwhile
if len(get(get(b:, 'autoflip_state', {}), 'views', {})) == 0
  call writefile(['FAIL: no real modernize-use-auto view; ' .. execute('AutoFlipStatus')->trim()], '/dev/stderr')
  cquit
endif
let s:preferred = values(b:autoflip_state.views)
if empty(filter(copy(s:preferred), {_, view -> view.replacement =~# '\<auto\>'}))
  call writefile(['FAIL: real clang-tidy replacement did not contain auto'], '/dev/stderr')
  cquit
endif

AutoFlipPreferAutoLevel same-type-copies
let s:copy_line = search('IntegrationState copied = state;', 'nw')
let s:copy_again_line = search('IntegrationState copied_again = copied;', 'nw')
let s:remaining = 500
while s:remaining > 0
  let s:copy_views = filter(values(get(get(b:, 'autoflip_state', {}), 'views', {})),
        \ {_, view -> (view.lnum == s:copy_line || view.lnum == s:copy_again_line)
        \   && view.replacement ==# 'auto'})
  if len(s:copy_views) == 2
    break
  endif
  sleep 20m
  let s:remaining -= 1
endwhile
if len(get(s:, 'copy_views', [])) != 2
  call writefile(['FAIL: real clangd AST did not render both same-type copy views; ' .. execute('AutoFlipStatus')->trim()], '/dev/stderr')
  cquit
endif
if s:copy_views[0].length != strlen('IntegrationState')
  call writefile(['FAIL: AST copy view did not cover the explicit type'], '/dev/stderr')
  cquit
endif
let s:selected_copy = filter(copy(s:copy_views), {_, view -> view.lnum == s:copy_line})[0]
call cursor(s:copy_line, s:selected_copy.col)
doautocmd CursorMoved
call assert_equal([], filter(prop_list(s:copy_line), {_, prop -> prop.type =~# '^autoflip_'}))
call assert_equal(1, len(filter(prop_list(s:copy_again_line), {_, prop -> prop.type =~# '^autoflip_'})))
call cursor(s:copy_line, s:selected_copy.col + s:selected_copy.length)
doautocmd CursorMoved
call assert_equal(1, len(filter(prop_list(s:copy_line), {_, prop -> prop.type =~# '^autoflip_'})))
call assert_equal(1, len(filter(prop_list(s:copy_again_line), {_, prop -> prop.type =~# '^autoflip_'})))
call assert_equal(s:before, getline(1, '$'))
call assert_false(&modified)
if !empty(v:errors)
  call writefile(v:errors, '/dev/stderr')
  cquit
endif
call writefile(['PASS: real clangd views and selective cursor reveal rendered display-only'], '/dev/stdout')
AutoFlipDisable
qall!
