#!/usr/bin/env bash

setup_log_colors() {
  if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    LOG_BOLD=$'\033[1m'
    LOG_DIM=$'\033[2m'
    LOG_INFO=$'\033[1;32m'
    LOG_WARN=$'\033[1;33m'
    LOG_ERROR=$'\033[1;31m'
    LOG_RESET=$'\033[0m'
  else
    LOG_BOLD=""
    LOG_DIM=""
    LOG_INFO=""
    LOG_WARN=""
    LOG_ERROR=""
    LOG_RESET=""
  fi
}

setup_log_colors

bold() {
  printf '%s%s%s\n' "$LOG_BOLD" "$*" "$LOG_RESET"
}

info() {
  printf '%s[INFO]%s %s\n' "$LOG_INFO" "$LOG_RESET" "$*"
}

ok() {
  printf '%sPASS%s %s\n' "$LOG_INFO" "$LOG_RESET" "$*" >&2
}

warn() {
  printf '%sWARN%s %s\n' "$LOG_WARN" "$LOG_RESET" "$*" >&2
}

error() {
  printf '%s[ERROR]%s %s\n' "$LOG_ERROR" "$LOG_RESET" "$*" >&2
}

fail() {
  printf '%sFAIL%s %s\n' "$LOG_ERROR" "$LOG_RESET" "$*" >&2
}

die() {
  fail "$*"
  exit 1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

require_cmd() {
  have "$1" || die "missing required command: $1"
}
