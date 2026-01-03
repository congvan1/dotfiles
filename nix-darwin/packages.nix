{
  brews = [
    # Essential Nix Tools
    "pam-reattach"         # Fix TouchID in Tmux
    "direnv"               # Environment management
    "starship"             # Prompt (via Homebrew)
    "zsh-autosuggestions"
    "zsh-syntax-highlighting"
    
    # Development Toolchains
    "rustup"
    "go"
    "gcc"
    "cmake"
    "pkg-config"
    "make"
    "tldr"
    "stow"
    "node"
    "wireshark"
      
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
    "diff-so-fancy"
    
    # Kubernetes Tools
    "kubectl"
    "kubectx"
    "kubernetes-helm"
    "kubeseal"
    "k9s"
    
    # Container & VM Tools
    "docker"
    "docker-compose"
    "qemu"              # Emulator
    
    # Audio/Video
    "ffmpeg"
    "neovim"
    
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
    
    # AI Agents
    "aichat"            # All-in-one LLM CLI (GPT, Claude, Gemini)
    "cliproxyapi"
    
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

  casks = [
    "font-jetbrains-mono-nerd-font"
    "maccy"             # Clipboard manager
    "aerospace"         # Tiling window manager
    "multipass"         # Ubuntu VMs
    "google-chrome"
    "chromedriver"
    "cloudflare-warp"
  ];
}
