#!/usr/bin/env bash
set -u

WARNINGS=0
FAILS=0
PASSES=0

if [[ -t 1 ]]; then
  BOLD="$(tput bold 2>/dev/null || true)"
  DIM="$(tput dim 2>/dev/null || true)"
  RED="$(tput setaf 1 2>/dev/null || true)"
  GREEN="$(tput setaf 2 2>/dev/null || true)"
  YELLOW="$(tput setaf 3 2>/dev/null || true)"
  RESET="$(tput sgr0 2>/dev/null || true)"
else
  BOLD=""
  DIM=""
  RED=""
  GREEN=""
  YELLOW=""
  RESET=""
fi

SYSTEM_PROFILER="/usr/sbin/system_profiler"
IOREG="/usr/sbin/ioreg"
PROFILES="/usr/bin/profiles"
PMSET="/usr/bin/pmset"
DISKUTIL="/usr/sbin/diskutil"
FDESETUP="/usr/bin/fdesetup"
CSRUTIL="/usr/bin/csrutil"
SPCTL="/usr/sbin/spctl"
NVRAM="/usr/sbin/nvram"
BPUTIL="/usr/bin/bputil"
SW_VERS="/usr/bin/sw_vers"
SCUTIL="/usr/sbin/scutil"
MOUNT="/sbin/mount"
DATE_BIN="/bin/date"
STAT="/usr/bin/stat"

usage() {
  cat <<'EOF'
Usage: used-macbook-check.sh [--history]

Run this on a MacBook before buying it second-hand. It prints a read-only
inspection report for identity, battery, charging state, MDM, Activation Lock
visibility, storage health, and hardware-test next steps.

Options:
  --history   Include recent power/charge events from pmset logs.
EOF
}

INCLUDE_HISTORY=0
for arg in "$@"; do
  case "$arg" in
    --history) INCLUDE_HISTORY=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

have() {
  command -v "$1" >/dev/null 2>&1
}

section() {
  printf "\n%s== %s ==%s\n" "$BOLD" "$1" "$RESET"
}

item() {
  printf "%-28s %s\n" "$1:" "${2:-unknown}"
}

log_status() {
  local status="$1"
  local color="$2"
  local message="$3"

  printf "%s%s%s: %s%s\n" "$color" "$BOLD" "$status" "$message" "$RESET"
  if [[ -n "${SUMMARY_FILE:-}" ]]; then
    printf "%s\t%s\n" "$status" "$message" >>"$SUMMARY_FILE"
  fi
}

warn() {
  WARNINGS=$((WARNINGS + 1))
  log_status "WARN" "$YELLOW" "$1"
}

fail() {
  FAILS=$((FAILS + 1))
  log_status "FAIL" "$RED" "$1"
}

ok() {
  PASSES=$((PASSES + 1))
  log_status "OK" "$GREEN" "$1"
}

print_summary_group() {
  local status="$1"
  local label="$2"
  local color="$3"
  local lines
  lines="$(awk -F'\t' -v status="$status" '$1 == status { print $2 }' "$SUMMARY_FILE")"
  if [[ -z "$lines" ]]; then
    return
  fi

  printf "\n%s%s%s%s\n" "$color" "$BOLD" "$label" "$RESET"
  printf "%s\n" "$lines" | sed 's/^/  - /'
}

capture() {
  local output_file="$1"
  shift
  "$@" >"$output_file" 2>&1 || true
}

field() {
  local file="$1"
  local key="$2"
  awk -F': *' -v key="$key" '
    {
      field_name = $1
      gsub(/^[[:space:]]+/, "", field_name)
      gsub(/[[:space:]]+$/, "", field_name)
    }
    field_name == key {
      print $2
      exit
    }
  ' "$file"
}

first_matching_field() {
  local file="$1"
  shift
  local key
  for key in "$@"; do
    local value
    value="$(field "$file" "$key")"
    if [[ -n "$value" ]]; then
      printf "%s\n" "$value"
      return
    fi
  done
}

