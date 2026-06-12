#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: mr-slack.sh [options]

Commit staged changes, push the current branch, create/find a GitLab MR with glab, then notify Slack.

Options:
  -t, --target-branch BRANCH  Target branch for the MR. Defaults to MR_TARGET_BRANCH or main.
  -m, --message MESSAGE       Commit title/message. Defaults to formatted current branch name.
      --draft                 Create a draft MR.
      --channel ID            Slack channel ID to send to, overriding SLACK_CHANNEL_ID.
      --thread VALUE          Send Slack notification as a thread reply. Accepts Slack permalink or thread timestamp.
      --no-slack              Skip Slack notification.
  -h, --help                  Show this help.

Environment:
  MR_SLACK_ENV                Env file path. Defaults to $HOME/dotfiles/.env.
  MR_TARGET_BRANCH            Default target branch.
  GITLAB_HOST                 Optional GitLab host override.
  SLACK_BOT_TOKEN             Slack bot token used with chat.postMessage.
  SLACK_CHANNEL_ID            Slack channel ID, e.g. C0123456789.
  SLACK_API_URL               Slack API URL. Defaults to https://slack.com/api/chat.postMessage.
  SLACK_THREAD                 Optional default Slack permalink or thread timestamp.
  SLACK_THREAD_CACHE_TTL_HOURS Thread cache TTL in /tmp. Defaults to 12.
  SLACK_WEBHOOK_URL           Optional fallback Slack incoming webhook URL.
  SLACK_REVIEWER_OPTIONS      Bash array of selectable reviewers, e.g. ("Van <@U123>" "An <@U456>").
EOF
}

setup_colors() {
  if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    color_info=$'\033[1;32m'
    color_error=$'\033[1;31m'
    color_reset=$'\033[0m'
  else
    color_info=""
    color_error=""
    color_reset=""
  fi
}

info() {
  printf '%s[INFO]%s %s\n' "$color_info" "$color_reset" "$*"
}

error() {
  printf '%s[ERROR]%s %s\n' "$color_error" "$color_reset" "$*" >&2
}

