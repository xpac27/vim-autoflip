# Features

## 2026-08-31 15:58 CEST - Reliable diagnostic refresh

- Diagnostic updates queue a follow-up request without discarding the
  code-action or AST response that is already in flight.
- Actual edits continue to invalidate stale requests immediately.

## 2026-08-31 15:49 CEST - Selective edit retention

- Editing one substitution no longer clears byte-identical substitutions on
  other lines while AutoFlip waits for a refreshed clangd reply.
- Edited or shifted lines clear immediately; insert-mode reveal remains intact.

## 2026-08-31 15:32 CEST - Responsive AST preflight

- AST-backed candidate discovery now masks and classifies the visible source
  through one shared linear pass rather than repeatedly rescanning its prefix.
- Code-action and AST requests remain asynchronous through vim-lsp.

## 2026-08-31 14:51 CEST - Broader AST-proven locals

- `ast-proven-locals` preserves conservative and `same-type-copies` results,
  then adds exact clangd AST proof for direct class copies, lvalue subscript
  reference bindings, and direct pointer-variable reads.
- It displays the corresponding `auto`, `auto&`, or `auto*` spelling without
  special-casing containers or project types.
- Direct call results now render as `auto`; top-level const call-result
  declarations render as `const auto`.
- Pointer call results and const lvalue-subscript references render as
  `auto*`/`const auto*` and `const auto&`.
- A direct call initializer may occupy the line immediately following its
  declaration; wider multiline parsing remains intentionally unsupported.
- Rvalue references, null pointers, conversion-wrapped calls, malformed
  ranges, and ambiguous ASTs fail closed.

## 2026-08-29 09:50 CEST - Reliable delayed enable

- AutoFlip registers for vim-lsp notifications during plugin load, before a
  startup C++ buffer can publish its first diagnostics.
- Manually enabling AutoFlip after clangd has finished therefore retains the
  cached `modernize-use-auto` authority needed for conservative substitutions.
- Registration remains idempotently retried on `lsp_setup` and enable.

## 2026-08-28 21:05 CEST - vim-autoflip product identity

- The package and repository identity is `vim-autoflip`.
- All commands use the `AutoFlip` prefix; globals, buffer state, autoload
  modules, properties, and the augroup use `autoflip`.
- Highlight groups are `AutoFlipAuto` and `AutoFlipDeducedType`.
- The rename is intentionally complete and installs no compatibility aliases.

## 2026-08-28 20:55 CEST - Selective cursor reveal

- Cursor reveal now omits only the TypeView containing the cursor instead of
  clearing every rendered type in the buffer.
- Moving directly between source ranges re-conceals the previous type and
  reveals the new one atomically.
- Insert mode and `:AutoFlipReveal` retain intentional full-buffer reveal.
- Split windows keep every unrelated type concealed; only the selected type is
  exposed across splits because its virtual text is buffer-owned.

## 2026-08-28 20:29 CEST - Configurable prefer-auto authority

- `prefer-auto` now has a conservative default and an opt-in
  `same-type-copies` level.
- The stronger level preserves all clang-tidy results and adds cv/ref/pointer-
  free local `Type target = source;` copies only when clangd's structured AST proves
  the initializer is a direct reference with only an `LValueToRValue`
  conversion.
- `:AutoFlipPreferAutoLevel` switches the policy at runtime.
- `g:autoflip_max_ast_requests` bounds the additional visible-range requests.
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
autoflip-limitations`. Unsupported or ambiguous inputs are deliberately left
unchanged on screen.
