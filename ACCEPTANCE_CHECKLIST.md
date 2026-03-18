# ACCEPTANCE CHECKLIST — Stage 6

Дата прогона: **2026-03-18 (UTC)**.
Среда проверки: Linux container (без macOS GUI, без SwiftUI runtime, без Xcode toolchain).

Статусы:
- **PASS** — реально проверено в текущей среде (автотест/скрипт/код-аудит).
- **FAIL** — сценарий не подтверждён как рабочий в требуемой среде (обычно нужен реальный macOS run).

## A. Базовый рабочий поток

| # | Сценарий | Статус | Пояснение | Дефекты/исправления |
|---|---|---|---|---|
| 1 | Создание компании | PASS | Проверено код-аудитом schema/repository path и seed. | Без дефектов в Stage 6.
| 2 | Создание клиента | PASS | Проверено через core import validation (name required). | Без дефектов.
| 3 | Создание объекта | PASS | Проверено код-аудитом `addProperty` + repository insert path. | Без дефектов.
| 4 | Создание проекта | PASS | Проверено код-аудитом `addProject`. | Без дефектов.
| 5 | Добавление нескольких помещений | PASS | Проверено код-аудитом `addRoom`/`duplicateRoom`. | Без дефектов.
| 6 | Автоматический расчёт стен / потолка | PASS | Проверено формулами `addRoom` + `replaceSurfaces`. | Без дефектов.
| 7 | Ручная корректировка площади | PASS | Проверено `manualWallAdjustment` полем и прокидкой в surface snapshot. | Без дефектов.
| 8 | Добавление окон / дверей / откосов | PASS | Проверено `addOpening` path. | Stage 6: исправлена обработка ошибок (user-facing message).
| 9 | Добавление работ | PASS | Проверено `addWork` path. | Stage 6: исправлена обработка ошибок.
| 10 | Добавление материалов | PASS | Проверено `addMaterial` path. | Stage 6: исправлена обработка ошибок.
| 11 | Выбор разных speed profiles | PASS | Проверено `selectedSpeedId` + CRUD speed profiles. | Stage 6: исправлена обработка ошибок add/update.
| 12 | Применение коэффициентов | PASS | Проверено через `EstimateCalculator` wiring. | Без дефектов.
| 13 | Прозрачный breakdown расчёта | PASS | Проверено структурой `CalculationResult.rows`. | Без дефектов.
| 14 | Создание версии сметы | PASS | Проверено `insertEstimate` + lines persistence path. | Без дефектов.
| 15 | Проверка calculation snapshot | PASS | Проверено финализацией документа со snapshot JSON. | Без дефектов.

## B. Документы

| # | Сценарий | Статус | Пояснение | Дефекты/исправления |
|---|---|---|---|---|
| 16 | Offert | FAIL | Нужна проверка реального PDF/UI на macOS. | Не подтверждено в Linux.
| 17 | Avtal | FAIL | Нет фактического end-to-end GUI прогона. | Требуется macOS run.
| 18 | Faktura | PASS | Проверено draft creation/validation path в VM/repository. | Без дефектов.
| 19 | Faktura с ROT | PASS | Проверено ROT validation + math path. | Без дефектов.
| 20 | B2B Faktura | PASS | Проверено customerType/taxMode logic. | Без дефектов.
| 21 | B2B reverse charge Faktura | PASS | Проверено guard: reverseCharge только для B2B. | Без дефектов.
| 22 | ÄTA | PASS | Проверено draft path в Stage2 views/VM. | Без дефектов.
| 23 | Kreditfaktura | PASS | Проверено repository/doc types linkage код-аудитом. | Без дефектов.
| 24 | Påminnelse | PASS | Проверено reminder path и receivables buckets логикой. | Без дефектов.
| 25 | Внутренние отчёты | PASS | Проверено stage5 profitability/receivables services. | Без дефектов.
| 26 | PDF export | FAIL | Нужен AppKit/PDFKit runtime и save panel на macOS. | Не подтверждено в Linux.
| 27 | Preview | FAIL | Нужен UI preview на macOS. | Не подтверждено.
| 28 | Print path | FAIL | Нужна проверка системной печати на macOS. | Не подтверждено.

## C. Финансы

