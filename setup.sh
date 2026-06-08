#!/bin/bash
# =============================================================================
# Dev Environment Setup Script — Debian
# Idempotent: safe to run multiple times
# Graceful: continues on failure, reports summary at end
# Installs: prerequisites, snapd, zsh, oh-my-zsh, nvm, node, pm2,
#           postgresql, docker, docker-compose, php, python3, tailscale, firefox
# =============================================================================
# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'
# ── Tracking ──────────────────────────────────────────────────────────────────
PASSED=()
FAILED=()
SKIPPED=()
ok()     { echo -e "${GREEN}  ✔ ${1}${RESET}";       PASSED+=("$1"); }
fail()   { echo -e "${RED}  ✘ ${1}: ${2}${RESET}";   FAILED+=("$1 — $2"); }
skip()   { echo -e "${YELLOW}  ⊘ ${1} already installed${RESET}"; SKIPPED+=("$1"); }
info()   { echo -e "${YELLOW}  ↳ ${1}${RESET}"; }
header() { echo -e "\n${CYAN}${BOLD}▶ ${1}${RESET}"; }
cmd_exists() { command -v "$1" &>/dev/null; }
# ── Sudo setup ────────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
  echo -e "${BOLD}This script needs sudo. You may be prompted for your password.${RESET}"
  sudo -v || { echo -e "${RED}sudo access required. Exiting.${RESET}"; exit 1; }
fi
( while true; do sudo -n true; sleep 50; done ) 2>/dev/null &
SUDO_PID=$!
trap "kill $SUDO_PID 2>/dev/null" EXIT
# ── apt helper (never exits on failure) ───────────────────────────────────────
apt_install() {
  local pkg="$1" label="${2:-$1}"
  if dpkg -s "$pkg" &>/dev/null; then
    skip "$label"
  elif sudo apt-get install -y "$pkg" &>/dev/null; then
    ok "$label"
  else
    fail "$label" "apt install failed"
  fi
}
# =============================================================================
# 1. PACKAGE LIST UPDATE
# =============================================================================
header "Updating package lists"
if sudo apt-get update -qq 2>/dev/null; then
  ok "apt update"
else
  fail "apt update" "could not refresh — some installs may fail"
fi
# =============================================================================
# 2. PREREQUISITES
# Note: software-properties-common is Ubuntu-specific and not available in
# Debian repos. apt-transport-https + gnupg cover the same functionality here.
# =============================================================================
header "Prerequisites"
PREREQS=(curl wget git gnupg gnupg2 ca-certificates lsb-release apt-transport-https unzip)
for pkg in "${PREREQS[@]}"; do
  apt_install "$pkg"
done
# =============================================================================
# 3. SNAPD
# =============================================================================
header "snapd"
if cmd_exists snap; then
  skip "snapd ($(snap version 2>/dev/null | grep snapd | awk '{print $2}'))"
else
  if sudo apt-get install -y snapd &>/dev/null; then
    sudo systemctl enable --now snapd.socket &>/dev/null || true
    sudo ln -sf /var/lib/snapd/snap /snap 2>/dev/null || true
    ok "snapd"
    info "Restart your terminal after setup for snap PATH to work"
  else
    fail "snapd" "apt install failed"
  fi
fi
# =============================================================================
# 4. ZSH + OH MY ZSH + PLUGINS
# =============================================================================
header "zsh"
apt_install zsh
header "Oh My Zsh"
OMZ_DIR="${HOME}/.oh-my-zsh"
if [[ -d "$OMZ_DIR" ]]; then
  skip "oh-my-zsh"
else
  if RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
      "" --unattended 2>/dev/null; then
    ok "oh-my-zsh"
  else
    fail "oh-my-zsh" "install script failed"
  fi
fi
# Ensure .zshrc exists (oh-my-zsh creates it, but guard anyway)
ZSHRC="$HOME/.zshrc"
if [[ ! -f "$ZSHRC" ]] && [[ -f "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" ]]; then
  cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$ZSHRC"
fi
header "zsh plugins"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
AUTOSUG_DIR="$ZSH_CUSTOM/plugins/zsh-autosuggestions"
if [[ -d "$AUTOSUG_DIR" ]]; then
  skip "zsh-autosuggestions"
elif git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$AUTOSUG_DIR" &>/dev/null; then
  ok "zsh-autosuggestions"
else
  fail "zsh-autosuggestions" "git clone failed"
fi
SYNTHIGH_DIR="$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
if [[ -d "$SYNTHIGH_DIR" ]]; then
  skip "zsh-syntax-highlighting"
elif git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$SYNTHIGH_DIR" &>/dev/null; then
  ok "zsh-syntax-highlighting"
else
  fail "zsh-syntax-highlighting" "git clone failed"
