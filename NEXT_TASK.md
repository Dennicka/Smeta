# NEXT_TASK

## Следующая инженерная задача (одна)
D-015 — финальный review/sign-off clean-release discipline (после усиления recursive denylist).

## Scope
- Перепроверить D-015 verify-pass на актуальном дереве (`Scripts/verify_clean_release_d015.sh`).
- Подтвердить, что recursive denylist ловит шум в любой вложенности, а не только в корне.
- Поддерживать evidence в актуальном состоянии (exact commands, raw outputs, exit codes).

## Out of scope
- Новые фичи и изменения бизнес-логики.
- Параллельная работа по D-004/D-005/D-010 и другим backlog-пунктам.
- macOS runtime задачи (`D-001..D-003`, `D-002` AppKit e2e).

## Acceptance criteria
1. Verify-команда детерминированно отдаёт `PASS` на чистом состоянии.
2. Verify-команда детерминированно отдаёт `FAIL` при вложенном release-noise.
3. `EVIDENCE/D015_CLEAN_RELEASE.md`, `DEFECT_BACKLOG.md`, `CURRENT_STATE.md`, `NEXT_TASK.md` синхронизированы.
