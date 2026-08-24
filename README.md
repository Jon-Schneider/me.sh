# me.sh

This repo contains config files and scripts for setting up my dev environment and transferring changes between my Macs.

## Structure

There are several scripts in the project root for syncing app and system config. App and system config is done by script files matching the pattern ```configure_*.sh``` inside the configs directory. Config files for applications are stored with the config script that copies or links them to the right location.
## Use

### Initial Setup

1. Run ```me.sh```. It will walk you through any prerequisites and then configure your mac with my dev environment.
2. There is no step 2.

### Updates

- Run ```sync``` for targeted syncing: run it with no arguments to list config names, ```sync app karabiner-elements``` to sync one config, ```sync app``` / ```sync sys``` to sync a whole tree, or ```sync all``` for everything. Zsh tab-completion is installed by the shell config.
- The shell aliases ```sac``` and ```ssc``` are shorthand for ```sync app``` and ```sync sys```.
- Run ```sync_packages.sh``` when there are new apps to be installed.

I find ```sync app``` to be the one that I need to run most frequently because I'm constantly optimizing my app configurations, especially Karabiner-Elements.