ioreg_value() {
  local file="$1"
  local key="$2"
  awk -F'= ' -v key="\"$key\"" '
    index($1, key) {
      value = $2
      gsub(/^[[:space:]]+/, "", value)
      gsub(/[[:space:]]+$/, "", value)
      gsub(/^</, "", value)
      gsub(/>$/, "", value)
      gsub(/^"|"$/, "", value)
      print value
      exit
    }
  ' "$file"
}

print_command_if_available() {
  local title="$1"
  shift
  if have "$1"; then
    printf "\n%s%s%s\n" "$DIM" "$title" "$RESET"
    "$@" 2>&1 || true
  else
    warn "Missing command: $1"
  fi
}

check_command_path() {
  local label="$1"
  local path="$2"

  item "$label" "$path"
  if [[ ! -x "$path" ]]; then
    fail "Trusted command is missing or not executable: $path"
    return
  fi

  local owner_group_mode
  owner_group_mode="$("$STAT" -f '%Su:%Sg %Lp' "$path" 2>/dev/null || true)"
  item "$label owner/mode" "$owner_group_mode"
  case "$owner_group_mode" in
    root:wheel\ *|root:admin\ *) ok "$label is at the expected absolute system path." ;;
    *) warn "$label ownership is unusual; verify the OS was freshly erased." ;;
  esac
}

nvram_value() {
  local key="$1"
  awk -F'\t' -v key="$key" '$1 == key { print $2; exit }' "$NVRAM_FILE"
}

print_recent_charging_history() {
  if ! have "$PMSET"; then
    warn "pmset is not available."
    return
  fi

  printf "%sFiltered view: power source and charge percentage changes only. macOS maintenance sleep/darkwake noise is hidden.%s\n" "$DIM" "$RESET"

  local history_lines
  history_lines="$(
    "$PMSET" -g log 2>/dev/null |
      awk '/Assertions[[:space:]]+Summary-.*Using (AC|Batt|BATT)/ { print }' |
      sed -E 's/^([0-9-]+ [0-9:]+ [+-][0-9]+).*Using (AC|Batt|BATT)[( ]+Charge:? ?([0-9]+)\)?%?.*/\1  \2  \3%/' |
      awk '{ key = $4 " " $5 } key != previous_key { print; previous_key = key }' |
      tail -n 30
  )"

  if [[ -n "$history_lines" ]]; then
    printf "%-27s %-8s %s\n" "Time" "Source" "Charge"
    printf "%s\n" "$history_lines" | awk '{ printf "%s %s %s  %-8s %s\n", $1, $2, $3, $4, $5 }'
  else
    warn "No recent charging source changes found in pmset log."
  fi

  local low_battery_lines
  low_battery_lines="$(
    "$PMSET" -g log 2>/dev/null |
      awk 'tolower($0) ~ /low battery|sleep.*due to low|critical battery|emergency.*battery|battery.*emergency/ { print }' |
      tail -n 10
  )"

  if [[ -n "$low_battery_lines" ]]; then
    warn "Recent low-battery or emergency power events found; review the lines below."
    printf "%s\n" "$low_battery_lines"
  else
    ok "No recent low-battery emergency events found in pmset log."
  fi
}

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/used-macbook-check.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT
SUMMARY_FILE="$TMP_ROOT/summary.tsv"
: >"$SUMMARY_FILE"

HARDWARE_FILE="$TMP_ROOT/hardware.txt"
POWER_FILE="$TMP_ROOT/power.txt"
BATTERY_IOREG_FILE="$TMP_ROOT/battery-ioreg.txt"
PLATFORM_IOREG_FILE="$TMP_ROOT/platform-ioreg.txt"
STORAGE_FILE="$TMP_ROOT/storage.txt"
DISPLAY_FILE="$TMP_ROOT/display.txt"
IBRIDGE_FILE="$TMP_ROOT/ibridge.txt"
PROFILES_FILE="$TMP_ROOT/profiles.txt"
PROFILES_LIST_FILE="$TMP_ROOT/profiles-list.txt"
NVRAM_FILE="$TMP_ROOT/nvram.txt"
MOUNT_FILE="$TMP_ROOT/mount.txt"

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "This script is intended for macOS."
  exit 1
fi

