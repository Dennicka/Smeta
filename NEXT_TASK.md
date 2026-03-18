# NEXT_TASK

## Следующая инженерная задача (одна)
Исправить project memory files так, чтобы они честно отражали результаты независимого аудита и реальные product defects; после этого подготовить следующий defect-fix task по highest-priority product defect.

## Scope
- Обновить `AGENT_CONTEXT.md`, `CURRENT_STATE.md`, `DEFECT_BACKLOG.md`, `ACCEPTANCE_RULES.md`, `NEXT_TASK.md` так, чтобы независимые audit findings были явно отражены.
- Явно развести independently confirmed vs repository-claimed/documented vs unconfirmed.
- Зафиксировать product defects из независимого аудита в backlog с приоритетом, статусом и expected fix.
- Сформулировать (документально) следующий defect-fix task-кандидат по highest-priority product defect **без начала реализации этого дефекта в коде**.

## Out of scope
- Любые новые продуктовые фичи.
- Любые изменения UI/Views/Services/Repositories.
- Любой рефактор/миграция/исправление runtime-дефектов в коде приложения.

## Acceptance criteria
1. Все memory files синхронизированы с независимыми audit findings и не завышают подтверждённую готовность.
2. В `CURRENT_STATE.md` нет смешения между independently confirmed и repository-claimed.
3. В `DEFECT_BACKLOG.md` отражены D-008…D-015 с полями priority/status/expected fix.
4. `NEXT_TASK.md` остаётся в рамках correction of memory layer и не расширяется до продуктовой разработки.

## Evidence requirements
- Полный diff только memory files.
- Список формулировок, перемещённых из confirmed в repository-claimed/unconfirmed.
- Явное указание, какие audit findings добавлены и где они зафиксированы.
