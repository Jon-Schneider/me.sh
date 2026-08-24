# Declarative Config Manifests

Status: implemented; repository file-deployment units are migrated.

## Problem

Config units are discovered by path (`configs/{apps,macos}/<unit>/`),
but each unit's deployment topology lives inside imperative Bash. To learn that
`configs/apps/finicky/.finicky.js` deploys to `$HOME/.finicky.js`, you must read
or execute its configure script.

Most of those scripts are largely `mkdir -p` and `ln` rows encoded as code.
They also use several combinations of `ln` flags with no uniform policy for an
existing destination. Consequently, symlink topology cannot be inspected,
dry-run, linted, or checked for collisions without interpreting shell code.

Managed/composed files already expose their topology declaratively through the
`<base>.d/dest` convention. Ordinary symlinks and static copies should do the
same.

## Decision

A config-unit directory may replace its `configure_*.sh` scripts with a
declarative `config.yml` and an optional conventional `post.sh` hook.

```text
configs/apps/finicky/
  config.yml
  .finicky.js

configs/apps/example/
  config.yml
  post.sh
  assets...
```

The filesystem remains the registry:

- Scope comes from `configs/apps/` or `configs/macos/`.
- The unit's canonical name comes from its directory, minus an optional
  two-digit ordering prefix.
- A direct child of a scope directory is a manifest unit when it contains
  `config.yml`; nested asset directories are never units themselves.
- `post.sh`, when present, belongs to that manifest unit automatically; it is
  not listed inside YAML.
- A legacy directory remains discoverable through its `configure_*.sh` files.
- A directory containing both `config.yml` and `configure_*.sh` is invalid.

Bootstrap remains `bootstrap/NN-name.sh`. Bootstrap discovery and sequencing
must never require the YAML parser.

## Unit identity

Manifest adoption makes the directory the durable unit boundary. Script
filenames are an implementation detail and no longer create public aliases.
For example, a converted `configs/apps/vscode/` is invoked as `me vscode`; the
incidental `me vscode_extensions` alias disappears.

The repository migration accounted for directories that exposed multiple
useful names:

- Sudoers setup moved out of `shell` into its own macOS unit, preserving
  `me sudoers` and correcting its scope.
- VS Code settings and extension reconciliation became the single `vscode`
  unit, intentionally retiring `me vscode_extensions`.

No `name:` or `aliases:` fields are added to YAML. Identity remains derived
from path rather than duplicated in metadata.

## Manifest shape

`config.yml` describes symlinks and static copies:

```yaml
symlinks:
  - src: .finicky.js
    dest: $HOME/.finicky.js
  - src: themes/jon
    dest: $HOME/.config/ghostty/themes/jon
copies:
  - src: Default.idekeybindings
    dest: $HOME/Library/Developer/Xcode/UserData/KeyBindings/Default.idekeybindings
```

Both sections are optional and default to empty lists. Row order within each
section is preserved. Symlinks deploy first, followed by copies. A manifest
with no rows remains useful for a unit containing only managed files,
`post.sh`, or both.

The schema deliberately has no general interpolation and no embedded shell:

- `src` is a path relative to the unit directory.
- `dest` accepts only a literal `$HOME/` prefix.
- Destinations name the final link path. A trailing directory used to request
  `ln`'s implicit-basename behavior is rejected.
- Unknown sections and keys are errors rather than silently ignored.

## Managed files remain marker-canonical

`<base>.d/dest` remains the sole declaration of a composed file and its
destination. Repeating those rows in `config.yml` would create two sources of
truth.

The manifest engine must nevertheless deploy them automatically. A converted
unit no longer has a configure script available to call
`deploy_managed_under`, so managed-file discovery is part of manifest-unit
execution.

Lint and collision detection build one combined destination index from both:

- every `config.yml` symlink or copy row;
- every `<base>.d/dest` marker.

This catches a symlink and a composed file claiming the same destination, not
just collisions between manifests.

## Optional `post.sh`

`post.sh` is the single escape hatch for behavior that is not file deployment:
`defaults write`, `launchctl`, application CLIs, generated files, or other
bespoke convergence logic.

The runner executes it directly, so it must be executable and contain its own
shebang. Its contract is:

- current working directory: the unit directory;
- `ME_REPO_ROOT`: absolute repository root;
- `ME_UNIT_DIR`: absolute unit directory;
- nonzero exit: stop that unit; an aggregate run records the failure and
  continues with the next ordinary unit.

If bespoke logic must happen before or between file-deployment operations, the
unit is not a good manifest candidate yet. It should remain a complete legacy
`configure_*.sh` unit rather than hide deployment order inside hooks.

## Execution model

For a manifest unit:

1. Parse and validate the complete manifest and the unit's managed markers.
2. Create destination parent directories and deploy symlinks in row order.
3. Materialize static copies in row order.
4. Deploy managed/composed files discovered under the unit directory.
5. Execute `post.sh`, if present.

Immediately before each deployment or hook, the engine prints the symlink,
copy, managed-file composition, or `post.sh` path it is about to run. Hooks do
not need their own boilerplate status messages; their output can focus on the
work they perform.