die() {
  error "$*"
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

branch_to_message() {
  local branch="$1"
  local type
  local rest
  local ticket
  local title
  local capitalized_type
  local message

  if [[ "$branch" =~ ^([[:alpha:]][[:alnum:]_-]*)/([A-Z]+-[0-9]+)-(.+)$ ]]; then
    type="${BASH_REMATCH[1]}"
    ticket="${BASH_REMATCH[2]}"
    title="${BASH_REMATCH[3]//-/ }"
    capitalized_type="$(printf '%s%s' "$(printf '%s' "${type:0:1}" | tr '[:lower:]' '[:upper:]')" "${type:1}")"

    printf '[%s] %s: %s\n' "$ticket" "$capitalized_type" "$title"
    return
  fi

  message="${branch//\//:}"
  message="${message//-/ }"
  printf '%s\n' "$message"
}

extract_url() {
  grep -Eo 'https?://[^[:space:]]+' | tail -n 1 | sed 's/[[:punct:]]$//'
}

load_env() {
  env_file="${MR_SLACK_ENV:-$HOME/dotfiles/.env}"

  if [[ -f "$env_file" ]]; then
    # shellcheck disable=SC1090
    source "$env_file"
  fi
}

parse_args() {
  target_branch="${MR_TARGET_BRANCH:-main}"
  commit_message=""
  draft=0
  send_slack=1
  mr_created=0
  slack_thread_input="${SLACK_THREAD:-${SLACK_THREAD_TS:-}}"
  slack_thread_ts=""
  slack_thread_from_cache=0
  slack_thread_from_input=0
  slack_channel_from_arg=0
  slack_message_ts=""
  slack_thread_cache_file="${SLACK_THREAD_CACHE_FILE:-/tmp/mr-slack-thread-cache}"
  slack_thread_cache_ttl_hours="${SLACK_THREAD_CACHE_TTL_HOURS:-12}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t|--target-branch)
        [[ $# -ge 2 ]] || die "$1 requires a branch"
        target_branch="$2"
        shift 2
        ;;
      -m|--message)
        [[ $# -ge 2 ]] || die "$1 requires a message"
        commit_message="$2"
        shift 2
        ;;
      --draft)
        draft=1
        shift
        ;;
      --channel)
        [[ $# -ge 2 ]] || die "$1 requires a Slack channel ID"
        SLACK_CHANNEL_ID="$2"
        slack_channel_from_arg=1
        shift 2
        ;;
      --thread)
        [[ $# -ge 2 ]] || die "$1 requires a Slack thread permalink or timestamp"
        slack_thread_input="$2"
        shift 2
        ;;
      --no-slack)
        send_slack=0
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown option: $1"
        ;;
    esac
  done
}

check_dependencies() {
  require_cmd git
  require_cmd glab
  require_cmd jq
}

current_branch() {
  git branch --show-current
}

git_remote_url() {
  git remote get-url origin 2>/dev/null || git remote get-url "$(git remote | head -n 1)"
}

gitlab_host_from_remote() {
  local remote_url="$1"

  case "$remote_url" in
    ssh://*@*)
      remote_url="${remote_url#ssh://*@}"
      printf '%s\n' "${remote_url%%[:/]*}"
      ;;
    git@*:*)
      remote_url="${remote_url#git@}"
      printf '%s\n' "${remote_url%%:*}"
      ;;
    http://*|https://*)
      remote_url="${remote_url#http://}"
      remote_url="${remote_url#https://}"
      printf '%s\n' "${remote_url%%/*}"
      ;;
    *)
      return 1
      ;;
  esac
}

slack_ts_from_permalink_id() {
  local id="$1"
  local length="${#id}"
  local seconds
  local micros

  [[ "$id" =~ ^p?[0-9]+$ ]] || return 1
  id="${id#p}"
  length="${#id}"
  [[ "$length" -gt 6 ]] || return 1

  seconds="${id:0:length-6}"
  micros="${id:length-6:6}"
  printf '%s.%s\n' "$seconds" "$micros"
}

slack_permalink_id_from_ts() {
  local ts="$1"
  local seconds
  local micros

  [[ "$ts" =~ ^[0-9]+\.[0-9]+$ ]] || return 1
  seconds="${ts%%.*}"
  micros="${ts#*.}"
  micros="${micros}000000"
  micros="${micros:0:6}"
  printf 'p%s%s\n' "$seconds" "$micros"
}

parse_slack_thread() {
  local value="$1"
  local channel=""
  local ts=""

  [[ -n "$value" ]] || return 1

  if [[ "$value" =~ /archives/([^/?]+)/ ]]; then
    channel="${BASH_REMATCH[1]}"
  fi

  if [[ "$value" =~ /p([0-9]+) ]]; then
    ts="$(slack_ts_from_permalink_id "${BASH_REMATCH[1]}")"
  elif [[ "$value" =~ ^p?[0-9]{7,}$ ]]; then
    ts="$(slack_ts_from_permalink_id "$value")"
  elif [[ "$value" =~ ^[0-9]+\.[0-9]+$ ]]; then
    ts="$value"
  else
    return 1
  fi

  if [[ -n "$channel" ]]; then
    SLACK_CHANNEL_ID="$channel"
  fi
  slack_thread_ts="$ts"
}

save_slack_thread_cache() {
  [[ -n "$slack_thread_ts" ]] || return

  {
    printf 'saved_at=%s\n' "$(date +%s)"
    printf 'channel_id=%s\n' "${SLACK_CHANNEL_ID:-}"
    printf 'thread_ts=%s\n' "$slack_thread_ts"
  } > "$slack_thread_cache_file"
}

load_slack_thread_cache() {
  local now
  local saved_at=""
  local channel_id=""
  local thread_ts=""
  local key
  local value
  local max_age

  [[ -f "$slack_thread_cache_file" ]] || return 1

  while IFS='=' read -r key value; do
    case "$key" in
      saved_at) saved_at="$value" ;;
      channel_id) channel_id="$value" ;;
      thread_ts) thread_ts="$value" ;;
    esac
  done < "$slack_thread_cache_file"

  [[ "$saved_at" =~ ^[0-9]+$ && -n "$thread_ts" ]] || return 1

  now="$(date +%s)"
  max_age=$((slack_thread_cache_ttl_hours * 3600))
  (( now - saved_at <= max_age )) || return 1

  [[ -n "$channel_id" ]] && SLACK_CHANNEL_ID="$channel_id"
  slack_thread_ts="$thread_ts"
  slack_thread_from_cache=1
  info "using cached Slack thread from $slack_thread_cache_file"
}

