vim9script

import autoload 'autoveil/actions.vim' as actions

def LspRange(line: number, start: number, finish: number): dict<any>
  return {start: {line: line, character: start}, end: {line: line, character: finish}}
enddef

def Action(action_uri: string, action_range: dict<any>, new_text: string): dict<any>
  return {
    title: 'use auto',
    diagnostics: [{source: 'clang-tidy', code: 'modernize-use-auto', message: 'use auto'}],
    edit: {changes: {[action_uri]: [{range: action_range, newText: new_text}]}},
  }
enddef

new
setlocal filetype=cpp
setline(1, ['void f() {', '  std::vector<int>::iterator it = values.begin();', '}',
  'std::vector<int>::iterator field = values.begin();'])
var uri = 'file:///tmp/actions.cpp'
var requested = {start: {line: 0, character: 0}, end: {line: 4, character: 0}}
var edit_range = LspRange(1, 2, 28)
var valid = Action(uri, edit_range, 'auto')
var views = actions.Normalize(bufnr(), uri, requested, [valid])
assert_equal(1, len(views))
assert_equal(2, views[0].lnum)
assert_equal(3, views[0].col)
assert_equal(26, views[0].length)
assert_equal('auto', views[0].replacement)

var wrong_diagnostic = deepcopy(valid)
wrong_diagnostic.diagnostics[0].code = 'readability-identifier-naming'
assert_equal([], actions.Normalize(bufnr(), uri, requested, [wrong_diagnostic]))

var multi = deepcopy(valid)
add(multi.edit.changes[uri], {range: LspRange(1, 29, 31), newText: 'x'})
assert_equal([], actions.Normalize(bufnr(), uri, requested, [multi]))
assert_equal([], actions.Normalize(bufnr(), uri, requested,
  [Action(uri, edit_range, 'decltype(auto)')]))
assert_equal([], actions.Normalize(bufnr(), uri, requested,
  [Action(uri, LspRange(3, 0, 26), 'auto')]))

var conflicting = Action(uri, edit_range, 'const auto&')
assert_equal([], actions.Normalize(bufnr(), uri, requested, [valid, conflicting]))
bwipe!
