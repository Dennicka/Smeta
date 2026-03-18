# NEXT_TASK

## Статус по директиве
Выбран **Вариант A — честно остановиться** до появления реального macOS runtime host.

## Текущий формальный статус
- D-002: `BLOCKED_ENV`
- D-010: `PARTIAL`
- Задача D-010 / D-002 **не выполнена** из-за отсутствия macOS host.

## Что делать дальше (только при наличии macOS)
После предоставления реального macOS runtime выполнить E2E pass по scope:
1. Business document PDF export: Avtal, Faktura, Kreditfaktura, ÄTA, Påminnelse.
2. Offert generation/save flow.
3. UX paths: cancel save panel, overwrite existing file, export success, user-facing error delivery.

## Обязательный evidence pack
- exact steps / commands;
- raw outputs;
- список созданных PDF;
- размеры файлов;
- screenshots или video proof;
- type-by-type PASS/FAIL;
- отдельная разбивка: independently confirmed / blocked / failed.

## Ограничение
До появления macOS host не выполнять новые Linux-only псевдо-прогоны как замену runtime proof.
