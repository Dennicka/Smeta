# NEXT_TASK

## Следующая инженерная задача (одна)
Defect Fix 4 — начать D-010: довести единый PDF/document export pipeline для Avtal / Faktura / Kreditfaktura / ÄTA / Påminnelse до полного runtime e2e evidence.

## Scope
- Пройтись по текущим export paths в `SmetaApp` и устранить разрывы wiring между типами документов и финальным PDF generation.
- Обеспечить единый, предсказуемый путь формирования выходного документа для всех типов из D-010.
- Подготовить и выполнить verification сценарии по каждому типу документа с фиксацией runtime evidence.

## Out of scope
- Packaging/signing/release задачи macOS (`D-001..D-003`).
- Migration framework (`D-013`).
- CSV upsert redesign (`D-011`).

## Acceptance criteria
1. Для каждого типа (Avtal / Faktura / Kreditfaktura / ÄTA / Påminnelse) подтверждён рабочий export pipeline end-to-end.
2. Есть runtime evidence (команды, raw output, exit code; где релевантно — экспортированные PDF/артефакты).
3. Статус D-010 можно обновить из `OPEN` минимум до `PARTIAL` (или `RESOLVED`, если закрыто полностью).

## Evidence requirements
- Exact commands + full raw outputs + exit codes.
- Обновлённые `CURRENT_STATE.md`, `DEFECT_BACKLOG.md`, `NEXT_TASK.md`.
- Отдельный evidence-файл под D-010 с трассировкой критерий → доказательство.
