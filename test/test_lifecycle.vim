vim9script

import autoload 'autoveil/core.vim' as core
import autoload 'autoveil/types.vim' as types

new
setlocal filetype=cpp
setlocal conceallevel=1 concealcursor=nc
setline(1, ['int main() {', '  std::vector<int>::iterator it = values.begin();', '}'])
var before = getline(1, '$')
var undo_before = undotree().seq_cur
setlocal nomodified

core.Enable()
assert_true(core.State().enabled)
assert_equal(1, &l:conceallevel)
assert_equal('nc', &l:concealcursor)

var view = types.NewView('prefer-auto', 2, 3, 26, 'auto')
core.SetViewsForTest([view])
assert_equal(3, &l:conceallevel)
assert_equal('niv', &l:concealcursor)
assert_equal(before, getline(1, '$'))
assert_false(&modified)
assert_equal(undo_before, undotree().seq_cur)
assert_equal(1, len(prop_list(2)))
assert_equal(1, len(getmatches()->filter((_, m) => m.group ==# 'Conceal')))

core.Disable()
assert_false(core.State().enabled)
assert_equal(1, &l:conceallevel)
assert_equal('nc', &l:concealcursor)
assert_equal([], prop_list(2))
assert_equal([], getmatches()->filter((_, m) => m.group ==# 'Conceal'))

core.Disable()
assert_equal(before, getline(1, '$'))
bwipe!

# Pre-existing split windows retain independent option baselines.
new
setlocal filetype=cpp conceallevel=1 concealcursor=nc
setline(1, ['void f() {', '  auto item = make_item();', '}'])
var first_win = win_getid()
vsplit
setlocal conceallevel=2 concealcursor=v
var second_win = win_getid()
core.Enable()
var split_view = types.NewView('show-deduced-types', 2, 3, 4, 'Widget')
core.SetViewsForTest([split_view])
win_gotoid(first_win)
core.OnWindowEnter()
assert_equal(3, getwinvar(first_win, '&conceallevel'))
assert_equal(3, getwinvar(second_win, '&conceallevel'))
core.Disable()
assert_equal(1, getwinvar(first_win, '&conceallevel'))
assert_equal('nc', getwinvar(first_win, '&concealcursor'))
assert_equal(2, getwinvar(second_win, '&conceallevel'))
assert_equal('v', getwinvar(second_win, '&concealcursor'))
win_gotoid(second_win)
close
bwipe!

# A split created while rendering restores the inherited user baseline.
new
setlocal filetype=cpp conceallevel=1 concealcursor=nc
setline(1, ['void f() {', '  auto item = make_item();', '}'])
core.Enable()
core.SetViewsForTest([split_view])
vsplit
var inherited_win = win_getid()
core.OnWindowEnter()
core.Disable()
assert_equal(1, &l:conceallevel)
assert_equal('nc', &l:concealcursor)
close
bwipe!