resolve_slack_thread() {
  if [[ -n "$slack_thread_input" ]]; then
    parse_slack_thread "$slack_thread_input" || die "invalid Slack thread value: $slack_thread_input"
    slack_thread_from_input=1
    save_slack_thread_cache
    return
  fi

  if [[ "$slack_channel_from_arg" -eq 1 ]]; then
    info "skipping cached Slack thread because --channel was provided"
    return
  fi

  load_slack_thread_cache || true
}

ensure_git_context() {
  local remote_url

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository"

  branch="$(current_branch)"
  [[ -n "$branch" ]] || die "detached HEAD is not supported"
  [[ "$branch" != "$target_branch" ]] || die "current branch and target branch are both '$branch'"

  remote_url="$(git_remote_url)"
  gitlab_host="${GITLAB_HOST:-$(gitlab_host_from_remote "$remote_url")}"
  [[ -n "$gitlab_host" ]] || die "could not detect GitLab host from remote: $remote_url"
  export GITLAB_HOST="$gitlab_host"
}

ensure_glab_auth() {
  glab auth status --hostname "$gitlab_host" >/dev/null 2>&1 ||
    die "glab is not authenticated for $gitlab_host. Run: glab auth login --hostname $gitlab_host"
}

prompt_target_branch() {
  local target_input

  if [[ -t 0 && -z "${MR_TARGET_BRANCH:-}" ]]; then
    read -r -p "Target branch [$target_branch]: " target_input
    target_branch="${target_input:-$target_branch}"
  fi
}

resolve_commit_message() {
  if [[ -z "$commit_message" ]]; then
    commit_message="$(branch_to_message "$branch")"
  fi
}

commit_staged_changes() {
  if ! git diff --cached --quiet --exit-code; then
    info "committing staged changes: $commit_message"
    git commit -m "$commit_message"
  else
    info "no staged changes to commit; continuing with existing branch commits"
  fi
}

push_branch() {
  local push_output

  info "pushing branch: $branch"
  push_output="$(git push -u origin "$branch" 2>&1)"
  printf '%s\n' "$push_output"
}

mr_url_from_json() {
  jq -r 'if type == "array" then .[0].web_url // empty else .web_url // empty end'
}

find_existing_mr() {
  local output

  output="$(glab mr list \
    --source-branch "$branch" \
    --target-branch "$target_branch" \
    --output json)"

  mr_url="$(printf '%s\n' "$output" | mr_url_from_json)"
  if [[ -n "$mr_url" ]]; then
    mr_created=0
    info "existing MR found: $mr_url"
    return 0
  fi

  return 1
}

create_mr() {
  local output
  local args

  args=(
    mr create
    -s "$branch"
    -b "$target_branch"
    -t "$commit_message"
    --fill
    -y
  )

  if [[ "$draft" -eq 1 ]]; then
    args+=(--draft)
  fi

  info "creating MR into $target_branch"
  output="$(glab "${args[@]}")"
  printf '%s\n' "$output"

  mr_url="$(printf '%s\n' "$output" | extract_url || true)"
  if [[ -z "$mr_url" ]]; then
    output="$(glab mr view "$branch" --output json)"
    mr_url="$(printf '%s\n' "$output" | mr_url_from_json)"
  fi

  [[ -n "$mr_url" ]] || die "MR was created but URL could not be detected"
  mr_created=1
}

find_or_create_mr() {
  find_existing_mr && return
  create_mr
}

