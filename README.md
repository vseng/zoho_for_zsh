# zsh_for_zoho
an oh-my-zsh custom plugin consisting of a set of shell functions and supporting resources for interacting with various zoho apis from the shell

## Requirements:
* `oh-my-zsh`
* `jq` (installed via homebrew)

## Local Environment Setup Instructions:
01. Install or update homebrew using instructions appropriate for your machine (https://brew.sh/)
02. Install or update `jq` via homebrew -> `brew install jq` or `brew upgrade jq`
03. Install `oh-my-zsh` if you don't have it already (use these instructions for first-time setup: https://github.com/ohmyzsh/ohmyzsh)
04. Clone `zoho_for_zsh` into the directory of your choice -> `cd <your path here>; gh repo clone vseng/zoho_for_zsh`
05. Create a symlink from your new project directory to the `$ZSH_CUSTOM/plugins` directory -> `ln -s <your path here>/zoho_for_zsh $ZSH_CUSTOM/plugins`
06. Activate the plugin by adding it to your `.zshrc` file before `oh-my-zsh` is sourced -> `plugins=(zoho_for_zsh)`
07. In your `.zshrc` file, set `$ZOHO_IN` to the project resources directory before `oh-my-zsh` is sourced -> `export ZOHO_IN=<your path here>/zoho_for_zsh/resources`
08. In your `.zshrc` file, set `$ZOHO_OUT` to the directory of your choice before `oh-my-zsh` is sourced -> `export ZOHO_OUT=<your path here>`
09. Make sure you have read and write access to `$ZOHO_IN` and `$ZOHO_OUT`
10. Restart your shell and you are ready to go!
