# Architecture

## 2026-08-28 19:41 CEST - Reveal ownership

Reveal state records its source: cursor, insert mode, or the timed reveal
command. A cursor-owned reveal has no expiry timer. `CursorMoved` restores the
render only after the cursor leaves every cached TypeView source range, and
`WinLeave` prevents that reveal from remaining pinned in an inactive window.
This separation keeps asynchronous timers from changing concealment or screen
cursor placement while the cursor still occupies a source type.

## 2026-08-28 18:06 CEST - Initial implementation

AutoVeil is a Vim9script plugin with one external integration boundary:
`autoload/autoveil/lsp.vim`. It calls public vim-lsp functions and returns raw
response payloads. No other subsystem knows vim-lsp's API.

```text
vim-lsp / clangd
  | code actions                 | type inlay hints
  v                              v
actions.vim                   hints.vim
  |                              |
  +------- validated TypeView ---+
                    |
                    v
                core.vim
       generation, cache, lifecycle
                    |
                    v
               render.vim
      virtual text + conceal matches
```

`TypeView` is a dictionary with stable `id`, `kind`, one-based `lnum`, one-based
byte `col`, byte `length`, and display `replacement`. Both validators produce
the same shape; the renderer has no C++ or LSP knowledge.

Buffer-local `b:autoveil_state` owns enablement, mode, generation,
`changedtick`, timers, cached views, status/debug messages, reveal state, and a
window dictionary. Each window entry owns the pre-AutoVeil conceal option
values and its conceal match IDs.

Vim text properties are buffer-owned, while matches/options are window-owned.
A reveal therefore clears replacement properties and conceal matches for the
whole buffer. Normal rendering and restoration still track every split
independently.

Validation is fail-closed. clangd/clang-tidy supplies semantic authority; the
light lexer only rejects unsafe declaration shapes, masks comments/strings,
and classifies brace scope. It never invents a type.
