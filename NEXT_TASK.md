# NEXT_TASK

## Следующая инженерная задача (одна)
D-004 — стабилизировать Linux test path (`swift test`) без падения на `no such module 'SQLite3'`.

## Scope
- Зафиксировать воспроизводимую Linux-команду тестирования, которая стабильно проходит в текущем контейнере.
- Убрать источник падения `no such module 'SQLite3'` для Linux test path (через корректное ограничение test scope и/или корректную Linux-конфигурацию `SQLite3`).
- Обновить документацию статуса после фикса: `DEFECT_BACKLOG.md`, `CURRENT_STATE.md`, `NEXT_TASK.md` (+ evidence при необходимости).

## Out of scope
- Revert/reset/переписывание git-истории.
- Рефакторинг и изменения бизнес-логики приложения.
- macOS-only runtime задачи (`D-001..D-003`) и desktop e2e-подтверждения.

## Acceptance criteria
1. В Linux воспроизводится детерминированный `swift test` path без ошибки `no such module 'SQLite3'`.
2. Зафиксированы точные команды, raw output и итоговый exit code для PASS-сценария.
3. `NEXT_TASK.md`, `DEFECT_BACKLOG.md`, `CURRENT_STATE.md` остаются синхронизированы по статусам (`D-015 = RESOLVED`, следующая задача = `D-004`).
