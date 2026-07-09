#!/usr/bin/env bash
# Sync agent skills from the dotfiles skill library to coding agents.
#
# Canonical library: <dotfiles>/skills/<skill-name>/SKILL.md
# Installs via symlink (default) or copy into each agent's user skills dir.
#
# Usage:
#   ./scripts/sync-skills/sync-skills.sh                 # list library + status
#   ./scripts/sync-skills/sync-skills.sh install          # all skills → all agents
#   ./scripts/sync-skills/sync-skills.sh install codex    # one agent
#   ./scripts/sync-skills/sync-skills.sh install claude log-search caveman
#   ./scripts/sync-skills/sync-skills.sh uninstall grok
#   ./scripts/sync-skills/sync-skills.sh status
#   ./scripts/sync-skills/sync-skills.sh paths
#
# Env:
#   SKILLS_ROOT   override library path (default: <repo>/skills)
#   DRY_RUN=1     print actions only
#   MODE=copy     copy instead of symlink

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/shell.sh
source "${SCRIPT_DIR}/../lib/shell.sh"

DOTFILES_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SKILLS_ROOT="${SKILLS_ROOT:-${DOTFILES_ROOT}/skills}"
MODE="${MODE:-symlink}" # symlink | copy
DRY_RUN="${DRY_RUN:-0}"

# Agent name → default user skills directory.
# Aliases: agent=agents, gemeni=gemini, claude-code=claude
declare -A AGENT_PATHS=(
  [codex]="${HOME}/.codex/skills"
  [claude]="${HOME}/.claude/skills"
  [gemini]="${HOME}/.gemini/skills"
  [grok]="${HOME}/.grok/skills"
  [agents]="${HOME}/.agents/skills"
)

# Also known as (for Codex shared standard + Gemini alias)
# Installing to `agents` covers the cross-tool ~/.agents/skills path used by
# Codex, Gemini CLI, and other Agent Skills–compatible tools.

usage() {
  cat <<'EOF'
Usage: sync-skills.sh <command> [agent|all] [skill...]

Commands:
  list                 List skills in the library
  paths                Print agent skill directories
  status               Show library skills vs installed agents
  install [agent|all] [skill...]
                       Symlink (or copy) skills into agent dirs
  uninstall [agent|all] [skill...]
                       Remove managed links/copies for skills we own
  help                 Show this help

Agents:
  codex    → ~/.codex/skills
  claude   → ~/.claude/skills
  gemini   → ~/.gemini/skills   (also: gemeni)
  grok     → ~/.grok/skills
  agents   → ~/.agents/skills   (shared Agent Skills path)
  all      → every agent above

Options via env:
  DRY_RUN=1       preview without writing
  MODE=copy       copy files instead of symlink
  SKILLS_ROOT=…   override library path

Examples:
  sync-skills.sh install all
  sync-skills.sh install codex
  sync-skills.sh install claude log-search metric-search
  DRY_RUN=1 sync-skills.sh install grok
  MODE=copy sync-skills.sh install agents caveman
EOF
}

resolve_agent() {
  local name="${1:-}"
  name="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"
  case "$name" in
    codex) echo codex ;;
    claude|claude-code|cc) echo claude ;;
    gemini|gemeni|gemini-cli) echo gemini ;;
    grok|agent|grok-build|xai) echo grok ;;
    agents|agent-skills|universal) echo agents ;;
    all) echo all ;;
    *)
      error "Unknown agent: $1"
      echo "Valid: codex claude gemini grok agents all" >&2
      return 1
      ;;
  esac
}

