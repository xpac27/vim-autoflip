# Technical debt and intentional limitations

## 2026-08-28 18:06 CEST - Buffer-wide reveal

Impact: revealing source in one split also removes AutoVeil's virtual text from
other splits showing the same buffer for the short reveal interval.

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
AutoVeil must still never execute or apply the action.

## 2026-08-28 18:06 CEST - Long inferred types are skipped

Impact: types beyond `g:autoveil_type_name_limit` remain as source `auto`.

Reason: arbitrary truncation could hide semantically important suffixes. Safe
structured truncation is future work.

