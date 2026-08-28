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
assert_equal(3, &l:conceallevel)
assert_equal('niv', &l:concealcursor)

var view = types.NewView('prefer-auto', 2, 3, 26, 'auto')
core.SetViewsForTest([view])
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

