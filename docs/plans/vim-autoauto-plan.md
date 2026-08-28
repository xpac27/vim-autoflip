# `vim-autoauto`: Implementation Plan

## Goal

Create a modern **Vim** plugin for C++ that presents local variable declarations
in either of two display-only type views, while never changing the buffer or the
file on disk:

- **prefer-auto**: show a safe `auto` spelling in place of an explicit type;
- **show-deduced-types**: show the full inferred type in place of `auto`.

Example source:

```cpp
std::unordered_map<Key, Value>::const_iterator it = map.begin();
```

In `prefer-auto` mode, Vim should display:

```cpp
auto it = map.begin();
```

The display must use `auto&`, `const auto&`, `auto*`, etc. whenever that is the
safe replacement proposed by the C++ tooling. Conversely, in
`show-deduced-types` mode, this source:

```cpp
const auto& record = records.front();
```

may display as:

```cpp
const Record& record = records.front();
```

## Scope and compatibility

- Target **modern Vim only** (current Vim 9.x with `+textprop`, `+conceal`,
  `+channel`, and `+job`). Do not add a legacy-Vim fallback.
- Use Vim9script for all plugin code.
- Target `*.cc`, `*.cpp`, `*.cxx`, `*.h`, `*.hh`, `*.hpp`, and `*.hxx` buffers.
- Require **`vim-lsp`** as a hard plugin dependency and an attached `clangd`
  client. Do not implement an LSP client or JSON-RPC protocol in this plugin.
- Require clangd to run clang-tidy and enable the `modernize-use-auto` check.
- Require clangd inlay hints for `show-deduced-types` mode.
- Do not add a dependency on Node, Coc, Lua, Neovim, or Tree-sitter for the
  first version.

The plugin must remain read-only: it must not apply a code action, write a
buffer, alter undo history, save files, or affect Git diffs.

## Design principle: two LSP-backed sources of truth

Do **not** infer conversions with regular expressions or by comparing LSP hover
types. C++ `auto` deduction has reference, cv-qualification, array, function,
and conversion subtleties.

### `prefer-auto`: clang-tidy code actions

Request code actions from clangd and accept only edits produced for clang-tidy's
`modernize-use-auto` diagnostic.

For every accepted action:

1. Inspect its `WorkspaceEdit` without applying it.
2. Accept it only if it replaces exactly one contiguous type-specifier range in
   the current buffer with a spelling containing `auto`.
3. Render that edit as a display-only substitution.
4. Ignore fixes that also edit another range, another line, another file, or
   change anything other than the declaration type.

This conservative rule is intentional. It makes incorrect display vastly less
likely and keeps the first release simple to review.

### `show-deduced-types`: clangd inlay hints

Request `textDocument/inlayHint` through `vim-lsp` for the visible range.
Accept only **type** inlay hints that clangd attaches to a declaration using
`auto`. The hint label is the authoritative spelling of the deduced type.

Use a light lexical parser to identify the declaration prefix to conceal. For
example, it must replace the complete source spelling `auto`, `auto*`,
`const auto&`, etc., rather than only the `auto` token. Do not attempt a
substitution if the declaration shape or associated hint is ambiguous.

Keep the two data paths separate behind a shared `TypeView` representation:

```text
clang-tidy code action ─┐
                        ├─ validated TypeView ─→ shared renderer
clangd type inlay hint ─┘
```

## Rendering design in Vim

Vim virtual text is inserted before a position and shifts the rendered line; it
does not provide Neovim's overlay mode. Combine it with concealment:

1. Add a zero-width virtual-text property at the first byte of the original
   type, with `text` equal to the validated replacement (for example
   `const auto&`).
2. Add a high-priority `Conceal` match over the original type range.
3. Set window-local `conceallevel=3` and ensure `concealcursor` conceals in
   normal and insert modes while the feature is enabled.
4. The virtual text takes the visual space; the concealed original type takes
   none.

Keep all Vim option changes per-window and restore their exact previous values
when the feature is disabled or the window is closed.

### Implemented adjustment: reveal scope (2026-08-28 18:06 CEST)

Vim virtual text properties are buffer-owned and have no public window-local
visibility control, whereas conceal matches and conceal options are
window-owned. Therefore a truthful reveal cannot remove replacement text in
only one split: doing so would either affect all splits or leave duplicate
source and replacement text in the revealed window.

