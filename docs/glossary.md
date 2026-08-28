# Glossary

## 2026-08-28 20:29 CEST - Prefer-auto levels

- **conservative**: the default prefer-auto level, authorized exclusively by a
  direct clang-tidy `modernize-use-auto` code action.
- **same-type-copies**: an opt-in superset that also accepts a narrow local
  copy declaration when clangd's structured AST proves the supported shape.
- **AST candidate**: a lexically discovered request range with no authority of
  its own; it becomes a TypeView only after clangd AST validation.

## 2026-08-28 19:41 CEST - Reveal ownership

- **cursor-pinned reveal**: a reveal that persists while the active cursor is
  inside a TypeView's complete source range and ends on range or window exit.
- **timed reveal**: the temporary reveal started by `:AutoVeilReveal` and ended
  by its configured debounce timer.

## 2026-08-28 18:06 CEST - Canonical terms

- **AutoVeil**: this plugin and command prefix.
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
