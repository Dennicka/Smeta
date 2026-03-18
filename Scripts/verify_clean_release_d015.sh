#!/usr/bin/env bash
set -u

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root" || exit 2

# Root-level entries allowed in a clean release/archive snapshot.
readonly ALLOWLIST_ROOT=(
  "ACCEPTANCE_CHECKLIST.md"
  "ACCEPTANCE_RULES.md"
  "ADMIN_GUIDE.md"
  "AGENT_CONTEXT.md"
  "BACKUP_RESTORE.md"
  "CURRENT_STATE.md"
  "DATA_PORTABILITY.md"
  "DEFECT_BACKLOG.md"
  "DEMO_RESET.md"
  "DEMO_WALKTHROUGH.md"
  "EVIDENCE"
  "FINAL_VERIFICATION_REPORT.md"
  "IMPORT_EXPORT.md"
  "INSTALL.md"
  "INTERNAL_REPORTS.md"
  "KNOWN_LIMITATIONS.md"
  "NEXT_TASK.md"
  "Package.swift"
  "PURCHASES.md"
  "README.md"
  "RELEASE_NOTES.md"
  "Scripts"
  "Sources"
  "Tests"
  "USER_GUIDE.md"
)

# Noise directories that must not exist anywhere in repo tree.
readonly DENY_DIR_SEGMENTS=(
  ".build"
  "build"
  "Build"
  "DerivedData"
  "output"
  "tmp"
  "temp"
  "cache"
  ".cache"
)

# Noise files that must not exist anywhere in repo tree.
readonly DENY_FILE_GLOBS=(
  "*.log"
  "*.tmp"
  "*.temp"
  "*.pid"
  "*.sqlite-wal"
  "*.sqlite-shm"
  "*.db-wal"
  "*.db-shm"
  ".DS_Store"
)

is_deny_segment_match() {
  local rel="$1"
  local segment

  for segment in "${DENY_DIR_SEGMENTS[@]}"; do
    if [[ "$rel" == "$segment" || "$rel" == "$segment"/* || "$rel" == */"$segment" || "$rel" == */"$segment"/* ]]; then
      printf "%s" "$segment"
      return 0
    fi
  done

  return 1
}

is_deny_file_match() {
  local rel="$1"
  local glob

  for glob in "${DENY_FILE_GLOBS[@]}"; do
    if [[ "$rel" == $glob || "$rel" == */$glob ]]; then
      printf "%s" "$glob"
      return 0
    fi
  done

  return 1
}

printf 'D-015 clean-release verification\n'
printf 'Repository root: %s\n\n' "$repo_root"

violations=()

# 1) Root allowlist check (ignore local VCS metadata).
while IFS= read -r entry; do
  name="${entry#./}"
  [[ "$name" == ".git" ]] && continue

  is_allowed=0
  for allowed in "${ALLOWLIST_ROOT[@]}"; do
    if [[ "$name" == "$allowed" ]]; then
      is_allowed=1
      break
    fi
  done

  if [[ $is_allowed -eq 0 ]]; then
    violations+=("ALLOWLIST_ROOT: unexpected top-level entry '$name'")
  fi
done < <(find . -mindepth 1 -maxdepth 1 -printf '%p\n' | sort)

# 2) Recursive denylist check.
while IFS= read -r path; do
  rel="${path#./}"
  [[ "$rel" == .git || "$rel" == .git/* ]] && continue

  if matched_segment="$(is_deny_segment_match "$rel")"; then
    violations+=("DENYLIST_DIR: '$rel' contains forbidden segment '$matched_segment'")
    continue
  fi

  if matched_glob="$(is_deny_file_match "$rel")"; then
    violations+=("DENYLIST_FILE: '$rel' matches '$matched_glob'")
    continue
  fi
done < <(find . -mindepth 1 -printf '%p\n' | sort)

printf 'Allowlist root entries (%d):\n' "${#ALLOWLIST_ROOT[@]}"
printf ' - %s\n' "${ALLOWLIST_ROOT[@]}"
printf '\nDenylist directory segments (recursive, %d):\n' "${#DENY_DIR_SEGMENTS[@]}"
printf ' - %s\n' "${DENY_DIR_SEGMENTS[@]}"
printf '\nDenylist file patterns (recursive, %d):\n' "${#DENY_FILE_GLOBS[@]}"
printf ' - %s\n' "${DENY_FILE_GLOBS[@]}"
printf '\n'

if (( ${#violations[@]} > 0 )); then
  printf 'RESULT: FAIL\n'
  printf 'Violations (%d):\n' "${#violations[@]}"
  printf ' - %s\n' "${violations[@]}"
  exit 1
fi

printf 'RESULT: PASS\n'
printf 'Violations: 0\n'
exit 0
