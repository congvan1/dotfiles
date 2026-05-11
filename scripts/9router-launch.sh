#!/usr/bin/env bash
set -euo pipefail

VERSION="0.4.29"
LABEL="dev.decolua.9router"
DEFAULT_PORT="20128"
DEFAULT_HOST="localhost"

HOME_DIR="${HOME:-/Users/van}"
ENV_FILE="${HOME_DIR}/.config/9router/env"
NPM_PREFIX="${HOME_DIR}/.npm-global"
PACKAGE_DIR="${NPM_PREFIX}/lib/node_modules/9router"
APP_DIR="${PACKAGE_DIR}/app"
NODE="/opt/homebrew/bin/node"
NPM="/opt/homebrew/bin/npm"

COMBO_NAME="${COMBO_NAME:-openclaw-free}"
OPENCLAW_MODELS=(
  "kr/claude-sonnet-4.5"
  "kr/glm-5"
  "kr/MiniMax-M2.5"
)

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok() { printf '\033[1;32mPASS\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33mWARN\033[0m %s\n' "$*" >&2; }
fail() { printf '\033[1;31mFAIL\033[0m %s\n' "$*" >&2; }
die() { fail "$*"; exit 1; }

usage() {
  cat <<EOF
9router local service helper

Usage:
  $0 [command] [options]

Commands:
  start              Start the launchd service, or report the running router. Default.
  serve              Run the 9router server in the foreground. Used by launchd.
  foreground         Run in the foreground, but fail fast if the port is already used.
  restart            Restart the launchd service.
  status             Show health, endpoint, launchd state, and listener.
  openclaw-free      Create/update the free OpenClaw combo and OpenClaw config.
  dashboard          Print the dashboard URL.
  logs               Tail launchd logs.
  help               Show this help.

Options:
  -h, --help         Show this help.
  -p, --port PORT    Override port. Default: ${DEFAULT_PORT}
  -H, --host HOST    Override host. Default: ${DEFAULT_HOST}
  --base-url URL     Override local API URL, for example http://localhost:20128.

Environment:
  ROUTER_PASSWORD    Dashboard password for openclaw-free setup. Default: 123456.
  COMBO_NAME         Combo name for openclaw-free setup. Default: openclaw-free.
  DATA_DIR           9router data dir. Default: ~/.9router.

Examples:
  $0
  $0 status
  $0 restart
  $0 openclaw-free
  $0 foreground --port 20129
EOF
}

