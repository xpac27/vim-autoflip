# vim-lsp integration details

## 2026-08-28 18:06 CEST - Verified upstream API

The host did not contain vim-lsp itself, so the implementation was checked
against current upstream documentation and source, then exercised against a
temporary checkout at commit e10d186452743beb7b43d2b3427020832. The adapter uses only
autoload functions without private/internal prefixes:

- `lsp#get_allowed_servers(bufnr)` to find registered servers for the buffer;
- `lsp#get_server_info(name)` and `lsp#is_server_running(name)` to identify an
  attached clangd;
- `lsp#get_server_capabilities(name)` for `codeActionProvider` and
  `inlayHintProvider`;
- `lsp#get_text_document_identifier(bufnr)` for the URI;
- `lsp#register_notifications(name, callback)` to cache published clang-tidy
  diagnostics for code-action context;
- `lsp#send_request(name, request)` for `textDocument/codeAction` and
  `textDocument/inlayHint`.

Requests include `bufnr`, protocol params, and an `on_notification` callback.
The callback reads the unmodified `response.result`; no vim-lsp rendered hint
text is inspected. AutoVeil never calls workspace edit application functions.

The adapter requests code actions with `context.only = ['quickfix']` and only
cached `modernize-use-auto` diagnostics inside the visible request range. Even
then, the returned action must carry the matching diagnostic and pass the full
validator.

The adapter does not enable `g:lsp_inlay_hints_enabled`; its independent raw
request avoids duplicate display.
