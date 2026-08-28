# vim-lsp integration details

## 2026-08-28 20:29 CEST - clangd AST requests

The opt-in `same-type-copies` level additionally reads `astProvider` through
`lsp#get_server_capabilities(name)` and sends one bounded
`textDocument/ast` request per discovered copy candidate with
`lsp#send_request(name, request)`.

The adapter joins raw AST replies with the normal code-action response before
calling core. Each AST reply retains the candidate that originated it, even
when replies arrive out of order. Transport failures become skipped malformed
reply counts. Core then applies its normal generation, changedtick, mode, and
policy checks to the combined response.

This is a documented clangd protocol extension, not standard LSP. AutoVeil
checks the advertised capability and validates only structured `role`, `kind`,
`detail`, `range`, and `children` fields. It does not inspect the optional
human-oriented `arcana` field. No request changes the server document.

## 2026-08-28 18:06 CEST - Verified upstream API

The host did not contain vim-lsp itself, so the implementation was checked
against current upstream documentation and source, then exercised against a
temporary checkout at commit e10d186452743beb7b43d2b3427020832. The adapter uses only
autoload functions without private/internal prefixes:

- `lsp#get_allowed_servers(bufnr)` to find registered servers for the buffer;
- `lsp#get_server_info(name)` and `lsp#is_server_running(name)` to identify an
  attached clangd;
- `lsp#get_server_capabilities(name)` for `codeActionProvider`,
  `inlayHintProvider`, and optional `astProvider`;
- `lsp#get_text_document_identifier(bufnr)` for the URI;
- `lsp#register_notifications(name, callback)` to cache published clang-tidy
  diagnostics for code-action context;
- `lsp#send_request(name, request)` for `textDocument/codeAction`,
  `textDocument/inlayHint`, and optional `textDocument/ast`.

Requests include `bufnr`, protocol params, and an `on_notification` callback.
The callback reads the unmodified `response.result`; no vim-lsp rendered hint
text is inspected. AutoVeil never calls workspace edit application functions.

The adapter requests code actions with `context.only = ['quickfix']` and only
cached `modernize-use-auto` diagnostics inside the visible request range. Even
then, the returned action must carry the matching diagnostic and pass the full
validator.

The adapter does not enable `g:lsp_inlay_hints_enabled`; its independent raw
request avoids duplicate display.
