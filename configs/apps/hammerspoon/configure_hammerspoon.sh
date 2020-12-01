echo "Configuring Hammerspoon"
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ln -fhs $current_dir/hammerspoon ~/.hammerspoon # For some reason this would not work with a relative path, an absolute path was required