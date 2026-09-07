vim9script

import autoload 'autoflip/core.vim' as core
import autoload 'autoflip/best_effort.vim' as best_effort
import autoload 'autoflip/lsp.vim' as lsp

def LspRange(line: number, start: number, finish: number): dict<any>
  return {start: {line: line, character: start}, end: {line: line, character: finish}}
enddef

def ModernizeAction(
    action_uri: string,
    line: number = 1,
    start: number = 2,
    finish: number = 28): dict<any>
  return {
    title: 'use auto',
    diagnostics: [{source: 'clang-tidy', code: 'modernize-use-auto', message: 'use auto'}],
    edit: {changes: {[action_uri]: [{range: LspRange(line, start, finish), newText: 'auto'}]}},
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

# A late attachment retries even when vim-lsp fails to emit its event.
new
setlocal filetype=cpp
setline(1, ['void f() {', '  std::vector<int>::iterator it = values.begin();', '}'])
setlocal nomodified
g:autoflip_test_lsp.attached = false
g:autoflip_test_lsp.requests = []
core.Enable()
assert_match('waiting: no running clangd server is attached', core.Status())
assert_equal([], g:autoflip_test_lsp.requests)
g:autoflip_test_lsp.attached = true
sleep 120m
assert_equal('code-actions', g:autoflip_test_lsp.requests[0].kind)
assert_equal(1, len(core.State().views))
core.Disable()
bwipe!

# A diagnostic update queues a follow-up refresh without invalidating its reply.
new
setlocal filetype=cpp
setline(1, ['void f() {', '  std::vector<int>::iterator it = values.begin();', '}'])
setlocal nomodified
g:autoflip_test_lsp.code_actions = [ModernizeAction(uri)]
g:autoflip_test_lsp.requests = []
g:autoflip_test_lsp.delay_ms = 20
var diagnostic_state = core.State()
diagnostic_state.mode = 'prefer-auto'
core.Enable()
var diagnostic_generation = core.State().generation
core.OnLspEvent()
assert_equal(diagnostic_generation, core.State().generation)
assert_true(core.State().refresh_after_reply)
sleep 60m
assert_equal(1, len(core.State().views))
assert_match('stale=0', core.Status())
core.Disable()
bwipe!
g:autoflip_test_lsp.delay_ms = 0

# An edit clears only views whose source line changed while refresh is pending.
new
setlocal filetype=cpp
setline(1, [
  'void f() {',
  '  std::vector<int>::iterator first = values.begin();',
  '  std::vector<int>::iterator second = values.begin();',
  '}',
])
setlocal nomodified
g:autoflip_test_lsp.code_actions = [ModernizeAction(uri, 1), ModernizeAction(uri, 2)]
g:autoflip_test_lsp.requests = []
var retained_state = core.State()
retained_state.mode = 'prefer-auto'
core.Enable()
assert_equal(2, len(core.State().views))
setline(2, '  int changed = 1;')
core.OnBufferChanged()
assert_equal(1, len(core.State().views))
assert_equal(3, values(core.State().views)[0].lnum)
core.Disable()
bwipe!

# The best-effort policy joins clang-tidy and generic clangd AST results.
new
setlocal filetype=cpp
setline(1, ['void best_effort() {', '  const Value* pointer = factory.getPointer();', '}'])
setlocal nomodified
var best_effort_requested = {start: {line: 0, character: 0}, end: {line: 2, character: 1}}
var pointer_candidate = best_effort.Candidates(bufnr(), best_effort_requested, 10)[0]
var pointer_ast = {
  role: 'declaration',
  kind: 'Var',
  detail: 'pointer',
  range: pointer_candidate.range,
  children: [
    {role: 'type', kind: 'Pointer', range: pointer_candidate.semantic_type_range,
      arcana: "QualType 'const Value *'"},
    {role: 'expression', kind: 'CXXMemberCall', range: pointer_candidate.initializer_range,
      arcana: "CXXMemberCallExpr 'const Value *'"},
  ],
}
g:autoflip_test_lsp.code_actions = [ModernizeAction(uri, 1, 8, 13)]
g:autoflip_test_lsp.ast_responses = [{candidate: pointer_candidate, node: pointer_ast}]
g:autoflip_test_lsp.requests = []
g:autoflip_test_lsp.supports_ast = true
g:autoflip_prefer_auto_level = 'best-effort'
var best_effort_state = core.State()
best_effort_state.mode = 'prefer-auto'
core.Enable()
assert_equal(1, len(core.State().views))
var pointer_view = values(core.State().views)[0]
assert_equal(2, pointer_view.lnum)
assert_equal(9, pointer_view.col)
assert_equal(5, pointer_view.length)
assert_equal('auto', pointer_view.replacement)
assert_equal(['code-actions', 'asts'],
  g:autoflip_test_lsp.requests->mapnew((_, request) => request.kind))
assert_false(&modified)
core.Disable()
bwipe!
g:autoflip_prefer_auto_level = 'clang-tidy'

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
