# ncdu background deletion

Requires ncdu 2.9+ and Python 3. Deploy with `./me ncdu`.

Pressing `d` immediately renames the selected file, directory, or symlink into
a private `.ncdu-delete-*` directory beside its original path, then launches
`rm -rf` in a detached session. There is no confirmation prompt. The original
path disappears before ncdu refreshes it; disk space is reclaimed as deletion
progresses, even after exiting ncdu or closing the terminal.

The rename never copies data across filesystems. If the rename fails (for
example, when selecting a mount point), the original stays in place. Symlinks
are deleted without following their targets. A new item created at the original
path is unaffected by the background deletion.

Successful deletions remove the staging directory. Failed deletions leave the
remaining data under `.ncdu-delete-*/item` and diagnostics in `error.log` beside
it. These directories may appear when refreshing their parent while deletion
is still running. They are permanent deletions, not Trash; there is no undo.

Run the focused checks with:

```sh
python3 -m unittest discover -s configs/apps/ncdu/tests -v
```
