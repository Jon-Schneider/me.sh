# me.sh

This repo contains config files and scripts for setting up my dev environment and transferring changes between my Macs.

## Structure

There are several scripts in the project root for syncing app and system config. App and system config is done by script files matching the pattern ```configure_*.sh``` inside the configs directory. Config files for applications are stored with the config script that copies or links them to the right location.

Most config files are symlinked into place, so editing either side edits both. Files marked **managed** -- a gitignored ```<file>.d/``` overlay directory next to them containing a tracked ```dest``` marker naming the deploy path -- are instead deployed as composed copies: the repo base file merged with machine-local fragments (```.json```/```.yaml```/```.yml```/```.toml``` deep-merge; executables act as stdin/stdout transformers). Apps that rewrite their own config only touch the deployed copy, so their machine-local state never reaches the repo. Run ```me diff <name>``` to preview that drift and ```me up <name>``` (alias ```absorb```) to interactively pull chosen hunks back into the base file. Full manual: ```docs/merged-configs.md```.
## Use

### Initial Setup

1. Run ```me.sh```. It will walk you through any prerequisites and then configure your mac with my dev environment.
2. There is no step 2.

### Updates

- Run ```me``` for targeted syncing: run it with no arguments to list config names, ```me app karabiner-elements``` to sync one config, ```me app``` / ```me sys``` to sync a whole tree, or ```me all``` for everything. Zsh tab-completion is installed by the shell config.
- Run ```sync_packages.sh``` when there are new apps to be installed.

I find ```me app``` to be the one that I need to run most frequently because I'm constantly optimizing my app configurations, especially Karabiner-Elements.