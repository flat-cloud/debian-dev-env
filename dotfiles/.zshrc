# Enable Powerlevel10k instant prompt (MUST stay at the top of ~/.zshrc)
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Quiet instant prompt warnings if any background scripts output text
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

# Path to Oh My Zsh installation
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Enabled Plugins (Excluded fzf plugin to eliminate Debian path warning)
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh

# Persistent GCP Vertex AI Environment Variables
export GOOGLE_GENAI_USE_VERTEXAI=True
export GOOGLE_CLOUD_PROJECT="$(gcloud config get-value project 2>/dev/null)"
export GOOGLE_CLOUD_LOCATION="us-central1"
export PATH="$HOME/.local/bin:$PATH"

# Quick Alias for Antigravity Agent
alias dev='agy'

# Load Powerlevel10k theme configuration if present
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