if have "$SYSTEM_PROFILER"; then
  capture "$HARDWARE_FILE" "$SYSTEM_PROFILER" SPHardwareDataType
  capture "$POWER_FILE" "$SYSTEM_PROFILER" SPPowerDataType
  capture "$STORAGE_FILE" "$SYSTEM_PROFILER" SPStorageDataType SPNVMeDataType
  capture "$DISPLAY_FILE" "$SYSTEM_PROFILER" SPDisplaysDataType
  capture "$IBRIDGE_FILE" "$SYSTEM_PROFILER" SPiBridgeDataType
else
  fail "system_profiler is not available."
  exit 1
fi

if have "$IOREG"; then
  capture "$BATTERY_IOREG_FILE" "$IOREG" -r -c AppleSmartBattery
  capture "$PLATFORM_IOREG_FILE" "$IOREG" -rd1 -c IOPlatformExpertDevice
fi

if have "$PROFILES"; then
  capture "$PROFILES_FILE" "$PROFILES" status -type enrollment
  capture "$PROFILES_LIST_FILE" "$PROFILES" list
fi

if have "$NVRAM"; then
  capture "$NVRAM_FILE" "$NVRAM" -p
fi

if have "$MOUNT"; then
  capture "$MOUNT_FILE" "$MOUNT"
fi

section "Used MacBook Inspection"
item "Generated" "$("$DATE_BIN" '+%Y-%m-%d %H:%M:%S %Z')"
item "macOS" "$("$SW_VERS" -productName 2>/dev/null) $("$SW_VERS" -productVersion 2>/dev/null) ($("$SW_VERS" -buildVersion 2>/dev/null))"
item "Host" "$("$SCUTIL" --get ComputerName 2>/dev/null || hostname)"

section "Machine Identity"
MODEL_NAME="$(field "$HARDWARE_FILE" "Model Name")"
MODEL_ID="$(field "$HARDWARE_FILE" "Model Identifier")"
MODEL_NUMBER="$(field "$HARDWARE_FILE" "Model Number")"
CHIP_OR_CPU="$(first_matching_field "$HARDWARE_FILE" "Chip" "Processor Name")"
MEMORY="$(field "$HARDWARE_FILE" "Memory")"
SERIAL="$(first_matching_field "$HARDWARE_FILE" "Serial Number (system)" "Serial Number")"
ACTIVATION_LOCK="$(field "$HARDWARE_FILE" "Activation Lock Status")"

item "Model" "$MODEL_NAME"
item "Model Identifier" "$MODEL_ID"
item "Model Number" "$MODEL_NUMBER"
item "Chip/CPU" "$CHIP_OR_CPU"
item "Memory" "$MEMORY"
item "Serial" "$SERIAL"
item "Coverage URL" "https://checkcoverage.apple.com/"

if [[ -z "$SERIAL" ]]; then
  fail "Serial number is missing from System Information."
else
  ok "Compare this serial with the bottom case, box, invoice, and Apple Check Coverage."
fi

section "Command Integrity"
check_command_path "system_profiler" "$SYSTEM_PROFILER"
check_command_path "ioreg" "$IOREG"
check_command_path "profiles" "$PROFILES"
check_command_path "pmset" "$PMSET"
check_command_path "diskutil" "$DISKUTIL"
check_command_path "csrutil" "$CSRUTIL"
check_command_path "spctl" "$SPCTL"
check_command_path "nvram" "$NVRAM"
if have "$BPUTIL"; then
  check_command_path "bputil" "$BPUTIL"
fi

section "Deep Anti-Tamper Checks"
PLATFORM_SERIAL="$(ioreg_value "$PLATFORM_IOREG_FILE" "IOPlatformSerialNumber")"
PLATFORM_MODEL="$(ioreg_value "$PLATFORM_IOREG_FILE" "model")"
PLATFORM_UUID="$(ioreg_value "$PLATFORM_IOREG_FILE" "IOPlatformUUID")"
PLATFORM_TARGET="$(ioreg_value "$PLATFORM_IOREG_FILE" "target-sub-type")"

item "IORegistry Serial" "$PLATFORM_SERIAL"
item "IORegistry Model" "$PLATFORM_MODEL"
item "IORegistry UUID" "$PLATFORM_UUID"
item "IORegistry Target" "$PLATFORM_TARGET"

