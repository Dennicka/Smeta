# NEXT_TASK

## Следующая инженерная задача (одна)
D-014 — очистка acceptance/release статусов от optimistic PASS без runtime evidence.

## Scope
- Провести ревизию acceptance/release документов и убрать optimistic PASS, не подтверждённые runtime evidence.
- Согласовать `ACCEPTANCE_CHECKLIST.md`, `FINAL_VERIFICATION_REPORT.md`, `CURRENT_STATE.md`, `DEFECT_BACKLOG.md` по единому evidence-based правилу.
- Явно разделить статусы на: independently confirmed / repository-claimed / unconfirmed.

## Out of scope
- Любые изменения бизнес-логики и новые фичи.
- Попытка «закрыть» macOS-only задачи без релевантной среды (`D-001..D-003`, D-010 AppKit proof).
- Рефактор migration-кода (D-013 уже закрыт и подтверждён).

## Acceptance criteria
1. В acceptance/release документах нет PASS, основанных только на code-audit/assumption.
2. Для спорных пунктов есть явная маркировка confirmed vs unconfirmed/repository-claimed.
3. Все изменения статусов подтверждены ссылками на конкретные evidence-команды/outputs.

## Evidence requirements
- Exact commands + full raw outputs + exit codes.
- Отдельный evidence-файл по D-014 audit/remarking pass.
- Обновлённые `CURRENT_STATE.md`, `DEFECT_BACKLOG.md`, `NEXT_TASK.md`.