The implemented smallest safe adjustment makes reveal buffer-wide for every
split showing that buffer. Conceal match IDs and original option values remain
tracked and restored independently per window. This preserves the display-only
contract and avoids showing a misleading duplicate type.

### Editing ergonomics

#### Implemented selective cursor adjustment (2026-08-28 20:55 CEST)

Cursor reveal now records the stable ID of the TypeView containing the cursor
and rebuilds rendering with only that view omitted. Other types retain both
their virtual replacement and conceal match. Insert mode and
`:AutoVeilReveal` intentionally retain full reveal. Because the selected
virtual-text property is buffer-owned, its source spelling appears in every
split showing the buffer, but unrelated types remain concealed in every split.

#### Implemented cursor-stability adjustment (2026-08-28 19:41 CEST)

The short timer must not restore concealment while the cursor remains inside a
rendered source range: Vim then redraws against the shorter replacement and
the visible cursor position jumps. Cursor-triggered reveal therefore remains
pinned until `CursorMoved` leaves the complete source range or `WinLeave`
deactivates the window. The explicit `:AutoVeilReveal` command remains timed by
`g:autoveil_debounce_ms`.

- On `InsertEnter`, temporarily reveal all original types in that window.
- On `InsertLeave`, refresh and conceal again after a short debounce.
- On `CursorMoved`, reveal the declaration currently under the cursor for a
  configurable short time, or provide it in `:AutoVeilReveal` initially if
  automatic reveal is visually distracting.
- Highlight virtual `auto` with a dedicated `AutoVeilAuto` group linked by
  default to `Type` and subtly distinguish it as a display transformation.
- Highlight inferred explicit types with a distinct `AutoVeilDeducedType` group
  linked by default to `Type`.
- Selection, yanking, searching, macros, LSP navigation, and writes must keep
  operating on the original buffer text.

## Plugin structure

```text
autoload/autoveil.vim             # Small compatibility entry points, if needed
plugin/autoveil.vim               # Commands, defaults, autocmd group
autoload/autoveil/core.vim        # Per-buffer state and refresh scheduler
autoload/autoveil/lsp.vim         # vim-lsp capability/code-action adapter
autoload/autoveil/actions.vim     # Validate/normalize clang-tidy WorkspaceEdits
autoload/autoveil/hints.vim       # Validate clangd type inlay hints
autoload/autoveil/render.vim      # Text properties, matches, conceal options
autoload/autoveil/types.vim       # TypeView aliases and small data helpers
doc/autoveil.txt                  # :help documentation
test/                              # Vim test scripts and fixtures
```

Use a buffer-local state dictionary containing:

- enabled status;
- LSP client identity/capabilities;
- current buffer `changedtick` or equivalent generation;
- pending timer id;
- validated display edits keyed by stable id;
- match ids and virtual-text property ids;
- original window-local conceal options, keyed by window id.

Never leave properties, matches, timers, or changed local options behind after
`BufWipeout`, `WinClosed`, or `:AutoVeilDisable`.

## LSP integration

### Required adapter: vim-lsp

Depend directly on `vim-lsp`, but isolate the small number of calls in an
adapter so all display and validation code remains independent of its API. It
should provide:

```vim
def IsAttached(bufnr: number): bool
def SupportsCodeAction(bufnr: number): bool
def RequestCodeActions(bufnr: number, range: dict<any>, callback: func): void
def SupportsInlayHints(bufnr: number): bool
def RequestInlayHints(bufnr: number, range: dict<any>, callback: func): void
```

Use vim-lsp's public API only. Detect a missing vim-lsp dependency, clangd, or
required capability cleanly and leave the relevant mode untouched, with
`:AutoVeilStatus` explaining why.

### Request strategy

- Request code actions only for the visible range plus a small line margin.
- Debounce changes by roughly 250–400 ms.
- Cancel or discard responses whose buffer generation no longer matches.
- Refresh on `BufEnter`, `WinEnter`, `TextChanged`, `TextChangedI` (debounced),
  `InsertLeave`, and after a relevant LSP diagnostic update.
- Do not request actions while completion menus are active or while the buffer
  is in a transient invalid editing state.
- Cache accepted actions until the next relevant buffer change.

Request code actions with the matching clangd diagnostic as context. Request
inlay hints independently for the visible range. Never scrape Vim's rendered
inlay-hint text: consume the LSP response before vim-lsp renders it.

### clangd configuration documentation

