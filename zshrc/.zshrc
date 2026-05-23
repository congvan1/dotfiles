# Path to your oh-my-zsh installation.
# Reevaluate the prompt string each time it's displaying a prompt
setopt prompt_subst

if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
autoload -Uz compinit
mkdir -p "$HOME/.cache/zsh"

clean_fpath=()
for dir in $fpath; do
  broken_completion=0
  if [[ -d "$dir" ]]; then
    for completion in "$dir"/_*(N); do
      [[ -L "$completion" && ! -e "$completion" ]] && broken_completion=1 && break
    done
  fi
  (( broken_completion )) || clean_fpath+=("$dir")
done
fpath=("${clean_fpath[@]}")
unset clean_fpath broken_completion completion dir

compinit -i -d "$HOME/.cache/zsh/zcompdump"
autoload -Uz bashcompinit && bashcompinit
zstyle ':completion:*' cache-path "$HOME/.cache/zsh"
if command -v kubectl >/dev/null 2>&1; then
    source <(kubectl completion zsh)
fi
if command -v aws_completer >/dev/null 2>&1; then
    complete -C "$(command -v aws_completer)" aws
fi

# Safely load zsh-autosuggestions
if command -v brew >/dev/null 2>&1 && [ -f "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    source "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# Safely load zsh-syntax-highlighting
if command -v brew >/dev/null 2>&1 && [ -f "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
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
alias l=less
alias d=docker
alias dc=docker-compose

# Git
alias gc="git commit -m"
alias gca="git commit -a -m"
alias gp="git push origin HEAD"
alias gpu="git pull origin"
alias gs="git status"
alias glog="git log --graph --topo-order --pretty='%w(100,0,6)%C(yellow)%h%C(bold)%C(black)%d %C(cyan)%ar %C(green)%an%n%C(bold)%C(white)%s %N' --abbrev-commit"
unalias gdiff 2>/dev/null
gdiff() {
	if command -v delta >/dev/null 2>&1; then
		git -c core.pager="delta --syntax-theme=Dracula --line-numbers --side-by-side" diff "$@"
	elif command -v diff-so-fancy >/dev/null 2>&1; then
		git diff --color=always "$@" | diff-so-fancy | less --tabs=4 -RFX
	else
		git diff "$@"
	fi
}
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
_cd_dot_parent_path() {
	local levels="$1"
	local path=".."
	local i

	for (( i = 2; i <= levels; i++ )); do
		path="$path/.."
	done

	print -r -- "$path"
}

cd() {
	if [[ "$#" -eq 1 && "$1" =~ '^\.\.+$' ]]; then
		builtin cd "$(_cd_dot_parent_path $((${#1} - 1)))"
	else
		builtin cd "$@"
	fi
}

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

export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Users/omer/.vimpkg/bin:${GOPATH}/bin:$HOME/.cargo/bin"

alias cl='clear'

# K8S
export KUBECONFIG="$HOME/.kube/config"
alias k="kubectl"
if (( $+functions[_kubectl] )); then
    compdef _kubectl k
fi
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
    local namespace=""
    local secret=""
    local -a kubectl_args

    while (( $# )); do
        case "$1" in
            -n|--namespace)
                namespace="$2"
                shift 2
                ;;
            --namespace=*)
                namespace="${1#--namespace=}"
                shift
                ;;
            -h|--help)
                echo "usage: kdec [-n namespace] secret"
                return 0
                ;;
            -*)
                echo "kdec: unknown option: $1" >&2
                return 2
                ;;
            *)
                if [[ -z "$secret" ]]; then
                    secret="$1"
                elif [[ -z "$namespace" ]]; then
                    namespace="$1"
                else
                    echo "kdec: unexpected argument: $1" >&2
                    return 2
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$secret" ]]; then
        echo "usage: kdec [-n namespace] secret" >&2
        return 2
    fi

    kubectl_args=(get secret "$secret")
    [[ -n "$namespace" ]] && kubectl_args+=(-n "$namespace")
    kubectl_args+=(-o yaml)

    kubectl "${kubectl_args[@]}" | yq '.data | to_entries[] | .key as $k | .value | @base64d | "\($k): \(.)"'
}

_kdec_completion() {
    local -a secret_names namespaces kubectl_args
    local namespace=""
    local i

    for (( i = 2; i <= $#words; i++ )); do
        case "${words[i]}" in
            -n|--namespace)
                namespace="${words[i+1]}"
                ;;
            --namespace=*)
                namespace="${words[i]#--namespace=}"
                ;;
        esac
    done

    kubectl_args=(get secret -o name)
    [[ -n "$namespace" ]] && kubectl_args+=(-n "$namespace")
    secret_names=("${(@f)$(kubectl "${kubectl_args[@]}" 2>/dev/null | sed 's#^secret/##')}")
    namespaces=("${(@f)$(kubectl get namespace -o name 2>/dev/null | sed 's#^namespace/##')}")

    _arguments -C \
        '(-h --help)'{-h,--help}'[show help]' \
        '(-n --namespace)'{-n,--namespace}'[namespace]:namespace:->namespace' \
        '1:secret:->secret' \
        '2:namespace:->namespace'

    case "$state" in
        namespace)
            _describe -t namespaces 'namespace' namespaces
            ;;
        secret)
            _describe -t secrets 'secret' secret_names
            ;;
    esac
}

