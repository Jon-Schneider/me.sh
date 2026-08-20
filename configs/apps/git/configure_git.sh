echo "Configuring git..."
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ln -sfn $current_dir/.gitignore ~/.gitignore
ln -sfn $current_dir/.gitconfig_shared ~/.gitconfig_shared
ln -sfn $current_dir/.gitconfig_jsc ~/.gitconfig_jsc
ln -sfn $current_dir/.gitattributes ~/.gitattributes
ln -sfn $current_dir/git-branch-select ~/bin/git-branch-select

# ~/.gitconfig has to stay a real, untracked file: it is where `git config
# --global` and machine setup tools (iapsshctl) write, and those writes must not
# land in this repo. It includes the tracked config first, so anything written
# afterwards overrides it.
if [[ -L ~/.gitconfig ]]; then
  unlink ~/.gitconfig
fi
if ! grep -qs 'gitconfig_shared' ~/.gitconfig; then
  existing_config="$(cat ~/.gitconfig 2>/dev/null)"
  {
    printf '[include]\n\tpath = ~/.gitconfig_shared\n'
    if [[ -n "$existing_config" ]]; then
      printf '%s\n' "$existing_config"
    fi
  } > ~/.gitconfig
fi
