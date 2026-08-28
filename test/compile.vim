set nocompatible
set nomore
execute 'set runtimepath^=' .. fnameescape(fnamemodify(expand('<sfile>'), ':p:h:h'))
runtime plugin/autoveil.vim
call autoveil#ModeComplete('', '', 0)
qall!

