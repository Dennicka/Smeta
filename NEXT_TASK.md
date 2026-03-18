# NEXT_TASK

## Следующая инженерная задача (одна)
Defect Fix 8b — довести D-012 до полного закрытия (остаточные hardcoded money-impacting коэффициенты).

## Scope
- Убрать оставшиеся hardcoded money-impacting коэффициенты/пороги в расчётном контуре (`0.01/0.1/0.2` в `EstimateCalculator`) и согласовать, какие из них должны стать правилами.
- Убрать/обосновать VAT fallback `0.25` в смежном расчётном пути (Stage2 createDraftDocument), чтобы не было расхождения с rule/settings source.
- Расширить единый source-of-truth правил так, чтобы итоговые деньги не зависели от magic literals.
- Добавить runtime evidence, что изменение каждого вынесенного правила меняет релевантный кусок результата.

## Out of scope
- macOS runtime E2E задачи (`D-001..D-003`, D-010 AppKit proof).
- D-013 migration framework redesign.
- Рефакторинг подсистем, не относящихся к вычислению процентов.

## Acceptance criteria
1. В money-impacting расчётном пути не остаётся hardcoded коэффициентов/процентов, которые должны быть правилами.
2. Есть воспроизводимое подтверждение, что смена каждого правила меняет ожидаемую часть результата.
3. `CURRENT_STATE.md`, `DEFECT_BACKLOG.md`, `NEXT_TASK.md` синхронизированы по факту evidence, без завышения статуса.

## Evidence requirements
- Exact commands + full raw outputs + exit codes.
- Отдельный evidence-файл по D-012 update (с трассировкой rule value → расчетный результат для остаточных коэффициентов).
- Обновлённые `CURRENT_STATE.md`, `DEFECT_BACKLOG.md`, `NEXT_TASK.md`.
