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
- macOS-only сценарии подтверждения (`Preview/Print/PDF AppKit`, `.app/.dmg`, clean install, restart lifecycle, GUI stress) остаются `blocked_env`.
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

## Важная оговорка
- После D-014 в acceptance/release документах больше не используется optimistic `PASS`, если он не подкреплён runtime evidence.
- Любой статус готовности теперь должен попадать только в одну явную категорию: `independently confirmed` / `repository-claimed` / `unconfirmed` / `blocked_env`.
