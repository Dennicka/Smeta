# CI in this repository

This repository uses GitHub Actions to keep the baseline green without weakening existing checks.

## What CI checks

The CI setup preserves the existing validated baseline:

- `swift test`
- `bash Scripts/verify_macos_app_build_contour.sh`
- `SMETA_ENABLE_RUNTIME_UI_SMOKE=1 bash Scripts/macos_smoke_check.sh` (self-hosted only)

## Hosted runner checks (always on push/PR)

Workflow file: `.github/workflows/ci.yml`

Job: `unit-and-build`

Runner: `macos-latest` (GitHub-hosted)

Steps:
1. Checkout repository
2. Show Xcode and Swift versions
3. `swift package clean`
4. `swift test`
5. `bash Scripts/verify_macos_app_build_contour.sh`

This is the always-on CI gate for pull requests and pushes.

## Self-hosted macOS checks (manual, explicit)

Workflow file: `.github/workflows/ci.yml`

Job: `runtime-ui-smoke`

Runner: `[self-hosted, macOS]`

Steps:
1. Checkout repository
2. Show Xcode and Swift versions
3. `bash Scripts/verify_macos_app_build_contour.sh`
4. `SMETA_ENABLE_RUNTIME_UI_SMOKE=1 bash Scripts/macos_smoke_check.sh`

This job runs only on manual trigger (`workflow_dispatch`) with input `run_runtime_ui_smoke=true`.

## Why runtime UI smoke is separated

Runtime UI smoke requires a self-hosted macOS environment. Keeping it manual and explicit is the cleanest honest setup because:

- push/PR CI always runs on GitHub-hosted `macos-latest`
- pipeline does not get blocked waiting for unavailable self-hosted capacity
- runtime smoke remains available as a real check (not removed, not faked)

## How Denis can connect an iMac as self-hosted runner

1. Open GitHub repository settings.
2. Go to **Settings → Actions → Runners → New self-hosted runner**.
3. Choose **macOS** and follow the generated commands on the iMac.
4. Keep labels including `self-hosted` and `macOS` (required by this workflow).
5. Start the runner service on the iMac.
6. In GitHub Actions, run workflow **CI** manually and set `run_runtime_ui_smoke=true`.

After the runner is online, the `runtime-ui-smoke` job executes full runtime smoke exactly as locally validated.
