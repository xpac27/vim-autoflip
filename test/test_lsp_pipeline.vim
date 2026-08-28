vim9script

import autoload 'autoveil/core.vim' as core
import autoload 'autoveil/copies.vim' as copies
import autoload 'autoveil/lsp.vim' as lsp

def LspRange(line: number, start: number, finish: number): dict<any>
  return {start: {line: line, character: start}, end: {line: line, character: finish}}
enddef

def ModernizeAction(action_uri: string): dict<any>
  return {
    title: 'use auto',
    diagnostics: [{source: 'clang-tidy', code: 'modernize-use-auto', message: 'use auto'}],
    edit: {changes: {[action_uri]: [{range: LspRange(1, 2, 28), newText: 'auto'}]}},
  }
enddef

new
setlocal filetype=cpp
setline(1, ['void f() {', '  std::vector<int>::iterator it = values.begin();', '}'])
setlocal nomodified
var uri = 'file:///pipeline.cpp'
g:autoveil_test_lsp = {
  available: true,
  attached: true,
  supports_code_actions: true,
  supports_inlay_hints: true,
  uri: uri,
  requests: [],
  code_actions: [ModernizeAction(uri)],
  inlay_hints: [{position: {line: 1, character: 31}, label: ': Iterator', kind: 1}],
}
lsp.ResetForTest()
var original_debounce = g:autoveil_debounce_ms
g:autoveil_debounce_ms = 10
core.Enable()
assert_equal(1, len(core.State().views))
assert_equal('auto', values(core.State().views)[0].replacement)
assert_equal('code-actions', g:autoveil_test_lsp.requests[0].kind)
assert_false(&modified)

core.SetMode('show-deduced-types')
assert_equal(0, len(core.State().views))
# The source declaration is explicit, so the mock hint is correctly rejected.
assert_equal('inlay-hints', g:autoveil_test_lsp.requests[-1].kind)
core.Disable()
bwipe!

# The opt-in copy level merges clangd AST-proven copies with clang-tidy views.
new
setlocal filetype=cpp
setline(1, ['void copies() {', '  State c = a;', '}'])
setlocal nomodified
var copy_requested = {start: {line: 0, character: 0}, end: {line: 2, character: 1}}
var copy_candidate = copies.Candidates(bufnr(), copy_requested, 10)[0]
var copy_expression = LspRange(1, 12, 13)
var copy_ast = {
  role: 'declaration',
  kind: 'Var',
  detail: 'c',
  range: LspRange(1, 2, 13),
  children: [
    {role: 'type', kind: 'Enum', detail: 'State', range: LspRange(1, 2, 7)},
    {
      role: 'expression',
      kind: 'ImplicitCast',
      detail: 'LValueToRValue',
      range: copy_expression,
      children: [{role: 'expression', kind: 'DeclRef', detail: 'a', range: copy_expression}],
    },
  ],
}
g:autoveil_test_lsp.supports_ast = true
g:autoveil_test_lsp.code_actions = []
g:autoveil_test_lsp.ast_responses = [{candidate: copy_candidate, node: copy_ast}]
g:autoveil_test_lsp.requests = []
g:autoveil_prefer_auto_level = 'same-type-copies'
var copy_state = core.State()
copy_state.mode = 'prefer-auto'
core.Enable()
assert_equal(1, len(core.State().views))
assert_equal('auto', values(core.State().views)[0].replacement)
assert_equal(['code-actions', 'asts'],
  g:autoveil_test_lsp.requests->mapnew((_, request) => request.kind))
assert_equal('c', g:autoveil_test_lsp.requests[1].candidates[0].identifier)
assert_false(&modified)
core.SetPreferAutoLevel('conservative')
assert_equal(0, len(core.State().views))
assert_equal('code-actions', g:autoveil_test_lsp.requests[-1].kind)
core.Disable()
bwipe!

# The stronger policy fails closed when clangd lacks its AST capability.
new
setlocal filetype=cpp
setline(1, ['void copies() {', '  State c = a;', '}'])
g:autoveil_prefer_auto_level = 'same-type-copies'
g:autoveil_test_lsp.supports_ast = false
var unsupported_state = core.State()
unsupported_state.mode = 'prefer-auto'
core.Enable()
assert_match('does not advertise AST support', core.Status())
assert_equal(0, len(core.State().views))
core.Disable()
bwipe!
g:autoveil_test_lsp.supports_ast = true
g:autoveil_prefer_auto_level = 'conservative'

new
setlocal filetype=cpp
setline(1, ['void f() {', '  auto item = make_item();', '}'])
setlocal nomodified
g:autoveil_test_lsp.inlay_hints = [
  {position: {line: 1, character: 11}, label: ': Widget', kind: 1},
]
g:autoveil_mode = 'show-deduced-types'
var deduced_state = core.State()
deduced_state.mode = 'show-deduced-types'
core.Enable()
assert_equal(1, len(core.State().views))
assert_equal('Widget', values(core.State().views)[0].replacement)
assert_false(&modified)
core.OnInsertEnter()
assert_equal([], prop_list(2))
core.OnInsertLeave()
sleep 20m
assert_equal(1, len(prop_list(2)))
core.Disable()
bwipe!

# Delayed responses from a previous generation are discarded.
new
setlocal filetype=cpp
setline(1, ['void f() {', '  std::vector<int>::iterator it = values.begin();', '}'])
g:autoveil_test_lsp.code_actions = [ModernizeAction(uri)]
g:autoveil_test_lsp.delay_ms = 20
var stale_state = core.State()
stale_state.mode = 'prefer-auto'
core.Enable()
setline(2, '  int changed = 1;')
core.OnBufferChanged()
sleep 40m
assert_equal(0, len(core.State().views))
assert_match('stale=1', core.Status())
core.Disable()
bwipe!

# Large visible regions are capped, and scrolling alone creates no request.
new
setlocal filetype=cpp
setline(1, range(1, 400)->mapnew((_, line) => printf('// line %d', line)))
var original_max_lines = g:autoveil_max_visible_lines
g:autoveil_max_visible_lines = 10
g:autoveil_test_lsp.delay_ms = 0
g:autoveil_test_lsp.requests = []
var large_state = core.State()
large_state.mode = 'prefer-auto'
core.Enable()
var large_request = g:autoveil_test_lsp.requests[-1]
assert_true(large_request.range.end.line - large_request.range.start.line < 10)
var request_count = len(g:autoveil_test_lsp.requests)
normal! G
assert_equal(request_count, len(g:autoveil_test_lsp.requests))
core.Disable()
g:autoveil_max_visible_lines = original_max_lines
bwipe!

unlet g:autoveil_test_lsp
lsp.ResetForTest()
g:autoveil_debounce_ms = original_debounce

# Missing vim-lsp is a clean waiting state on this isolated runtime path.
new
setlocal filetype=cpp
setline(1, ['void f() {', '  auto x = 1;', '}'])
core.Enable()
assert_match('waiting: vim-lsp is not installed', core.Status())
core.Disable()
bwipe!