send_slack_message() {
  local text="$1"
  local payload
  local response
  local ok
  local error
  local response_channel
  local response_ts

  if [[ -n "${SLACK_BOT_TOKEN:-}" && -n "${SLACK_CHANNEL_ID:-}" ]]; then
    payload="$(
      jq -n \
        --arg channel "$SLACK_CHANNEL_ID" \
        --arg text "$text" \
        --arg thread_ts "$slack_thread_ts" \
        '{channel: $channel, text: $text}
         | if $thread_ts != "" then . + {thread_ts: $thread_ts} else . end'
    )"

    response="$(
      curl -fsS -X POST \
        -H "Authorization: Bearer ${SLACK_BOT_TOKEN}" \
        -H 'Content-Type: application/json; charset=utf-8' \
        --data "$payload" \
        "${SLACK_API_URL:-https://slack.com/api/chat.postMessage}"
    )"

    ok="$(jq -r '.ok // false' <<<"$response")"
    if [[ "$ok" != "true" ]]; then
      error="$(jq -r '.error // "unknown_error"' <<<"$response")"
      die "Slack API failed: $error"
    fi

    response_channel="$(jq -r '.channel // empty' <<<"$response")"
    response_ts="$(jq -r '.ts // empty' <<<"$response")"
    [[ -n "$response_channel" ]] && SLACK_CHANNEL_ID="$response_channel"
    [[ -n "$response_ts" ]] && slack_message_ts="$response_ts"

    return
  fi

  if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
    [[ -z "$slack_thread_ts" ]] || die "SLACK_WEBHOOK_URL cannot send to a Slack thread; use SLACK_BOT_TOKEN + SLACK_CHANNEL_ID"
    payload="$(jq -n --arg text "$text" '{text: $text}')"
    curl -fsS -X POST \
      -H 'Content-Type: application/json' \
      --data "$payload" \
      "$SLACK_WEBHOOK_URL" >/dev/null
    return
  fi

  die "set SLACK_BOT_TOKEN + SLACK_CHANNEL_ID, or set SLACK_WEBHOOK_URL; use --no-slack to skip"
}

slack_mention_from_option() {
  local option="$1"

  if [[ "$option" =~ \<@[^[:space:]\>]+\> ]]; then
    printf '%s\n' "${BASH_REMATCH[0]}"
  else
    printf '%s\n' "$option"
  fi
}

select_slack_reviewers_with_fzf() {
  local selected
  local mentions=()
  local mention

  if [[ ! -t 0 ]]; then
    error "fzf reviewer selection requires an interactive terminal"
    return 1
  fi
  if ! command -v fzf >/dev/null 2>&1; then
    error "fzf is not installed or not in PATH"
    return 1
  fi
  if ! declare -p SLACK_REVIEWER_OPTIONS >/dev/null 2>&1; then
    error "SLACK_REVIEWER_OPTIONS is not set in $env_file"
    return 1
  fi
  if [[ "${#SLACK_REVIEWER_OPTIONS[@]}" -eq 0 ]]; then
    error "SLACK_REVIEWER_OPTIONS is empty"
    return 1
  fi

  selected="$(
    printf '%s\n' "${SLACK_REVIEWER_OPTIONS[@]}" |
      fzf \
        --multi \
        --prompt='Slack reviewers> ' \
        --height=40% \
        --border \
        --header="MR: ${mr_url:-} | ctrl-o open | ctrl-y copy | tab select | enter send" \
        --bind="ctrl-o:execute-silent(open '${mr_url:-}')" \
        --bind="ctrl-y:execute-silent(printf '%s' '${mr_url:-}' | pbcopy)"
  )" || return 1

  [[ -n "$selected" ]] || return 1

  while IFS= read -r option; do
    [[ -n "$option" ]] || continue
    mention="$(slack_mention_from_option "$option")"
    [[ -n "$mention" ]] && mentions+=("$mention")
  done <<<"$selected"

  printf '%s\n' "${mentions[*]}"
}

slack_reviewer_mentions() {
  local slack_reviewers

  slack_reviewers="$(select_slack_reviewers_with_fzf)" || return 1
  printf '%s\n' "$slack_reviewers"
}

notify_slack() {
  local reviewers
  local thread_id

  [[ "$send_slack" -eq 1 ]] || return

  reviewers="$(slack_reviewer_mentions)" || die "no Slack reviewer selected"
  [[ -n "$reviewers" ]] || die "no Slack reviewer selected"
  info "sending Slack notification"
  send_slack_message "${reviewers} please review MR: ${mr_url}"

  if [[ -z "$slack_thread_ts" && "$slack_thread_from_input" -eq 0 && "$slack_thread_from_cache" -eq 0 && -n "$slack_message_ts" ]]; then
    slack_thread_ts="$slack_message_ts"
    save_slack_thread_cache
    thread_id="$(slack_permalink_id_from_ts "$slack_thread_ts")"
    info "Slack thread id: $thread_id"
  fi
}

main() {
  setup_colors
  load_env
  parse_args "$@"
  check_dependencies
  resolve_slack_thread
  ensure_git_context
  ensure_glab_auth
  prompt_target_branch
  resolve_commit_message
  commit_staged_changes
  push_branch
  find_or_create_mr
  notify_slack

  info "done: $mr_url"
}

main "$@"
