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

## Важная оговорка
- После D-014 в acceptance/release документах больше не используется optimistic `PASS`, если он не подкреплён runtime evidence.
- Любой статус готовности теперь должен попадать только в одну явную категорию: `independently confirmed` / `repository-claimed` / `unconfirmed` / `blocked_env`.
