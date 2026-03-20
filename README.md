# Smeta Stage 1 (macOS native)

Нативное desktop-first приложение под **macOS Monterey 12.7** на:
- Swift
- SwiftUI
- AppKit bridge (PDF + системные диалоги)
- SQLite (локально, оффлайн)

## Архитектура
- `Models` — доменные сущности Stage 1.
- `Data` — SQLite-движок, схема БД, backup/restore на уровне файла.
- `Repositories` — CRUD и загрузка сущностей.
- `Services` — расчёт, генерация Offert PDF, backup/restore.
- `ViewModels` — сценарии приложения и orchestration без смешивания UI/домена.
- `Views` — рабочие экраны Stage 1.

## Stage 1 экраны
- Dashboard
- Clients
- Projects
- Create Estimate Wizard
- Rooms
- Works
- Materials
- Calculation
- Documents
- Offer editor
- Contract editor
- Invoice editor
- Payments
- Extra work / ÄTA
- Reminders
- Document templates
- Document numbering
- Tax settings
- Stage 5 Operations
- Settings

Текущий navigation shell в `RootView` реализован как двухколоночный `HStack`: слева кастомный sidebar со списком экранов, справа detail-область с верхним полем поиска и контентом выбранного экрана (через `switch selected`).

## Рабочий сценарий Stage 1
Поддерживается сквозной поток:
1. Создать клиента.
2. Создать объект.
3. Создать проект.
4. Добавить помещения.
5. Добавить работы/материалы (в каталоги).
6. Выбрать скорость.
7. Выполнить расчёт (часы/дни/стоимость труда/материалов/итог).
8. Сгенерировать `Offert` на шведском.
9. Экспортировать PDF через стандартный `NSSavePanel`.
10. Данные сохраняются в SQLite и доступны после повторного запуска.

## Seed data (demo)
При первом запуске автоматически добавляются:
- тестовая компания,
- 2 клиента,
- объекты,
- проект,
- помещения,
- базовый каталог работ,
- базовый каталог материалов,
- базовый каталог скоростей,
- шаблон документа `Offert Standard`.

## Прозрачная формула расчёта
`EstimateCalculator` рассчитывает по строкам с явными полями:
- объём,
- скорость,
- норма,
- коэффициент,
- часы,
- дни,
- стоимость труда,
- стоимость материалов,
- итог.

## Где хранится локальная база
`~/Library/Application Support/Smeta/smeta.sqlite`

## Backup / Restore
Экран `Settings`:
- **Backup базы** — сохраняет копию SQLite в выбранный файл.
- **Restore базы** — восстанавливает БД из выбранного файла.

## Сборка и запуск
### В Xcode (рекомендуется на macOS 12.7)
1. Открыть `Package.swift` в Xcode.
2. Выбрать схему `SmetaApp`.
3. `Run`.

### CLI
```bash
swift run SmetaApp
```

### macOS scripts (готово для копирования)
```bash
./Scripts/macos_build.sh
```
Собирает `release/Smeta.app`.

```bash
SMETA_ENABLE_RUNTIME_UI_SMOKE=1 ./Scripts/macos_smoke_check.sh
```
Канонический runtime smoke (macOS):
- проверяет operational runtime (не только launch/window),
- отдельно проверяет controlled startup failure classification,
- имеет negative criterion (должен падать при мёртвой interactive chain),
- проводит real UI actions через `Scripts/ui_smoke_driver.swift` (project selection + calculation trigger),
- честно возвращает `BLOCKED` при отсутствии Accessibility permission для AX automation,
- пишет логи в `release/smoke-logs/runtime-*.log`.

```bash
./Scripts/macos_package_dmg.sh
```
Упаковывает `release/Smeta.app` в `release/Smeta.dmg`.

> На Linux сборка UI-таргета невозможна, т.к. SwiftUI/AppKit доступны только на macOS.

## Что останется на Stage 2
- Полное редактирование/удаление всех сущностей в таблицах.
- Расширенный конструктор шаблонов документов.
- Улучшение типизации `EstimateLine` и привязки к каталогам.
- Валидация и защита от дубликатов/некорректных вводов.
- Печать через `NSPrintOperation` и расширенный layout PDF.


## Stage 4 stabilization highlights
- Усилена надёжность SQLite-соединения (`foreign_keys`, `WAL`, `busy_timeout`).
- Backup/restore усилены: timestamped backup, подтверждение restore, валидация структуры backup.
- Включены базовые валидации для критичных сущностей (клиенты/проекты/помещения/документы/оплаты).
- Добавлен UX-фидбек ошибок и успешных действий в основном интерфейсе.
- Поиск в верхней строке фильтрует список документов.
- В `Settings` явно показана папка данных и доступна кнопка открытия этой папки.

Дополнительные release-документы:
- `INSTALL.md`
- `USER_GUIDE.md`
- `BACKUP_RESTORE.md`
- `RELEASE_NOTES.md`
- `KNOWN_LIMITATIONS.md`
- `DEMO_WALKTHROUGH.md`
- `ACCEPTANCE_CHECKLIST.md`
- `FINAL_VERIFICATION_REPORT.md`

- Stage 5: operational/business layer for imports, purchasing, repricing, receivables, lifecycle and portability.