fi
# Enable plugins in .zshrc
if [[ -f "$ZSHRC" ]]; then
  if grep -q "zsh-autosuggestions" "$ZSHRC" 2>/dev/null; then
    skip "plugins in .zshrc"
  elif sed -i 's/^plugins=(\(.*\))/plugins=(\1 zsh-autosuggestions zsh-syntax-highlighting)/' "$ZSHRC" 2>/dev/null; then
    ok "plugins enabled in .zshrc"
  else
    fail "plugins in .zshrc" "sed failed"
  fi
else
  fail "plugins in .zshrc" ".zshrc not found"
fi
# =============================================================================
# 5. DEFAULT SHELL → ZSH
# chsh is wrapped in a timeout to prevent hanging when PAM requires a
# password interactively. Falls back to editing /etc/passwd directly.
# =============================================================================
header "Default shell"
ZSH_PATH="$(command -v zsh 2>/dev/null || echo '')"
if [[ -z "$ZSH_PATH" ]]; then
  fail "default shell" "zsh not found in PATH"
elif [[ "$SHELL" == "$ZSH_PATH" ]]; then
  skip "default shell (already zsh)"
else
  # Try chsh with a timeout — avoids hanging on PAM password prompts
  if timeout 5 chsh -s "$ZSH_PATH" "$USER" 2>/dev/null; then
    ok "default shell → zsh (via chsh)"
  # Fall back to editing /etc/passwd directly
  elif sudo sed -i "s|^\($USER:.*:\)[^:]*$|\1$ZSH_PATH|" /etc/passwd 2>/dev/null; then
    ok "default shell → zsh (via /etc/passwd)"
  else
    fail "default shell" "both chsh and /etc/passwd edit failed — run manually: chsh -s $ZSH_PATH"
  fi
fi
# =============================================================================
# 6. NVM + NODE + PM2
# =============================================================================
header "nvm"
export NVM_DIR="$HOME/.nvm"
if [[ -d "$NVM_DIR" ]]; then
  skip "nvm"
else
  NVM_LATEST=$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest 2>/dev/null \
    | grep '"tag_name"' | cut -d'"' -f4)
  if [[ -z "$NVM_LATEST" ]]; then
    fail "nvm" "could not fetch latest version"
  elif curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_LATEST}/install.sh" | bash &>/dev/null; then
    ok "nvm ($NVM_LATEST)"
  else
    fail "nvm" "install script failed"
  fi
fi
# Source nvm for use in this script session
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh" 2>/dev/null || true

# Ensure nvm init block is present in .zshrc (nvm installer only writes to .bashrc/.bash_profile)
NVM_INIT_MARKER="# nvm init — added by setup.sh"
if [[ -f "$ZSHRC" ]] && ! grep -q "$NVM_INIT_MARKER" "$ZSHRC" 2>/dev/null; then
  cat >> "$ZSHRC" <<EOF

$NVM_INIT_MARKER
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && source "\$NVM_DIR/nvm.sh"
[ -s "\$NVM_DIR/bash_completion" ] && source "\$NVM_DIR/bash_completion"
EOF
  ok "nvm init added to .zshrc"
else
  skip "nvm init in .zshrc"
fi
header "Node.js (LTS)"
if cmd_exists node; then
  skip "node ($(node --version))"
elif ! cmd_exists nvm && ! [[ -s "$NVM_DIR/nvm.sh" ]]; then
  fail "node" "nvm not available — skipping"
else
  if nvm install --lts &>/dev/null && nvm use --lts &>/dev/null && nvm alias default node &>/dev/null; then
    ok "node ($(node --version))"
  else
    fail "node" "nvm install --lts failed"
  fi
fi
header "pm2"
if cmd_exists pm2; then
  skip "pm2"
elif ! cmd_exists npm; then
  fail "pm2" "npm not available — install node first"
elif npm install -g pm2 &>/dev/null; then
  ok "pm2 ($(pm2 --version 2>/dev/null))"
else
  fail "pm2" "npm install -g failed"
fi
# =============================================================================
# 7. POSTGRESQL
# =============================================================================
header "PostgreSQL"
if cmd_exists psql; then
  skip "postgresql ($(psql --version))"
else
  CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
  curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    | sudo gpg --dearmor -o /usr/share/keyrings/postgresql.gpg 2>/dev/null
  echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] https://apt.postgresql.org/pub/repos/apt ${CODENAME}-pgdg main" \
    | sudo tee /etc/apt/sources.list.d/pgdg.list &>/dev/null
  sudo apt-get update -qq &>/dev/null
  if sudo apt-get install -y postgresql &>/dev/null; then
    ok "postgresql ($(psql --version))"
  else
    fail "postgresql" "apt install failed"
  fi
fi
# =============================================================================
# 8. DOCKER + DOCKER COMPOSE
# =============================================================================
header "Docker"
if cmd_exists docker; then
  skip "docker ($(docker --version))"
elif curl -fsSL https://get.docker.com | sudo sh &>/dev/null; then
  sudo usermod -aG docker "$USER" 2>/dev/null || true
  ok "docker ($(docker --version))"
  info "Log out and back in for docker group to take effect"
