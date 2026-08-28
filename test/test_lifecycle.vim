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

# Multiple same-line views and yanks remain source-based.
new
setlocal filetype=cpp conceallevel=0 concealcursor=
var adjacent = 'void f() { Type first = make(); Type second = make(); }'
setline(1, adjacent)
setlocal nomodified
core.Enable()
var first_type = match(adjacent, 'Type') + 1
var second_type = match(adjacent, 'Type', first_type) + 1
var adjacent_views = [
  types.NewView('prefer-auto', 1, first_type, 4, 'auto'),
  types.NewView('prefer-auto', 1, second_type, 4, 'const auto&'),
]
core.SetViewsForTest(adjacent_views)
assert_equal(2, len(prop_list(1)))
assert_equal(2, len(getmatches()->filter((_, m) => m.group ==# 'Conceal')))
normal! yy
assert_equal(adjacent .. "\n", getreg('"'))
assert_equal(adjacent, getline(1))
assert_false(&modified)
var old_debounce = g:autoveil_debounce_ms
g:autoveil_debounce_ms = 10
core.Reveal()
assert_equal([], prop_list(1))
assert_equal([], getmatches()->filter((_, m) => m.group ==# 'Conceal'))
sleep 60m
assert_equal(2, len(prop_list(1)))
g:autoveil_debounce_ms = old_debounce
core.Disable()
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

# Rendering and cleanup stay isolated between buffers.
new
setlocal filetype=cpp
setline(1, ['void a() {', '  auto one = 1;', '}'])
var first_buffer = bufnr()
core.Enable()
core.SetViewsForTest([types.NewView('show-deduced-types', 2, 3, 4, 'int')])
new
setlocal filetype=cpp
setline(1, ['void b() {', '  auto two = 2L;', '}'])
var second_buffer = bufnr()
core.Enable()
core.SetViewsForTest([types.NewView('show-deduced-types', 2, 3, 4, 'long')])
assert_equal(1, len(prop_list(2, {bufnr: first_buffer})))
assert_equal(1, len(prop_list(2, {bufnr: second_buffer})))
core.Disable()
assert_equal(1, len(prop_list(2, {bufnr: first_buffer})))
assert_equal(0, len(prop_list(2, {bufnr: second_buffer})))
bwipe!
execute 'buffer ' .. first_buffer
core.Disable()
bwipe!

# Buffer wipeout cancels a pending debounce timer.
new
setlocal filetype=cpp
setline(1, ['void timer_test() {', '  auto value = 1;', '}'])
core.Enable()
core.OnBufferChanged()
var pending = core.State().pending_timer
assert_true(pending > 0)
bwipe!
assert_equal([], timer_info(pending))

# Listed non-C++ extensions are enforced; .c is outside the product scope.
new
file autoveil-unsupported.c
setlocal filetype=c
core.Enable()
assert_false(core.State().enabled)
assert_match('not a supported C++ source/header', core.Status())
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
assert_true(has_key(core.State().windows, string(inherited_win)))
close
assert_false(has_key(core.State().windows, string(inherited_win)))
core.Disable()
assert_equal(1, &l:conceallevel)
assert_equal('nc', &l:concealcursor)
bwipe!
