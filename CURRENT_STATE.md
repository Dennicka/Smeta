# CURRENT_STATE

Дата среза: 2026-03-18 (UTC)

## Independently confirmed (runtime/code-evidence in current environment)
- Репозиторий действительно является Swift package с `SmetaApp` executable и `SmetaCore` library (`Package.swift`).
- В структуре кода реально присутствуют модули `Models/Data/Repositories/Services/ViewModels/Views` и отдельный `SmetaCore` слой.
- Core verification можно выполнить через компиляцию `SmetaCore` + `Scripts/stage6_core_verification.swift`, результат в текущей среде: `SUMMARY: PASS`.
- Параллельно: общий `swift test` в текущем контейнере не проходит (ошибка `no such module 'SQLite3'` в `SmetaApp` build path), поэтому общий тестовый PASS не подтверждён.

## Repository-claimed / documented (внутренние заявления репозитория, не независимое подтверждение)
- В `ACCEPTANCE_CHECKLIST.md` заявлено 43 PASS / 15 FAIL.
- В `FINAL_VERIFICATION_REPORT.md` заявлена условная готовность только для `core logic freeze` и явно не финальная desktop release готовность.
- Внутренние документы репозитория указывают, что часть PASS основана на code audit/flow audit, а не на полноценном runtime e2e.
- Наличие release-документов и checklist не является доказательством independently verified readiness.

## Unconfirmed (требует независимого runtime evidence)
- Любой macOS-only runtime: запуск `SmetaApp`, AppKit dialogs, Preview/Print, `.app`/`.dmg` packaging, clean install/restart lifecycle.
- Корректность end-to-end document generation на реальных данных проекта (Offert/Avtal/Faktura/Kreditfaktura/ÄTA/Påminnelse) без hardcoded/demo substitution.
- Полнота immutable document snapshot для юридически/финансово значимого восстановления документа.
- Реальная корректность CSV update/upsert semantics (а не имитация обновлений через дубликаты).
- Конфигурируемость процентов расчёта через settings/rules вместо hardcoded magic values.
- Надёжность migration/update flow на предсказуемой схеме, а не на opportunistic ALTER TABLE.
- Чистота архивного/релизного состояния (без build/output noise) как часть release readiness.

## Важная оговорка по acceptance PASS
- PASS из внутренних acceptance-документов не считается independently confirmed, если он основан только на code audit/assumption и не подкреплён runtime evidence в релевантной среде.
