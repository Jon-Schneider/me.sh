# me.sh

This repo contains config files and scripts for setting up my dev environment and transferring changes between my Macs.

## Structure

The repository is organized by lifecycle:

- `bootstrap/NN-name.sh` contains ordered, fail-fast steps needed to prepare a fresh Mac. The path opts a script into bootstrap and the numeric filename prefix determines its order.
- `configs/apps/` and `configs/macos/` contain convergent configuration units. A unit is either declarative (`config.yml`, plus optional `post.sh`) or legacy (`configure_*.sh`). These are the only units included in `me all`; an optional numeric directory prefix controls ordering without becoming part of the public name.
- `lib/` contains implementation shared by the runner and configuration scripts.

Config files live inside their unit directory. A declarative `config.yml` lists ordinary symlinks and static copies; managed files remain declared by their own `<file>.d/dest` markers and are deployed automatically. `configs/macos/00-homebrew/configure_homebrew.sh` runs first during `me all`, so the Brewfile (including the `yq` manifest parser) is reconciled before dependent units.

Most config files are symlinked into place, so editing either side edits both. Manifest `copies:` rows deploy ordinary materialized copies. Files marked **managed** -- a gitignored ```<file>.d/``` overlay directory next to them containing a tracked ```dest``` marker naming the deploy path -- are deployed as composed copies: the repo base file merged with machine-local fragments (```.json```/```.yaml```/```.yml```/```.toml``` deep-merge; executables act as stdin/stdout transformers). Apps that rewrite either kind of copy only touch the deployed file, so their changes never reach the repo implicitly. Run ```me diff <name>``` to preview copy drift and ```me up <name>``` (alias ```absorb```) to interactively pull chosen hunks back into the source file. Full managed-file manual: ```docs/merged-configs.md```.

## Use

### Initial Setup

1. Run ```me.sh```. It runs the ordered bootstrap sequence and then converges all macOS and app configuration.
2. There is no step 2.

### Updates

- Run ```me``` with no arguments to list every config and bootstrap unit.
- Run ```me app karabiner-elements``` to sync one app config, ```me app``` / ```me macos``` to sync a whole tree, or ```me all``` for everything.
- Run ```me bootstrap``` for all fresh-machine steps or, for example, ```me bootstrap homebrew-install``` for one. Bare names work when unambiguous.
- Run ```me install``` to (re)copy a ```~/bin/me``` shim that execs this checkout, so ```me``` works from any directory.
- Edit the Brewfile and run ```me homebrew``` for packages only, or let the next ```me all``` reconcile them automatically. Zsh tab-completion includes every scope and unit.
- Run ```me doctor``` to validate every manifest, managed-file marker, and destination claim. Run ```me plan finicky``` (or ```me plan app```) to validate and preview actions without deploying them.

I find ```me app``` to be the one that I need to run most frequently because I'm constantly optimizing my app configurations, especially Karabiner-Elements.
