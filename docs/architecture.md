# Architecture

## 2026-08-31 15:49 CEST - Selective edit retention

Core snapshots the complete source line for each rendered TypeView. A buffer
change preserves only views whose line remains byte-identical at the same line
number, then immediately rebuilds their display while the debounced request is
pending. Changed or shifted lines are cleared. Insert-mode reveal remains
unchanged, and the accepted clangd reply is still authoritative.

## 2026-08-31 15:58 CEST - Diagnostic reply ownership

LSP diagnostic notifications no longer impersonate buffer edits. A notification
received while an LSP reply is in flight marks a follow-up refresh, allowing
that reply to complete under its original generation. Actual buffer changes
still invalidate pending work immediately.

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
