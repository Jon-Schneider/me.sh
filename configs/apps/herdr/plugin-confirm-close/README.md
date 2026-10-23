# Confirm Close

Local plugin `me.confirm-close`, linked from this directory by `../post.sh`.
The managed `../config.toml` binds Cmd+W (forwarded as Ctrl+W by Ghostty) to
`me.confirm-close.close`.

An idle shell closes immediately. A detected agent or foreground job opens a
68×11 Herdr terminal popup with padded content, centered buttons, and
**Confirm** selected initially. **Left/Right**
switches between Confirm and Cancel; **Enter/Return** activates the selection.
**Y** closes directly; **N**, **Esc**, or any other key keeps the pane. The popup
disappears when its command exits and does not change the pane layout.
No dependencies beyond macOS's Python standard library.

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
