{
  description = "My Darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager }:
  let
    configuration = { pkgs, ... }: {
      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages = [];
      
      # Disable nix-darwin's Nix management (using Determinate Nix)
      nix.enable = false;

      # Make Homebrew-installed tools visible to non-interactive shells and services.
      environment.systemPath = [
        "/opt/homebrew/bin"
        "/opt/homebrew/sbin"
      ];
      
      nix.settings.experimental-features = "nix-command flakes";
      programs.zsh = {
        enable = true;
      };
      system.configurationRevision = self.rev or self.dirtyRev or null;
      system.stateVersion = 4;
      nixpkgs.hostPlatform = "aarch64-darwin";
      security.pam.services.sudo_local.touchIdAuth = true;
      security.pam.services.sudo_local.reattach = true; # Enable reattach for Tmux support
      system.primaryUser = "van";
      users.users.van.home = "/Users/van";
      home-manager.backupFileExtension = "backup";

      system.defaults = {
        # Dock settings
        dock.autohide = true;
        dock.autohide-delay = 0.0;
        dock.autohide-time-modifier = 0.2;
        dock.mru-spaces = false;
        dock.show-recents = false;
        dock.tilesize = 20;
        dock.orientation = "left";
        dock.minimize-to-application = true;
        
        # Finder settings
        finder.AppleShowAllExtensions = true;
        finder.AppleShowAllFiles = true;
        finder.FXPreferredViewStyle = "clmv"; # Column view
        finder.ShowPathbar = true;
        finder.ShowStatusBar = true;
        finder.FXEnableExtensionChangeWarning = false;
        finder.QuitMenuItem = true; # Allow quitting Finder
        
        # Login window
        loginwindow.LoginwindowText = "congvan";
        loginwindow.GuestEnabled = false;
        
        # Screenshots
        screencapture.location = "~/Pictures/screenshots";
        screencapture.type = "png";
        
        # Screensaver
        screensaver.askForPasswordDelay = 10;
        
        # Global macOS settings
        NSGlobalDomain.AppleShowAllExtensions = true;
        NSGlobalDomain.InitialKeyRepeat = 10; # Fast key repeat
        NSGlobalDomain.KeyRepeat = 3; # Very fast key repeat
        NSGlobalDomain.ApplePressAndHoldEnabled = false; # Disable press-and-hold for keys
        NSGlobalDomain.NSAutomaticCapitalizationEnabled = false;
        NSGlobalDomain.NSAutomaticDashSubstitutionEnabled = false;
        NSGlobalDomain.NSAutomaticPeriodSubstitutionEnabled = false;
        NSGlobalDomain.NSAutomaticQuoteSubstitutionEnabled = false;
        NSGlobalDomain.NSAutomaticSpellingCorrectionEnabled = false;
        NSGlobalDomain.NSNavPanelExpandedStateForSaveMode = true;
        NSGlobalDomain.NSNavPanelExpandedStateForSaveMode2 = true;
        NSGlobalDomain."com.apple.swipescrolldirection" = false; # Traditional scrolling (reversed)
        NSGlobalDomain.AppleInterfaceStyle = "Dark"; # Dark Mode
        
        # Trackpad settings
        trackpad.Clicking = true; # Tap to click
        trackpad.TrackpadThreeFingerDrag = false; # Disable drag (prevents text selection on move)
        trackpad.TrackpadThreeFingerHorizSwipeGesture = 2; # Enable 3-finger swipe left/right for switching spaces
        
        # Menu bar
        menuExtraClock.ShowSeconds = false;
        menuExtraClock.ShowDate = 0;
        menuExtraClock.Show24Hour = true;
      };

      # Homebrew Integration
      homebrew.enable = true;
      homebrew.onActivation.cleanup = "uninstall";  # Remove unmanaged apps without zapping app data
      homebrew.onActivation.autoUpdate = false;
      homebrew.onActivation.upgrade = false;

      homebrew.taps = (import ./packages.nix).taps;
      homebrew.brews = (import ./packages.nix).brews;
      homebrew.casks = (import ./packages.nix).casks;

      system.activationScripts.install9router.text = ''
        echo "setting up 9router npm CLI..."

        /bin/mkdir -p /Users/van/.npm-global /Users/van/.9router/logs /Users/van/.config/9router
        /usr/sbin/chown -R van:staff /Users/van/.npm-global /Users/van/.9router /Users/van/.config/9router

        if [ ! -f /Users/van/.config/9router/env ]; then
          /bin/cat > /Users/van/.config/9router/env <<'EOF'
# Local 9router runtime settings. Keep secrets out of git.
PORT=20128
HOSTNAME=localhost
DATA_DIR=/Users/van/.9router
BASE_URL=http://localhost:20128
NEXT_PUBLIC_BASE_URL=http://localhost:20128
CLOUD_URL=https://9router.com
NEXT_PUBLIC_CLOUD_URL=https://9router.com

# Optional local dashboard password. Change before exposing beyond localhost.
# INITIAL_PASSWORD=change-me

# Optional request logs for debugging only.
# ENABLE_REQUEST_LOGS=false
EOF
          /usr/sbin/chown van:staff /Users/van/.config/9router/env
          /bin/chmod 600 /Users/van/.config/9router/env
        fi

        if [ -x /opt/homebrew/bin/npm ]; then
          if ! /usr/bin/sudo -u van /usr/bin/env HOME=/Users/van npm_config_prefix=/Users/van/.npm-global /opt/homebrew/bin/npm install -g 9router@0.4.29 --no-audit --no-fund; then
            echo "warning: failed to install 9router@0.4.29 via npm; launchd will retry npm install on first run"
          fi
        else
          echo "warning: /opt/homebrew/bin/npm not found yet; install Homebrew node and rerun darwin-rebuild"
        fi
      '';

      system.activationScripts.fixDeterminateNixWarnings.text = ''
        if [ -f /etc/nix/nix.conf ]; then
          /usr/bin/grep -qE '^(eval-cores|lazy-trees)\s*=' /etc/nix/nix.conf || exit 0

          echo "removing unsupported Determinate Nix settings from /etc/nix/nix.conf..."
          /usr/bin/sed -i.bak -E '/^(eval-cores|lazy-trees)\s*=/d' /etc/nix/nix.conf
        fi
      '';

      launchd.user.agents."9router" = {
        serviceConfig = {
          Label = "dev.decolua.9router";
          ProgramArguments = [
            "/Users/van/dotfiles/scripts/9router-launch.sh"
            "serve"
          ];
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "/Users/van/.9router/logs/launchd.out.log";
          StandardErrorPath = "/Users/van/.9router/logs/launchd.err.log";
          EnvironmentVariables = {
            HOME = "/Users/van";
            PATH = "/Users/van/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
          };
        };
      };

      launchd.user.agents."colima" = {
        serviceConfig = {
          Label = "com.user.colima";
          ProgramArguments = [
            "/opt/homebrew/bin/colima"
            "start"
            "default"
            "--foreground"
          ];
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "/Users/van/Library/Logs/colima-launchd.log";
          StandardErrorPath = "/Users/van/Library/Logs/colima-launchd.log";
          EnvironmentVariables = {
            HOME = "/Users/van";
            PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
          };
        };
      };

      launchd.user.agents."spotify" = {
        serviceConfig = {
          Label = "com.user.spotify";
          ProgramArguments = [
            "/usr/bin/open"
            "-gj"
            "-a"
            "Spotify"
          ];
          RunAtLoad = true;
          StandardOutPath = "/Users/van/Library/Logs/spotify-launchd.log";
          StandardErrorPath = "/Users/van/Library/Logs/spotify-launchd.log";
          EnvironmentVariables = {
            HOME = "/Users/van";
            PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
          };
        };
      };
    };
  in
  {
    darwinConfigurations."Vans-MacBook-Air" = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [ 
	configuration
        home-manager.darwinModules.home-manager {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.van = import ./home.nix;
        }
      ];
    };

    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations."Vans-MacBook-Air".pkgs;
  };
}
