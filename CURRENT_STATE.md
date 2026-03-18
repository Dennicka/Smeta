# CURRENT_STATE

Дата среза: 2026-03-18 (UTC)

## Independently confirmed (runtime/code-evidence in current environment)
- Репозиторий действительно является Swift package с `SmetaApp` executable и `SmetaCore` library (`Package.swift`).
- В структуре кода реально присутствуют модули `Models/Data/Repositories/Services/ViewModels/Views` и отдельный `SmetaCore` слой.
- Core verification можно выполнить через компиляцию `SmetaCore` + `Scripts/stage6_core_verification.swift`, результат в текущей среде: `SUMMARY: PASS`.
- Параллельно: общий `swift test` в текущем контейнере не проходит (ошибка `no such module 'SQLite3'` в `SmetaApp` build path), поэтому общий тестовый PASS не подтверждён.
- Устранён hardcoded/demo flow для Stage2 `Offert` и `Faktura`: `OfferEditorView` и `InvoiceEditorView` больше не создают строковые позиции из UI, а вызывают отдельный mapping builder, который собирает payload из repository-backed project/estimate data.
- Добавлен отдельный mapping layer `DocumentDraftBuilder` (в `SmetaApp` и `SmetaCore`) с явным incomplete-state вместо fake fallback при отсутствии company/client/project/estimate/estimate lines.
- Добавлены автотесты для mapping/totals/vat/rot и empty-data behavior (`DocumentDraftBuilderTests`).
- Выполнен verification pass по текущему Offert/Faktura fix: кодовый аудит подтверждает отсутствие demo arrays в `OfferEditorView`/`InvoiceEditorView`, а сценарный скрипт `Scripts/verify_document_draft_builder.swift` подтверждает success path (Offert/Faktura draft payload) и incomplete path (empty estimate lines).
- Для D-009 внедрён полноценный immutable snapshot payload (`schemaVersion=2`) с отдельным builder/serializer слоем (`DocumentSnapshotBuilder`), который собирает frozen document meta, company/client/project context, финансовые поля, frozen lines и references; финализация документа в `AppViewModel` больше не пишет минимальный JSON `title/total/vat/rotReduction`.
- Для D-009a исправлен critical finalization bug на уровне кода: snapshot теперь строится из уже persisted final state (после присвоения финального `number` и статуса `finalized`) через атомарный repository flow `finalizeDocumentWithSnapshot` (BEGIN IMMEDIATE TRANSACTION → assign number/finalize → reread finalized document → build+persist snapshot → COMMIT).
- Добавлен legacy read path: новый parser snapshot'ов честно различает `full-v2` и `legacy-v1` форматы; старые минимальные snapshot'ы продолжают читаться как legacy, не маскируясь под полный формат.
- Добавлены/обновлены автотесты `DocumentSnapshotBuilderTests` (включая проверку final number/finalized status), script `Scripts/verify_document_snapshot_builder.swift` (builder-level PASS) и отдельный repository-level script `Scripts/verify_finalize_document_with_snapshot.swift` для позитивного/негативного сценариев `finalizeDocumentWithSnapshot(...)`.
- Для D-009 получен реальный repository-level runtime PASS в Linux через валидный `SQLite3` module map (`/tmp/sqlite3.modulemap`): verification script подтверждает final status/number, сохранение full snapshot rows, rollback при исключении в snapshotBuilder и корректный legacy parse path.
- Для test verification в Linux: `swift test --filter ...` по-прежнему падает из-за D-004 (`no such module 'SQLite3'` в `SmetaApp` build path), поэтому воспроизводимые зелёные команды для document-builder/snapshot fix — `swiftc Sources/SmetaCore/Models/Entities.swift Sources/SmetaCore/Services/DocumentDraftBuilder.swift Scripts/verify_document_draft_builder.swift -o /tmp/verify_document_draft_builder && /tmp/verify_document_draft_builder` и `swiftc Sources/SmetaCore/Models/Entities.swift Sources/SmetaCore/Services/DocumentSnapshotBuilder.swift Scripts/verify_document_snapshot_builder.swift -o /tmp/verify_document_snapshot_builder && /tmp/verify_document_snapshot_builder`.

## Repository-claimed / documented (внутренние заявления репозитория, не независимое подтверждение)
- В `ACCEPTANCE_CHECKLIST.md` заявлено 43 PASS / 15 FAIL.
- В `FINAL_VERIFICATION_REPORT.md` заявлена условная готовность только для `core logic freeze` и явно не финальная desktop release готовность.
- Внутренние документы репозитория указывают, что часть PASS основана на code audit/flow audit, а не на полноценном runtime e2e.
- Наличие release-документов и checklist не является доказательством independently verified readiness.

## Unconfirmed (требует независимого runtime evidence)
- Любой macOS-only runtime: запуск `SmetaApp`, AppKit dialogs, Preview/Print, `.app`/`.dmg` packaging, clean install/restart lifecycle.
- Корректность end-to-end document generation на реальных данных проекта для Avtal/Kreditfaktura/ÄTA/Påminnelse без hardcoded/demo substitution (Offert/Faktura path уже переведены на repository-backed builder, но macOS runtime E2E всё ещё не подтверждён).
- Реальная корректность CSV update/upsert semantics (а не имитация обновлений через дубликаты).
- Конфигурируемость процентов расчёта через settings/rules вместо hardcoded magic values.
- Надёжность migration/update flow на предсказуемой схеме, а не на opportunistic ALTER TABLE.
- Чистота архивного/релизного состояния (без build/output noise) как часть release readiness.

## Важная оговорка по acceptance PASS
- PASS из внутренних acceptance-документов не считается independently confirmed, если он основан только на code audit/assumption и не подкреплён runtime evidence в релевантной среде.