if [[ -n "$SERIAL" && -n "$PLATFORM_SERIAL" ]]; then
  if [[ "$SERIAL" == "$PLATFORM_SERIAL" ]]; then
    ok "System Information serial matches IORegistry serial."
  else
    fail "Serial mismatch: System Information=$SERIAL, IORegistry=$PLATFORM_SERIAL"
  fi
else
  warn "Could not cross-check serial between System Information and IORegistry."
fi

if [[ -n "$MODEL_ID" && -n "$PLATFORM_MODEL" ]]; then
  if [[ "$MODEL_ID" == "$PLATFORM_MODEL" ]]; then
    ok "System Information model identifier matches IORegistry model."
  else
    fail "Model mismatch: System Information=$MODEL_ID, IORegistry=$PLATFORM_MODEL"
  fi
else
  warn "Could not cross-check model between System Information and IORegistry."
fi

SIP_STATUS="$("$CSRUTIL" status 2>/dev/null || true)"
AUTH_ROOT_STATUS="$("$CSRUTIL" authenticated-root status 2>/dev/null || true)"
GATEKEEPER_STATUS="$("$SPCTL" --status 2>/dev/null || true)"
ROOT_MOUNT="$(awk '$3 == "/" { print; exit }' "$MOUNT_FILE")"
BOOT_ARGS="$(nvram_value "boot-args")"
CSR_ACTIVE_CONFIG="$(nvram_value "csr-active-config")"
RECOVERY_BOOT_MODE="$(nvram_value "recovery-boot-mode")"

item "SIP" "$SIP_STATUS"
case "$SIP_STATUS" in
  *enabled*) ok "System Integrity Protection is enabled." ;;
  *disabled*) fail "System Integrity Protection is disabled." ;;
  *) warn "Could not clearly verify System Integrity Protection status." ;;
esac

item "Authenticated Root" "$AUTH_ROOT_STATUS"
case "$AUTH_ROOT_STATUS" in
  *enabled*) ok "Authenticated root is enabled." ;;
  *disabled*) fail "Authenticated root is disabled; system volume may be modified." ;;
  *) warn "Could not verify authenticated root from this running OS." ;;
esac

item "Root Mount" "$ROOT_MOUNT"
if [[ "$ROOT_MOUNT" == *"sealed"* && "$ROOT_MOUNT" == *"read-only"* ]]; then
  ok "Root system volume is sealed and read-only."
elif [[ -n "$ROOT_MOUNT" ]]; then
  warn "Root system volume is not clearly sealed/read-only. On modern macOS, verify after erase/reinstall."
else
  warn "Could not inspect root system volume mount flags."
fi

item "Gatekeeper" "$GATEKEEPER_STATUS"
case "$GATEKEEPER_STATUS" in
  *enabled*) ok "Gatekeeper assessments are enabled." ;;
  *disabled*) warn "Gatekeeper assessments are disabled." ;;
  *) warn "Could not clearly verify Gatekeeper status." ;;
esac

if have "$BPUTIL"; then
  BPUTIL_STATUS="$("$BPUTIL" -d 2>&1 || true)"
  SECURE_BOOT_LINE="$(printf "%s\n" "$BPUTIL_STATUS" | awk '/Secure Boot|Security Mode|Security Policy|LocalPolicy/ { print; exit }')"
  item "Secure Boot Policy" "${SECURE_BOOT_LINE:-unknown}"
  case "$BPUTIL_STATUS" in
    *"requires running as root"*)
      warn "Secure Boot policy requires root to inspect. Run: sudo /usr/bin/bputil -d"
      ;;
    *"Full Security"*|*"full security"*)
      ok "Secure Boot appears to be Full Security."
      ;;
    *"Reduced Security"*|*"Permissive Security"*|*"No Security"*|*"reduced security"*|*"permissive security"*|*"no security"*)
      fail "Secure Boot is not Full Security. Verify why before buying."
      ;;
    *)
      warn "Could not clearly parse Secure Boot policy from bputil."
      ;;
  esac
fi

