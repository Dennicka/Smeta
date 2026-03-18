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
runtime_log="$log_dir/runtime.log"

if [[ ! -f "$exe_path" ]]; then
  echo "ERROR: не найден исполняемый файл: $exe_path"
  echo "Сначала соберите приложение: ./Scripts/macos_build.sh"
  exit 1
fi

echo "==> Smoke checks"
echo "1) Бандл найден: $app_path"
echo "2) Исполняемый файл найден: $exe_path"

echo "==> Запуск приложения на 8 секунд"
"$exe_path" >"$runtime_log" 2>&1 &
app_pid=$!

sleep 8

if ! kill -0 "$app_pid" 2>/dev/null; then
  echo "ERROR: процесс завершился раньше ожидаемого времени."
  echo "Смотрите лог: $repo_root/$runtime_log"
  exit 1
fi

kill "$app_pid" 2>/dev/null || true
wait "$app_pid" 2>/dev/null || true

echo "==> PASS: приложение стартует (smoke)"
echo "Runtime log: $repo_root/$runtime_log"
