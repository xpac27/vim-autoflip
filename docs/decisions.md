# Architecture decisions

## 2026-08-28 20:29 CEST - Add clangd AST as an opt-in authority

Reason:

- clang-tidy intentionally emits no action for plain same-type copies;
- clangd's structured AST distinguishes direct value copies from implicit
  conversions and supplies exact source ranges;
- vim-lsp's public generic request API preserves the existing integration
  boundary and source remains untouched;
- retaining conservative mode as the default preserves version 1 behavior.

Rejected:

- loosen the lexical validator: no semantic proof and violates fail-closed
  behavior;
- parse hover text or AST `arcana`: human-oriented, unstable strings;
- send speculative `didChange` messages with `auto`: corrupts clangd's view of
  the document and races other LSP features;
- run clang-query, clang-tidy plugins, or clangd directly: bypasses the required
  vim-lsp lifecycle and adds deployment burden.

## 2026-08-28 19:41 CEST - Pin cursor reveal to the source range

Reason:

- restoring conceal while the cursor remains in the source type makes the
  screen cursor jump against the shorter replacement;
- range entry and exit events provide a deterministic lifetime;
- explicit command reveal can retain its independent timer.

Rejected:

- repeatedly restart a short timer: still permits re-concealment beneath an
  idle cursor;
- disable cursor reveal: removes intended editing ergonomics.

## 2026-08-28 18:06 CEST - Use public vim-lsp request functions

Reason:

- vim-lsp is the required transport and lifecycle owner;
- raw responses remain available before its optional UI renderer;
- the adapter is small and mockable.

Rejected:

- direct clangd JSON-RPC: duplicates the required dependency and lifecycle;
- vim-lsp internal diagnostic/UI functions: private and unstable;
- scraping rendered hints: loses protocol structure and semantic provenance.

## 2026-08-28 18:06 CEST - Fail closed through one TypeView shape

Reason:

- both authorities receive identical range/render checks;
- ambiguity can be discarded before any display state changes;
- renderer tests do not need clangd.

Rejected:

- regex type inference: incorrect for C++ deduction;
- separate renderers: duplicates cleanup and split-window risks.

## 2026-08-28 18:06 CEST - Make reveal buffer-wide

Reason:

- Vim virtual text properties are buffer-scoped;
- clearing both virtual text and conceal is the only truthful reveal;
- a brief cross-split reveal is safer than showing source and replacement
  simultaneously.

Rejected:

- leave virtual text during reveal: displays duplicate, misleading types;
- popup overlays: violate the planned conceal/text-property design and harm
  positioning/editing behavior.
