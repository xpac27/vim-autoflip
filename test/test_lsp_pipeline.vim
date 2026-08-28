vim9script

import autoload 'autoveil/core.vim' as core
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

unlet g:autoveil_test_lsp
lsp.ResetForTest()

# Missing vim-lsp is a clean waiting state on this isolated runtime path.
new
setlocal filetype=cpp
setline(1, ['void f() {', '  auto x = 1;', '}'])
core.Enable()
assert_match('waiting: vim-lsp is not installed', core.Status())
core.Disable()
bwipe!
