# Merged configs ("managed files")

Most files in this repo are **symlinked** into place by a unit's `config.yml` or legacy `configure_*.sh`: edit either side of the link and both sides change. That liveness is great for tweaking configs, but it cuts both ways — apps that rewrite their own config (herdr, Codex, work-machine system tools) spray machine-local state straight into your working tree, which is how the old git clean-filter hack was born.

Files marked **managed** use a different model: they are deployed as **materialized copies**, composed from a canonical repo base plus machine-local overlay fragments. App-written state lands only in the deployed copy and never reaches the repo; changes you *do* want to keep flow back through an explicit review step (`me up`). Plain `copies:` rows in `config.yml` participate in the same diff/up workflow, but compare directly against their repo source without overlays.

```
repo base                    deployed copy (real file)
configs/apps/agents/Claude/settings.json
  + settings.json.d/10-shipyard-pane-title.json   ──compose──▶   ~/.claude/settings.json
  + settings.json.d/20-whatever.json              (gitignored)   (app-writable, repo-safe)
        gitignored overlays
```

## Declaring managed files: autodetection

There is no central registry. A config file is **managed** if and only if its sibling `<file>.d/` directory contains a `dest` marker -- a one-line file naming the deploy path (a literal `$HOME/` prefix is expanded; nothing else is evaluated):

```
configs/apps/agents/Claude/settings.json          # the repo base
configs/apps/agents/Claude/settings.json.d/dest   # contents: $HOME/.claude/settings.json
configs/apps/agents/Claude/settings.json.d/*.json # machine-local fragments (gitignored)
```

The marker lives *inside* the gitignored overlay dir, so it's the dir's single tracked file: it makes an otherwise-empty `.d/` directory committable, which is how a managed file with no fragments yet (e.g. `Codex/config.toml.d/dest`, managed purely to isolate app-written state) stays declared.

Manifest units deploy these markers automatically; legacy deployment scripts call `deploy_managed_under <config-dir>`. `me diff` / `me up` discover rows the same way, so declaration and behavior can't drift apart. Currently managed:

| Repo base | Deploys to |
|---|---|
| `configs/apps/agents/Claude/settings.json` | `$HOME/.claude/settings.json` |
| `configs/apps/agents/Codex/hooks.json` | `$HOME/.codex/hooks.json` |
| `configs/apps/agents/Codex/config.toml` | `$HOME/.codex/config.toml` |

A `.d/` directory missing its marker, or a marker whose base file is gone, prints an error during deploy instead of being silently skipped.

## Overlay fragments: `<file>.d/`

Any managed file may have a sibling directory named `<file>.d/`. It is gitignored (`*.d/`) and therefore **machine-local by design** — this is where system-specific hooks, work-only integrations, and personal experiments belong.

