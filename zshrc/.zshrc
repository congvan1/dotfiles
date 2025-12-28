# Path to your oh-my-zsh installation.
# Reevaluate the prompt string each time it's displaying a prompt
setopt prompt_subst
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
autoload bashcompinit && bashcompinit
autoload -Uz compinit
compinit -d "$HOME/.cache/zsh/zcompdump"
zstyle ':completion:*' cache-path "$HOME/.cache/zsh/zcompdump"
source <(kubectl completion zsh)
complete -C '/usr/local/bin/aws_completer' aws

# Safely load zsh-autosuggestions
if [ -f "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    source "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# Safely load zsh-syntax-highlighting
if [ -f "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    source "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

bindkey '^L' vi-forward-word
bindkey '^k' up-line-or-search
bindkey '^j' down-line-or-search

eval "$(starship init zsh)"
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"

# You may need to manually set your language environment
export LANG=en_US.UTF-8

export EDITOR=/opt/homebrew/bin/nvim

alias la=tree
alias cat=bat
alias C=pbcopy
alias tf=terraform

# Git
alias gc="git commit -m"
alias gca="git commit -a -m"
alias gp="git push origin HEAD"
alias gpu="git pull origin"
alias gs="git status"
alias glog="git log --graph --topo-order --pretty='%w(100,0,6)%C(yellow)%h%C(bold)%C(black)%d %C(cyan)%ar %C(green)%an%n%C(bold)%C(white)%s %N' --abbrev-commit"
alias gdiff="git diff"
alias gco="git checkout"
alias gb='git branch'
alias gba='git branch -a'
alias gadd='git add'
alias ga='git add -p'
alias gcoall='git checkout -- .'
alias gr='git remote'
alias gre='git reset'

# Docker
alias dco="docker compose"
alias dps="docker ps"
alias dpa="docker ps -a"
alias dl="docker ps -l -q"
alias dx="docker exec -it"

# Dirs
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ......="cd ../../../../.."

# GO
export GOPATH="$HOME/go"

# VIM
alias v="nvim"

# Nmap
alias nm="nmap -sC -sV -oN nmap"

export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Users/omer/.vimpkg/bin:${GOPATH}/bin:$HOME/.cargo/bin"

alias cl='clear'

# K8S
export KUBECONFIG="$HOME/.kube/config"
alias k="kubectl"
alias ka="kubectl apply -f"
alias kg="kubectl get"
alias kd="kubectl describe"
alias kdel="kubectl delete"
alias kl="kubectl logs"
alias kgpo="kubectl get pod"
alias kgd="kubectl get deployments"
alias kx="kubectx"
alias kns="kubens"
alias kl="kubectl logs -f"
alias ke="kubectl exec -it"
alias kcns='kubectl config set-context --current --namespace'
alias podname=''

kdec() {
    if [ -n "$2" ]; then
        kubectl get secret "$1" -n "$2" -o yaml | yq '.data | to_entries[] | .key as $k | .value | @base64d | "\($k): \(.)"'
    else
        kubectl get secret "$1" -o yaml | yq '.data | to_entries[] | .key as $k | .value | @base64d | "\($k): \(.)"'
    fi
}

seal() {
    if [[ -e "$1" ]]; then
        kubeseal --scope cluster-wide --controller-namespace kube-system --controller-name sealed-secrets-controller --cert $1 -o yaml -w sealed.yaml
    else
        echo "Path not exist"
    fi
}

# HTTP requests with xh!
alias http="xh"

# VI Mode!!!
bindkey jj vi-cmd-mode

# Eza
alias ll="eza -l --icons -a"
alias lt="eza --tree --level=2 --long --icons"
alias ltree="eza --tree --level=2  --icons"

# SEC STUFF
alias gobust="gobuster dir --wordlist $HOME/security/wordlists/diccnoext.txt --wildcard --url"
alias dirsearch='python dirsearch.py -w db/dicc.txt -b -u'
alias massdns="$HOME/hacking/tools/massdns/bin/massdns -r $HOME/hacking/tools/massdns/lists/resolvers.txt -t A -o S bf-targets.txt -w livehosts.txt -s 4000"
alias server='python -m http.server 4445'
alias tunnel='ngrok http 4445'
alias fuzz="ffuf -w $HOME/hacking/SecLists/content_discovery_all.txt -mc all -u"
alias gr="$HOME/go/src/github.com/tomnomnom/gf/gf"

### FZF ###
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow'
[ -f "$HOME/.fzf.zsh" ] && source "$HOME/.fzf.zsh"

# Homebrew - prioritize over nix for latest packages
export PATH=/opt/homebrew/bin:/opt/homebrew/sbin:$PATH

alias mat='osascript -e "tell application \"System Events\" to key code 126 using {command down}" && tmux neww "cmatrix"'

# Nix!
export NIX_CONF_DIR=$HOME/.config/nix
# Nix paths added after Homebrew so Homebrew takes precedence
export PATH=$PATH:/run/current-system/sw/bin

function ranger {
	local IFS=$'\t\n'
	local tempfile="$(mktemp -t tmp.XXXXXX)"
	local ranger_cmd=(
		command
		ranger
		--cmd="map Q chain shell echo %d > "$tempfile"; quitall"
	)

	${ranger_cmd[@]} "$@"
	if [[ -f "$tempfile" ]] && [[ "$(cat -- "$tempfile")" != "$(echo -n `pwd`)" ]]; then
		cd -- "$(cat "$tempfile")" || return
	fi
	command rm -f -- "$tempfile" 2>/dev/null
}
alias rr='ranger'

# navigation
cx() { cd "$@" && l; }
fcd() { cd "$(find . -type d -not -path '*/.*' | fzf)" && l; }
f() { echo "$(find . -type f -not -path '*/.*' | fzf)" | pbcopy }
fv() { nvim "$(find . -type f -not -path '*/.*' | fzf)" }

# Nix multi-user daemon setup
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi
export PATH="$PATH:/nix/var/nix/profiles/default/bin"

eval "$(zoxide init zsh)"
eval "$(atuin init zsh)"
eval "$(direnv hook zsh)"

# Force Block Cursor ALWAYS (even in vi-mode)
# Define a function to reset cursor to block when keymap changes (e.g. going to insert mode)
function zle-keymap-select {
  echo -ne '\e[2 q'
}
zle -N zle-keymap-select

# Ensure it runs on every prompt
echo -ne '\e[2 q'
precmd() { echo -ne '\e[2 q'; }

# Smart Vim Function
vim() {
  local real_path=$(realpath "$1" 2>/dev/null)
  [[ -z "$real_path" ]] && nvim "$1" && return

  local dir
  [[ -f "$real_path" ]] && dir=$(dirname "$real_path") || dir="$real_path"

  (cd "$dir" && nvim "$real_path")
}

# Custom Ctrl+W to delete words stopping at slashes
my-backward-kill-word() {
    local WORDCHARS='*?_-.[]~=&;!#$%^(){}<>\\'
    if [[ "$LBUFFER" =~ '/$' ]]; then
        zle backward-delete-char
    else
        zle backward-kill-word
    fi
}
zle -N my-backward-kill-word
bindkey '^W' my-backward-kill-word


export $(cat $HOME/.config/zshrc/.env | xargs)

# # Setup up workspace
# curl -fsSL https://claude.ai/install.sh | bash
# npm install -g @google/gemini-cli
# npm install -g @augmentcode/auggie