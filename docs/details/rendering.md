# Rendering and reveal behavior

## 2026-08-28 20:55 CEST - Selective cursor omission

Normal rendering begins from the complete cached TypeView list. It clears only
AutoFlip-owned properties and tracked matches, then adds one virtual-text
property and one conceal match per rendered view.

Cursor reveal stores one stable TypeView ID in buffer state. The same render
pipeline filters out that ID, so its source range has neither replacement text
nor a conceal match. Every other TypeView is reconstructed normally. Moving
between views changes the omitted ID in one render pass; leaving all view
ranges or the active window clears the ID and restores complete rendering.

Insert and explicit timed reveal set full-reveal state instead. The renderer
then leaves all AutoFlip properties and matches cleared until insert exit or
timer expiry.

Vim properties are buffer-owned and conceal matches are window-owned. Selective
omission therefore reveals the chosen type in every split showing the buffer,
while each split independently retains conceal matches and option restoration
for all unrelated views.
