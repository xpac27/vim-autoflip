# Tests

## 2026-08-28 20:29 CEST - AST copy coverage

The deterministic suite mocks `astProvider` and `textDocument/ast` to cover
candidate discovery, exact AST validation, conversion/malformed rejection,
policy switching, capability failure, and combined stale-safe rendering.

The optional real integration now verifies two independently returned
same-type copy AST nodes in addition to the clang-tidy action and deduced-type
hint. Its source buffer and modified flag must remain unchanged.

## 2026-08-28 18:06 CEST - Test entry points

Run deterministic unit, rendering, lifecycle, split-window, mocked pipeline,
and public-adapter contract tests with:

```sh
make check
```

The runner uses `vim -Nu NONE -U NONE -i NONE -n -es`; no personal
configuration or installed plugin is loaded.

`test/integration_clangd.vim` is optional. It exits successfully with a clear
skip message unless both `clangd` and an external vim-lsp checkout supplied in
`AUTOVEIL_VIM_LSP` are available. Run it through `test/run-integration.sh`.
