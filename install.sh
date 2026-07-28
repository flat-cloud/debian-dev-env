#!/usr/bin/env bash
set -e

# Cloud Shell Environment Bootstrap Script
# Restores zsh, Oh My Zsh, Powerlevel10k, plugins, and custom dotfiles.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$HOME"

# Suppress Cloud Shell apt-get notice
mkdir -p "$HOME_DIR/.cloudshell" && touch "$HOME_DIR/.cloudshell/no-apt-get-warning"

echo "🚀 Starting Cloud Shell environment setup..."

# 1. System Package Setup via .customize_environment
echo "📦 Setting up ~/.customize_environment for system packages..."
if [ -f "$SCRIPT_DIR/dotfiles/.customize_environment" ]; then
    cp "$SCRIPT_DIR/dotfiles/.customize_environment" "$HOME_DIR/.customize_environment"
    chmod +x "$HOME_DIR/.customize_environment"
fi

# If running as root or sudo is available, install required packages immediately
if command -v sudo >/dev/null 2>&1; then
    echo "⚡ Installing system packages immediately (zsh, jq, htop, fzf, ripgrep, tree)..."
    sudo apt-get update -q -y || true
    sudo apt-get install -q -y zsh jq htop fzf ripgrep tree python3-pip python3-venv tmux || true
fi

# 1b. Python CLI Tools Setup
echo "🐍 Installing Python CLI tools (uv, pipx, glances, rich-cli, httpie, llm, ruff, tldr, copier)..."
python3 -m pip install --user --break-system-packages uv pipx glances rich-cli httpie llm ruff tldr copier 2>/dev/null || python3 -m pip install --user uv pipx glances rich-cli httpie llm ruff tldr copier || true


# 2. Oh My Zsh Installation
OMZ_DIR="$HOME_DIR/.oh-my-zsh"
if [ ! -d "$OMZ_DIR" ]; then
    echo "✨ Cloning Oh My Zsh..."
    git clone https://github.com/ohmyzsh/ohmyzsh.git "$OMZ_DIR" || true
else
    echo "🔄 Updating Oh My Zsh..."
    (cd "$OMZ_DIR" && git pull --quiet || true)
fi

# 3. Custom Themes & Plugins
CUSTOM_DIR="${ZSH_CUSTOM:-$OMZ_DIR/custom}"

# Powerlevel10k Theme
P10K_DIR="$CUSTOM_DIR/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
    echo "🎨 Cloning Powerlevel10k theme..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR" || true
else
    echo "🔄 Updating Powerlevel10k theme..."
    (cd "$P10K_DIR" && git pull --quiet || true)
fi

# zsh-autosuggestions Plugin
AUTOSUGGEST_DIR="$CUSTOM_DIR/plugins/zsh-autosuggestions"
if [ ! -d "$AUTOSUGGEST_DIR" ]; then
    echo "🔌 Cloning zsh-autosuggestions plugin..."
    git clone https://github.com/zsh-users/zsh-autosuggestions.git "$AUTOSUGGEST_DIR" || true
else
    echo "🔄 Updating zsh-autosuggestions plugin..."
    (cd "$AUTOSUGGEST_DIR" && git pull --quiet || true)
fi

# zsh-syntax-highlighting Plugin
SYNTAX_DIR="$CUSTOM_DIR/plugins/zsh-syntax-highlighting"
if [ ! -d "$SYNTAX_DIR" ]; then
    echo "🔌 Cloning zsh-syntax-highlighting plugin..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$SYNTAX_DIR" || true
else
    echo "🔄 Updating zsh-syntax-highlighting plugin..."
    (cd "$SYNTAX_DIR" && git pull --quiet || true)
fi

# 4. Copy/Link Dotfiles to $HOME
echo "📄 Deploying dotfiles to $HOME_DIR..."
for df in .zshrc .p10k.zsh .hushlogin .tmux.conf; do
    if [ -f "$SCRIPT_DIR/dotfiles/$df" ]; then
        cp "$SCRIPT_DIR/dotfiles/$df" "$HOME_DIR/$df"
        echo "   -> Updated $df"
    fi
done

# 5. Hand off ~/.bashrc to zsh for interactive shells
BASHRC="$HOME_DIR/.bashrc"
HANDOFF_COMMENT="# Auto-handoff interactive sessions to zsh"
if [ -f "$BASHRC" ]; then
    if ! grep -q "$HANDOFF_COMMENT" "$BASHRC"; then
        echo "🐚 Adding zsh handoff to ~/.bashrc..."
        cat << 'EOF' >> "$BASHRC"

# Auto-handoff interactive sessions to zsh
if [ -t 1 ] && [ -x "$(command -v zsh)" ] && [ -z "$ZSH_VERSION" ]; then
    export SHELL="$(command -v zsh)"
    exec zsh -l
fi
EOF
    fi
fi

echo "✅ Environment setup complete! Restart your shell or run 'zsh' to activate."


# 1c. Install nodetmp CLI tool
echo "🔗 Installing nodetmp CLI utility..."
mkdir -p "$HOME_DIR/.local/bin"
if [ -f "$SCRIPT_DIR/bin/nodetmp" ]; then
    cp "$SCRIPT_DIR/bin/nodetmp" "$HOME_DIR/.local/bin/nodetmp"
    chmod +x "$HOME_DIR/.local/bin/nodetmp"
fi


# 1d. GitHub CLI Setup
if [ -n "$GH_TOKEN" ] || [ -n "$GITHUB_TOKEN" ]; then
    TOKEN="${GH_TOKEN:-$GITHUB_TOKEN}"
    echo "🐙 Setting up GitHub CLI authentication..."
    mkdir -p "$HOME_DIR/.config/gh"
    cat << EOF > "$HOME_DIR/.config/gh/hosts.yml"
github.com:
    oauth_token: $TOKEN
    git_protocol: https
EOF
    chmod 600 "$HOME_DIR/.config/gh/hosts.yml"
fi

# 1e. PostgreSQL Service Setup
echo "🐘 Starting PostgreSQL service and setting up dev database..."
if command -v service >/dev/null 2>&1; then
    sudo service postgresql start || true
    sudo -u postgres psql -c "CREATE USER postgres WITH SUPERUSER PASSWORD 'postgres';" 2>/dev/null || true
    sudo -u postgres createdb dev 2>/dev/null || true
fi

# 1f. Nginx Service Setup
echo "🌐 Starting Nginx web server..."
if command -v service >/dev/null 2>&1; then
    sudo service nginx start || true
fi

# 1g. tokless Token Optimization Suite for Antigravity (agy)
echo "⚡ Installing tokless token-saving suite for Antigravity..."
if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://raw.githubusercontent.com/HoangP8/tokless/main/scripts/install.sh | bash -s -- --agents antigravity || true
fi
