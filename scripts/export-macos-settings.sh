#!/bin/bash

set -euo pipefail

timestamp="$(date +%Y%m%d-%H%M%S)"
output_dir="${1:-reports/macos-settings-${timestamp}}"
domain_dir="${output_dir}/domains"

mkdir -p "$domain_dir"

log() {
  printf '%s\n' "$1"
}

read_default() {
  local domain="$1"
  local key="$2"

  defaults read "$domain" "$key" 2>/dev/null || printf '<unset>'
}

export_domain() {
  local domain="$1"
  local file="$domain_dir/${domain}.plist"

  if defaults export "$domain" "$file" 2>/dev/null; then
    log "exported ${domain}"
  else
    log "skipped ${domain}"
  fi
}

{
  printf '# macOS Settings Snapshot\n\n'
  printf 'Generated: %s\n\n' "$(date)"
  printf 'Output directory: %s\n\n' "$output_dir"

  printf '## Summary\n\n'
  printf '%s\n' "- Function key state: $(read_default -g com.apple.keyboard.fnState)"
  printf '%s\n' "- Press and hold: $(read_default -g ApplePressAndHoldEnabled)"
  printf '%s\n' "- Key repeat: $(read_default -g KeyRepeat)"
  printf '%s\n' "- Initial key repeat: $(read_default -g InitialKeyRepeat)"
  printf '%s\n' "- Screenshot location: $(read_default com.apple.screencapture location)"
  printf '%s\n' "- Screenshot format: $(read_default com.apple.screencapture type)"
  printf '%s\n' "- Finder show all files: $(read_default com.apple.finder AppleShowAllFiles)"
  printf '%s\n' "- Finder show extensions: $(read_default com.apple.finder AppleShowAllExtensions)"
  printf '%s\n' "- Dock autohide: $(read_default com.apple.dock autohide)"
  printf '%s\n' "- Dock show recents: $(read_default com.apple.dock show-recents)"
  printf '%s\n' "- Trackpad clicking: $(read_default com.apple.AppleMultitouchTrackpad Clicking)"
  printf '%s\n' "- Trackpad three-finger drag: $(read_default com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag)"
  printf '%s\n' "- Window Manager auto hide: $(read_default com.apple.WindowManager AutoHide)"
  printf '\n'

  printf '## Exported Domains\n\n'
  printf '%s\n' '- NSGlobalDomain'
  printf '%s\n' '- com.apple.dock'
  printf '%s\n' '- com.apple.finder'
  printf '%s\n' '- com.apple.screencapture'
  printf '%s\n' '- com.apple.AppleMultitouchTrackpad'
  printf '%s\n' '- com.apple.AppleMultitouchMouse'
  printf '%s\n' '- com.apple.WindowManager'
  printf '%s\n' '- com.apple.symbolichotkeys'
  printf '%s\n' '- com.apple.loginwindow'
  printf '%s\n' '- com.apple.spaces'
} > "${output_dir}/summary.md"

domains=(
  "NSGlobalDomain"
  "com.apple.dock"
  "com.apple.finder"
  "com.apple.screencapture"
  "com.apple.AppleMultitouchTrackpad"
  "com.apple.AppleMultitouchMouse"
  "com.apple.WindowManager"
  "com.apple.symbolichotkeys"
  "com.apple.loginwindow"
  "com.apple.spaces"
)

for domain in "${domains[@]}"; do
  export_domain "$domain"
done

log ""
log "Wrote snapshot to ${output_dir}/summary.md"
