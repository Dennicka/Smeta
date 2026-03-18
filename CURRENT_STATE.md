# CURRENT_STATE

Дата среза: 2026-03-18 (UTC)

## Independently confirmed
- В D-014 pass независимо подтверждены только runtime-сценарии, воспроизводимые в Linux через `Scripts/stage6_core_verification.swift`: CSV parse/import preview, receivables bucketing, export manifest consistency (см. `EVIDENCE/D014_ACCEPTANCE_AUDIT.md`).
- В acceptance-матрице этим соответствуют пункты: **#31, #37, #40, #41** (`independently confirmed`).

## Repository-claimed
- Пункты acceptance, ранее обозначенные как PASS только на основании code-audit/flow-audit, понижены до `repository-claimed`.
- По состоянию после D-014 их **42**; эти пункты заявлены репозиторием, но не считаются независимым runtime-подтверждением релизной готовности.

## Unconfirmed
- После ревизии D-014 отдельных пунктов со статусом `unconfirmed` в acceptance-матрице не осталось (**0**).
- Если появятся claims без воспроизводимого evidence и без стабильного repository-основания, они должны маркироваться `unconfirmed`.

## Blocked by environment
- macOS-only сценарии подтверждения (`Preview/Print/PDF AppKit`, `.app/.dmg`, clean install, restart lifecycle, GUI stress) остаются `blocked_env`; дополнительный pass attempt D-010/D-002 от 2026-03-18 это подтвердил.
- Количество `blocked_env` в acceptance-матрице: **12**.

## D-004 Linux test path (новое)
- Дефект `D-004` закрыт как `RESOLVED`: в `Package.swift` выполнено platform-aware разделение package graph, где `SmetaApp` (macOS-only) больше не попадает в Linux build/test graph.
- В текущем Linux контейнере детерминированная команда `swift test` проходит стабильно; ошибка `no such module 'SQLite3'` в целевом test path не воспроизводится.
- Полный evidence (exact commands, raw outputs, exit codes): `EVIDENCE/D004_LINUX_SWIFT_TEST_STABILIZATION.md`.

## D-005 stage6 core verification runner (новое)
- Прямой запуск `swift Scripts/stage6_core_verification.swift` в Linux подтверждён как принципиально неполный path для этого файла: interpreter не видит `Stage5Service`/`BusinessDocument` из `SmetaCore` и падает.
- `@main` удалён из `Scripts/stage6_core_verification.swift`, чтобы убрать interpreter-specific `@main`/scope mismatch из script layout.
- Введён явный entrypoint `Scripts/stage6_core_verification/main.swift`; официальный воспроизводимый запуск теперь фиксирован одной командой compile-and-run:
  - `swiftc Sources/SmetaCore/Models/Entities.swift Sources/SmetaCore/Services/Stage5Service.swift Scripts/stage6_core_verification.swift Scripts/stage6_core_verification/main.swift -o /tmp/stage6_core_verification && /tmp/stage6_core_verification`
- Runtime результат в текущем Linux контейнере: `SUMMARY: PASS`, `EXIT_CODE:0`.
- Полный evidence (включая FAIL старого пути и PASS нового): `EVIDENCE/D005_STAGE6_CORE_VERIFICATION_RUNNER.md`.

## D-015 clean-release discipline
- `Scripts/verify_clean_release_d015.sh` теперь делает не только top-level allowlist-check, но и **recursive denylist-check по всей глубине репозитория**.
- Запрещённые сегменты директорий (`.build/build/Build/DerivedData/output/tmp/temp/cache/.cache`) и шумные file-patterns (`*.log/*.tmp/*.temp/*.pid/*.sqlite-wal/*.sqlite-shm/*.db-wal/*.db-shm/.DS_Store`) детектируются в любом вложенном пути.
- В evidence зафиксированы оба сценария: `FAIL` на искусственном `Scripts/tmp/...` шуме и `PASS` после очистки; raw output + exit codes в `EVIDENCE/D015_CLEAN_RELEASE.md`.



