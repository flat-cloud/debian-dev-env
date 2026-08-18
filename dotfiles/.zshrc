# Enable Powerlevel10k instant prompt (MUST stay at the top of ~/.zshrc)
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Quiet instant prompt warnings if any background scripts output text
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

# Path to Oh My Zsh installation
export ZSH="$HOME/.oh-my-zsh"
# Load Powerlevel10k theme
ZSH_THEME="powerlevel10k/powerlevel10k"

# Enabled plugins.
plugins=(
  git
  zsh-autosuggestions
)

# Load Oh My Zsh
source "$ZSH/oh-my-zsh.sh"

# Keep suggestions readable in dim gray (color 244)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=244'

# Persistent GCP Vertex AI Environment Variables
export GOOGLE_GENAI_USE_VERTEXAI=True
export GOOGLE_CLOUD_PROJECT="$(gcloud config get-value project 2>/dev/null)"
export GOOGLE_CLOUD_LOCATION="us-central1"
export PATH="$HOME/.local/bin:$PATH"

# Quick Alias for Antigravity Agent
alias dev='agy'

# Load Powerlevel10k theme configuration if present
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


# nodetmp: Offload node_modules to /tmp to save $HOME quota
alias npmi="nodetmp install"
alias nmlink="nodetmp link"
alias nmenforce="nodetmp enforce"
alias nmstatus="nodetmp status"
alias nmfix="nodetmp fix"


# Global package caches -> per-user /tmp storage (keeps $HOME disk clean)
[[ ! -r "$HOME/.config/cloudshell-env/dependency-cache-env.sh" ]] || \
  source "$HOME/.config/cloudshell-env/dependency-cache-env.sh"

alias pyvenv="nodetmp venv"

alias tm='tmux attach -t dev || tmux new -s dev'

# PostgreSQL Aliases
alias pgstart="sudo service postgresql start"
alias pgstatus="sudo service postgresql status"
alias psqldev="sudo -u postgres psql -d dev"

# Nginx Aliases
alias ngstart="sudo service nginx start"
alias ngstop="sudo service nginx stop"
alias ngreload="sudo service nginx reload"
alias ngstatus="sudo service nginx status"
alias ngconf="sudo nano /etc/nginx/sites-available/default"

# Cloudflare Tunnel Alias
alias cftunnel="cloudflared tunnel --url"

# zsh-syntax-highlighting must be sourced after Powerlevel10k and every other
# ZLE integration. Limit the inspected buffer to prevent large pastes from
# monopolizing a resource-constrained Cloud Shell session.
if [[ "${CLOUDSHELL_DISABLE_ZSH_HIGHLIGHTING:-0}" != 1 && \
      -r "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  typeset -g ZSH_HIGHLIGHT_MAXLENGTH=512
  typeset -gA ZSH_HIGHLIGHT_STYLES
  ZSH_HIGHLIGHT_STYLES[default]='fg=244'
  ZSH_HIGHLIGHT_STYLES[arg0]='fg=250'
  ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=244'
  ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=244'
  ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=244'
  ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=244'
  ZSH_HIGHLIGHT_STYLES[redirection]='fg=244'
  ZSH_HIGHLIGHT_STYLES[comment]='fg=244'
  source "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
