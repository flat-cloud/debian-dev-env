# Enable Powerlevel10k instant prompt (DISABLED)
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi

# Quiet instant prompt warnings if any background scripts output text
# typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

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
alias nmstatus="nodetmp status"
alias nmfix="nodetmp fix"


# Global Package Caches -> /tmp (keeps $HOME disk clean)
export PIP_CACHE_DIR="/tmp/.cache/pip"
export UV_CACHE_DIR="/tmp/.cache/uv"
export NPM_CONFIG_CACHE="/tmp/.cache/npm"
export YARN_CACHE_FOLDER="/tmp/.cache/yarn"

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

# zsh-syntax-highlighting disabled to prevent paste crash
# if [[ "${CLOUDSHELL_DISABLE_ZSH_HIGHLIGHTING:-0}" != 1 && \
#       -r "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
#   typeset -g ZSH_HIGHLIGHT_MAXLENGTH=512
#   typeset -gA ZSH_HIGHLIGHT_STYLES
#   source "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
# fi
