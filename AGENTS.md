# Repository Agent Guidance

- Baseline must stay green.
- Before considering any task done, verify:
  - `swift test`
  - `bash Scripts/verify_macos_app_build_contour.sh`
- Do not change business logic unless the task explicitly requires it.
- Keep diffs minimal and scoped.
- Never silently weaken tests.
- Never remove smoke/build checks to get green.
- If a check cannot run in the current environment, state it explicitly in logs/docs instead of faking success.
