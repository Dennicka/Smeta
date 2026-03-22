# Baseline Gap Report (строгая версия)

Дата фиксации: 2026-03-22.

## Правила статусов (жёсткие)
- **DONE** — подтверждён рабочий пользовательский контур и есть опора на автотесты (не только model/repository/builder).
- **PARTIAL** — есть рабочие части реализации, но baseline-контур закрыт не полностью (обычно нет полноценного acceptance e2e).
- **MISSING** — baseline-функция как принимаемый пользовательский контур фактически не собрана/не доказана; отдельные заготовки в коде это не отменяют.
- **UNVERIFIED** — есть кодовые признаки реализации, но текущий репозиторий не даёт достаточного подтверждения, что baseline-пункт можно принять.

## Coverage-map по обязательному baseline

| Baseline пункт | Статус | Что подтверждено фактами | Конкретные ссылки на код | Подтверждение тестами | Runtime smoke | Почему статус не выше |
|---|---|---|---|---|---|---|
| Клиенты | DONE | CRUD-контур реализован и прогоняется в runtime CRUD тесте. | `Sources/SmetaApp/ViewModels/AppViewModel.swift`, `Sources/SmetaApp/Repositories/AppRepository.swift`, `Sources/SmetaApp/Views/ClientsView.swift` | `Tests/SmetaAppStartupTests/CRUDSafetyAndRoomPersistenceTests.swift` (CRUD flow) | Нет отдельного smoke на clients-only | Для DONE есть связка UI+VM+repo и тестовый CRUD-контур. |
| Объекты | DONE | CRUD объектов (property) участвует в реальном тестовом CRUD-сценарии. | `Sources/SmetaApp/ViewModels/AppViewModel.swift`, `Sources/SmetaApp/Repositories/AppRepository.swift`, `Sources/SmetaApp/Views/ClientsView.swift` | `Tests/SmetaAppStartupTests/CRUDSafetyAndRoomPersistenceTests.swift` | Нет отдельного smoke на properties-only | DONE только в пределах CRUD-контура без расширенного acceptance UX. |
| Проекты | DONE | Создание/выбор/удаление подтверждаются тестовым runtime flow. | `Sources/SmetaApp/ViewModels/AppViewModel.swift`, `Sources/SmetaApp/Repositories/AppRepository.swift`, `Sources/SmetaApp/Views/ProjectsView.swift` | `Tests/SmetaAppStartupTests/CRUDSafetyAndRoomPersistenceTests.swift` | `Scripts/ui_smoke_driver.swift` (project selection) | DONE ограничен базовым CRUD/selection, не всем lifecycle-сценарием. |
| Помещения | DONE | CRUD помещений и пересчёт геометрии проверяются тестами. | `Sources/SmetaApp/ViewModels/AppViewModel.swift`, `Sources/SmetaApp/Repositories/AppRepository.swift`, `Sources/SmetaApp/Views/RoomsView.swift` | `Tests/SmetaAppStartupTests/CRUDSafetyAndRoomPersistenceTests.swift` (geometry/openings persistence) | Нет отдельного smoke по room editing | DONE только для подтверждённого технического контура. |
| Работы | DONE | Каталог + привязки к room проверяются roundtrip/validation тестами. | `Sources/SmetaApp/ViewModels/AppViewModel.swift`, `Sources/SmetaApp/Repositories/AppRepository.swift`, `Sources/SmetaApp/Views/WorksView.swift` | `Tests/SmetaAppStartupTests/CRUDSafetyAndRoomPersistenceTests.swift` | Косвенно через smoke расчёта | DONE только для каталога/привязок, не для полного бизнес-процесса документов. |
| Материалы | DONE | Каталог + привязки к room проверяются roundtrip тестами. | `Sources/SmetaApp/ViewModels/AppViewModel.swift`, `Sources/SmetaApp/Repositories/AppRepository.swift`, `Sources/SmetaApp/Views/MaterialsView.swift` | `Tests/SmetaAppStartupTests/CRUDSafetyAndRoomPersistenceTests.swift` | Косвенно через smoke расчёта | DONE только в границах каталога/привязок. |
| Расчёт | PARTIAL | Движок и запуск есть; smoke подтверждает, что действие «Рассчитать» интерактивно живо. | `Sources/SmetaApp/Services/EstimateCalculator.swift`, `Sources/SmetaApp/ViewModels/AppViewModel.swift`, `Sources/SmetaApp/Views/CalculationView.swift` | В `Tests/` нет отдельного численного oracle-набора именно для `EstimateCalculator`; есть косвенная проверка non-nil результата в CRUD runtime тесте | `Scripts/ui_smoke_driver.swift`, `Scripts/macos_smoke_check.sh` (calculation action) | Нет строгого acceptance e2e расчёта с проверяемыми итогами для baseline. |
| Offert | PARTIAL | Builder + generation/export code path присутствуют и имеют контурные тесты. | `Sources/SmetaApp/Services/DocumentDraftBuilder.swift`, `Sources/SmetaApp/ViewModels/AppViewModel.swift`, `Sources/SmetaApp/Views/Stage2Views.swift`, `Sources/SmetaApp/Views/DocumentsView.swift` | `Tests/SmetaAppTests/DocumentDraftBuilderTests.swift`, `Tests/SmetaAppStartupTests/OffertGenerationContourTests.swift` | Нет подтверждённого full user e2e по macOS acceptance | Нет доказанного end-to-end пользовательского baseline-контура. |
| Avtal | UNVERIFIED | Есть builder/создание draft и финализация на уровне репозитория. | `Sources/SmetaApp/Services/DocumentDraftBuilder.swift`, `Sources/SmetaApp/ViewModels/AppViewModel.swift`, `Sources/SmetaApp/Repositories/AppRepository+Stage2.swift` | `Tests/SmetaAppTests/DocumentDraftBuilderTests.swift`, `Tests/SmetaAppStartupTests/DocumentFinalizationContourTests.swift` | Нет runtime smoke по Avtal path | Подтверждён в основном технический контур, не baseline UX-контур. |
| Faktura | PARTIAL | Draft/finalize/export логика реализована и есть contour-тесты экспорта. | `Sources/SmetaApp/Services/DocumentDraftBuilder.swift`, `Sources/SmetaApp/ViewModels/AppViewModel.swift`, `Sources/SmetaApp/Repositories/AppRepository+Stage2.swift` | `Tests/SmetaAppTests/DocumentDraftBuilderTests.swift`, `Tests/SmetaAppStartupTests/DocumentFinalizationContourTests.swift`, `Tests/SmetaAppStartupTests/BusinessDocumentPDFExportContourTests.swift` | Нет подтверждённого acceptance runtime e2e | Нет полного пользовательского процесса (выпуск → оплата → финальные артефакты) как принятого baseline. |
| Kreditfaktura | UNVERIFIED | Есть построение драфта и связь с исходной faktura. | `Sources/SmetaApp/Services/DocumentDraftBuilder.swift`, `Sources/SmetaApp/ViewModels/AppViewModel.swift` | `Tests/SmetaAppTests/DocumentDraftBuilderTests.swift` | Нет runtime smoke по kreditfaktura | Нет подтверждённого пользовательского e2e. |
| ÄTA | UNVERIFIED | Есть builder и create draft path. | `Sources/SmetaApp/Services/DocumentDraftBuilder.swift`, `Sources/SmetaApp/ViewModels/AppViewModel.swift`, `Sources/SmetaApp/Views/Stage2Views.swift` | `Tests/SmetaAppTests/DocumentDraftBuilderTests.swift` | Нет runtime smoke по ÄTA | Нет полноценного подтверждённого baseline-контура. |
| Påminnelse | UNVERIFIED | Есть builder от задолженности и draft path. | `Sources/SmetaApp/Services/DocumentDraftBuilder.swift`, `Sources/SmetaApp/ViewModels/AppViewModel.swift`, `Sources/SmetaApp/Views/Stage2Views.swift` | `Tests/SmetaAppTests/DocumentDraftBuilderTests.swift` | Нет runtime smoke по reminder flow | Нет доказанного end-to-end пользовательского сценария напоминания. |
| ROT | UNVERIFIED | Поля/формулы в документах и налоговых профилях есть. | `Sources/SmetaApp/Services/DocumentDraftBuilder.swift`, `Sources/SmetaApp/Repositories/AppRepository+Stage2.swift`, `Sources/SmetaCore/Models/Entities.swift` | `Tests/SmetaAppTests/DocumentDraftBuilderTests.swift` (арифметика rot/vat в payload) | Нет runtime smoke, подтверждающего ROT в реальном пользовательском документном цикле | Тестируется вычислительная часть, но baseline-процесс в пользовательском контуре не доказан. |
| MOMS / reverse charge | UNVERIFIED | Налоговые профили и reverseCharge guards реализованы. | `Sources/SmetaApp/Repositories/AppRepository+Stage2.swift`, `Sources/SmetaApp/ViewModels/AppViewModel.swift`, `Sources/SmetaApp/Services/DocumentDraftBuilder.swift` | `Tests/SmetaAppTests/DocumentDraftBuilderTests.swift` (reverse charge payload) | Нет runtime smoke по B2B reverse-charge сценарию | Нет подтверждённого e2e пользовательского контура. |
| Оплаты / частичные оплаты | DONE | Реализован рабочий контур partial/full payments: валидация входа, atomic registerPayment, корректные `paid_amount`/`balance_due`/status transitions, список платежей в UI и immediate refresh после записи. | `Sources/SmetaApp/Repositories/AppRepository+Stage2.swift`, `Sources/SmetaApp/ViewModels/AppViewModel.swift`, `Sources/SmetaApp/Views/Stage2Views.swift`, `Sources/SmetaApp/Services/DocumentDraftBuilder.swift` | `Tests/SmetaAppStartupTests/PaymentContourTests.swift` (A–G сценарии: partial/full/invalid/overpay/draft-reject/reload/reminder-outstanding compatibility) | Нет отдельного runtime smoke по payments-only | Блок закрыт на уровне baseline-контура; ограничение только в отсутствии выделенного runtime smoke test именно для payments screen. |
| backup / restore | MISSING | Есть AppKit-диалоги и API копирования/restore, но нет подтверждённого baseline user flow acceptance. | `Sources/SmetaApp/Services/BackupService.swift`, `Sources/SmetaApp/Data/SQLiteDatabase.swift`, `Sources/SmetaApp/Views/SettingsView.swift` | В `Tests/` нет независимого end-to-end backup+restore acceptance теста | Текущий runtime smoke не закрывает backup/restore; macOS-only путь в Linux blocked | Без подтверждённого e2e этот baseline-пункт не может считаться принятым. |
| PDF / print | MISSING | PDF export pipeline есть, но baseline сформулирован как «PDF / print», а print-контур не подтверждён как принят. | `Sources/SmetaApp/Services/DocumentExportPipeline.swift`, `Sources/SmetaApp/Services/PDFDocumentService.swift`, `Sources/SmetaApp/ViewModels/AppViewModel.swift`, `Sources/SmetaApp/Views/DocumentsView.swift` | Есть contour-тесты для PDF export: `Tests/SmetaAppStartupTests/BusinessDocumentPDFExportContourTests.swift` | Нет подтверждённого runtime acceptance по print/PDF визуальному сценарию | Из-за отсутствия доказанного print-пути и полного пользовательского acceptance пункт baseline считаем не принятым. |
| Справочники и полная редактируемость из UI | MISSING | Редактирование покрывает не все справочники; часть экранов по сути read-only. | `Sources/SmetaApp/Views/WorksView.swift`, `Sources/SmetaApp/Views/MaterialsView.swift`, `Sources/SmetaApp/Views/SettingsView.swift`, `Sources/SmetaApp/Views/Stage2Views.swift` (`DocumentNumberingView`, `TaxSettingsView`) | Есть частичные roundtrip тесты: `Tests/SmetaAppStartupTests/CRUDSafetyAndRoomPersistenceTests.swift`, `Tests/SmetaAppStartupTests/StartupPersistentBootstrapTests.swift` | Нет runtime smoke на полный UI-edit контур справочников | Baseline требует полной редактируемости из UI; это сейчас не доказано и не собрано целиком. |

