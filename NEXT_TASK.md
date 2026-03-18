# NEXT_TASK

## Следующая инженерная задача (одна)
Defect Fix 8 — начать закрытие D-012 (магические проценты в расчётах).

## Scope
- Найти и перечислить все hardcoded проценты в расчётном контуре (transport/equipment/waste/margin/moms и связанные коэффициенты).
- Вынести эти проценты в явный конфигурируемый source-of-truth (settings/rules), доступный для чтения в runtime расчётах.
- Убрать прямое использование magic constants из расчётного пути и заменить на чтение настроек/правил.
- Добавить минимальный evidence pack с runtime проверкой, что изменение настроек влияет на результат расчёта.

## Out of scope
- macOS runtime E2E задачи (`D-001..D-003`, D-010 AppKit proof).
- D-013 migration framework redesign.
- Рефакторинг подсистем, не относящихся к вычислению процентов.

## Acceptance criteria
1. В расчётном контуре больше нет hardcoded процентов из D-012: они берутся из настроек/правил.
2. Есть воспроизводимое подтверждение, что смена значения правила меняет итог расчёта.
3. `CURRENT_STATE.md`, `DEFECT_BACKLOG.md`, `NEXT_TASK.md` синхронизированы по факту evidence, без завышения статуса.

## Evidence requirements
- Exact commands + full raw outputs + exit codes.
- Отдельный evidence-файл по D-012 (с трассировкой rule value → расчетный результат).
- Обновлённые `CURRENT_STATE.md`, `DEFECT_BACKLOG.md`, `NEXT_TASK.md`.
