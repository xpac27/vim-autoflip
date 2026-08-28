vim9script

import autoload 'autoflip/lsp.vim' as lsp

execute 'set runtimepath+=' .. fnameescape(fnamemodify(expand('<sfile>'), ':p:h') .. '/fake_lsp')
lsp.ResetForTest()
assert_true(lsp.DependencyAvailable())
assert_true(lsp.IsAttached(bufnr()))
assert_true(lsp.SupportsCodeAction(bufnr()))
assert_true(lsp.SupportsInlayHints(bufnr()))
assert_true(lsp.SupportsAst(bufnr()))
lsp.Initialize()
assert_true(exists('g:AutoflipFakeNotificationCallback'))

var diagnostic = {
  source: 'clang-tidy',
  code: 'modernize-use-auto',
  message: 'use auto',
  range: {start: {line: 0, character: 0}, end: {line: 0, character: 3}},
}
g:AutoflipFakeNotificationCallback('clangd', {
  response: {
    method: 'textDocument/publishDiagnostics',
    params: {uri: 'file:///fake.cpp', diagnostics: [diagnostic]},
  },
})

var response: dict<any> = {}
var Callback = (payload) => extend(response, payload)
var requested = {start: {line: 0, character: 0}, end: {line: 1, character: 0}}
g:autoflip_fake_result = [{title: 'fake action'}]
lsp.RequestCodeActions(bufnr(), requested, Callback)
assert_true(response.ok)
assert_equal('textDocument/codeAction', g:autoflip_fake_request.method)
assert_equal(bufnr(), g:autoflip_fake_request.bufnr)
assert_equal(['quickfix'], g:autoflip_fake_request.params.context.only)
assert_equal(1, len(g:autoflip_fake_request.params.context.diagnostics))

response = {}
lsp.RequestInlayHints(bufnr(), requested, Callback)
assert_true(response.ok)
assert_equal('textDocument/inlayHint', g:autoflip_fake_request.method)
assert_false(get(g:, 'lsp_inlay_hints_enabled', false))

var candidate = {
  range: {start: {line: 0, character: 0}, end: {line: 0, character: 9}},
  identifier: 'copy',
}
response = {}
g:autoflip_fake_result = {role: 'declaration', kind: 'Var', detail: 'copy'}
lsp.RequestAsts(bufnr(), [candidate], Callback)
assert_true(response.ok)
assert_equal(0, response.errors)
assert_equal('textDocument/ast', g:autoflip_fake_request.method)
assert_equal(candidate.range, g:autoflip_fake_request.params.range)
assert_equal(candidate, response.result[0].candidate)
assert_equal('Var', response.result[0].node.kind)

response = {}
g:autoflip_fake_result = []
lsp.RequestAsts(bufnr(), [candidate], Callback)
assert_true(response.ok)
assert_equal(1, response.errors)
assert_equal([], response.result)

execute 'set runtimepath-=' .. fnameescape(fnamemodify(expand('<sfile>'), ':p:h') .. '/fake_lsp')
unlet! g:AutoflipFakeNotificationCallback
unlet! g:autoflip_fake_request
unlet! g:autoflip_fake_result
unlet! g:autoloaded_autoflip_fake_lsp
lsp.ResetForTest()
