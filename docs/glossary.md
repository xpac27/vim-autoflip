# Glossary

## 2026-08-28 21:05 CEST - Product identity

- **vim-autoflip**: package, repository, implementation-plan, and installation
  directory name.
- **AutoFlip**: user-facing command, status, and highlight-group prefix.
- **autoflip**: Vim9script module, global, buffer-state, property, augroup,
  integration-test, and environment-variable namespace.

## 2026-08-28 20:55 CEST - Selective reveal

- **selected TypeView ID**: the one cached substitution omitted from rendering
  while the cursor occupies its source range.
- **full reveal**: removal of every AutoFlip property and conceal match for
  insert mode or the timed reveal command.

## 2026-09-03 08:26 CEST - Prefer-auto policy

- **clang-tidy**: the default and currently sole prefer-auto policy, authorized
  exclusively by a direct clang-tidy `modernize-use-auto` code action.

## 2026-08-28 19:41 CEST - Reveal ownership

- **cursor-pinned reveal**: selective omission that persists while the active
  cursor is inside one TypeView's complete source range and ends on range or
  window exit.
- **timed reveal**: the temporary reveal started by `:AutoFlipReveal` and ended
  by its configured debounce timer.

## 2026-08-28 18:06 CEST - Canonical terms

- **AutoFlip**: this plugin and command prefix.
- **prefer-auto**: display mode that shows an authoritative safe `auto`
  spelling over an explicit type.
- **show-deduced-types**: display mode that shows clangd's inferred full type
  over a source `auto` declaration prefix.
- **TypeView**: validated, renderer-independent display substitution.
- **source range**: original buffer bytes concealed by a TypeView.
- **replacement**: virtual text displayed before a concealed source range.
- **generation**: monotonically increasing buffer request epoch used to reject
  stale asynchronous replies.
- **reveal**: temporary removal of both virtual replacement text and conceal
  matches, exposing original source.
- **authority**: clang-tidy code action or clangd type inlay hint; lexical code
  is only a safety filter.
