# NEXT_TASK

## Следующая инженерная задача (одна)
Defect Fix 5 — добить остаток D-008: закрыть generation contour для Avtal / Kreditfaktura / ÄTA / Påminnelse без hardcoded/demo fallback.

## Scope
- Найти и убрать оставшиеся hardcoded/demo generation paths для Avtal / Kreditfaktura / ÄTA / Påminnelse.
- Перевести generation этих типов на repository-backed/snapshot-backed реальный payload.
- Убедиться, что при нехватке данных используется честный incomplete/error путь, а не fake content fallback.

## Out of scope
- Packaging/signing/release задачи macOS (`D-001..D-003`).
- D-011 CSV upsert redesign.
- Migration framework (`D-013`).

## Acceptance criteria
1. Для Avtal / Kreditfaktura / ÄTA / Påminnelse generation идёт из реальных repository/snapshot данных без demo/fake substitution.
2. Есть runtime/code-level evidence с exact commands + raw outputs + exit codes.
3. `CURRENT_STATE.md` и `DEFECT_BACKLOG.md` обновлены честно по факту статуса D-008 (минимум `PARTIAL`, `RESOLVED` только при полном доказательстве).

## Evidence requirements
- Exact commands + full raw outputs + exit codes.
- Обновлённые `CURRENT_STATE.md`, `DEFECT_BACKLOG.md`, `NEXT_TASK.md`.
- Отдельный evidence-файл под D-008 с трассировкой критерий → доказательство.