Fragments apply in lexical order (`10-…` before `20-…`; prefix by tens so insertions don't force renames). Three kinds:

### 1. `.json`, `.yaml`/`.yml`, `.toml` fragments — merged

All three formats use identical merge semantics (each side is parsed by its own suffix; YAML and TOML conversion is delegated to [`yq`](https://github.com/mikefarah/yq), so `brew install yq` is required on machines that compose YAML/TOML fragments):

Merge semantics:

| Base value | Fragment value | Result |
|---|---|---|
| dict | dict | recursive deep-merge |
| array | array | concatenation, exact duplicates dropped |
| anything | anything | fragment replaces |

Array concatenation is deliberate: hook groups append instead of clobbering. Example JSON fragment that adds a PostToolUse hook without touching any base hooks:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "command": "/Users/$(whoami)/bin/update_shipyard_pane_title", "type": "command" }
        ]
      }
    ]
  }
}
```

### 2. Executable fragments — transformed

Anything executable (no extension required) acts as a transformer: composed-so-far content on **stdin**, rewritten content on **stdout**. Run in lexical order after/between JSON merges, so a transformer sees everything before it.

```sh
#!/bin/sh
python3 -c 'import json,sys; d=json.load(sys.stdin); d.setdefault("env",{})["MY_FLAG"]="1"; print(json.dumps(d, indent=2))'
```

Non-executable files with unknown extensions are silently skipped (so editor droppings and `.DS_Store` don't explode a deploy).

**Composition caveats:** the *composed output* is re-emitted from parsed data, so comments in a YAML/TOML base are dropped from the deployed copy, TOML datetimes may come back as strings, and key order follows the base document. Repo bases are never rewritten by composition — only `me up` (via your explicit approval) touches them.

## Daily usage

```sh
me diff agents          # preview drift for one config
me diff                 # preview drift across every config
me diff app agents git  # several configs, explicit scope
me up agents            # interactive hunk-by-hunk review
me absorb agents        # older name, same thing
```

- **Drift** is everything the deployed copy contains beyond its deployable repo state: the manifest source for a static copy, or a fresh base-plus-overlays composition for a managed file. That includes app-written runtime state, formatting churn, and edits made directly to the live file.
- `me diff` renders one combined `git diff` covering every drifted static or managed copy (`a/` = repo side, `b/` = live side), so the whole sweep pages through your git config (delta, less, …) in a single session whenever stdout is a terminal; plain when piped. Read-only.
- `me up` reviews hunks with native `git add -p`: `[y]` stage, `[n]` skip, `[a]` stage the rest of this file, `[d]` skip the rest, `[s]` split, `[e]` edit, `[?]` help. Staged hunks are applied to the **repo source** with `git apply`; declined hunks stay in the deployed copy only. Scripted or non-tty runs fall back to `lib/hunk_selector.py`: set `ABSORB_ANSWERS="y n q"` — answers are consumed in order but **restart for each deployed file**, since each file spawns a fresh picker.
- After absorbing, re-run the normal sync (`me app agents`, for example) to redeploy clean copies.
- If a hunk won't apply (its context overlaps fragment-added regions), nothing is lost: the diff is kept in a `/tmp/me-drift.*` directory and its path is printed — resolve by editing the base or fragment by hand.

## Editing workflows

| You change… | Then… | Effect |
|---|---|---|
| Repo base or a committed file elsewhere | `me app <name>` | Recomposed into the deployed copy |
| An overlay fragment | `me app <name>` | Same — fragments compose on every deploy |
| A deployed static or managed copy | `me diff` to see it, `me up <name>` to keep some/all of it | Keeper hunks land in the manifest source or managed base |

Unlike symlinked files, static and managed copies have no live link back to the repo: deploying overwrites them from their repo source or fresh composition. That's the point — it's also what keeps junk out. Nothing is silently destroyed that `me diff` wouldn't have shown you first, though; make `diff` a habit before `up`.

## Adding a new managed file

1. Add a sibling `<file>.d/` directory containing a `dest` marker with the deploy path.
2. If the owning unit has `config.yml`, nothing else is required: managed markers are discovered and deployed automatically. For a legacy unit, make sure its `configure_*.sh` calls `deploy_managed_under` (or use `deploy_config <src> <dst>` when that behavior is specifically wanted).
3. Optionally add fragments to the `.d/` directory.
4. `me <scope> <name>`.

**One-time cost when converting a formerly-symlinked file:** the fresh composition starts from the clean repo base, so runtime state the app had written into the old link target disappears from the live copy (Codex re-prompts project trust once; herdr registrations return on the next `configure` run because it reinstalls integrations). Back up the live file first if in doubt.

## Multi-machine behavior

- The `dest` markers are **tracked**, so management declarations propagate on pull automatically. Fragment *contents* stay gitignored, so each machine gets exactly the overlays you give it: ship the Shipyard pane-title fragment by copying the `settings.json.d/10-*.json` / `hooks.json.d/10-*.json` files; machines without them simply don't register those hooks.
- If a fragment turns out to be wanted everywhere, commit it deliberately. Re-including files inside an ignored directory takes three rules and is easiest per-path:

  ```gitignore
  #.gitignore additions to track one shared fragment
  !configs/apps/agents/Claude/settings.json.d/
  configs/apps/agents/Claude/settings.json.d/*
  !configs/apps/agents/Claude/settings.json.d/*.shared.json
  ```

  (A blanket `!**/*.d/` un-ignore re-exposes *every* fragment — verified the hard way so you don't have to.)
- Old clones that still have `filter.*` entries in `.git/config`: harmless dead weight once this lands there (the `.gitattributes` wiring is deleted with it). `git config --unset filter.<name>.clean/smudge` tidies up if you care.

## Implementation map

| Piece | Role |
|---|---|
| `lib/compose.sh` | Marker discovery (`managed_files_under`), `$HOME` expansion, overlay discovery, merge dispatch + transformer execution, `deploy_config` / `deploy_managed_under` |
| `lib/deep_merge.py` | Format parsing/emission (JSON native; YAML/TOML via `yq`) and the shared deep-merge semantics |
| `lib/hunk_selector.py` | Fallback hunk picker for scripted/no-tty `me up` runs; interactive runs use native `git add -p` |
| `run_drift` in `me` | Shared engine behind `me diff` and `me up` / `absorb` for manifest copies and managed files |
| `lib/manifests.sh` | Manifest validation/deployment, static-copy drift discovery, and automatic managed-marker handling |
| `<file>.d/dest` markers | What is managed and where it deploys |

Deploys replace an existing destination via temp file + move and **never write through an existing symlink** — the link is removed first, so a botched migration can't clobber your repo through the link.
