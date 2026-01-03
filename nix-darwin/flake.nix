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
      
      nix.settings.experimental-features = "nix-command flakes";
      programs.zsh = {
        enable = true;  # default shell on catalina
        interactiveShellInit = ''
          if [ -d "$HOME/LOCAL/working-space" ]; then
             cd "$HOME/LOCAL/working-space"
          fi
        '';
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
        
        # Trackpad settings
        trackpad.Clicking = true; # Tap to click
        trackpad.TrackpadThreeFingerDrag = false; # Disable drag (prevents text selection on move)
        trackpad.TrackpadThreeFingerHorizSwipeGesture = 2; # Enable 3-finger swipe left/right for switching spaces
        
        # Menu bar
        menuExtraClock.ShowSeconds = true;
      };

      # Homebrew Integration
      homebrew.enable = true;
      homebrew.onActivation.cleanup = "zap";  # Remove all unmanaged packages
      homebrew.onActivation.autoUpdate = true;
      homebrew.onActivation.upgrade = true;

      homebrew.taps = [
        "nikitabobko/tap"
        "FelixKratz/formulae"
      ];
      
      homebrew.brews = (import ./packages.nix).brews;
      homebrew.casks = (import ./packages.nix).casks;
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