item "NVRAM boot-args" "${BOOT_ARGS:-not set}"
if [[ -n "$BOOT_ARGS" ]]; then
  if [[ "$BOOT_ARGS" == *"amfi_get_out_of_my_way"* || "$BOOT_ARGS" == *"keepsyms"* || "$BOOT_ARGS" == *"debug"* ]]; then
    fail "Suspicious NVRAM boot-args are set: $BOOT_ARGS"
  else
    warn "NVRAM boot-args are set. Verify why before buying."
  fi
else
  ok "NVRAM boot-args are not set."
fi

item "NVRAM csr-active-config" "${CSR_ACTIVE_CONFIG:-not set}"
if [[ -n "$CSR_ACTIVE_CONFIG" ]]; then
  fail "NVRAM csr-active-config is set; SIP may have been altered."
else
  ok "NVRAM csr-active-config is not set."
fi

item "NVRAM recovery-boot-mode" "${RECOVERY_BOOT_MODE:-not set}"
if [[ -n "$RECOVERY_BOOT_MODE" ]]; then
  warn "NVRAM recovery-boot-mode is set; reboot normally and re-check."
fi

section "Activation Lock"
if [[ -n "$ACTIVATION_LOCK" ]]; then
  item "Activation Lock" "$ACTIVATION_LOCK"
  case "$ACTIVATION_LOCK" in
    *Enabled*|*enabled*)
      fail "Activation Lock appears enabled. Do not buy until the seller removes it and the Mac activates cleanly."
      ;;
    *Disabled*|*disabled*)
      ok "Activation Lock appears disabled in System Information."
      ;;
    *)
      warn "Activation Lock status is present but not clearly enabled/disabled."
      ;;
  esac
else
  warn "Activation Lock status is not exposed by this macOS/model. Verify after erase/reactivation before paying."
fi

section "Battery And Charging"
BATTERY_INSTALLED="$(field "$POWER_FILE" "Battery Installed")"
CYCLE_COUNT="$(field "$POWER_FILE" "Cycle Count")"
BATTERY_CONDITION="$(field "$POWER_FILE" "Condition")"
MAX_CAPACITY="$(field "$POWER_FILE" "Maximum Capacity")"
FULL_CHARGE_MAH="$(field "$POWER_FILE" "Full Charge Capacity (mAh)")"
BATTERY_SERIAL="$(ioreg_value "$BATTERY_IOREG_FILE" "Serial")"
BATTERY_MANUFACTURER="$(ioreg_value "$BATTERY_IOREG_FILE" "Manufacturer")"
BATTERY_DEVICE="$(ioreg_value "$BATTERY_IOREG_FILE" "DeviceName")"
DESIGN_CAPACITY="$(ioreg_value "$BATTERY_IOREG_FILE" "DesignCapacity")"
MAX_CAPACITY_RAW="$(ioreg_value "$BATTERY_IOREG_FILE" "MaxCapacity")"
CURRENT_CAPACITY_RAW="$(ioreg_value "$BATTERY_IOREG_FILE" "CurrentCapacity")"
IS_CHARGING="$(ioreg_value "$BATTERY_IOREG_FILE" "IsCharging")"
EXTERNAL_CONNECTED="$(ioreg_value "$BATTERY_IOREG_FILE" "ExternalConnected")"

item "Battery Installed" "$BATTERY_INSTALLED"
item "Cycle Count" "$CYCLE_COUNT"
item "Condition" "$BATTERY_CONDITION"
item "Maximum Capacity" "$MAX_CAPACITY"
item "Full Charge Capacity" "$FULL_CHARGE_MAH"
item "Design Capacity" "$DESIGN_CAPACITY"
item "Raw Max Capacity" "$MAX_CAPACITY_RAW"
item "Raw Current Capacity" "$CURRENT_CAPACITY_RAW"
item "Charging Now" "$IS_CHARGING"
item "Power Connected" "$EXTERNAL_CONNECTED"
item "Battery Manufacturer" "$BATTERY_MANUFACTURER"
item "Battery Device" "$BATTERY_DEVICE"
item "Battery Serial" "$BATTERY_SERIAL"