Validation happens before mutation. A failure during deployment stops the
current unit. As today, aggregate and multi-unit commands normally continue
with the next selected unit, summarize failures, and ultimately return nonzero.

Legacy units continue to run their configure scripts unchanged. The engine
supports legacy and manifest units in different directories indefinitely so
migration can remain opportunistic.

## Homebrew and `yq`

YAML is parsed with the Mike Farah `yq` already declared in the Brewfile.
Discovery, sorting, and selection remain shell-only; `yq` is needed only when a
selected manifest unit begins execution.

Fresh-machine ordering is:

```text
me bootstrap     # installs Homebrew without parsing YAML
me all
  -> configs/macos/00-homebrew/configure_homebrew.sh
       -> brew bundle installs yq
  -> remaining legacy and manifest units
```

`00-homebrew` is an infrastructure prerequisite for manifest-backed config.
During aggregates that include it (`me all` and `me macos`), it remains a
legacy shell unit and is run fail-fast before any manifest unit. If it fails,
the aggregate stops instead of producing one missing-`yq` error per subsequent
unit.

A targeted manifest command on a machine without `yq` fails once with a clear
message: run `me homebrew`, then retry. It does not silently install packages
or invoke another unit.

This is intentionally different from a bootstrap YAML manifest: configuration
metadata is consumed only after the package manager exists, while the recipe
that acquires the package manager remains parser-free.

## Symlink safety policy

The engine owns one explicit policy rather than exposing `ln` flags in YAML:

- Resolve `src` against the unit directory and require it to exist.
- Canonicalized sources must remain inside the repository. This permits a unit
  to reference shared repository assets such as `../../../lib/...`, but not
  arbitrary machine files.
- Expand only the literal `$HOME/` prefix in `dest`.
- Reject empty destinations, destination `.` or `..` path components,
  non-home destinations, and trailing slashes.
- Create missing destination parent directories.
- If the destination is absent, create the symlink.
- If the destination is a symlink, replace that symlink without following it.
- If the destination is a real file, directory, or another object, fail loudly
  and leave it untouched.

System paths such as `/etc/sudoers.d` are intentionally outside this grammar;
they belong in a legacy script or `post.sh`, where privileged mutation remains
obvious during review.

## Copy safety and drift

Copy rows use the same source and destination grammar as symlinks, but their
sources must be regular files. Deployment prepares a sibling temporary file
and replaces an absent destination, a symlink, or a regular file. It refuses to
replace a directory or any other non-file object.

`me diff` compares each deployed copy directly with its repo source. `me up`
(or `me absorb`) offers the same hunk-by-hunk review used for managed files and
applies accepted content changes to that source. Re-run the unit afterward to
redeploy the accepted state. Copy drift is not composed: units that need local
overlay fragments should continue to use `<base>.d/dest`.

## Validation and doctor

Runtime validation covers the selected unit. A read-only `me doctor` validates
the entire repository without deploying anything:

- YAML parses and matches the exact schema.
- Every source exists and remains within the repository.
- Every destination follows the grammar above.
- No normalized destination is claimed more than once across manifests and
  managed-file markers, regardless of scope.
- Every marker base exists and every marker destination is valid.
- `post.sh`, when present, is a regular executable file.
- No manifest unit also contains `configure_*.sh`.
- No legacy unit contains an orphaned `post.sh`.
- Numeric directory prefixes are well formed and do not produce duplicate
  public unit names after stripping.

Doctor should report all findings in one run and exit nonzero if any exist.

## Dry run

`me plan [scope] [name...]` uses normal resolution but performs no deployment:

- Manifest units print each symlink replacement, managed-file deployment, and
  optional `post.sh` execution in actual execution order.
- Legacy units are reported as opaque configure scripts that would execute;
  their internal mutations cannot be inferred safely.
- Validation errors are reported exactly as they would be during execution.

With no names, `me plan app`, `me plan macos`, and `me plan all` cover the
corresponding aggregates. Planning requires `yq` for selected manifest units.

## Migration

Migration is per directory and reversible:

1. Choose a unit whose deployment is mostly symlinks or static copies.
2. Add `config.yml`; add `post.sh` only for genuine post-deployment behavior.
3. Remove that directory's `configure_*.sh` in the same change.
4. Run `me doctor`, `me plan <unit>`, the targeted unit, and relevant drift
   checks.

All units that deploy repository-owned files now use manifests. Purely
imperative legacy units remain for Homebrew, Ruby, npm globals, Finder, and
Night Shift. Units such as Karabiner and the general macOS settings unit use an
empty manifest plus `post.sh` because their file changes are generated or
privileged rather than declarative repo-file copies.

## Deliberate non-goals

- Manifests do not define bootstrap membership or ordering.
- Manifests do not define unit identity, aliases, dependencies, or scope.
- Manifests do not redeclare composed files.
- Manifests do not expose clobber-policy switches.
- `post.sh` is not a general workflow language.
- Conversion of every legacy script is not required for completion.

## Documentation

The README and `docs/merged-configs.md` describe directory-canonical unit
discovery, automatic managed-file deployment, `me doctor`, and the
legacy/manifest coexistence rule.
