# DEFECT_BACKLOG

Дата обновления: 2026-03-18 (UTC)

Статусы:
- `OPEN` — дефект известен, не закрыт.
- `PARTIAL` — есть частичное решение/обходной путь, но acceptance не закрыт.
- `RESOLVED` — исправление внесено и подтверждено в доступной среде.
- `BLOCKED_ENV` — не может быть закрыт без macOS runtime.

| ID | Дефект | Приоритет | Статус | Expected fix |
|---|---|---:|---|---|
| D-001 | Невозможно подтвердить `.app`/`.dmg` packaging и запуск desktop bundle в текущем Linux окружении. | P0 | BLOCKED_ENV | Провести отдельный macOS release pass: build/sign/package/run, приложить артефакты и обновить acceptance. |
| D-002 | Не подтверждены Preview/Print/PDF export через AppKit/PDFKit runtime. | P0 | BLOCKED_ENV | Выполнить ручные E2E на macOS с evidence (видео/скриншоты/файлы PDF + чек-лист PASS/FAIL). |
| D-003 | Не подтверждён clean-machine install path и first-run/restart lifecycle. | P0 | BLOCKED_ENV | Прогон на чистой macOS машине с фиксацией install/run/restart сценариев и журналом результатов. |
| D-004 | `swift test` в текущем контейнере не проходит полностью: `no such module 'SQLite3'` при сборке `SmetaApp`. | P1 | OPEN | Разделить/ограничить тестовый запуск до `SmetaCore` в CI Linux или добавить корректную Linux-конфигурацию для SQLite module map; зафиксировать команду, которая стабильно зелёная. |
| D-005 | Скрипт `Scripts/stage6_core_verification.swift` не запускается прямой командой `swift Scripts/...` (ошибка `@main`/scope), заявленная в доках команда не зафиксирована как рабочая. | P1 | OPEN | Добавить документированную воспроизводимую команду или оформить скрипт как исполняемый target. |
| D-006 | Stage 6 вердикт остаётся «условно готово только для core logic freeze, НЕ финальный desktop release». | P0 | PARTIAL | Закрыть все macOS-only FAIL сценарии и обновить Final Verification Report до безусловной release-ready оценки. |
| D-007 | Ранее были silent error paths (`print(error)`) в `AppViewModel`; по отчёту исправлено, но без runtime UX-подтверждения в macOS. | P2 | PARTIAL | Подтвердить на macOS UI, что все ошибки доходят до user-facing сообщений в критичных flows. |
| D-008 | Document generation relies on hardcoded/demo lines in views instead of real project/estimate/document mapping. | P0 | OPEN | Перевести генерацию документов на repository-backed immutable data mapping без UI hardcoded/demo fallback. |
| D-009 | Document snapshot is incomplete and does not store full immutable document content. | P0 | OPEN | Ввести полный immutable snapshot payload для каждого документа (header/lines/totals/tax/refs) на момент фиксации. |
| D-010 | PDF/document export flow is not fully wired for Avtal / Faktura / Kreditfaktura / ÄTA / Påminnelse. | P0 | OPEN | Довести единый export pipeline для всех типов документов и закрыть runtime e2e evidence по каждому типу. |
| D-011 | CSV client import uses fake update by inserting new records with "(updated)" instead of true update/upsert. | P1 | OPEN | Реализовать настоящий update/upsert по стабильному ключу (например, email/externalId) с отчётом create/update/skip. |
| D-012 | Calculation contains hardcoded magic percentages for transport/equipment/waste/margin/moms instead of settings/rules. | P0 | OPEN | Вынести проценты в конфигурируемые правила/настройки с версионируемым source-of-truth и audit trail. |
| D-013 | Migration/update path is weak and relies on opportunistic ALTER TABLE logic rather than a predictable migration flow. | P0 | OPEN | Внедрить версионированные миграции (ordered/idempotent) с явными up/down (или repair) шагами и проверками схемы. |
| D-014 | Acceptance/release documents overstate readiness because some PASS statuses are based on code audit or assumption rather than runtime evidence. | P0 | OPEN | Перемаркировать статусы по строгим evidence rules: audit-only → repository-claimed/unconfirmed до runtime подтверждения. |
| D-015 | Archive/release state is not clean and includes build/output noise inconsistent with a clean release bundle. | P1 | OPEN | Ввести deterministic clean-release checklist (artifact allowlist + cleanup step + verify command) перед фиксацией release state. |