if [[ -n "$CYCLE_COUNT" && "$CYCLE_COUNT" =~ ^[0-9]+$ ]]; then
  if (( CYCLE_COUNT >= 1000 )); then
    fail "Battery cycle count is at or above 1000. Price it as needing battery service."
  elif (( CYCLE_COUNT >= 800 )); then
    warn "Battery cycle count is high. Expect reduced runtime."
  elif (( CYCLE_COUNT >= 500 )); then
    warn "Battery cycle count is moderate. Check runtime carefully."
  else
    ok "Battery cycle count is not high by modern MacBook standards."
  fi
else
  warn "Could not parse battery cycle count."
fi

if [[ -n "$BATTERY_CONDITION" ]]; then
  case "$BATTERY_CONDITION" in
    *Normal*|*normal*) ok "Battery condition reports Normal." ;;
    *) fail "Battery condition is not Normal: $BATTERY_CONDITION" ;;
  esac
else
  warn "Could not parse battery condition."
fi

if [[ -n "$MAX_CAPACITY" ]]; then
  CAPACITY_NUMBER="${MAX_CAPACITY%%%}"
  if [[ "$CAPACITY_NUMBER" =~ ^[0-9]+$ ]]; then
    if (( CAPACITY_NUMBER < 80 )); then
      fail "Battery maximum capacity is below 80%."
    elif (( CAPACITY_NUMBER < 90 )); then
      warn "Battery maximum capacity is below 90%."
    else
      ok "Battery maximum capacity is healthy."
    fi
  fi
fi

if have "$PMSET"; then
  print_command_if_available "Current battery estimate from pmset" "$PMSET" -g batt
else
  warn "pmset is not available."
fi

section "MDM And Configuration Profiles"
if [[ -s "$PROFILES_FILE" ]]; then
  cat "$PROFILES_FILE"
  if grep -Eqi 'MDM enrollment:[[:space:]]*Yes|Enrolled via DEP:[[:space:]]*Yes|Enrolled via Automated Device Enrollment:[[:space:]]*Yes' "$PROFILES_FILE"; then
    fail "This Mac appears enrolled in MDM/DEP. Do not buy unless the organization releases it."
  else
    ok "profiles status does not report MDM/DEP enrollment."
  fi
else
  warn "Could not read profiles enrollment status."
fi

if [[ -s "$PROFILES_LIST_FILE" ]] && grep -Eqi 'configuration profiles|attribute|profileIdentifier|com\.' "$PROFILES_LIST_FILE"; then
  warn "Configuration profiles may be installed. Review the profiles list before buying."
  sed -n '1,80p' "$PROFILES_LIST_FILE"
else
  ok "No obvious configuration profiles listed."
fi

section "Storage"
ROOT_DISK="$("$DISKUTIL" list internal physical 2>/dev/null | awk '/^\/dev\/disk/ { sub("/dev/", "", $1); print $1; exit }')"
if [[ -z "$ROOT_DISK" ]]; then
  ROOT_DISK="$("$DISKUTIL" info / 2>/dev/null | awk -F': *' '/Part of Whole/ { print $2; exit }')"
fi

if [[ -n "$ROOT_DISK" ]]; then
  DISK_INFO_FILE="$TMP_ROOT/disk-info.txt"
  capture "$DISK_INFO_FILE" "$DISKUTIL" info "$ROOT_DISK"
  item "Internal Disk" "$ROOT_DISK"
  item "Device / Media Name" "$(field "$DISK_INFO_FILE" "Device / Media Name")"
  item "Disk Size" "$(field "$DISK_INFO_FILE" "Disk Size")"
  SMART_STATUS="$(field "$DISK_INFO_FILE" "SMART Status")"
  item "SMART Status" "$SMART_STATUS"
  case "$SMART_STATUS" in
    Verified) ok "SMART status is Verified." ;;
    "") warn "SMART status not exposed for this internal storage." ;;
    *) fail "SMART status is not Verified: $SMART_STATUS" ;;
  esac
else
  warn "Could not identify internal physical disk."
  if [[ -s "$STORAGE_FILE" ]]; then
    printf "\n%s%s%s\n" "$DIM" "Storage summary from system_profiler" "$RESET"
    grep -E '^[[:space:]]+([A-Z0-9 ].*:|TRIM Support|Model|Revision|Serial Number|Detachable Drive|Capacity|Medium Type|SMART Status):' "$STORAGE_FILE" || true
  fi