## Что уже подтверждено без натяжек
- Клиенты, объекты, проекты, помещения, работы, материалы — только в рамках подтверждённого CRUD/roundtrip контура с автотестами.
- Не более этого: данные блоки подтверждены как технически рабочие контуры, но не как полный бизнес-acceptance всего приложения.

## Что можно считать реально принятым baseline уже сейчас
Только следующие пункты:
- клиенты;
- объекты;
- проекты;
- помещения;
- работы;
- материалы;
- оплаты / частичные оплаты.

Основание: для CRUD-блоков есть прямое подтверждение через `Tests/SmetaAppStartupTests/CRUDSafetyAndRoomPersistenceTests.swift`; для payments-контурa есть отдельное подтверждение через `Tests/SmetaAppStartupTests/PaymentContourTests.swift`.

## Что нельзя считать принятым baseline на текущий момент
- расчёт;
- Offert;
- Avtal;
- Faktura;
- Kreditfaktura;
- ÄTA;
- Påminnelse;
- ROT;
- MOMS / reverse charge;
- backup / restore;
- PDF / print;
- справочники и полная редактируемость из UI.

Причина общая: нет подтверждённого end-to-end acceptance пользовательского контура по требованиям baseline; в ряде пунктов есть только частичная реализация или технические заготовки.

