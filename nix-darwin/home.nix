# home.nix
# home-manager switch 

{ config, pkgs, ... }:

{
  home.username = "van";
  home.homeDirectory = "/Users/van";
  home.stateVersion = "23.05"; # Please read the comment before changing.

# Makes sense for user specific applications that shouldn't be available system-wide
  home.packages = [
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    ".zshrc".source = ~/dotfiles/zshrc/.zshrc;
    # ".config/wezterm".source = ~/dotfiles/wezterm;
    # ".config/skhd".source = ~/dotfiles/skhd;
    # ".config/starship".source = ~/dotfiles/starship;
    # ".config/zellij".source = ~/dotfiles/zellij;
    # ".config/nvim".source = ~/dotfiles/nvim;
    # ".config/nix".source = ~/dotfiles/nix;
    # ".config/nix-darwin".source = ~/dotfiles/nix-darwin;
    ".config/tmux".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/tmux";
    ".config/atuin".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/atuin";
    # ".config/ghostty".source = ~/dotfiles/ghostty;
    # ".config/aerospace".source = ~/dotfiles/aerospace;
    # ".config/sketchybar".source = ~/dotfiles/sketchybar;
    # ".config/nushell".source = ~/dotfiles/nushell;
  };

  home.sessionVariables = {
  };

  home.sessionPath = [
    "/run/current-system/sw/bin"
      "$HOME/.nix-profile/bin"
  ];
  programs.home-manager.enable = true;
  programs.zsh = {
    enable = true;
    initContent = ''
      # Fix Neovim terminal staircasing
      stty onlcr

      # Add any additional configurations here
      export PATH=/run/current-system/sw/bin:$HOME/.nix-profile/bin:$PATH
      if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
      fi
      
      # Initialize Atuin (Enhanced Shell History)
      eval "$(atuin init zsh)"
    '';
  };
}
