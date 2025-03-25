#!/bin/bash

set -e

############################################
# 0) Helper Functions
############################################
play_sound() {
    afplay /System/Library/Sounds/Ping.aiff    
}

############################################
# 1) Homebrew Setup
############################################
echo "🔍 Checking for Homebrew..."
if ! command -v brew &>/dev/null; then
    echo "🍺 Installing Homebrew..."
    NONINTERACTIVE=1 
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "✅ Homebrew already installed."
fi

echo "🔄 Updating Homebrew..."
brew update && brew upgrade

############################################
# 2) Install CLI Tools
############################################
install_cli_tool() {
    if ! brew list "$1" &>/dev/null; then
        echo "⚙️ Installing $1..."
        brew install "$1"
    else
        echo "✅ $1 is already installed. Skipping."
    fi
}

echo "⚙️ Installing command-line tools..."
install_cli_tool git
install_cli_tool gpg
install_cli_tool node
install_cli_tool nvm
install_cli_tool python
install_cli_tool awscli
install_cli_tool docker
install_cli_tool jq
install_cli_tool tree

echo "✅ Command-line tools installed!"

############################################
# 3) NVM Setup
############################################
echo "📦 Setting up NVM (Node Version Manager)..."
export NVM_DIR="$HOME/.nvm"
[ -s "$(brew --prefix nvm)/nvm.sh" ] && source "$(brew --prefix nvm)/nvm.sh"
nvm install --lts

echo "✅ NVM setup complete!"

############################################
# 4) Git User Setup
############################################
play_sound
read -p "Enter your Git username: " git_username
if [[ -z "$git_username" ]]; then
    echo "❌ Git username cannot be empty! Exiting."
    exit 1
fi
git config --global user.name "$git_username"

read -p "Enter your Git email: " git_email
if [[ -z "$git_email" ]]; then
    echo "❌ Git email cannot be empty! Exiting."
    exit 1
fi
git config --global user.email "$git_email"
git config --global core.editor "code --wait"
git config --global init.defaultBranch main

echo "✅ Git configured!"

############################################
# 6) GPG Key Setup (Simplified)
############################################

echo "🔐 Checking for existing GPG key..."

# Attempt to find an existing GPG key ID
existing_gpg_key_id="$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep '^sec' | head -n1 | sed -E 's|.*/([^ ]+) .*|\1|')"

if [ -n "$existing_gpg_key_id" ]; then
    echo "🔑 Copying public key to clipboard..."
    gpg --armor --export "$existing_gpg_key_id" | pbcopy
    echo "✅ Public GPG key copied to clipboard!"
    echo "(Here is the same key, displayed in terminal for reference:)"
    gpg --armor --export "$existing_gpg_key_id"
else
    echo "🔧 No GPG key found. Generating a new one..."

    gpg_config="$HOME/.gnupg/gpg-key-config"
    mkdir -p "$HOME/.gnupg" && chmod 700 "$HOME/.gnupg"

    cat > "$gpg_config" <<EOF
Key-Type: RSA
Key-Length: 4096
Key-Usage: sign
Name-Real: "$(git config --global user.name)"
Name-Email: "$(git config --global user.email)"
Expire-Date: 0
%no-protection
%commit
EOF

    gpg --batch --gen-key "$gpg_config"
    rm "$gpg_config"

    # Grab the newly generated key ID
    new_gpg_key_id="$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep '^sec' | head -n1 | sed -E 's|.*/([^ ]+) .*|\1|')"
    echo "🔑 Copying public key to clipboard..."
    gpg --armor --export "$new_gpg_key_id" | pbcopy
    echo "✅ Public key copied to clipboard! (ID: $new_gpg_key_id)"
    echo "🚀 It is now ready to be pasted into your Bitbucket GPG key settings."
    echo "(Here is the same key, displayed in terminal for reference:)"
    gpg --armor --export "$new_gpg_key_id"

    existing_gpg_key_id="$new_gpg_key_id"
fi

echo "⚠️ IMPORTANT: Please add this key to Bitbucket following the instructions here:"
echo "https://confluence.atlassian.com/bitbucketserver/using-gpg-keys-913477014.html#UsingGPGkeys-add"
echo "🚀 Once you've added your key, press any key to continue..."
play_sound
read -n 1 -s

if [ -n "$existing_gpg_key_id" ]; then
    git config --global user.signingkey "$existing_gpg_key_id"
    git config --global commit.gpgsign true
    echo "✅ Git commit signature verification configured with key ID: $existing_gpg_key_id"
else
    echo "❌ No GPG key found or generated. Cannot configure signing."
fi

############################################
# 7) Install CLI Tools
############################################

install_cask_app() {
    local app_name="$1"
    local app_folder_name="${2:-$app_name}"
    local user_app="$HOME/Applications/$app_folder_name.app"

    if [ -d "$user_app" ]; then
        echo "✅ $app_name is already installed at $user_app. Skipping."
    else
        echo "🧹 App not found, checking for stale Homebrew install..."
        if brew list --cask "$app_name" &>/dev/null; then
            echo "⚠️  $app_name is registered in Homebrew but missing from disk. Forcing uninstall..."
            brew uninstall --cask --force "$app_name"
        fi
        echo "📦 Installing $app_name to /Applications..."
        brew install --cask "$app_name"
    fi
}

echo "📦 Installing essential applications..."
install_cask_app google-chrome "Google Chrome"
install_cask_app slack "Slack"
install_cask_app postman "Postman"
install_cask_app visual-studio-code "Visual Studio Code"
code --install-extension ms-python.python
code --install-extension dbaeumer.vscode-eslint
code --install-extension esbenp.prettier-vscode
code --install-extension openai.chatgpt
code --install-extension GitHub.copilot
code --install-extension GitHub.copilot-chat

install_cask_app --cask microsoft-word
install_cask_app --cask microsoft-excel
install_cask_app --cask microsoft-powerpoint
install_cask_app --cask microsoft-outlook
install_cask_app --cask microsoft-onenote
install_cask_app --cask microsoft-teams
install_cask_app --cask microsoft-auto-update

echo "🚀 Setup complete! Restart your terminal."
