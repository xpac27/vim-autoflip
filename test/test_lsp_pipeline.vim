vim9script

import autoload 'autoflip/core.vim' as core
import autoload 'autoflip/copies.vim' as copies
import autoload 'autoflip/lsp.vim' as lsp

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
g:autoflip_test_lsp = {
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
var original_debounce = g:autoflip_debounce_ms
g:autoflip_debounce_ms = 10
core.Enable()
assert_equal(1, len(core.State().views))
assert_equal('auto', values(core.State().views)[0].replacement)
assert_equal('code-actions', g:autoflip_test_lsp.requests[0].kind)
assert_false(&modified)

core.SetMode('show-deduced-types')
assert_equal(0, len(core.State().views))
# The source declaration is explicit, so the mock hint is correctly rejected.
assert_equal('inlay-hints', g:autoflip_test_lsp.requests[-1].kind)
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
g:autoflip_test_lsp.supports_ast = true
g:autoflip_test_lsp.code_actions = []
g:autoflip_test_lsp.ast_responses = [{candidate: copy_candidate, node: copy_ast}]
g:autoflip_test_lsp.requests = []
g:autoflip_prefer_auto_level = 'same-type-copies'
var copy_state = core.State()
copy_state.mode = 'prefer-auto'
core.Enable()
assert_equal(1, len(core.State().views))
assert_equal('auto', values(core.State().views)[0].replacement)
assert_equal(['code-actions', 'asts'],
  g:autoflip_test_lsp.requests->mapnew((_, request) => request.kind))
assert_equal('c', g:autoflip_test_lsp.requests[1].candidates[0].identifier)
assert_false(&modified)
core.SetPreferAutoLevel('conservative')
assert_equal(0, len(core.State().views))
assert_equal('code-actions', g:autoflip_test_lsp.requests[-1].kind)
core.Disable()
bwipe!

# The broadest policy requests and renders an AST-proven lvalue subscript reference.
new
setlocal filetype=cpp
setline(1, ['void references() {', '  Value& reference = values[index];', '}'])
setlocal nomodified
var reference_requested = {start: {line: 0, character: 0}, end: {line: 2, character: 1}}
var reference_candidate = copies.AstProvenCandidates(bufnr(), reference_requested, 10)[0]
var reference_ast = {
  role: 'declaration',
  kind: 'Var',
  detail: 'reference',
  range: reference_candidate.range,
  children: [
    {role: 'type', kind: 'LValueReference', range: reference_candidate.type_range},
    {
      role: 'expression',
      kind: 'CXXOperatorCall',
      arcana: "CXXOperatorCallExpr 'Value' lvalue '[]'",
      range: reference_candidate.initializer_range,
    },
  ],
}
g:autoflip_test_lsp.code_actions = []
g:autoflip_test_lsp.ast_responses = [{candidate: reference_candidate, node: reference_ast}]
g:autoflip_test_lsp.requests = []
g:autoflip_prefer_auto_level = 'ast-proven-locals'
var reference_state = core.State()
reference_state.mode = 'prefer-auto'
core.Enable()
assert_equal(1, len(core.State().views))
assert_equal('auto&', values(core.State().views)[0].replacement)
assert_equal(['code-actions', 'asts'],
  g:autoflip_test_lsp.requests->mapnew((_, request) => request.kind))
assert_equal('reference', g:autoflip_test_lsp.requests[1].candidates[0].identifier)
assert_false(&modified)
core.Disable()
bwipe!
g:autoflip_prefer_auto_level = 'conservative'

# The broadest policy preserves top-level const on direct call results.
new
setlocal filetype=cpp
setline(1, ['void calls() {', '  const Count hash = hashValue();', '}'])
setlocal nomodified
var call_requested = {start: {line: 0, character: 0}, end: {line: 2, character: 1}}
var call_candidate = copies.AstProvenCandidates(bufnr(), call_requested, 10)[0]
var call_ast = {
  role: 'declaration',
  kind: 'Var',
  detail: 'hash',
  range: call_candidate.range,
  children: [
    {role: 'type', kind: 'Qualified', detail: 'const', range: call_candidate.type_range},
    {role: 'expression', kind: 'Call', range: call_candidate.initializer_range},
  ],
}
g:autoflip_test_lsp.code_actions = []
g:autoflip_test_lsp.ast_responses = [{candidate: call_candidate, node: call_ast}]
g:autoflip_test_lsp.requests = []
g:autoflip_prefer_auto_level = 'ast-proven-locals'
var call_state = core.State()
call_state.mode = 'prefer-auto'
core.Enable()
assert_equal(1, len(core.State().views))
assert_equal('const auto', values(core.State().views)[0].replacement)
assert_false(&modified)
core.Disable()
bwipe!
g:autoflip_prefer_auto_level = 'conservative'

# The stronger policy fails closed when clangd lacks its AST capability.
new
setlocal filetype=cpp
setline(1, ['void copies() {', '  State c = a;', '}'])
g:autoflip_prefer_auto_level = 'same-type-copies'
g:autoflip_test_lsp.supports_ast = false
var unsupported_state = core.State()
unsupported_state.mode = 'prefer-auto'
core.Enable()
assert_match('does not advertise AST support', core.Status())
assert_equal(0, len(core.State().views))
core.Disable()
bwipe!
g:autoflip_test_lsp.supports_ast = true
g:autoflip_prefer_auto_level = 'conservative'

# Changing the authority level invalidates an in-flight combined response.
new
setlocal filetype=cpp
setline(1, ['void copies() {', '  State c = a;', '}'])
copy_candidate = copies.Candidates(bufnr(), copy_requested, 10)[0]
g:autoflip_test_lsp.ast_responses = [{candidate: copy_candidate, node: copy_ast}]
g:autoflip_test_lsp.delay_ms = 20
g:autoflip_prefer_auto_level = 'same-type-copies'
var changing_state = core.State()
changing_state.mode = 'prefer-auto'
core.Enable()
core.SetPreferAutoLevel('conservative')
sleep 50m
assert_equal(0, len(core.State().views))
assert_match('stale=1', core.Status())
core.Disable()
bwipe!
g:autoflip_test_lsp.delay_ms = 0

new
setlocal filetype=cpp
setline(1, ['void f() {', '  auto item = make_item();', '}'])
setlocal nomodified
g:autoflip_test_lsp.inlay_hints = [
  {position: {line: 1, character: 11}, label: ': Widget', kind: 1},
]
g:autoflip_mode = 'show-deduced-types'
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
g:autoflip_test_lsp.code_actions = [ModernizeAction(uri)]
g:autoflip_test_lsp.delay_ms = 20
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
var original_max_lines = g:autoflip_max_visible_lines
g:autoflip_max_visible_lines = 10
g:autoflip_test_lsp.delay_ms = 0
g:autoflip_test_lsp.requests = []
var large_state = core.State()
large_state.mode = 'prefer-auto'
core.Enable()
var large_request = g:autoflip_test_lsp.requests[-1]
assert_true(large_request.range.end.line - large_request.range.start.line < 10)
var request_count = len(g:autoflip_test_lsp.requests)
normal! G
assert_equal(request_count, len(g:autoflip_test_lsp.requests))
core.Disable()
g:autoflip_max_visible_lines = original_max_lines
bwipe!

unlet g:autoflip_test_lsp
lsp.ResetForTest()
g:autoflip_debounce_ms = original_debounce

# Missing vim-lsp is a clean waiting state on this isolated runtime path.
new
setlocal filetype=cpp
setline(1, ['void f() {', '  auto x = 1;', '}'])
core.Enable()
assert_match('waiting: vim-lsp is not installed', core.Status())
core.Disable()
bwipe!