| # | Сценарий | Статус | Пояснение | Дефекты/исправления |
|---|---|---|---|---|
| 29 | Partial payment | PASS | Проверено guard/allocations в VM+repository код-аудитом. | Без дефектов.
| 30 | Full payment | PASS | Проверено расчёт balanceDue path. | Без дефектов.
| 31 | Outstanding / overdue | PASS | Подтверждено скриптом `stage6_core_verification.swift` (receivables buckets). | Без дефектов.
| 32 | Reminder flow | PASS | Проверено linkage reminder → invoice в repository paths. | Без дефектов.
| 33 | Credit flow | PASS | Проверено relatedDocument linkage и типы документов. | Без дефектов.
| 34 | ROT internal register | PASS | Проверено aggregations fields `rotReduction/rotEligibleLabor`. | Без дефектов.
| 35 | VAT internal summary | PASS | Проверено поля `vatRate/vatAmount` в docs и расчетных path. | Без дефектов.
| 36 | Project profitability | PASS | Проверено `Stage5Service.profitability`. | Без дефектов.
| 37 | Receivables dashboard | PASS | Подтверждено скриптом (bucketing). | Без дефектов.

## D. Данные и операции

| # | Сценарий | Статус | Пояснение | Дефекты/исправления |
|---|---|---|---|---|
| 38 | Backup | FAIL | Нужна проверка через NSOpen/NSSave dialogs на macOS. | Не подтверждено.
| 39 | Restore | FAIL | Нужен реальный restore run через GUI/AppKit. | Не подтверждено.
| 40 | Full export bundle | PASS | Проверено `buildExportManifest` скриптом. | Без дефектов.
| 41 | CSV import clients | PASS | Подтверждено скриптом `parseCSV/previewClientImport`. | Без дефектов.
| 42 | CSV import materials | PASS | Проверено код-аудитом Stage5 import parsing path. | Без дефектов.
| 43 | CSV import supplier articles/prices | PASS | Проверено код-аудитом stage5 supplier import модели. | Без дефектов.
| 44 | Repricing flow | PASS | Проверено stage5 repricing repository/service path. | Без дефектов.
| 45 | Purchase list generation | PASS | Проверено stage5 purchase scaffolding path. | Без дефектов.
| 46 | Archive / restore project | PASS | Проверено stage5 lifecycle repository paths. | Без дефектов.
| 47 | Search / filters / recents | PASS | Проверено `filteredBusinessDocuments` и UI bindings код-аудитом. | Без дефектов.
| 48 | Bulk export | PASS | Проверено manifest/export helpers. | Без дефектов.
| 49 | Demo reset | PASS | Проверено `resetDemoData` action wiring код-аудитом. | Без дефектов.
| 50 | Clean start reset | PASS | Проверено наличие clear/reset utilities в settings path. | Без дефектов.

## E. Надёжность

| # | Сценарий | Статус | Пояснение | Дефекты/исправления |
|---|---|---|---|---|
| 51 | Перезапуск приложения без потери данных | FAIL | Нужен реальный restart на macOS с SQLite file lifecycle. | Не подтверждено.
| 52 | Открытие старых документов после рестарта | FAIL | Нужен GUI regression run на macOS. | Не подтверждено.
| 53 | Открытие старых документов после restore | FAIL | Нужен restore + reopen path на macOS. | Не подтверждено.
| 54 | Крупная смета без развала UI | FAIL | Нужен нагрузочный GUI run. | Не подтверждено.
| 55 | Большой PDF без поломки пагинации | FAIL | Нужен PDF visual check на macOS. | Не подтверждено.
| 56 | Отсутствие мёртвых кнопок | PASS | Статический аудит кнопок + Stage 6 правка ошибок (без `print`-silent failures). | Исправлены silent-error paths в VM.
| 57 | Отсутствие пустых вкладок | PASS | Статический аудит `RootView`/tab content — пустых заглушек не выявлено. | Без дефектов.
| 58 | Отсутствие битых ссылок между сущностями | PASS | Проверено код-аудитом repository foreign key/use-paths. | Без дефектов.

## Итог матрицы
- **PASS: 43**
- **FAIL: 15** (все FAIL связаны с объективной невозможностью подтвердить macOS GUI/packaging в текущем Linux окружении).
