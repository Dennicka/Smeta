# AGENT_CONTEXT

## Что это за приложение
Smeta — desktop-first сметное приложение для ремонтно-строительных работ (клиенты, объекты, проекты, помещения, работы/материалы, расчёт, документы, операционный слой Stage 5/6).

## Платформа
- Целевая платформа: macOS 12+ (Monterey), GUI через SwiftUI/AppKit.
- Текущее инженерное окружение репозитория: Linux container (без macOS runtime).

## Стек
- Язык: Swift 5.9.
- UI: SwiftUI + AppKit/PDFKit bridge.
- Хранилище: SQLite (`sqlite3`, локальная оффлайн БД).
- Сборка: Swift Package Manager (`Package.swift`) с target'ами `SmetaApp` и `SmetaCore`.

## Архитектурные модули
- `Sources/SmetaApp/Models` — доменные сущности UI-слоя.
- `Sources/SmetaApp/Data` — SQLite engine/helpers.
- `Sources/SmetaApp/Repositories` — CRUD + сценарии Stage2/Stage5.
- `Sources/SmetaApp/Services` — расчёт, PDF, backup/restore и др.
- `Sources/SmetaApp/ViewModels` — orchestration и UX-состояние.
- `Sources/SmetaApp/Views` — экраны приложения.
- `Sources/SmetaCore/*` — изолированный core-слой для верификаций/тестов вне GUI.
- `Tests/SmetaAppTests` — тесты core/service логики.

## Источники истины (source of truth)
1. Фактический код в `Sources/*` и `Tests/*`.
2. Независимые выводы external archive audit (если есть) должны быть отражены в `CURRENT_STATE.md` и `DEFECT_BACKLOG.md` наряду с данными репозитория.
3. Репозиторные документы (`ACCEPTANCE_CHECKLIST.md`, `FINAL_VERIFICATION_REPORT.md`, `KNOWN_LIMITATIONS.md`) — это заявленные внутренние статусы, а не автоматическое независимое подтверждение.
4. Для состояния выполнения: только то, что подтверждено реальным запуском команд/тестов в релевантной среде.
5. Для продуктовых ограничений macOS-фич: явные FAIL/UNCONFIRMED до отдельного macOS runtime прогона.

## Что запрещено делать
- Запрещено считать repository docs равными independently verified truth без runtime evidence.
- Запрещено объявлять desktop release «готовым», пока не закрыты macOS-only acceptance сценарии.
- Запрещено ставить PASS без runtime/автотест/доказуемого evidence.
- Запрещено подменять статусы «не проверено» эвфемизмами («почти готово», «должно работать»).
- Запрещено игнорировать external audit findings при обновлении project memory files.
- Запрещено расширять scope в freeze-режиме без явного решения (сейчас зафиксирован defect-fix режим Stage 6).
