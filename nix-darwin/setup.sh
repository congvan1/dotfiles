#!/bin/bash

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
FLAKE_FILE="flake.nix"
HOME_FILE="home.nix"

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
echo "Running darwin-rebuild..."
sudo darwin-rebuild switch --flake .

echo "Done!"
