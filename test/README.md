# Tests

## 2026-08-28 21:05 CEST - AutoFlip identity coverage

`test/test_identity.vim` asserts all eight `AutoFlip` commands, nine
`g:autoflip_*` configuration variables, both highlight groups, both property
names, the load guard, and the status prefix. Compile and integration runners
load only `plugin/autoflip.vim`; the optional integration uses
`AUTOFLIP_VIM_LSP` and `AUTOFLIP_TEST_ROOT`.

## 2026-08-28 20:55 CEST - Selective reveal coverage

Lifecycle tests render multiple TypeViews and verify that cursor entry removes
only the selected property/match, movement within it stays stable, direct
movement to another view swaps the omission, and range/window exit restores
both. The split test asserts every tracked window retains matches for unrelated
views.

The optional real integration selects one clangd AST-backed copy and verifies
that another real copy view remains rendered while source stays unchanged.

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
`AUTOFLIP_VIM_LSP` are available. Run it through `test/run-integration.sh`.
