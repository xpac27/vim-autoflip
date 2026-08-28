set nocompatible
set nomore
execute 'set runtimepath^=' .. fnameescape(fnamemodify(expand('<sfile>'), ':p:h:h'))
runtime plugin/autoflip.vim
call autoflip#ModeComplete('', '', 0)
call autoflip#PreferAutoLevelComplete('', '', 0)
qall!
