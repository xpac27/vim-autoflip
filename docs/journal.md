# Engineering journal

## 2026-08-29 10:36 CEST - Improve README demonstration legibility

- Re-recorded the real Vim, vim-lsp, and clangd demonstration with Kitty
  explicitly configured to use the installed Hack font.
- Enabled Vim C++ syntax and vim-lsp semantic highlighting in the hermetic demo
  configuration so types, keywords, functions, and comments remain distinct.
- Expanded the fixture with labeled, separated examples for conservative
  clang-tidy substitution, AST-backed aggressive substitution, and deduced
  type display.
- Updated the cursor choreography for the longer fixture without jumps and
  regenerated the looping 900x594 GIF at 10 FPS.

## 2026-08-29 10:16 CEST - Add before-and-after use cases

- Added a README table comparing source text with the display-only AutoFlip
  view for conservative prefer-auto, AST-backed aggressive prefer-auto, and
  deduced-type reveal.
- Used block-form code markup inside each table cell and labeled the semantic
  authority for every transformation.

## 2026-08-29 10:00 CEST - Replace README demonstration

- Re-recorded the real session after the eager diagnostic subscription fix;
  the clang-tidy-authorized iterator and both AST-authorized copies now render
  as `auto`.
- Loaded the user's Humdrum colorscheme in a hermetic runtime, excluding
  unrelated personal autocommands from the recording process.
- Replaced cursor jumps with visible line-by-line, word-by-word movement and
  moved the compositor pointer outside the captured output.
- Regenerated the looping 900x558 GIF at 10 FPS and visually inspected the
  opening frame plus twelve key frames across the complete sequence.

## 2026-08-29 09:50 CEST - Preserve diagnostics before delayed enable

- Reproduced that standalone clang-tidy emitted the iterator replacement while
  the README demo rendered only AST-backed copy substitutions.
- Found that vim-lsp had published diagnostics before AutoFlip registered its
  notification callback on manual enable; public registration does not replay
  old notifications.
- Moved the idempotent adapter initialization to plugin load while retaining
  setup and enable fallbacks. No server request or buffer mutation was added.
- Added a deterministic plugin-load contract and changed the real integration
  to publish diagnostics while AutoFlip is disabled before testing enable.

## 2026-08-29 09:41 CEST - Add README demonstration

- Recorded a real Vim 9.x, vim-lsp, and clangd session at a fixed
  README-friendly size rather than simulating plugin output.
- Demonstrated prefer-auto substitutions, selective cursor reveal,
  show-deduced-types, disable cleanup, and the unchanged source buffer.
- Converted the recording to a 900x558, 10 FPS looping GIF and embedded it
  near the README introduction.

## 2026-08-28 21:05 CEST - Complete vim-autoflip rename

- Inventoried runtime paths, public commands, globals, buffer state,
  properties, highlights, augroups, fake-LSP hooks, environment variables,
  fixtures, help tags, documentation, and plan paths before changing names.
- Renamed the runtime to `plugin/autoflip.vim` and
  `autoload/autoflip/`, with the public `AutoFlip` command/highlight prefix and
  `autoflip` internal/configuration namespace.
- Renamed the help file and implementation plan, updated installation and test
  surfaces, and added a deterministic public-identity contract.
- Chose a clean breaking rename without compatibility aliases to prevent two
  plugin entry points, duplicated autocommands, or mixed buffer state.
- Audited tracked content and filenames for superseded product identifiers;
  the audit returned zero matches.

## 2026-08-28 20:55 CEST - Make cursor reveal selective

- Reproduced that cursor reveal called the full `render.Reveal()` path, which
  cleared every AutoFlip property and conceal match in the buffer.
- Added a stable selected-TypeView ID to buffer state. Normal rendering now
  omits only that view while rebuilding every unrelated property and match.
- Kept insert and explicit command reveal on the existing full-reveal path.
- Added deterministic coverage for multiple types, direct movement between
  types, timeout stability, range/window exit, and match counts in two splits.
- Extended the real clangd integration to prove that selecting one AST-backed
  type leaves another real substitution rendered and never modifies source.

## 2026-08-28 20:29 CEST - Add opt-in same-type copies

- Confirmed clang-tidy's `MinTypeNameLength` and `RemoveStars` options do not
  broaden `modernize-use-auto` to declarations such as `State c = a`.
- Inspected current clangd protocol documentation and a real response for the
  reported declaration. clangd advertises `astProvider`; `textDocument/ast`
  returned an exact `Var`, type range, and `LValueToRValue`/`DeclRef` tree.
- Rejected hover markup, clangd `arcana` parsing, speculative `didChange`,
  direct tool processes, and unverified lexical replacement as authorities.
- Added a bounded lexical discovery pass, a strict structured-AST validator,
  public vim-lsp AST requests, combined reply/staleness handling, runtime
  policy switching, diagnostics, and documentation.
- Deterministic tests cover accepted copies, conversion rejection, malformed
  ranges/nodes, capability failure, policy switching, and display-only state.
- The optional real integration rendered two distinct AST-proven copies plus
  existing clang-tidy and inlay-hint views without changing the buffer.

## 2026-08-28 19:41 CEST - Fix cursor reveal expiry

- Reproduced the report with a deterministic headless test: entering an
  explicit source type cleared its display properties, but the shared reveal
  timer restored them after the debounce interval while the cursor remained
  inside the type.
- Split cursor, insert, and command reveal ownership. Cursor reveal now stays
  pinned without a timer and is released on source-range or window exit.
- Captured the originating buffer and generation for timed callbacks instead
  of resolving the current buffer when a timer fires.
- Added regression coverage for waiting across multiple debounce intervals,
  moving within a type, and leaving its range.

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
