# Engineering journal

## 2026-08-28 18:06 CEST - End-to-end implementation

- Read the complete product plan and repository rules before implementation.
- Confirmed Vim 9.2 has every required feature. clangd 22.1.8 is installed.
- Found vim-lsp-settings but no installed vim-lsp checkout on this host.
- Inspected current upstream vim-lsp documentation and source. Confirmed the
  public request seam: `lsp#get_allowed_servers()`, server info/capabilities,
  text document identifiers, notification registration, and
  `lsp#send_request()` with `bufnr` and `on_notification`.
- Implemented lifecycle/rendering, validators, then the adapter/scheduler in
  focused commits with headless tests after every slice.
- Found that Vim virtual text is buffer-owned and cannot be hidden per window.
  Recorded and implemented buffer-wide reveal while retaining exact per-window
  conceal cleanup.
- Added a fake public vim-lsp surface so adapter request shapes are exercised
  without a personal Vim setup.
- Cloned current upstream vim-lsp commit e10d186452743beb7b43d2b3427020832 to
  `/tmp` and passed the optional integration against clangd 22.1.8. Both a
  real inferred `int` hint and a real `modernize-use-auto` action rendered
  while buffer text and the modified flag remained unchanged.