## Ключевые файлы-источники аудита
- `Sources/SmetaApp/ViewModels/AppViewModel.swift`
- `Sources/SmetaApp/Repositories/AppRepository.swift`
- `Sources/SmetaApp/Repositories/AppRepository+Stage2.swift`
- `Sources/SmetaApp/Repositories/AppRepository+Stage5.swift`
- `Sources/SmetaApp/Services/DocumentDraftBuilder.swift`
- `Sources/SmetaApp/Services/EstimateCalculator.swift`
- `Sources/SmetaApp/Services/BackupService.swift`
- `Sources/SmetaApp/Services/DocumentExportPipeline.swift`
- `Sources/SmetaApp/Services/PDFDocumentService.swift`
- `Sources/SmetaApp/Views/ClientsView.swift`
- `Sources/SmetaApp/Views/ProjectsView.swift`
- `Sources/SmetaApp/Views/RoomsView.swift`
- `Sources/SmetaApp/Views/WorksView.swift`
- `Sources/SmetaApp/Views/MaterialsView.swift`
- `Sources/SmetaApp/Views/CalculationView.swift`
- `Sources/SmetaApp/Views/Stage2Views.swift`
- `Sources/SmetaApp/Views/DocumentsView.swift`
- `Sources/SmetaApp/Views/SettingsView.swift`
- `Tests/SmetaAppTests/DocumentDraftBuilderTests.swift`
- `Tests/SmetaAppStartupTests/CRUDSafetyAndRoomPersistenceTests.swift`
- `Tests/SmetaAppStartupTests/DocumentFinalizationContourTests.swift`
- `Tests/SmetaAppStartupTests/OffertGenerationContourTests.swift`
- `Tests/SmetaAppStartupTests/BusinessDocumentPDFExportContourTests.swift`
- `Tests/SmetaAppStartupTests/StartupPersistentBootstrapTests.swift`
- `Tests/SmetaAppStartupTests/RuntimeUISmokeHarnessTests.swift`
- `Scripts/ui_smoke_driver.swift`
- `Scripts/macos_smoke_check.sh`
