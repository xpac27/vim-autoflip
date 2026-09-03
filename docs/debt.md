# Technical debt and intentional limitations

## 2026-09-03 08:26 CEST - Best-effort clangd AST dependency

Impact: `best-effort` is unavailable when clangd does not advertise
`astProvider`, and an incompatible future AST schema causes candidates to
remain explicit.

Reason: standard LSP does not expose a semantic type-equality query. AutoFlip
uses clangd's documented AST extension and only accepts its exact structured
proof.

Risk: best-effort coverage is intentionally bounded by
`g:autoflip_max_ast_requests` and the visible range. The `clang-tidy` policy
remains independent and available.

## 2026-08-29 09:50 CEST - Late lazy loading cannot replay diagnostics

Impact: loading the AutoFlip runtime itself only after clangd has already
published the current diagnostics cannot recover those past notifications
until clangd publishes again. Normal startup loading is covered by eager
registration, including later `:AutoFlipEnable`.

Reason: current public vim-lsp APIs support notification registration but do
not expose or replay the stored diagnostic payloads.

Risk: an unusually lazy-loaded installation can temporarily omit
clang-tidy-backed substitutions. Load AutoFlip normally before opening C++
buffers; a future public vim-lsp diagnostic snapshot/replay API could remove
this limitation.

## 2026-08-28 21:05 CEST - Breaking product namespace

Impact: existing user configuration and mappings must use the `autoflip` and
`AutoFlip` namespaces after upgrading. An earlier copied installation must be
removed so Vim does not load a stale plugin file outside this repository.

Reason: compatibility aliases would retain two public identities and risk
duplicate commands, autocommands, state variables, help tags, and properties.

Risk: upgrades require a one-time configuration/path migration and Vim
restart. The README and help state the exact current namespaces.

## 2026-08-28 20:55 CEST - Selected type remains buffer-scoped

Impact: cursor reveal now exposes only the selected type, but that one source
spelling appears in every split displaying the same buffer.

Reason: the selected virtual-text property is buffer-owned. Removing it only
in the active window has no public Vim representation; retaining it would show
the source and replacement together.

Risk: another split briefly exposes the same selected type. Every unrelated
type remains concealed. Future window-local property visibility could narrow
the selected omission to the active split.

## 2026-08-28 19:41 CEST - Buffer-wide cursor reveal (superseded)

Impact: holding the cursor inside a rendered source type reveals the original
spelling in every split displaying that buffer until the active cursor leaves
the range or window.

Reason: the reveal must remove buffer-scoped virtual text as well as
window-scoped conceal matches. Cursor pinning prevents unstable re-concealment
and screen cursor displacement.

Risk: another split can show source for longer than the former debounce
interval. Source integrity is unaffected. Window-local virtual-text visibility
in a future Vim release would permit independent per-window cursor reveals.

Superseded at 2026-08-28 20:55 CEST: cursor reveal now omits only its selected
TypeView. The cross-split limitation remains only for that one type.

## 2026-08-28 18:06 CEST - Buffer-wide reveal

Impact: revealing source in one split also removes AutoFlip's virtual text from
other splits showing the same buffer for the duration of that reveal.

Reason: Vim virtual text properties are buffer-scoped, with no public
window-local visibility switch. Conceal matches alone cannot display a
multi-character replacement.

Risk: another split briefly shows original source. Source integrity is not at
risk. Future Vim support for window-local property visibility would allow this
to become truly per-window.

## 2026-08-28 18:06 CEST - Narrow declaration grammar

Impact: valid but complex locals such as direct-list initialization,
constructor function-try blocks, structured bindings, macros, and ambiguous
multi-declarators are skipped.

Reason: version 1 is intentionally fail-closed. Expand only with clangd-backed
fixtures and regression tests.

## 2026-08-28 18:06 CEST - Direct code actions only

Impact: a clangd version that returns only command-backed or resolved code
actions cannot drive `prefer-auto`.

Reason: resolving/executing a command can mutate state and is outside the safe
read-only contract. A future public vim-lsp resolve API could be inspected, but
AutoFlip must still never execute or apply the action.

## 2026-08-28 18:06 CEST - Long inferred types are skipped

Impact: types beyond `g:autoflip_type_name_limit` remain as source `auto`.

Reason: arbitrary truncation could hide semantically important suffixes. Safe
structured truncation is future work.
