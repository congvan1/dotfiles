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
      environment.systemPackages =
        [ 
          # Development Toolchains (Nix provides better version management)
          pkgs.rustup            # Rust toolchain manager
          pkgs.go                # Go language
          
        ];
      
      # Disable nix-darwin's Nix management (using Determinate Nix)
      nix.enable = false;
      
      nix.settings.experimental-features = "nix-command flakes";
      programs.zsh.enable = true;  # default shell on catalina
      system.configurationRevision = self.rev or self.dirtyRev or null;
      system.stateVersion = 4;
      nixpkgs.hostPlatform = "aarch64-darwin";
      security.pam.services.sudo_local.touchIdAuth = true;
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
        NSGlobalDomain.InitialKeyRepeat = 15; # Fast key repeat
        NSGlobalDomain.KeyRepeat = 2; # Very fast key repeat
        NSGlobalDomain.ApplePressAndHoldEnabled = false; # Disable press-and-hold for keys
        NSGlobalDomain.NSAutomaticCapitalizationEnabled = false;
        NSGlobalDomain.NSAutomaticDashSubstitutionEnabled = false;
        NSGlobalDomain.NSAutomaticPeriodSubstitutionEnabled = false;
        NSGlobalDomain.NSAutomaticQuoteSubstitutionEnabled = false;
        NSGlobalDomain.NSAutomaticSpellingCorrectionEnabled = false;
        NSGlobalDomain.NSNavPanelExpandedStateForSaveMode = true;
        NSGlobalDomain.NSNavPanelExpandedStateForSaveMode2 = true;
        NSGlobalDomain."com.apple.swipescrolldirection" = true; # Natural scrolling
        
        # Trackpad settings
        trackpad.Clicking = true; # Tap to click
        trackpad.TrackpadThreeFingerDrag = true;
        
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
      
      homebrew.brews = [
        # Essential Nix Tools
        "direnv"               # Environment management
        "starship"             # Prompt (via Homebrew)
        "zsh-autosuggestions"
        "zsh-syntax-highlighting"
          
        # Terminal & Shell
        "tmux"
        "nushell"
        "carapace"
        "sketchybar"
        
        
        # File Management & Navigation
        "tree"
        "eza"               # Modern ls
        "bat"               # Modern cat
        "fd"                # Modern find
        "fzf"               # Fuzzy finder
        "zoxide"            # Smart cd
        "ranger"            # File manager
        "ripgrep"           # Fast grep
        
        # Git & Version Control
        "git"
        "gh"                # GitHub CLI
        "pcre2"             # Git dependency (regex library)
        
        # Kubernetes Tools
        "kubectl"
        "kubectx"
        "kubernetes-helm"
        
        # Container & VM Tools
        "docker"
        "docker-compose"
        "qemu"              # Emulator
        
        # Audio/Video
        "ffmpeg"
        
        
        # Network & Security Tools
        "nmap"
        "xh"                # Modern HTTP client
        "ffuf"              # Web fuzzer
        "gobuster"          # Directory bruteforcer
        
        # System Monitoring
        "htop"
        "btop"
        
        # Network Tools
        "dnsmasq"           # DNS/DHCP server
        "wget"
        "curl"
        
        # Data Processing
        "jq"                # JSON processor
        "yq"                # YAML processor
        
        # Utilities
        "sshs"              # SSH manager
        "glow"              # Markdown renderer
        "atuin"             # Shell history
        "cmatrix"           # Matrix effect
        
        # DevOps & Infrastructure
        "terraform"
        "ansible"
        "python@3.12"       # Python for Ansible
        "sshpass"           # SSH password authentication
        
        # Database Clients
        "libpq"             # PostgreSQL client only (psql)
        "mysql-client"      # MySQL client only
        "redis"             # Redis client
        "mongosh"           # MongoDB shell
        
        # Cloud Tools
        "minio/stable/mc"   # MinIO mc
        "awscli"            # AWS CLI
      ];
      
      homebrew.casks = [
        "font-jetbrains-mono-nerd-font"
        "maccy"             # Clipboard manager
        "aerospace"         # Tiling window manager
        "multipass"         # Ubuntu VMs
      ];
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
