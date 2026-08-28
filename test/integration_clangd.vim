set nocompatible
set nomore
set noswapfile
set encoding=utf-8
execute 'set runtimepath^=' .. fnameescape($AUTOVEIL_VIM_LSP)
execute 'set runtimepath^=' .. fnameescape($AUTOVEIL_TEST_ROOT)
let g:lsp_inlay_hints_enabled = 0
runtime plugin/lsp.vim
runtime plugin/autoveil.vim

call lsp#register_server({
      \ 'name': 'clangd-autoveil-integration',
      \ 'cmd': {server_info -> ['clangd', '--clang-tidy', '--background-index=0']},
      \ 'allowlist': ['cpp'],
      \ })

execute 'edit ' .. fnameescape($AUTOVEIL_TEST_ROOT .. '/test/fixtures/integration.cpp')
setlocal filetype=cpp
let s:before = getline(1, '$')
setlocal nomodified
AutoVeilMode show-deduced-types
AutoVeilEnable
call lsp#activate()

let s:remaining = 500
while s:remaining > 0 && !lsp#is_server_running('clangd-autoveil-integration')
  sleep 20m
  let s:remaining -= 1
endwhile
if !lsp#is_server_running('clangd-autoveil-integration')
  call writefile(['FAIL: clangd did not attach'], '/dev/stderr')
  cquit
endif

AutoVeilRefresh
let s:remaining = 500
while s:remaining > 0 && len(get(get(b:, 'autoveil_state', {}), 'views', {})) == 0
  sleep 20m
  let s:remaining -= 1
endwhile

if len(get(get(b:, 'autoveil_state', {}), 'views', {})) == 0
  call writefile(['FAIL: no real clangd type view; ' .. execute('AutoVeilStatus')->trim()], '/dev/stderr')
  cquit
endif
let s:deduced = values(b:autoveil_state.views)
if empty(filter(copy(s:deduced), {_, view -> view.replacement ==# 'int'}))
  call writefile(['FAIL: real clangd deduced type was not int'], '/dev/stderr')
  cquit
endif

AutoVeilMode prefer-auto
let s:remaining = 500
while s:remaining > 0 && len(get(get(b:, 'autoveil_state', {}), 'views', {})) == 0
  sleep 20m
  let s:remaining -= 1
endwhile
if len(get(get(b:, 'autoveil_state', {}), 'views', {})) == 0
  call writefile(['FAIL: no real modernize-use-auto view; ' .. execute('AutoVeilStatus')->trim()], '/dev/stderr')
  cquit
endif
let s:preferred = values(b:autoveil_state.views)
if empty(filter(copy(s:preferred), {_, view -> view.replacement =~# '\<auto\>'}))
  call writefile(['FAIL: real clang-tidy replacement did not contain auto'], '/dev/stderr')
  cquit
endif

AutoVeilPreferAutoLevel same-type-copies
let s:copy_line = search('IntegrationState copied = state;', 'nw')
let s:copy_again_line = search('IntegrationState copied_again = copied;', 'nw')
let s:remaining = 500
while s:remaining > 0
  let s:copy_views = filter(values(get(get(b:, 'autoveil_state', {}), 'views', {})),
        \ {_, view -> (view.lnum == s:copy_line || view.lnum == s:copy_again_line)
        \   && view.replacement ==# 'auto'})
  if len(s:copy_views) == 2
    break
  endif
  sleep 20m
  let s:remaining -= 1
endwhile
if len(get(s:, 'copy_views', [])) != 2
  call writefile(['FAIL: real clangd AST did not render both same-type copy views; ' .. execute('AutoVeilStatus')->trim()], '/dev/stderr')
  cquit
endif
if s:copy_views[0].length != strlen('IntegrationState')
  call writefile(['FAIL: AST copy view did not cover the explicit type'], '/dev/stderr')
  cquit
endif
call assert_equal(s:before, getline(1, '$'))
call assert_false(&modified)
if !empty(v:errors)
  call writefile(v:errors, '/dev/stderr')
  cquit
endif
call writefile(['PASS: real clangd hint, clang-tidy action, and AST copy rendered display-only'], '/dev/stdout')
AutoVeilDisable
qall!
