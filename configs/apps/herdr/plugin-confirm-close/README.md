# Confirm Close

Local plugin `me.confirm-close`, linked from this directory by `../post.sh`.
The managed `../config.toml` binds Cmd+W (forwarded as Ctrl+W by Ghostty) to
`me.confirm-close.close`.

An idle shell closes immediately. A detected agent or foreground job opens a
68×12 Herdr terminal popup showing the pane title and running job, with padded
content, centered buttons, and
**Confirm** selected initially. **Left/Right**
switches between Confirm and Cancel; **Enter/Return** activates the selection.
Click either button to activate it with the mouse.
**Y** closes directly; **N**, **Esc**, or any other key keeps the pane. The popup
disappears when its command exits and does not change the pane layout.
No dependencies beyond macOS's Python standard library.

The title prefers the pane's label, then its title or terminal title, and falls
back to its pane ID. Long titles are shortened to fit the popup.

The existing micro/xlent Ctrl+W passthrough and pane → tab → workspace close
cascade are preserved. Confirmation targets the original terminal even if
focus changes. Unknown process metadata requires confirmation; API failures
leave the pane open. Mouse-menu closes keep Herdr's normal behavior.

Ordinary background jobs (`command &`) and detached processes are not detected.
Suspended agents are covered when Herdr retains their agent identity.

To activate manually:

```sh
herdr plugin link ~/Developer/jsc/me.sh/configs/apps/herdr/plugin-confirm-close
herdr config check
herdr server reload-config
```
