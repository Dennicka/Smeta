# NEXT_TASK

## Следующая инженерная задача (одна)
D-005 — стабилизировать запуск `Scripts/stage6_core_verification.swift` прямой командой `swift Scripts/...` (убрать `@main`/scope mismatch и зафиксировать воспроизводимую команду).

## Scope
- Найти реальную причину, почему текущая документированная команда запуска скрипта не проходит.
- Исправить wiring запуска без ручной магии (либо через корректный script layout, либо через executable target/runner path).
- Зафиксировать одну детерминированную команду запуска с raw output и exit code в evidence.
- Синхронизировать статус в `DEFECT_BACKLOG.md`, `CURRENT_STATE.md`, `NEXT_TASK.md`.

## Out of scope
- Revert/reset/переписывание git-истории.
- Изменения бизнес-логики, не требуемые для D-005.
- macOS-only runtime задачи (`D-001..D-003`) и desktop e2e-подтверждения.

## Acceptance criteria
1. Есть воспроизводимая команда запуска `stage6_core_verification` в текущем Linux контейнере.
2. Команда и её результат (raw output + exit code) зафиксированы в evidence.
3. Документы статуса синхронизированы: `D-004 = RESOLVED`, следующая задача = `D-005`.
