# NEXT_TASK

## Следующая инженерная задача (одна)
D-006 — снять partial-статус финальной Stage 6 готовности (перевести release verdict из «условно готово только для core logic freeze» к подтверждённому состоянию через недостающие runtime evidence).

## Scope
- Сфокусироваться на закрытии `PARTIAL` для D-006 через de-risk по оставшимся high-impact acceptance gap'ам.
- Подготовить последовательный план по `blocked_env`/macOS-only подтверждениям для путей, которые не могут быть закрыты в Linux.
- Синхронизировать release-вердикт в `FINAL_VERIFICATION_REPORT.md`, `ACCEPTANCE_CHECKLIST.md`, `CURRENT_STATE.md` после появления новых evidence.

## Out of scope
- Revert/reset/переписывание git-истории.
- Изменения бизнес-логики, не требуемые для D-006.
- Повторный аудит уже закрытого D-005 (кроме ссылок на готовое evidence).

## Acceptance criteria
1. Для D-006 зафиксирован явный plan-of-record: какие acceptance-пункты переводятся из `PARTIAL`/`blocked_env`, каким evidence и в какой среде.
2. После выполнения шага есть как минимум один новый проверяемый evidence-блок, уменьшающий объём неопределённости по финальному release verdict.
3. Документы статуса синхронизированы: `D-005 = RESOLVED`, следующая задача = `D-006`.
