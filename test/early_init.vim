set nocompatible
set nomore
set noswapfile
set encoding=utf-8

let s:test_root = fnamemodify(expand('<sfile>'), ':p:h:h')
execute 'set runtimepath^=' .. fnameescape(s:test_root .. '/test/fake_lsp')
execute 'set runtimepath^=' .. fnameescape(s:test_root)

runtime plugin/autoflip.vim

if !exists('g:AutoflipFakeNotificationCallback')
  call writefile(['FAIL: AutoFlip did not register for diagnostics during plugin load'], '/dev/stderr')
  cquit
endif

qall!
