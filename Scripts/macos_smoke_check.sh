#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: macos_smoke_check.sh нужно запускать только на macOS."
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

app_path="${1:-release/Smeta.app}"
exe_path="$app_path/Contents/MacOS/SmetaApp"
log_dir="release/smoke-logs"
mkdir -p "$log_dir"
operational_log="$log_dir/runtime-operational.log"
controlled_failure_log="$log_dir/runtime-controlled-failure.log"
negative_log="$log_dir/runtime-negative.log"
driver_log="$log_dir/runtime-driver.log"
db_name="smeta-runtime-smoke.sqlite"
db_path="$HOME/Library/Application Support/Smeta/$db_name"
driver_script="Scripts/ui_smoke_driver.swift"

if [[ ! -f "$exe_path" ]]; then
  echo "ERROR: не найден исполняемый файл: $exe_path"
  echo "Сначала соберите приложение: ./Scripts/macos_build.sh"
  exit 1
fi

rm -f "$operational_log" "$controlled_failure_log" "$negative_log" "$driver_log" "$db_path"

echo "==> Canonical runtime smoke checks"
echo "1) Bundle found: $app_path"
echo "2) Executable found: $exe_path"
echo "3) DB sandbox for smoke: $db_path"
echo "4) UI driver: $driver_script"

run_app() {
  local log_file="$1"
  shift 1
  SMETA_UI_SMOKE=1 \
  SMETA_DB_FILENAME="$db_name" \
  "$@" "$exe_path" >"$log_file" 2>&1 &
  app_pid=$!
}

run_driver() {
  local mode="$1"
  local log_file="$2"
  swift "$driver_script" "$mode" >"$log_file" 2>&1
}

handle_driver_blocked_if_any() {
  local log_file="$1"
  if grep -q "SMETA_UI_SMOKE verdict=BLOCKED classification=accessibility_permission_required" "$log_file"; then
    echo "BLOCKED: Accessibility permission is required for UI smoke automation."
    echo "Grant accessibility control to the shell/terminal process and rerun."
    cat "$log_file"
    stop_app
    exit 2
  fi
}

stop_app() {
  if [[ -n "${app_pid:-}" ]]; then
    kill "$app_pid" 2>/dev/null || true
    wait "$app_pid" 2>/dev/null || true
    app_pid=""
  fi
}

echo "==> [A+B+C+D+E+F] operational runtime probe"
run_app "$operational_log" env
if ! run_driver "operational" "$driver_log"; then
  handle_driver_blocked_if_any "$driver_log"
  echo "ERROR: operational probe failed."
  cat "$operational_log"
  cat "$driver_log"
  stop_app
  exit 1
fi
stop_app
if ! grep -q "SMETA_UI_SMOKE verdict=PASS classification=operational_runtime_success" "$driver_log"; then
  echo "ERROR: operational UI driver verdict missing"
  cat "$operational_log"
  cat "$driver_log"
  exit 1
fi

echo "==> [C/H] controlled startup failure must not be treated as operational PASS"
run_app "$controlled_failure_log" env SMETA_FORCE_BOOTSTRAP_FAILURE=1
if ! run_driver "controlled_failure" "$driver_log"; then
  handle_driver_blocked_if_any "$driver_log"
  echo "ERROR: controlled failure probe failed."
  cat "$controlled_failure_log"
  cat "$driver_log"
  stop_app
  exit 1
fi
stop_app
if ! grep -q "SMETA_UI_SMOKE verdict=PASS classification=controlled_launch_failure" "$driver_log"; then
  echo "ERROR: controlled failure UI driver verdict missing"
  cat "$controlled_failure_log"
  cat "$driver_log"
  exit 1
fi

echo "==> [G] negative check: dead interaction chain must FAIL"
set +e
run_app "$negative_log" env SMETA_SMOKE_DISABLE_CALCULATE=1
run_driver "operational" "$driver_log"
driver_negative_exit=$?
set -e
if [[ $driver_negative_exit -ne 0 ]]; then
  handle_driver_blocked_if_any "$driver_log"
fi
stop_app
if [[ $driver_negative_exit -eq 0 ]]; then
  echo "ERROR: negative probe unexpectedly passed."
  cat "$negative_log"
  cat "$driver_log"
  exit 1
fi
grep -q "SMETA_UI_SMOKE verdict=FAIL classification=operational" "$driver_log"

echo "==> PASS: canonical runtime smoke requires operational interactivity"
echo "Operational log: $repo_root/$operational_log"
echo "Controlled failure log: $repo_root/$controlled_failure_log"
echo "Negative log: $repo_root/$negative_log"
echo "Driver log: $repo_root/$driver_log"

rm -f "$db_path"
