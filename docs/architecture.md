# Architecture

## 2026-08-29 09:50 CEST - Eager diagnostic subscription

The plugin entry point initializes the LSP adapter immediately after import.
This registers AutoFlip's public vim-lsp notification callback before clangd
can publish diagnostics for a startup buffer. The existing `lsp_setup` and
enable paths call the same idempotent initializer as dependency-order
fallbacks.

Diagnostics remain adapter-owned raw protocol data. Core still performs no
vim-lsp state inspection and requests no code action until AutoFlip is enabled.

## 2026-08-28 21:05 CEST - Product namespace

The package identity is `vim-autoflip`. Runtime entry points are
`plugin/autoflip.vim`, `autoload/autoflip.vim`, and the
`autoload/autoflip/` module tree. Public Vim commands and highlights use
`AutoFlip`; script/global/property/buffer identifiers use `autoflip`.

No compatibility layer is loaded. This keeps one command set, one augroup, one
state dictionary, and one family of text-property types, preventing duplicate
autocommands or rendering when upgrading.

## 2026-08-28 20:55 CEST - Selective TypeView omission

Reveal state distinguishes a full reveal from a cursor-selected TypeView ID.
The renderer always rebuilds its buffer properties and per-window matches from
the cached TypeViews. During cursor reveal it omits only the matching stable ID;
all other views receive their normal virtual text and conceal matches. Moving
to another view changes the omitted ID, while range or window exit clears it.

Insert mode and the timed reveal command still use full reveal, which clears
all AutoFlip properties and matches. This keeps their editing semantics
unchanged. Since virtual text remains buffer-owned, omission of the selected ID
is visible in every split of the buffer, but it no longer affects unrelated
types.

## 2026-08-31 14:51 CEST - Broader AST-proven local authority

`ast-proven-locals` retains all conservative and `same-type-copies` results,
then adds four exact PCClangd AST shapes: direct class copy construction
(`CXXConstruct` with one `NoOp` cast over a `DeclRef`), lvalue
`CXXOperatorCall` `[]` bindings to a single `&` declaration, and direct
pointer-variable reads, and unwrapped `Call`/`CXXMemberCall` value results.
The corresponding displayed spellings are `auto`, `auto&`, `auto*`, and
`const auto` for a top-level const value.

The scanner remains a bounded nomination mechanism and supports only one-line,
single-declarator, non-cv declarations, plus a direct-call initializer on the
immediately following line. AST validation requires exact declaration/type/
initializer ranges and fails closed. PCClangd exposes the
lvalue category of overloaded `operator[]` in its extension `arcana` field;
that field is used only for this otherwise-unavailable lvalue proof. No
container, template, or project type name is recognized.

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
command. A cursor-owned reveal has no expiry timer and records the selected
TypeView ID. `CursorMoved` restores that view only after the cursor leaves its
source range, and `WinLeave` prevents it from remaining exposed in an inactive
window. This separation keeps asynchronous timers from changing concealment or
screen cursor placement while the cursor still occupies a source type.

## 2026-08-28 18:06 CEST - Initial implementation

AutoFlip is a Vim9script plugin with one external integration boundary:
`autoload/autoflip/lsp.vim`. It calls public vim-lsp functions and returns raw
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

Buffer-local `b:autoflip_state` owns enablement, mode, generation,
`changedtick`, timers, cached views, status/debug messages, reveal state, and a
window dictionary. Each window entry owns the pre-AutoFlip conceal option
values and its conceal match IDs.

Vim text properties are buffer-owned, while matches/options are window-owned.
Full reveal clears every replacement property and conceal match. Cursor reveal
selectively omits one property and its corresponding match in every split.
Normal rendering and restoration still track every split independently.

Validation is fail-closed. clangd/clang-tidy supplies semantic authority; the
light lexer only rejects unsafe declaration shapes, masks comments/strings,
and classifies brace scope. It never invents a type.