fi

if have "$DISKUTIL"; then
  print_command_if_available "Internal disk layout" "$DISKUTIL" list internal
else
  warn "diskutil is not available."
fi

section "Display"
grep -E '^[[:space:]]+(Chipset Model|Type|Resolution|Main Display|Mirror|Online|Automatically Adjust Brightness):' "$DISPLAY_FILE" || warn "Could not summarize display information."

section "Security And Ownership"
if have "$FDESETUP"; then
  FDE_STATUS="$("$FDESETUP" status 2>/dev/null || true)"
  item "FileVault" "$FDE_STATUS"
fi
if have "$CSRUTIL"; then
  item "SIP" "$("$CSRUTIL" status 2>/dev/null || true)"
fi
if [[ -s "$IBRIDGE_FILE" ]]; then
  grep -E '^[[:space:]]+(Model Name|Model Identifier|Firmware Version|Boot ROM Version|Secure Boot|External Boot):' "$IBRIDGE_FILE" || true
fi

section "Replacement Clues"
cat <<'EOF'
Software cannot reliably prove whether the battery, screen, keyboard, logic board,
or top case was replaced. Treat these as clues only:
- Battery cycle count very low on an old Mac can be normal after battery service; ask for invoice.
- Serial/model in System Information should match the bottom case, box, and invoice.
- Activation Lock and MDM must be clean after erase and reactivation, not only before erase.
- Run Apple Diagnostics in front of the seller and keep the result code.
EOF

section "Apple Diagnostics Steps"
cat <<'EOF'
Apple silicon:
  Shut down -> hold power/Touch ID until startup options appear -> press Command-D.

Intel:
  Shut down -> power on and immediately hold D. If that fails, use Option-D.

Disconnect external devices except power before running diagnostics.
EOF

if (( INCLUDE_HISTORY == 1 )); then
  section "Recent Charging History"
  print_recent_charging_history
fi

section "Summary"
printf "%s%sQuick Facts%s\n" "$BOLD" "$DIM" "$RESET"
item "Model" "${MODEL_NAME:-unknown} ${MODEL_ID:-unknown}"
item "Serial" "${SERIAL:-unknown}"
item "Battery" "cycle=${CYCLE_COUNT:-unknown}, condition=${BATTERY_CONDITION:-unknown}, max=${MAX_CAPACITY:-unknown}"
item "MDM/DEP" "$(awk 'NF { line = line (line ? "; " : "") $0 } END { print line }' "$PROFILES_FILE" 2>/dev/null)"
if [[ -n "${ACTIVATION_LOCK:-}" ]]; then
  item "Activation Lock" "$ACTIVATION_LOCK"
else
  item "Activation Lock" "not exposed; verify after erase/reactivation"
fi

printf "%s%sPASS%s: %d  %s%sWARN%s: %d  %s%sFAIL%s: %d\n" \
  "$GREEN" "$BOLD" "$RESET" "$PASSES" \
  "$YELLOW" "$BOLD" "$RESET" "$WARNINGS" \
  "$RED" "$BOLD" "$RESET" "$FAILS"

print_summary_group "FAIL" "Failures" "$RED"
print_summary_group "WARN" "Warnings" "$YELLOW"
print_summary_group "OK" "Passed Checks" "$GREEN"

section "Verdict"
if (( FAILS > 0 )); then
  printf "%s%sResult: DO NOT BUY YET (%d fail, %d warning)%s\n" "$RED" "$BOLD" "$FAILS" "$WARNINGS" "$RESET"
  exit 1
fi
if (( WARNINGS > 0 )); then
  printf "%s%sResult: CHECK MANUALLY / NEGOTIATE (%d warning)%s\n" "$YELLOW" "$BOLD" "$WARNINGS" "$RESET"
  exit 0
fi
printf "%s%sResult: BASIC SOFTWARE CHECKS LOOK CLEAN%s\n" "$GREEN" "$BOLD" "$RESET"
