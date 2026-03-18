# NEXT_TASK

## Следующая инженерная задача (одна)
D-013 — предсказуемый migration/update flow вместо opportunistic ALTER TABLE.

## Scope
- Спроектировать и внедрить версионированные миграции схемы БД с явным порядком применения.
- Убрать зависимость от `try? ALTER TABLE ...` как основного механизма эволюции схемы.
- Добавить проверяемый migration evidence: команда, которая поднимает старую схему до актуальной и проходит smoke-check.

## Out of scope
- macOS runtime E2E задачи (`D-001..D-003`, D-010 AppKit proof).
- Закрытие D-004 (`SQLite3` module map в Linux) сверх минимально необходимого для migration evidence.
- Любые функциональные фичи вне migration path.

## Acceptance criteria
1. Migration flow детерминированный и повторяемый (idempotent там, где требуется).
2. Старый state БД корректно доводится до актуальной схемы без ручных правок.
3. Есть runtime evidence с exact commands/raw outputs/exit codes.

## Evidence requirements
- Exact commands + full raw outputs + exit codes.
- Отдельный evidence-файл по D-013 migration pass.
- Обновлённые `CURRENT_STATE.md`, `DEFECT_BACKLOG.md`, `NEXT_TASK.md`.
