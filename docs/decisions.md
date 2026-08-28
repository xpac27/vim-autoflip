# Architecture decisions

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

