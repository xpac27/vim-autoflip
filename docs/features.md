# Features

## 2026-08-28 20:29 CEST - Configurable prefer-auto authority

- `prefer-auto` now has a conservative default and an opt-in
  `same-type-copies` level.
- The stronger level preserves all clang-tidy results and adds cv/ref/pointer-
  free local `Type target = source;` copies only when clangd's structured AST proves
  the initializer is a direct reference with only an `LValueToRValue`
  conversion.
- `:AutoVeilPreferAutoLevel` switches the policy at runtime.
- `g:autoveil_max_ast_requests` bounds the additional visible-range requests.
- Missing capabilities, malformed AST replies, conversions, and ambiguous
  syntax fail closed without changing source.

## 2026-08-28 19:41 CEST - Stable cursor reveal

- A source type under the cursor remains revealed until the cursor leaves its
  full source range.
- Moving within the type no longer starts a timer that re-conceals it beneath
  the cursor.
- Leaving the active window releases a cursor-pinned reveal; the explicit
  reveal command remains temporary.

## 2026-08-28 18:06 CEST - Version 1 implementation

Implemented:

- Opt-in `prefer-auto` view authorized only by clang-tidy
  `modernize-use-auto` diagnostics and direct single-edit code actions.
- Opt-in `show-deduced-types` view authorized only by clangd type inlay hints.
- Shared validated `TypeView` representation and display-only renderer.
- Vim virtual text plus per-window conceal matches.
- Exact per-window `conceallevel` and `concealcursor` restoration.
- Insert reveal, cursor/command reveal, visible-range requests, debounce,
  generation checks, `changedtick` checks, and stale-response rejection.
- Split-window and multi-buffer lifecycle cleanup.
- Commands, configuration, status reporting, help, and deterministic tests.

Limitations are maintained in [debt.md](debt.md) and `:help
autoveil-limitations`. Unsupported or ambiguous inputs are deliberately left
unchanged on screen.
