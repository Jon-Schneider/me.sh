# Escape to Notebook Navigator

Version 1.0.2

A tiny local Obsidian plugin that makes Escape mean **stop editing**, not
"toggle between the editor and sidebar."

## Behavior

- Markdown/Live Preview editor + `Esc`
  - Focus Notebook Navigator's note list.
- Notebook Navigator note list + `Esc`
  - Do nothing; remain in Notebook Navigator.
- Notebook Navigator folder/navigation pane + `Esc`
  - Do nothing; remain in Notebook Navigator.
- Notebook Navigator search/rename text field + `Esc`
  - Preserve the field's normal close/cancel behavior.
- Modal/menu/autocomplete/popover + `Esc`
  - Preserve normal close/dismiss behavior.

Use Notebook Navigator's arrows, Tab, Shift+Tab, Enter, etc. to move back
toward the editor.

## Requirement

Install and enable the **Notebook Navigator** community plugin first.

## Install / update

Replace `manifest.json` and `main.js` in:

`.obsidian/plugins/escape-to-notebook-navigator/`

Then restart Obsidian, or disable/re-enable the plugin.

## Test

1. Click into a Markdown/Live Preview editor.
2. Press Escape -> focus should move to Notebook Navigator's note list.
3. Press Escape again -> focus should stay in Notebook Navigator.
4. Move to the folder pane and press Escape -> focus should stay there.
5. Open Notebook Navigator search and press Escape -> search should close normally.
