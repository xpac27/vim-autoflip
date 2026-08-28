# Architecture

## 2026-08-28 20:29 CEST - Optional AST copy authority

The `conservative` prefer-auto level retains the original code-action path.
`same-type-copies` discovers a bounded set of simple one-line copy candidates,
then the adapter requests `textDocument/ast` for each candidate through public
vim-lsp APIs. Discovery is not semantic authority.

`copies.vim` accepts only a structured `Var` declaration whose type range is
exact, and whose initializer is an `ImplicitCast(LValueToRValue)` containing a
single `DeclRef` with the expected source identifier. It never reads clangd's
human-oriented `arcana` dump. The resulting `auto` TypeViews are merged with
validated clang-tidy TypeViews before the shared renderer sees them.

```text
simple copy discovery -> vim-lsp -> clangd AST -> copies.vim --+
clang-tidy diagnostic -> vim-lsp -> code action -> actions.vim -+-> TypeView
```

Generation, `changedtick`, mode, and prefer-auto-level checks apply after both
asynchronous result sets have joined. A policy change therefore invalidates an
in-flight combined reply just like an edit or mode change.

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
