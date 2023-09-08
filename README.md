# zoho_for_zsh
an oh-my-zsh custom plugin consisting of a set of shell functions and supporting resources for interacting with various zoho apis from the shell

## Requirements:
* `oh-my-zsh`
* `jq` (installed via homebrew)

## Setup Instructions for MacOS:
1. Install or update homebrew using instructions appropriate for your machine's CPU (https://brew.sh/)
2. Install or update `jq` via homebrew with command `brew install jq` or `brew upgrade jq`
3. Install `oh-my-zsh` if you don't have it set up already (use these instructions for first-time setup: https://github.com/ohmyzsh/ohmyzsh)
4. Clone this repository into your `$ZSH_CUSTOM/plugins` folder with command `gh repo clone vseng/zoho_for_zsh`
5. Add the plugin to your `.zshrc` file before oh-my-zsh is sourced using command `plugins=(zoho_for_zsh)`
6. In your `.zshrc` file, set `$ZOHO_SAVE_DIR` to the directory of your choice before oh-my-zsh is sourced with command `export ZOHO_SAVE_DIR=<your path here>`
7. Restart your shell and you are ready to go!