list_library_skills() {
  local d
  [[ -d "$SKILLS_ROOT" ]] || die "Skills library not found: $SKILLS_ROOT"
  for d in "$SKILLS_ROOT"/*/; do
    [[ -d "$d" ]] || continue
    local base
    base="$(basename "$d")"
    # skip non-skill dirs
    [[ "$base" == .* ]] && continue
    if [[ -f "${d}SKILL.md" ]]; then
      printf '%s\n' "$base"
    fi
  done | sort
}

is_managed_link() {
  # True if path is a symlink into our skills library (or a copy we may remove).
  local path="$1"
  if [[ -L "$path" ]]; then
    local target
    target="$(readlink "$path" 2>/dev/null || true)"
    [[ "$target" == "$SKILLS_ROOT"/* ]] && return 0
    # also accept old codex layout if still pointing there after migrate
    [[ "$target" == */dotfiles/skills/* ]] && return 0
    [[ "$target" == */dotfiles/codex/skills/* ]] && return 0
  fi
  return 1
}

do_link() {
  local src="$1"
  local dest="$2"
  if [[ "$DRY_RUN" == "1" ]]; then
    info "DRY_RUN would $MODE: $dest → $src"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  if [[ -L "$dest" ]] || [[ -e "$dest" ]]; then
    if is_managed_link "$dest"; then
      rm -f "$dest"
    elif [[ -L "$dest" ]]; then
      # foreign symlink — replace only if MODE forces; otherwise skip
      warn "skip existing non-library link: $dest → $(readlink "$dest")"
      return 0
    elif [[ -d "$dest" ]] || [[ -f "$dest" ]]; then
      warn "skip existing real path (not ours): $dest"
      return 0
    fi
  fi
  if [[ "$MODE" == "copy" ]]; then
    rm -rf "$dest"
    cp -R "$src" "$dest"
    ok "copied $dest"
  else
    ln -sfn "$src" "$dest"
    ok "linked  $dest → $src"
  fi
}

do_unlink() {
  local dest="$1"
  if [[ ! -e "$dest" && ! -L "$dest" ]]; then
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    info "DRY_RUN would remove: $dest"
    return 0
  fi
  if is_managed_link "$dest"; then
    rm -f "$dest"
    ok "removed $dest"
  elif [[ "$MODE" == "copy" && -d "$dest" && -f "${dest}/SKILL.md" ]]; then
    # only remove copies if they look like a skill and user asked uninstall
    # require dest name to match a library skill (caller ensures)
    rm -rf "$dest"
    ok "removed copy $dest"
  else
    warn "leave unmanaged path: $dest"
  fi
}

agents_to_use() {
  local a="$1"
  if [[ "$a" == "all" ]]; then
    printf '%s\n' codex claude gemini grok agents
  else
    printf '%s\n' "$a"
  fi
}

cmd_list() {
  bold "Skill library: $SKILLS_ROOT"
  local s count=0
  while IFS= read -r s; do
    printf '  %s\n' "$s"
    count=$((count + 1))
  done < <(list_library_skills)
  info "${count} skill(s)"
}

cmd_paths() {
  bold "Agent skill directories"
  local a
  for a in codex claude gemini grok agents; do
    printf '  %-8s %s\n' "$a" "${AGENT_PATHS[$a]}"
  done
  printf '\n  library  %s\n' "$SKILLS_ROOT"
}

cmd_status() {
  bold "Status (library → agents)"
  local skills=()
  local s a
  while IFS= read -r s; do
    skills+=("$s")
  done < <(list_library_skills)

  printf '%-28s' "skill"
  for a in codex claude gemini grok agents; do
    printf ' %-7s' "$a"
  done
  printf '\n'
  printf '%s\n' "--------------------------------------------------------------------------------"

  for s in "${skills[@]}"; do
    printf '%-28s' "$s"
    for a in codex claude gemini grok agents; do
      local dest="${AGENT_PATHS[$a]}/${s}"
      local mark="."
      if [[ -L "$dest" ]]; then
        if is_managed_link "$dest"; then
          mark="L"
        else
          mark="?"
        fi
      elif [[ -d "$dest" ]]; then
        mark="D"
      fi
      printf ' %-7s' "$mark"
    done
    printf '\n'
  done
  echo
  info "Legend: L=symlink to library  D=real dir  ?=other link  .=missing"
}

install_one() {
  local agent="$1"
  local skill="$2"
  local src="${SKILLS_ROOT}/${skill}"
  local dest="${AGENT_PATHS[$agent]}/${skill}"
  [[ -d "$src" && -f "${src}/SKILL.md" ]] || die "Not a skill: $skill ($src)"
  mkdir -p "${AGENT_PATHS[$agent]}"
  do_link "$src" "$dest"
}

uninstall_one() {
  local agent="$1"
  local skill="$2"
  local dest="${AGENT_PATHS[$agent]}/${skill}"
  do_unlink "$dest"
}

cmd_install() {
  local agent_arg="${1:-all}"
  shift || true
  local agent
  agent="$(resolve_agent "$agent_arg")"

  local skills=()
  if [[ $# -gt 0 ]]; then
    skills=("$@")
  else
    while IFS= read -r s; do
      skills+=("$s")
    done < <(list_library_skills)
  fi

  [[ ${#skills[@]} -gt 0 ]] || die "No skills to install"

  local a skill
  while IFS= read -r a; do
    bold "Install → $a (${AGENT_PATHS[$a]})"
    for skill in "${skills[@]}"; do
      install_one "$a" "$skill"
    done
  done < <(agents_to_use "$agent")
}

cmd_uninstall() {
  local agent_arg="${1:-all}"
  shift || true
  local agent
  agent="$(resolve_agent "$agent_arg")"

  local skills=()
  if [[ $# -gt 0 ]]; then
    skills=("$@")
  else
    while IFS= read -r s; do
      skills+=("$s")
    done < <(list_library_skills)
  fi

  local a skill
  while IFS= read -r a; do
    bold "Uninstall ← $a"
    for skill in "${skills[@]}"; do
      uninstall_one "$a" "$skill"
    done
  done < <(agents_to_use "$agent")
}

migrate_broken_codex_links() {
  # Best-effort: drop dead symlinks that pointed at old codex/skills paths
  local dir="${HOME}/.codex/skills"
  [[ -d "$dir" ]] || return 0
  local link
  for link in "$dir"/*; do
    [[ -L "$link" ]] || continue
    if [[ ! -e "$link" ]]; then
      if [[ "$DRY_RUN" == "1" ]]; then
        info "DRY_RUN would remove broken link: $link"
      else
        warn "removing broken link: $link → $(readlink "$link")"
        rm -f "$link"
      fi
    fi
  done
}

main() {
  local cmd="${1:-status}"
  shift || true

  case "$cmd" in
    list|ls) cmd_list ;;
    paths) cmd_paths ;;
    status|st) cmd_status ;;
    install|sync|link)
      migrate_broken_codex_links
      cmd_install "$@"
      ;;
    uninstall|remove|rm)
      cmd_uninstall "$@"
      ;;
    help|-h|--help) usage ;;
    *)
      error "Unknown command: $cmd"
      usage
      exit 1
      ;;
  esac
}

main "$@"