Document both project-local and user-local configuration. A project example:

```yaml
# .clangd
Diagnostics:
  ClangTidy:
    Add: [modernize-use-auto]
```

And ensure the user's clangd launch includes `--clang-tidy` when required by
their setup. The README/help must explain that accurate compilation commands
(`compile_commands.json`) are essential; the plugin should not attempt to
manufacture compiler flags.

## Commands and configuration

### Implemented optional authority adjustment (2026-08-28 20:29 CEST)

The initial product deliberately made clang-tidy `modernize-use-auto` the sole
prefer-auto authority. It intentionally offers no action for plain copies such
as `State c = a`, and its configuration options cannot broaden that policy.

At the user's explicit request, prefer-auto now exposes a conservative default
and an opt-in `same-type-copies` level. The additional level uses clangd's
advertised `textDocument/ast` extension through public vim-lsp APIs. A lexical
pass only discovers bounded, simple `Type target = source;` request ranges;
structured clangd AST fields must then prove the exact variable/type ranges
and an `LValueToRValue` conversion over the expected `DeclRef`. Human-oriented
hover or `arcana` text is not parsed. Unsupported servers and ambiguous nodes
fail closed, and the original clang-tidy path remains unchanged.

This is the smallest safe scope adjustment that covers the motivating `c` and
`d` enum copies without introducing a direct Clang process, speculative server
document edits, or regex-based semantic authority.

Provide these commands:

- `:AutoVeilEnable` — enable for the current buffer.
- `:AutoVeilDisable` — remove all rendering for the current buffer.
- `:AutoVeilToggle` — toggle it.
- `:AutoVeilMode prefer-auto` — display safe `auto` spellings.
- `:AutoVeilMode show-deduced-types` — display full inferred type spellings.
- `:AutoVeilPreferAutoLevel {level}` — select conservative or opt-in
  same-type-copies authority.
- `:AutoVeilRefresh` — force a new LSP query for the visible region.
- `:AutoVeilReveal` — temporarily show real types in the current window.
- `:AutoVeilStatus` — report prerequisites, LSP attachment, cache generation,
  and number of substitutions.

Initial configuration variables:

```vim
g:autoveil_enabled_by_default = false
g:autoveil_mode = 'prefer-auto'
g:autoveil_debounce_ms = 300
g:autoveil_reveal_on_insert = true
g:autoveil_reveal_under_cursor = true
g:autoveil_max_visible_lines = 300
g:autoveil_type_name_limit = 80
g:autoveil_prefer_auto_level = 'conservative'
g:autoveil_max_ast_requests = 40
```

Make the plugin opt-in by default. Do not globally override mappings. If a
mapping is useful, document an example rather than installing one.

## Validation rules for a candidate action

Accept only an action when all conditions hold:

- It belongs to a clang-tidy `modernize-use-auto` diagnostic.
- Its edit targets the current buffer only.
- It contains exactly one text edit.
- The edit range is non-empty, entirely on one line, and falls within the
  requested range.
- The replacement is a valid, non-empty `auto` spelling. Initially allow only
  whitespace plus `const`, `volatile`, `auto`, `&`, `&&`, and `*` around it.
- The original range is before a local variable identifier and an initializer;
  add a light lexical sanity check to protect against malformed or stale edits.
- The edit does not touch preprocessor directives, comments, string literals,
  template parameter declarations, function return types, fields, aliases, or
  declarations without an initializer.

If any condition is ambiguous, skip it silently and leave the explicit type
visible.

## Validation rules for an inlay hint

Accept a type hint only when all conditions hold:

- It is a clangd type inlay hint associated with an `auto` local declaration in
  the current buffer and visible request range.
- Its label resolves to a non-empty, display-safe C++ type spelling.
- The associated declaration prefix is unambiguous and confined to one line.
- Replacing the entire prefix preserves visible cv/ref/pointer spelling from the
  type supplied by clangd; never concatenate an inferred type with leftover
  source `*`, `&`, or qualifiers.
- The rendered type does not exceed `g:autoveil_type_name_limit`; truncate only
  at a clear boundary and append an ellipsis, or skip it if safe truncation is
  not possible.
- It is not a structured binding, function return, field, alias, macro-expanded
  declaration, template parameter, or invalid/incomplete declaration.

The first release may intentionally support only simple initialized local
variables. Expanding syntax support requires new fixtures first.

## Implementation phases

