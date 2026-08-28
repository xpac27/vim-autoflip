# Technology

## 2026-08-28 18:06 CEST - Supported stack

- Vim 9.x only, using Vim9script modules.
- Required Vim features: text properties/virtual text, conceal, timers,
  channels, and jobs.
- vim-lsp is the sole LSP client and clangd process owner.
- clangd supplies type hints; clang-tidy `modernize-use-auto` supplies safe
  conversion edits.
- Tests use Vim's headless Ex mode and built-in assertions. No Node, Lua,
  Neovim, Tree-sitter, Coc, or test framework dependency is introduced.

Public vim-lsp functions used are listed in
[details/vim-lsp.md](details/vim-lsp.md).

