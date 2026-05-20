# Dotfiles

My personal dotfiles managed with GNU Stow and Nix-Darwin.

## 📦 What's Included

- **Shell**: Zsh with Starship prompt, syntax highlighting, and autosuggestions
- **Editor**: Neovim configuration
- **Terminal**: Tmux, Ghostty, WezTerm configurations
- **Window Management**: Aerospace, Hammerspoon, SKHD
- **Status Bar**: Sketchybar
- **Package Management**: Nix-Darwin for declarative macOS configuration
- **Development Tools**: Docker, Kubernetes, Terraform, Ansible, and more

## 🚀 Installation

### 1. Install Dotfiles with Stow

```bash
cd ~/dotfiles
stow .
```

### 2. Install Nix and Nix-Darwin

First time setup from this checkout:

```bash
cd ~/dotfiles
./nix-darwin/setup.sh
```

The setup script installs Determinate Nix if `nix` is missing, rewrites the
nix-darwin flake for the current user and host, then bootstraps `darwin-rebuild`
from the flake.

## 🔄 Updating Configuration

### Apply Nix-Darwin Changes

After modifying `flake.nix` or `home.nix`:

```bash
cd ~/dotfiles/nix-darwin
darwin-rebuild switch --flake .
```

To update flake inputs first:

```bash
cd ~/dotfiles/nix-darwin
nix flake update
darwin-rebuild switch --flake .
```

### Clear Cached Build Failures

If you see "cached failure" errors:

```bash
cd ~/dotfiles/nix-darwin
nix flake update
nix store gc  # Clear old builds
darwin-rebuild switch --flake .
```

### Reload Shell Configuration

After modifying `.zshrc`:

```bash
source ~/.zshrc
```

## 📝 Configuration Files

### Nix-Darwin

- **`nix-darwin/flake.nix`** - System packages and macOS settings
- **`nix-darwin/home.nix`** - User-specific home-manager configuration
- **`nix/nix.conf`** - Nix configuration

### Shell

- **`zshrc/.zshrc`** - Zsh configuration with aliases and functions

### Applications

- **`nvim/`** - Neovim configuration
- **`tmux/`** - Tmux configuration
- **`starship/`** - Starship prompt configuration
- **`ghostty/`** - Ghostty terminal configuration
- **`aerospace/`** - Aerospace window manager
- **`sketchybar/`** - Sketchybar status bar

## 🛠️ Installed Packages

### Development Tools
- Git, GitHub CLI
- Docker, Docker Compose
- Neovim, Vim
- Go, Direnv

### Kubernetes & Cloud
- kubectl, kubectx, helm
- AWS CLI, Google Cloud SDK, Azure CLI
- Terraform, Ansible, Packer, Vault

### Database Clients
- PostgreSQL (psql), MySQL, Redis, MongoDB

### CLI Utilities
- eza (modern ls), bat (modern cat), fd (modern find)
- fzf (fuzzy finder), ripgrep, zoxide
- jq, yq, wget, curl
- htop, btop

### Security Tools
- nmap, ffuf, gobuster, ngrok

## 🎨 macOS Settings

Managed declaratively in `flake.nix`:

- **Dock**: Auto-hide, no recent apps, 48px icons
- **Finder**: Show all extensions, hidden files, path bar, status bar
- **Keyboard**: Fast key repeat, no auto-correct
- **Trackpad**: Tap to click, three-finger drag
- **Screenshots**: Saved to `~/Pictures/screenshots` as PNG
- **Security**: Touch ID for sudo enabled

## 📚 Useful Commands

### Nix Package Management

```bash
# Search for packages
nix search nixpkgs <package-name>

# List installed packages
nix-env -q

# Update flake inputs
nix flake update ~/dotfiles/nix-darwin
```

### Shell Aliases

```bash
# Navigation
l          # List files with eza
lt         # Tree view
fcd        # Fuzzy find directory and cd
fv         # Fuzzy find file and open in nvim

# Git shortcuts
gc         # git commit -m
gp         # git push origin HEAD
gst        # git status

# Kubernetes
k          # kubectl
kx         # kubectx
kns        # kubens

# Docker
dco        # docker compose
dps        # docker ps

# Utilities
C          # pbcopy (copy to clipboard)
```

## 🔧 Troubleshooting

### SSL Certificate Issues

If you encounter SSL errors, ensure the certificate path is set:

```bash
export NIX_SSL_CERT_FILE=/etc/nix/macos-keychain.crt
```

### Nix Daemon Issues

Restart the Nix daemon:

```bash
sudo launchctl kickstart -k system/systems.determinate.nix-daemon
```

## 📄 License

Personal dotfiles - use at your own risk!