else
  fail "docker" "get.docker.com install script failed"
fi
header "Docker Compose"
if docker compose version &>/dev/null 2>&1; then
  skip "docker compose ($(docker compose version --short 2>/dev/null))"
elif cmd_exists docker-compose; then
  skip "docker-compose ($(docker-compose --version))"
else
  DC_VERSION=$(curl -fsSL https://api.github.com/repos/docker/compose/releases/latest 2>/dev/null \
    | grep '"tag_name"' | cut -d'"' -f4)
  DEST="/usr/local/lib/docker/cli-plugins/docker-compose"
  sudo mkdir -p /usr/local/lib/docker/cli-plugins
  if sudo curl -fsSL \
      "https://github.com/docker/compose/releases/download/${DC_VERSION}/docker-compose-linux-$(uname -m)" \
      -o "$DEST" &>/dev/null && sudo chmod +x "$DEST"; then
    ok "docker compose ($DC_VERSION)"
  else
    fail "docker compose" "download failed"
  fi
fi
# =============================================================================
# 9. PHP (via sury.org — latest for Debian)
# =============================================================================
header "PHP"
if cmd_exists php; then
  skip "php ($(php --version | head -1))"
else
  CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
  curl -fsSL https://packages.sury.org/php/apt.gpg \
    | sudo gpg --dearmor -o /usr/share/keyrings/sury-php.gpg 2>/dev/null
  echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ ${CODENAME} main" \
    | sudo tee /etc/apt/sources.list.d/sury-php.list &>/dev/null
  sudo apt-get update -qq &>/dev/null
  if sudo apt-get install -y php php-cli php-common php-mbstring php-xml php-curl &>/dev/null; then
    ok "php ($(php --version | head -1))"
  else
    fail "php" "apt install failed"
  fi
fi
# =============================================================================
# 10. PYTHON 3
# =============================================================================
header "Python 3"
if cmd_exists python3; then
  skip "python3 ($(python3 --version))"
elif sudo apt-get install -y python3 &>/dev/null; then
  ok "python3 ($(python3 --version))"
else
  fail "python3" "apt install failed"
fi
if cmd_exists pip3; then
  skip "pip3"
elif sudo apt-get install -y python3-pip &>/dev/null; then
  ok "pip3"
else
  fail "pip3" "apt install failed"
fi
if python3 -c "import venv" &>/dev/null; then
  skip "python3-venv"
elif sudo apt-get install -y python3-venv &>/dev/null; then
  ok "python3-venv"
else
  fail "python3-venv" "apt install failed"
fi
# =============================================================================
# 11. TAILSCALE
# =============================================================================
header "Tailscale"
if cmd_exists tailscale; then
  skip "tailscale ($(tailscale version | head -1))"
elif curl -fsSL https://tailscale.com/install.sh | sudo sh &>/dev/null; then
  ok "tailscale"
  info "Run: sudo tailscale up --ssh  to authenticate"
else
  fail "tailscale" "install script failed"
fi
# =============================================================================
# 12. FIREFOX (Mozilla official apt repo)
# =============================================================================
header "Firefox"
if cmd_exists firefox; then
  skip "firefox"
else
  sudo install -d -m 0755 /etc/apt/keyrings &>/dev/null
  curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg \
    | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc &>/dev/null
  echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
    | sudo tee /etc/apt/sources.list.d/mozilla.list &>/dev/null
  sudo apt-get update -qq &>/dev/null
  if sudo apt-get install -y firefox &>/dev/null; then
    ok "firefox"
  else
    fail "firefox" "mozilla apt repo failed"
  fi
fi
# =============================================================================
# SUMMARY
# =============================================================================
echo -e "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}  Setup Summary${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
if [[ ${#PASSED[@]} -gt 0 ]]; then
  echo -e "\n${GREEN}${BOLD}Installed (${#PASSED[@]})${RESET}"
  for item in "${PASSED[@]}"; do echo -e "  ${GREEN}✔ $item${RESET}"; done
fi
if [[ ${#SKIPPED[@]} -gt 0 ]]; then
  echo -e "\n${YELLOW}${BOLD}Already present (${#SKIPPED[@]})${RESET}"
  for item in "${SKIPPED[@]}"; do echo -e "  ${YELLOW}⊘ $item${RESET}"; done
fi
if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo -e "\n${RED}${BOLD}Failed (${#FAILED[@]})${RESET}"
  for item in "${FAILED[@]}"; do echo -e "  ${RED}✘ $item${RESET}"; done
fi
echo -e "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
if [[ ${#FAILED[@]} -eq 0 ]]; then
  echo -e "\n${GREEN}${BOLD}All done!${RESET}"
else
  echo -e "\n${YELLOW}Completed with ${#FAILED[@]} error(s). Re-run the script to retry failed steps.${RESET}"
fi
echo -e "${YELLOW}Restart your terminal (or run: exec zsh) to apply all changes.${RESET}\n"
