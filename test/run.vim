set nocompatible
set nomore
set noswapfile
set encoding=utf-8
execute 'set runtimepath^=' .. fnameescape(fnamemodify(expand('<sfile>'), ':p:h:h'))
runtime plugin/autoveil.vim

source test/test_types.vim
source test/test_range.vim
source test/test_actions.vim
source test/test_copies.vim
source test/test_hints.vim
source test/test_lifecycle.vim
source test/test_lsp_pipeline.vim
source test/test_lsp_adapter.vim

if !empty(v:errors)
  call writefile(v:errors, '/dev/stderr')
  cquit
endif
qall!
