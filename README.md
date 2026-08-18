# Cloud Shell Custom Environment (`cloudshell-env`)

This repository locks in and automates the restoration of a personalized Linux/Cloud Shell terminal environment.

## 🌟 Included Configurations & Tools
- **Shell**: Zsh + Oh My Zsh
- **Theme**: Powerlevel10k (Lean / Pure style with instant prompt)
- **Plugins**: `git`, `zsh-autosuggestions`, `zsh-syntax-highlighting`
- **CLI Tools**: `jq`, `htop`, `fzf`, `ripgrep`, `tree`, `tmux`, `gh` (GitHub CLI)
- **Database**: `postgresql` (PostgreSQL 16 service & `psql` client)
- **Web Server**: `nginx` (Reverse proxy & web server)
- **AI Agent Optimization**: `tokless` (Unified token-saving suite for Antigravity `agy`: `rtk`, `caveman`, `codegraph`, `context-mode`)
- **Networking**: `cloudflared` (Cloudflare Tunnel CLI for instant HTTPS tunnels)
- **Python CLI Tools**: `uv`, `pipx`, `glances`, `rich-cli`, `httpie`, `llm`, `ruff`, `tldr`, `copier`
- **Environment**: GCP Vertex AI variables (`GOOGLE_GENAI_USE_VERTEXAI`, `GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION`)
- **Aliases**: `dev` -> `agy` (Antigravity Agent)

The Zsh configuration loads syntax highlighting after Powerlevel10k, caps highlighting work for large pasted commands, and uses a Cloud Shell-friendly gray palette. For emergency troubleshooting, start Zsh with highlighting disabled:

```bash
CLOUDSHELL_DISABLE_ZSH_HIGHLIGHTING=1 zsh -l
```

---

## ⚡ Quick Start / Installation

To restore or apply this configuration on any fresh Google Cloud Shell or Debian environment:

```bash
git clone https://github.com/flat-cloud/debian-dev-env.git -b cloudshell-config ~/cloudshell-env
cd ~/cloudshell-env
./install.sh
```

---

## 💡 How Cloud Shell Persistence Works

1. **Persistent `$HOME` vs Ephemeral Container**:
   - In Google Cloud Shell, your `$HOME` directory is mounted on persistent storage and preserved across restarts.
   - However, root system packages installed via `apt-get` outside `$HOME` reset whenever the container is recycled.

2. **Automated Package Restoration (`.customize_environment`)**:
   - Google Cloud Shell automatically executes `~/.customize_environment` as `root` in the background on container boot.
   - The included `.customize_environment` script automatically installs `zsh`, `jq`, `htop`, `fzf`, `ripgrep`, and `tree` via `apt-get` on every boot.

3. **Silent Shell Handoff (`.bashrc`)**:
   - Cloud Shell defaults to launch `bash` on login. `install.sh` configures `~/.bashrc` to silently `exec zsh -l` whenever an interactive TTY session starts, seamlessly transitioning you into Zsh with Powerlevel10k.


---

## 💾 Saving Disk Space: `nodetmp` Utility

To prevent reproducible dependencies from consuming your persistent **5 GB `$HOME` disk quota**, this environment includes **`nodetmp`**. It offloads Node `node_modules`, Composer `vendor`, Python `.venv`, Rust `target`, and known package/browser caches to per-user storage under `/tmp`, then leaves symlinks in the project.

### Usage

- `nodetmp enforce [path]` (or `nmenforce`): Recursively finds supported projects, safely moves their dependency directories, and migrates known caches. Use `--dry-run` to preview.
- `nodetmp link [path]` (or `nmlink`): Safely moves supported dependency directories for one project and replaces them with symlinks.
- `nodetmp install` (or `npmi`): Creates the `/tmp` symlink if missing, then runs `npm install`.
- `nodetmp venv` (or `pyvenv`): Creates an offloaded Python virtual environment.
- `nodetmp status` (or `nmstatus`): Displays whether project targets are linked and how much temporary disk space they use.
- `nodetmp fix` (or `nmfix`): Scans for broken managed symlinks after container reboots and restores their targets.
- `nodetmp scan [path]`: Audits all supported dependency locations and disk usage.
- `nodetmp clean`: Removes only `nodetmp`-managed links and temporary data for the current project.

`nodetmp` refuses to replace or remove symlinks it does not manage. Transfers are copied to a staging directory before the persistent original is removed. Set `NODETMP_STORE_DIR` to override its temporary storage root.

The installer and boot customization run `nodetmp enforce` automatically. Existing real dependency directories are moved to `/tmp`; after a Cloud Shell VM reset, broken managed links are recreated with empty targets. Enforcement never downloads packages. Run the normal locked install command (`npm ci`, `composer install`, `uv sync`, and so on) when you first need a project in the new session. `nmfix` remains available when you explicitly want broken links restored and dependencies installed.

The cache setup is active in both login Bash and Zsh. It covers npm, pnpm, Yarn, Bun, pip, uv, Composer, Playwright, Puppeteer, and Cypress caches without moving persistent configuration or credentials.

### Development checks

Run the dependency-free regression suite before changing `nodetmp`:

```bash
bash -n bin/nodetmp install.sh dotfiles/.customize_environment tests/nodetmp_test.sh
sh -n dotfiles/dependency-cache-env.sh
zsh -n dotfiles/.zshrc dotfiles/.p10k.zsh
./tests/nodetmp_test.sh
```