compdef _kdec_completion kdec

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
alias ll="eza -l -a"
alias lt="eza --tree --level=2 --long"
alias ltree="eza --tree --level=2"

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
if [[ -r "$HOME/.fzf.zsh" ]]; then
	source "$HOME/.fzf.zsh"
elif [[ -r /opt/homebrew/opt/fzf/shell/key-bindings.zsh ]]; then
	source /opt/homebrew/opt/fzf/shell/key-bindings.zsh
	[[ -r /opt/homebrew/opt/fzf/shell/completion.zsh ]] && source /opt/homebrew/opt/fzf/shell/completion.zsh
fi

# Homebrew - prioritize over nix for latest packages
export PATH=/opt/homebrew/bin:/opt/homebrew/sbin:$PATH

alias mat='osascript -e "tell application \"System Events\" to key code 126 using {command down}" && tmux neww "cmatrix"'

# Nix!
export NIX_CONF_DIR=$HOME/.config/nix
# Nix paths added after Homebrew so Homebrew takes precedence
export PATH=$PATH:/run/current-system/sw/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin

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
export PATH="$PATH:/nix/var/nix/profiles/default/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin"

eval "$(zoxide init zsh)"
eval "$(atuin init zsh --disable-up-arrow)"
eval "$(direnv hook zsh)"

if [[ -r /opt/homebrew/share/zsh-navigation-tools/zsh-navigation-tools.plugin.zsh ]]; then
	source /opt/homebrew/share/zsh-navigation-tools/zsh-navigation-tools.plugin.zsh
fi

if (( $+widgets[fzf-history-widget] )); then
	bindkey -M emacs '^R' fzf-history-widget
	bindkey -M viins '^R' fzf-history-widget
	bindkey -M vicmd '^R' fzf-history-widget
fi

bindkey -M emacs '^I' expand-or-complete
bindkey -M viins '^I' expand-or-complete
bindkey -M vicmd '^I' expand-or-complete

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

syncmain() {
  local current_branch
  current_branch="$(git branch --show-current)" || return 1

  if [[ -z "$current_branch" ]]; then
    echo "syncmain: not on a branch."
    return 1
  fi

  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "syncmain: working tree is dirty. Commit or stash first."
    git status --short
    return 1
  fi

  git fetch origin || return 1
  git switch main || return 1

  if ! git pull --ff-only; then
    git switch "$current_branch" >/dev/null 2>&1
    return 1
  fi

  git switch "$current_branch" || return 1

  if ! git merge origin/main; then
    echo "syncmain: merge conflict. Resolve it and commit, or run: git merge --abort"
    return 1
  fi
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

if [ -f "$HOME/.config/zshrc/.env" ]; then
  export $(grep -v '^[[:space:]]*#' "$HOME/.config/zshrc/.env" | xargs)
fi

export WORKSPACE="$HOME/workspace"
export WORK_DIR="$WORKSPACE/work"
export CLIENTS_DIR="$WORK_DIR/clients"
export CELLUTIONS_DIR="$CLIENTS_DIR/Cellutions"
export VNG_DIR="$CLIENTS_DIR/VNG"
export CELLUTIONS_SSH_DIR="$CELLUTIONS_DIR/ssh"
export VNG_SECRETS_DIR="$VNG_DIR/secrets"
export VNG_SSH_DIR="$VNG_SECRETS_DIR/ssh"

alias ws='cd "$WORKSPACE"'
alias work='cd "$WORK_DIR"'
alias clients='cd "$CLIENTS_DIR"'
alias cellutions='cd "$CELLUTIONS_DIR"'
alias vng='cd "$VNG_DIR"'
alias cellssh='cd "$CELLUTIONS_SSH_DIR"'
alias vngssh='cd "$VNG_SSH_DIR"'

export scripts_path="$HOME/dotfiles/scripts"
[[ -x "$scripts_path/git-puller.sh" ]] && alias puller="bash $scripts_path/git-puller.sh"
[[ -x "$scripts_path/mr-slack.sh" ]] && alias slackmr="bash $scripts_path/mr-slack.sh"

# ProxyPal - Amp CLI Configuration (alternative to settings.json)
export AMP_URL="http://localhost:8317"
export AMP_API_KEY="proxypal-local"

# For Amp cloud features, get your API key from https://ampcode.com/settings
# and add it to ProxyPal Settings > Amp CLI Integration > Amp API Key

# Amp CLI
export PATH="/Users/van/.amp/bin:$PATH"

export PATH="/opt/homebrew/opt/helm@3/bin:$PATH"

install_apple_container() {
  if command -v container >/dev/null 2>&1; then
    echo "✔ Apple container already installed"
    container system start
    return
  fi

  VERSION="0.10.0"
  PKG="container-${VERSION}-installer-signed.pkg"
  URL="https://github.com/apple/container/releases/download/${VERSION}/${PKG}"
  TMP="/tmp/${PKG}"

  echo "⬇ Downloading Apple container ${VERSION}..."
  curl -L "$URL" -o "$TMP"

  echo "📦 Installing..."
  sudo installer -pkg "$TMP" -target /

  echo "✔ Apple container installed successfully"
}

# install_apple_container
