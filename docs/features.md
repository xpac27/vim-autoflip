# Features

## 2026-09-07 20:10 CEST - Delayed clangd attachment recovery

- An enabled C++ buffer now retries a missing clangd attachment every 100 ms,
  for at most five seconds. This recovers normal startup flows where vim-lsp's
  attachment event is missed.
- The retry remains inactive when vim-lsp itself is unavailable, stops after
  successful attachment, and can be restarted explicitly with
  `:AutoFlipRefresh`.
- It accepts Vim's post-`FileType` startup `changedtick` update only before
  any LSP request has been sent; normal edit staleness protection is unchanged.

## 2026-09-07 15:15 CEST - Qualified AST type equivalence

- Best-effort `prefer-auto` now recognizes clangd AST responses where a
  declaration spells a type locally but the initializer reports its fully
  qualified spelling.
- Matching remains exact against type spellings within clangd's declaration
  type subtree and preserves the existing conversion-free expression checks.

## 2026-09-03 08:26 CEST - Generic best-effort prefer-auto

- `prefer-auto` now has two policies: default `clang-tidy` and opt-in
  `best-effort`.
- Best-effort nominates simple local declarations around `=`, including
  whitespace, optional `const`, one pointer/reference declarator, and
  multiline initializers through a visible semicolon.
- clangd AST ranges, canonical types, and conversion-free expression shapes
  remain mandatory; the scanner never supplies semantic authority.

## 2026-08-31 15:58 CEST - Reliable diagnostic refresh

- Diagnostic updates queue a follow-up request without discarding the
  code-action or AST response that is already in flight.
- Actual edits continue to invalidate stale requests immediately.

## 2026-08-31 15:49 CEST - Selective edit retention

- Editing one substitution no longer clears byte-identical substitutions on
  other lines while AutoFlip waits for a refreshed clangd reply.
- Edited or shifted lines clear immediately; insert-mode reveal remains intact.

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
