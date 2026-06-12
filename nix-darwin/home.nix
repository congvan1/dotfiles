# home.nix
# home-manager switch 

{ config, pkgs, ... }:

{
  home.username = "van";
  home.homeDirectory = "/Users/van";
  home.stateVersion = "23.05"; # Please read the comment before changing.

# Makes sense for user specific applications that shouldn't be available system-wide
  home.packages = [
    pkgs.asm-lsp
    pkgs.nasm
    pkgs.openbao
    pkgs.gnupg
    pkgs.television

    # Security and supply-chain scanning
    pkgs.gitleaks
    pkgs.grype
    pkgs.hadolint
    pkgs.kube-linter
    pkgs.kube-score
    pkgs.osv-scanner
    pkgs.pre-commit
    pkgs.semgrep
    pkgs.syft
    pkgs.trivy
    pkgs.trufflehog

    pkgs.playwright
    (pkgs.writeShellScriptBin "playwright" ''
      exec ${pkgs.playwright}/cli.js "$@"
    '')
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    ".zshrc".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/zshrc/.zshrc";
    ".config/wezterm".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/wezterm";
    ".config/skhd".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/skhd";
    ".config/starship".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/starship";
    ".config/zellij".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/zellij";
    ".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/nvim";
    ".config/nix".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/nix";
    ".config/nix-darwin".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/nix-darwin";
    ".config/karabiner".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/karabiner";
    ".config/tmux".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/tmux";
    ".config/atuin".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/atuin";
    ".docker/cli-plugins/docker-buildx".source =
      config.lib.file.mkOutOfStoreSymlink "/opt/homebrew/lib/docker/cli-plugins/docker-buildx";
    ".config/ghostty".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/ghostty";
    ".config/aerospace".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/aerospace";
    ".config/sketchybar".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/sketchybar";
    ".config/nushell".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/nushell";
  };

  home.sessionVariables = {
  };

  home.sessionPath = [
    "/run/current-system/sw/bin"
      "$HOME/.nix-profile/bin"
  ];
  programs.home-manager.enable = true;
  # programs.zsh = {
  #   enable = true;
  #   initContent = ''
  #     # Fix Neovim terminal staircasing
  #     stty onlcr
  #
  #     # Add any additional configurations here
  #     export PATH=/run/current-system/sw/bin:$HOME/.nix-profile/bin:$PATH
  #     if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
  #       . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
  #     fi
  #     
  #     # Initialize Atuin (Enhanced Shell History)
  #     eval "$(atuin init zsh)"
  #   '';
  # };
}
