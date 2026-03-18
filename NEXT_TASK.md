# NEXT_TASK

## Следующая инженерная задача (одна)
Defect Fix 3c — добить D-009 до `RESOLVED`: получить реальный runtime evidence для repository-level `finalizeDocumentWithSnapshot(...)` в окружении, где доступен модуль `SQLite3`.

## Scope
- Запустить `Scripts/verify_finalize_document_with_snapshot.swift` в валидном окружении (macOS или Linux с рабочим `SQLite3` module map).
- Зафиксировать полный evidence pack (команды, raw output, exit code) и подтвердить:
  - final number в persisted snapshot,
  - finalized status в persisted snapshot,
  - rollback при ошибке snapshotBuilder.
- Подтвердить, что активный runtime path не использует удалённый legacy finalize API.
- После успешного runtime evidence перевести D-009 из `PARTIAL` в `RESOLVED` и обновить memory files.

## Out of scope
- D-010 export pipeline.
- Packaging/macOS runtime релизные задачи.
- Изменение налоговой математики (D-012).
- Import/update flow (D-011).

## Acceptance criteria
1. `Scripts/verify_finalize_document_with_snapshot.swift` выполнен успешно в релевантной среде.
2. Есть явный PASS по final number/finalized status/rollback checks.
3. Есть grep/evidence, что legacy finalize path отсутствует в runtime usage.
4. D-009 можно честно перевести в `RESOLVED`.

## Evidence requirements
- Exact commands + full raw outputs + exit codes.
- Обновлённые `CURRENT_STATE.md`, `DEFECT_BACKLOG.md`, `NEXT_TASK.md`.
- Обновлённый `EVIDENCE/D009_REPOSITORY_FINALIZATION.md` с итоговым вердиктом.
