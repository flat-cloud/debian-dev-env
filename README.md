# Cloud Shell Custom Environment (`cloudshell-env`)

This repository locks in and automates the restoration of a personalized Linux/Cloud Shell terminal environment.

## 🌟 Included Configurations & Tools
- **Shell**: Zsh + Oh My Zsh
- **Theme**: Powerlevel10k (Lean / Pure style with instant prompt)
- **Plugins**: `git`, `zsh-autosuggestions`, `zsh-syntax-highlighting`
- **CLI Tools**: `jq`, `htop`, `fzf`, `ripgrep`, `tree`
- **Environment**: GCP Vertex AI variables (`GOOGLE_GENAI_USE_VERTEXAI`, `GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION`)
- **Aliases**: `dev` -> `agy` (Antigravity Agent)

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