### Phase 1 — Skeleton and lifecycle

1. Create plugin layout, Vim9script conventions, help file, and a minimal
   README.
2. Implement commands, feature checks, buffer/window state, cleanup, and
   `:AutoVeilStatus`.
3. Implement a renderer test double so lifecycle tests do not require clangd.

### Phase 2 — Rendering proof of concept

1. Implement `RenderEdit()` and `ClearRenderedEdits()` using a conceal match
   and zero-width virtual text property.
2. Verify types of different lengths and declarations adjacent on the same line.
3. Handle split windows independently and restore conceal options exactly.
4. Implement reveal in insert mode and explicit reveal command.

### Phase 3 — required clangd/vim-lsp adapter

1. Detect a vim-lsp-attached clangd client and code-action support.
2. Request code actions for a supplied range.
3. Normalize command-backed actions versus direct `edit` actions if vim-lsp and
   clangd expose both forms; initially support direct `WorkspaceEdit` actions
   only and report unsupported action shapes in debug status.
4. Correlate actions with `modernize-use-auto` diagnostics.
5. Request raw type inlay hints through vim-lsp without enabling vim-lsp's own
   rendered hints for the buffer.

### Phase 4 — Conservative type-view validators

1. Parse LSP ranges correctly (including UTF-16 positions when negotiated).
2. Enforce all validation rules above.
3. Add fixtures for `auto`, `auto&`, `const auto&`, pointers, nested template
   types, and rejected multi-edit/stale actions.
4. Validate type inlay hints and map them to the complete local `auto`
   declaration prefix.

### Phase 5 — Scheduling and performance

1. Add a generation counter and debounced refresh timer.
2. Limit requests to the visible range.
3. Drop stale asynchronous responses deterministically.
4. Profile a large C++ file and ensure scrolling does not cause request storms.

### Phase 6 — Documentation and release quality

1. Write install/configuration/troubleshooting guidance for vim-lsp, clangd,
   `.clangd`, and `compile_commands.json`.
2. Explain both display modes, that the plugin is a visual aid, and that it
   never changes source.
3. Include a concise limitations section and a known-good demo fixture.

## Testing strategy

Use Vim's built-in test runner in headless mode. Tests must be deterministic
and must not depend on a personal Vim configuration.

### Unit tests

- Candidate action validation and LSP range conversion.
- Type inlay-hint normalization, association, and length handling.
- WorkspaceEdit normalization.
- Replacement spelling validation.
- State cleanup, timer cancellation, and idempotent enable/disable.
- Window option capture/restore.

### Rendering integration tests

- Assert properties and conceal match placement for representative declarations.
- Assert `prefer-auto` and `show-deduced-types` render the same source buffer
  differently but remain entirely display-only.
- Verify the original buffer lines and `&modified` do not change.
- Verify yanking returns the original explicit type.
- Verify insert-mode reveal and post-insert re-conceal.
- Verify two windows into the same buffer and two separate buffers.

### LSP adapter tests

- Mock the vim-lsp adapter to simulate attached/unattached,
  code-action/inlay-hint capability support, direct edits, delayed replies, and
  stale replies.
- Keep an optional end-to-end test fixture that runs a real clangd only when it
  is installed in CI; skip with a clear message otherwise.

### Manual acceptance test

Open a C++ project with valid compilation commands and at least several
`modernize-use-auto` diagnostics. Enable the plugin, edit one declaration,
split the window, toggle it repeatedly, save the file, and inspect `git diff`.
The diff must remain empty unless the user made a normal source edit.

## Non-goals for v1

- Applying conversions to source code.
- Replacing every explicit type or every `auto` by heuristic.
- Support for legacy Vim, Neovim, Coc, or other LSP clients.
- Function return types, aliases, fields, structured bindings, or macro-heavy
  declarations.
- Persistent cache or project-wide analysis.

## Useful references

- Vim virtual text and text properties: https://vimhelp.org/textprop.txt.html
- Vim conceal options: https://vimhelp.org/options.txt.html
- vim-lsp documentation: https://github.com/prabirshrestha/vim-lsp/blob/master/doc/vim-lsp.txt
- clangd configuration and inlay hints: https://clangd.llvm.org/config
- clang-tidy `modernize-use-auto`: https://clang.llvm.org/extra/clang-tidy/checks/modernize/use-auto.html
- clangd Vim/Neovim setup: https://clangd.llvm.org/installation