## D-010 / D-002 macOS runtime evidence pass attempt (новое)
- Выполнен отдельный evidence-pack: `EVIDENCE/D010_D002_MACOS_RUNTIME_E2E_PASS_ATTEMPT_2026-03-18.md`.
- Зафиксированы exact commands/raw outputs для проверки реального runtime-хоста (`sw_vers`, `xcodebuild`, `swift run SmetaApp`) и факта отсутствия PDF-артефактов в текущем запуске.
- Независимо подтверждено только ограничение среды: запуск выполнен в Linux, а не macOS; AppKit/PDFKit SavePanel/Print/export UX path в этой среде недоступен.
- По всем запрошенным сценариям (5 business document типов + Offert save flow + cancel/error UX matrix) текущий вердикт: `FAIL (BLOCKED_ENV)`.
- D-002 остаётся `BLOCKED_ENV`; D-010 остаётся `PARTIAL` (code-level фиксы есть, но нет реального macOS runtime PASS).
- **Важно:** это не закрывает поставленную работу по D-010/D-002; задача считается невыполненной до реального macOS runtime E2E proof.

## D-010 macOS runtime E2E (обновлено)
- Подготовлен и обновлён evidence-pack `EVIDENCE/D010_MACOS_RUNTIME_E2E.md` с exact commands/raw outputs/type-by-type verdict для Avtal/Faktura/Kreditfaktura/ÄTA/Påminnelse.
- В evidence теперь явно разделено: что было кодовым дефектом, а что является environment blocker.
- D-010a закрыт: compile-time syntax blocker в `Sources/SmetaApp/Services/PDFDocumentService.swift` устранён и подтверждён командой `swiftc -typecheck ...` с `EXIT_CODE:0`.
- D-010 остаётся `PARTIAL`: для всех 5 document types runtime E2E в Linux всё ещё `FAIL (BLOCKED_ENV)` из-за отсутствия macOS AppKit runtime path (`swift build --product SmetaApp` не запускается в этой среде).
- Следующий шаг — реальный macOS прогон с созданными PDF-артефактами и размерами файлов.

## D-007a user-facing error handling pass (новое)
- Выполнен целевой проход по критичным пользовательским цепочкам: document generation/draft/export, import-export bundle, backup/restore, lifecycle notes/profitability.
- Убраны silent/non-user-facing paths в критичных действиях: guard-return без сообщения, optional-write swallow (`try ...?`), cancel-path без feedback и ложный успех на backup/restore cancel.
- В `BackupService` введены typed cancel errors, а `AppViewModel` теперь корректно показывает user-facing info/error вместо silent return или false-success.
- Добавлен evidence-pack `EVIDENCE/D007A_ERROR_HANDLING.md` с exact commands, raw outputs, exit codes и coverage map (covered / not covered / blocked).
- D-007 после этого остаётся `PARTIAL`: кодовые silent paths в покрытом scope исправлены, но macOS runtime UX-подтверждение сообщений по AppKit flow в текущем Linux окружении недоступно (`blocked_env`).

## D-007c Offert cancel semantics (новое)
- В `saveEstimateAndGenerateDocument()` устранён ложный no-op/cancel эффект с persistence side effects: `insertEstimate`/`insertEstimateLine`/`insertGeneratedDocument` перенесены после `NSSavePanel` confirm и успешной PDF генерации.
- Инвариант code-path теперь явный: при Cancel flow завершается с user-facing info-message и без insert-операций в persistence layer для этого сценария.
- Подготовлен отдельный evidence-pack `EVIDENCE/D007C_OFFERT_CANCEL_SEMANTICS.md` с exact commands/raw outputs/exit codes и честным разделением: runtime confirmed vs code-path confirmed vs blocked_env.
- Ограничение верификации не изменилось: Linux `swift test` не компилирует macOS-only `SmetaApp` target, поэтому UI-layer изменения подтверждены code-audit, а не Linux runtime AppKit execution.

