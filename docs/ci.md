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

## Artifacts and logs

To simplify failure analysis, CI uploads diagnostics as GitHub Actions artifacts even when a job fails.

Hosted job (`unit-and-build`) uploads:

- `release/build-logs/**`
- `.build/**/TestResults*` (if present)
- available build contour logs (if created by scripts), including:
  - `release/contour-logs/**`
  - `release/**/contour*.log`
  - `release/**/*contour*.log`

Runtime smoke job (`runtime-ui-smoke`) uploads:

- `release/smoke-logs/**`

Hosted job (`unit-and-build`) also uploads release build artifact:

- artifact name: `smeta-release-app`
- content path: `release/dist/**`
- archive produced in CI: `release/dist/Smeta.app.zip` (packaged from `release/Smeta.app`)
- build manifest produced in CI: `release/dist/build-manifest.txt`

## Release build artifacts (hosted CI)

The hosted `unit-and-build` job now packages the built app bundle after:

- `swift test`
- `bash Scripts/verify_macos_app_build_contour.sh`

Packaging behavior:

1. Verifies `release/Smeta.app` exists.
2. Creates `release/dist`.
3. Builds `release/dist/Smeta.app.zip` using macOS-native `ditto`, preserving the app bundle structure.
4. Generates `release/dist/build-manifest.txt` with build metadata.

Manifest fields:

- `repository`
- `git_commit_sha`
- `git_ref`
- `git_ref_name`
- `git_head_ref`
- `git_branch_resolved` (`GITHUB_HEAD_REF` for PRs, otherwise `GITHUB_REF_NAME`)
- `build_utc`
- `xcode_version`
- `swift_version`
- `archive_path`
- `archive_name`
- `archive_sha256`
- `archive_size_bytes`
- `runner_os`
- `runner_environment`

Where to download:

- Open a completed GitHub Actions run for workflow **CI**.
- Open job **Unit and Build Contour**.
- In **Artifacts**, download `smeta-release-app` (contains both `Smeta.app.zip` and `build-manifest.txt`).

Important scope note:

- `smeta-release-app` is a hosted CI build artifact for download/inspection.
- It is **not** a runtime validation result and does **not** replace self-hosted runtime UI smoke checks.

Why this matters:

- failed runs keep actionable logs attached to the run page
- local reproduction is faster because raw logs are downloadable
- no need to rerun immediately just to inspect missing diagnostics