load_env() {
  mkdir -p "${HOME_DIR}/.9router/logs" "${HOME_DIR}/.config/9router" "${NPM_PREFIX}"

  export HOME="${HOME_DIR}"
  export PATH="${NPM_PREFIX}/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  export npm_config_prefix="${NPM_PREFIX}"

  local env_data_dir="${DATA_DIR:-}"
  local env_port="${PORT:-}"
  local env_hostname=""
  local env_base_url=""
  local env_next_public_base_url=""
  local env_cloud_url=""
  local env_next_public_cloud_url=""

  unset HOSTNAME BASE_URL NEXT_PUBLIC_BASE_URL CLOUD_URL NEXT_PUBLIC_CLOUD_URL

  if [[ -f "${ENV_FILE}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${ENV_FILE}"
    set +a
    env_data_dir="${DATA_DIR:-${env_data_dir}}"
    env_port="${PORT:-${env_port}}"
    env_hostname="${HOSTNAME:-}"
    env_base_url="${BASE_URL:-}"
    env_next_public_base_url="${NEXT_PUBLIC_BASE_URL:-}"
    env_cloud_url="${CLOUD_URL:-}"
    env_next_public_cloud_url="${NEXT_PUBLIC_CLOUD_URL:-}"
  fi

  export DATA_DIR="${env_data_dir:-${HOME_DIR}/.9router}"
  export PORT="${ROUTER_PORT:-${env_port:-${DEFAULT_PORT}}}"
  export HOSTNAME="${ROUTER_HOST:-${env_hostname:-${DEFAULT_HOST}}}"
  export BASE_URL="${ROUTER_BASE_URL:-${env_base_url:-http://${HOSTNAME}:${PORT}}}"
  export NEXT_PUBLIC_BASE_URL="${env_next_public_base_url:-${BASE_URL}}"
  export CLOUD_URL="${env_cloud_url:-https://9router.com}"
  export NEXT_PUBLIC_CLOUD_URL="${env_next_public_cloud_url:-https://9router.com}"
  export NEXT_TELEMETRY_DISABLED="${NEXT_TELEMETRY_DISABLED:-1}"
}

api_url() {
  printf '%s\n' "${ROUTER_BASE_URL:-${BASE_URL:-http://${HOSTNAME}:${PORT}}}" | sed 's:/*$::'
}

launchd_domain() {
  printf 'gui/%s/%s\n' "$(id -u)" "${LABEL}"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

ensure_node() {
  [[ -x "${NODE}" ]] || die "${NODE} not found; install Homebrew node first"
}

ensure_package() {
  if [[ -f "${APP_DIR}/server.js" ]]; then
    return 0
  fi

  [[ -x "${NPM}" ]] || die "${NPM} not found; install Homebrew node first"
  "${NPM}" install -g "9router@${VERSION}" --no-audit --no-fund
}

ensure_runtime() {
  ensure_node
  ensure_package

  local runtime_node_modules="${DATA_DIR}/runtime/node_modules"
  local app_node_modules="${APP_DIR}/node_modules"
  export NODE_PATH="${runtime_node_modules}:${app_node_modules}:${NODE_PATH:-}"

  if [[ -f "${PACKAGE_DIR}/hooks/sqliteRuntime.js" ]]; then
    "${NODE}" -e "require('${PACKAGE_DIR}/hooks/sqliteRuntime').ensureSqliteRuntime({ silent: true })" || true
  fi
}

health_ok() {
  curl -fsS "$(api_url)/api/health" >/dev/null 2>&1
}

wait_for_router() {
  local attempts="${1:-30}"
  local i

  for ((i = 1; i <= attempts; i++)); do
    if health_ok; then
      return 0
    fi
    sleep 1
  done

  return 1
}

serve_foreground() {
  if [[ -t 1 ]] && health_ok; then
    die "9router is already running at $(api_url). Use '$0 status' or '$0 restart'."
  fi
  ensure_runtime
  cd "${APP_DIR}"
  exec "${NODE}" --max-old-space-size=6144 "${APP_DIR}/server.js"
}

run_foreground() {
  if health_ok; then
    die "9router is already running at $(api_url). Use '$0 status' or '$0 restart'."
  fi
  serve_foreground
}

start_service() {
  if health_ok; then
    ok "9router is already running at $(api_url)"
    return 0
  fi

  local domain
  domain="$(launchd_domain)"

  if launchctl print "${domain}" >/dev/null 2>&1; then
    warn "Starting launchd service ${domain}"
    launchctl kickstart -k "${domain}" >/dev/null 2>&1 || true
    wait_for_router 45 || die "9router launchd service did not become healthy at $(api_url)"
    ok "9router launchd service is running"
    return 0
  fi

  warn "launchd service is not loaded; starting a background server"
  nohup "$0" serve >"${HOME_DIR}/.9router/logs/manual.out.log" 2>"${HOME_DIR}/.9router/logs/manual.err.log" &
  wait_for_router 60 || die "9router did not start at $(api_url)"
  ok "9router is running in the background"
}

restart_service() {
  local domain
  domain="$(launchd_domain)"

  if launchctl print "${domain}" >/dev/null 2>&1; then
    launchctl kickstart -k "${domain}" >/dev/null 2>&1 || true
    wait_for_router 45 || die "9router did not become healthy after restart"
    ok "9router restarted at $(api_url)"
    return 0
  fi

  warn "launchd service is not loaded; starting instead"
  start_service
}

show_status() {
  bold "9router Status"

  if health_ok; then
    ok "Health OK at $(api_url)"
  else
    fail "Health check failed at $(api_url)"
  fi

  local domain
  domain="$(launchd_domain)"
  if launchctl print "${domain}" >/dev/null 2>&1; then
    ok "launchd service loaded: ${domain}"
    launchctl print "${domain}" | awk '/^\t(state|pid|runs|last exit code|job state) =/ { print "  " $0 }'
  else
    warn "launchd service is not loaded: ${domain}"
  fi

  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"${PORT}" -sTCP:LISTEN 2>/dev/null || true
  fi
}

tail_logs() {
  local out="${HOME_DIR}/.9router/logs/launchd.out.log"
  local err="${HOME_DIR}/.9router/logs/launchd.err.log"
  bold "launchd stdout: ${out}"
  tail -n 80 "${out}" 2>/dev/null || true
  bold "launchd stderr: ${err}"
  tail -n 80 "${err}" 2>/dev/null || true
}

cookie_jar=""

cleanup_cookie() {
  if [[ -n "${cookie_jar}" ]]; then
    rm -f "${cookie_jar}"
  fi
}

api() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local args=(-fsS -X "${method}" -H "Content-Type: application/json")

  if [[ -n "${cookie_jar}" ]]; then
    args+=(-b "${cookie_jar}" -c "${cookie_jar}")
  fi

  if [[ -n "${body}" ]]; then
    args+=(-d "${body}")
  fi

  curl "${args[@]}" "$(api_url)${path}"
}

login_dashboard() {
  cookie_jar="$(mktemp -t 9router-openclaw-free.XXXXXX)"
  trap cleanup_cookie EXIT

  if api GET /api/keys >/dev/null 2>&1; then
    ok "Dashboard API is already authenticated"
    return 0
  fi

  local password="${ROUTER_PASSWORD:-123456}"
  local payload
  payload="$(jq -nc --arg password "${password}" '{password:$password}')"

  if api POST /api/auth/login "${payload}" >/dev/null; then
    ok "Logged in to 9router dashboard API"
    return 0
  fi

  die "Could not log in. If you changed the dashboard password, run: ROUTER_PASSWORD='your-password' $0 openclaw-free"
}

ensure_api_key() {
  local keys key created

  keys="$(api GET /api/keys)" || die "Could not read 9router API keys"
  key="$(jq -r '.keys[]? | select(.isActive != false) | .key' <<<"${keys}" | head -n 1)"

  if [[ -z "${key}" || "${key}" == "null" ]]; then
    created="$(api POST /api/keys '{"name":"OpenClaw Local"}')" || die "Could not create a 9router API key"
    key="$(jq -r '.key // empty' <<<"${created}")"
    ok "Created 9router API key for OpenClaw"
  else
    ok "Reusing existing 9router API key"
  fi

  [[ -n "${key}" && "${key}" != "null" ]] || die "Could not read or create a 9router API key"
  printf '%s\n' "${key}"
}

ensure_openclaw_combo() {
  local combos combo_id payload models_json

  combos="$(api GET /api/combos)" || die "Could not read 9router combos"
  combo_id="$(jq -r --arg name "${COMBO_NAME}" '.combos[]? | select(.name == $name) | .id' <<<"${combos}" | head -n 1)"
  models_json="$(printf '%s\n' "${OPENCLAW_MODELS[@]}" | jq -R . | jq -s .)"
  payload="$(jq -nc --arg name "${COMBO_NAME}" --argjson models "${models_json}" '{name:$name,kind:"fallback",models:$models}')"

  if [[ -n "${combo_id}" && "${combo_id}" != "null" ]]; then
    api PUT "/api/combos/${combo_id}" "${payload}" >/dev/null
    ok "Updated combo ${COMBO_NAME}"
  else
    api POST /api/combos "${payload}" >/dev/null
    ok "Created combo ${COMBO_NAME}"
  fi
}

apply_openclaw() {
  local api_key="$1"
  local payload
  local v1_url="$(api_url)/v1"

  payload="$(jq -nc \
    --arg baseUrl "${v1_url}" \
    --arg apiKey "${api_key}" \
    --arg model "${COMBO_NAME}" \
    '{baseUrl:$baseUrl,apiKey:$apiKey,model:$model}')"

  api POST /api/cli-tools/openclaw-settings "${payload}" >/dev/null
  ok "Applied OpenClaw settings to ${HOME_DIR}/.openclaw/openclaw.json"
}

check_kiro() {
  if api GET /v1/models | jq -e --arg model "${OPENCLAW_MODELS[0]}" '.data[]? | select(.id == $model)' >/dev/null 2>&1; then
    ok "Kiro models are visible in 9router"
  else
    warn "Kiro is not connected yet. Open $(api_url)/dashboard and connect Providers -> Kiro AI."
  fi
}

setup_openclaw_free() {
  need_cmd curl
  need_cmd jq
  need_cmd launchctl

  bold "9router OpenClaw Free Setup"
  start_service
  login_dashboard

  local api_key
  api_key="$(ensure_api_key)"
  ensure_openclaw_combo
  apply_openclaw "${api_key}"
  check_kiro

  bold "Summary"
  printf 'Combo:     %s\n' "${COMBO_NAME}"
  printf 'Fallback:  %s -> %s -> %s\n' "${OPENCLAW_MODELS[0]}" "${OPENCLAW_MODELS[1]}" "${OPENCLAW_MODELS[2]}"
  printf 'Endpoint:  %s/v1\n' "$(api_url)"
  printf 'OpenClaw:  %s/.openclaw/openclaw.json\n' "${HOME_DIR}"
  printf 'Dashboard: %s/dashboard\n' "$(api_url)"
}

parse_args() {
  COMMAND="start"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help|help)
        usage
        exit 0
        ;;
      -p|--port)
        [[ $# -ge 2 ]] || die "--port requires a value"
        export ROUTER_PORT="$2"
        shift 2
        ;;
      -H|--host)
        [[ $# -ge 2 ]] || die "--host requires a value"
        export ROUTER_HOST="$2"
        shift 2
        ;;
      --base-url)
        [[ $# -ge 2 ]] || die "--base-url requires a value"
        export ROUTER_BASE_URL="$2"
        shift 2
        ;;
      start|serve|foreground|restart|status|openclaw-free|dashboard|logs)
        COMMAND="$1"
        shift
        ;;
      *)
        die "Unknown argument: $1. Run '$0 --help'."
        ;;
    esac
  done
}

main() {
  parse_args "$@"
  load_env

  case "${COMMAND}" in
    start) start_service ;;
    serve) serve_foreground ;;
    foreground) run_foreground ;;
    restart) restart_service ;;
    status) show_status ;;
    openclaw-free) setup_openclaw_free ;;
    dashboard) printf '%s/dashboard\n' "$(api_url)" ;;
    logs) tail_logs ;;
    *) die "Unknown command: ${COMMAND}" ;;
  esac
}

main "$@"