## D-007e orphan-file / half-success semantics (новое)
- Для `saveEstimateAndGenerateDocument()` и `exportDocumentPDF(_:)` добавлен temp-file + transaction + cleanup pattern: PDF сначала генерируется во временный файл, затем DB/logging шаги выполняются в транзакции, финальный move делается до `COMMIT`.
- При fail до `COMMIT` выполняется `ROLLBACK`; временный файл удаляется, а если финальный файл уже был создан в этом flow — он также очищается, чтобы не оставлять orphan artifact при persistence/logging ошибке.
- Вынесены helper-функции подготовки/переноса PDF и унифицирована схема атомаризации/cleanup для обоих критичных экспортных сценариев.
- Добавлен evidence-pack `EVIDENCE/D007E_ATOMIC_PDF_PERSISTENCE.md` с exact commands/raw outputs/exit codes и отдельной фиксацией runtime-vs-code-path-vs-blocked_env.

## D-007g safe overwrite semantics (новое)
- Убрана destructive delete-before-replace схема, которая могла уничтожить pre-existing пользовательский PDF при fail после move/до commit.
- Temp PDF теперь создаётся рядом с `finalURL` (same-directory path), а не в global temporary directory; это устраняет cross-volume ambiguity для replace-flow.
- Реализована backup/restore стратегия для существующего `finalURL`: старый файл переносится в backup перед подменой, и при fail до commit восстанавливается автоматически, а при success удаляется после commit.
- Безопасная схема применена в обоих целевых flow: `saveEstimateAndGenerateDocument()` и `exportDocumentPDF(_)`.
- Добавлен evidence-pack `EVIDENCE/D007G_SAFE_OVERWRITE_SEMANTICS.md` с exact commands/raw outputs/exit codes и scenario-table (no-existing-file / existing-file / fail-before-commit / fail-after-move).

## D-007g2 hard recovery semantics (новое)
- Вынесен отдельный file-state helper `PDFFileStateOrchestrator` с throwing API для temp/backup/promote/recover/cleanup; best-effort `try?` удалён из критичного recovery/restore/backup-cleanup path.
- При неполном восстановлении состояния (`recoverAfterFailedCommit`) теперь генерируется явная ошибка `PDFFileStateError.incompleteRecovery(...)` с деталями и backup path.
- В `AppViewModel` recovery failures агрегируются и поднимаются как явная user-facing ошибка; post-commit backup cleanup failures больше не silent и выводятся в warning/info path.
- Добавлен scenario-based evidence-pack `EVIDENCE/D007G2_HARD_RECOVERY_SEMANTICS.md` с реальными файловыми сценариями (existing/no-existing, fail before move, fail after move, recovery success, recovery failure).

## D-007g3 temp-leak + post-commit false-failure semantics (новое)
- Закрыт temp leak до входа в transaction/recovery: temp PDF cleanup теперь выполняется для fail path до BEGIN (включая PDF generation fail и BEGIN fail), а не только для transaction-error ветки.
- Убрана false-failure семантика после успешного COMMIT: post-commit `reloadAll()` ошибки переведены в warning/info path и не маркируют всю операцию как failure.
- Для export/save flow сохранён явный warning path при post-commit backup cleanup issues (не silent).
- Добавлен scenario-based evidence-pack `EVIDENCE/D007G3_TEMP_LEAK_AND_POST_COMMIT_SEMANTICS.md` (cases: generation fail before tx, begin fail, commit success + refresh fail, export success + post-commit warning).


## D-007g4 evidence honesty / verifier alignment (новое)
- `Scripts/verify_d007g3_semantics.swift` приведён в соответствие production semantics: C1 теперь проверяет cleanup **после фактического создания temp artifact**, а не synthetic fail до temp path.
- C4 верификатора переведён на реальный post-commit warning path (success + warning), без искусственного throw/catch как финального failure.
- `EVIDENCE/D007G3_TEMP_LEAK_AND_POST_COMMIT_SEMANTICS.md` синхронизирован с тем, что реально проверяется в runtime script.
- В `EVIDENCE/D007E_ATOMIC_PDF_PERSISTENCE.md` и `EVIDENCE/D007G_SAFE_OVERWRITE_SEMANTICS.md` добавлены явные historical notes, чтобы не создавать ложное впечатление «свежего raw proof» для текущего orchestrator-based состояния.

## Важная оговорка
- После D-014 в acceptance/release документах больше не используется optimistic `PASS`, если он не подкреплён runtime evidence.
- Любой статус готовности теперь должен попадать только в одну явную категорию: `independently confirmed` / `repository-claimed` / `unconfirmed` / `blocked_env`.
