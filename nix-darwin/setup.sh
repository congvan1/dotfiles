#!/usr/bin/env bash
set -euo pipefail

# setup.sh - Auto-configure Nix Flake for current user/host

# 1. Detect System Info
CURRENT_USER=$(whoami)
CURRENT_HOST=$(scutil --get LocalHostName)
CURRENT_HOME=$HOME

echo "Detected System Info:"
echo "  User: $CURRENT_USER"
echo "  Host: $CURRENT_HOST"
echo "  Home: $CURRENT_HOME"
echo ""

# 2. Define Paths
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_FILE="$SCRIPT_DIR/flake.nix"
HOME_FILE="$SCRIPT_DIR/home.nix"

ensure_nix() {
  if command -v nix >/dev/null 2>&1 || [ -x /nix/var/nix/profiles/default/bin/nix ]; then
    return 0
  fi

  echo "Nix is not installed or not on PATH."
  echo "Installing Determinate Nix..."

  local installer="${TMPDIR:-/tmp}/determinate-nix-installer.sh"
  local install_args=("install" "--no-confirm")

  if [ -f /etc/nix/nix.conf ] && [ ! -d /nix/var/nix ]; then
    echo "Detected stale /etc/nix configuration without a Nix store; allowing installer to recreate managed files."
    install_args+=("--force")
  fi

  curl -fsSL https://install.determinate.systems/nix -o "$installer"
  sh "$installer" "${install_args[@]}"
}

nix_cmd() {
  if command -v nix >/dev/null 2>&1; then
    command -v nix
  elif [ -x /nix/var/nix/profiles/default/bin/nix ]; then
    echo "/nix/var/nix/profiles/default/bin/nix"
  else
    echo "nix was not found after installation" >&2
    return 1
  fi
}

# 3. Backup Original Files
cp "$FLAKE_FILE" "$FLAKE_FILE.bak"
cp "$HOME_FILE" "$HOME_FILE.bak"

# 4. Update flake.nix
# Replace Hostname (assuming format "darwinConfigurations.\"OLD_HOST\"")
# We use regex to find the string inside darwinConfigurations
sed -i '' "s/darwinConfigurations\.\"[^\"]*\"/darwinConfigurations.\"$CURRENT_HOST\"/" "$FLAKE_FILE"

# Replace User 'van' -> Current User
# Replace primaryUser
sed -i '' "s/system.primaryUser = \"[^\"]*\";/system.primaryUser = \"$CURRENT_USER\";/" "$FLAKE_FILE"
# Replace users.users.van
sed -i '' "s/users.users\.[a-zA-Z0-9_]*/users.users.$CURRENT_USER/g" "$FLAKE_FILE"
# Replace home directory
sed -i '' "s|/Users/[a-zA-Z0-9_]*|$CURRENT_HOME|g" "$FLAKE_FILE"
# Replace home-manager user
sed -i '' "s/home-manager.users\.[a-zA-Z0-9_]*/home-manager.users.$CURRENT_USER/g" "$FLAKE_FILE"


# 5. Update home.nix
# Replace username
sed -i '' "s/home.username = \"[^\"]*\";/home.username = \"$CURRENT_USER\";/" "$HOME_FILE"
# Replace home directory
sed -i '' "s|home.homeDirectory = \"[^\"]*\";|home.homeDirectory = \"$CURRENT_HOME\";|" "$HOME_FILE"

echo "Configuration files updated."

# 6. Run Rebuild
ensure_nix
NIX_BIN="$(nix_cmd)"

echo "Updating flake lock..."
"$NIX_BIN" flake lock "$SCRIPT_DIR"

echo "Running darwin-rebuild..."
if command -v darwin-rebuild >/dev/null 2>&1; then
  sudo darwin-rebuild switch --flake "$SCRIPT_DIR#$CURRENT_HOST"
else
  sudo "$NIX_BIN" --extra-experimental-features "nix-command flakes" \
    run github:nix-darwin/nix-darwin/master#darwin-rebuild -- \
    switch --flake "$SCRIPT_DIR#$CURRENT_HOST"
fi

echo "Done!"
