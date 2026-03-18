# ACCEPTANCE CHECKLIST — Stage 6 (D-014 audit sync)

Дата ревизии: **2026-03-18 (UTC)**.  
Среда проверки: Linux container (без macOS GUI, без SwiftUI runtime, без Xcode toolchain).

## Правила статусов (жёсткие)
- **independently confirmed** — есть прямое runtime evidence (команда + raw output + exit code).
- **repository-claimed** — статус заявлен репозиторием (код-аудит/внутренняя документация), но без независимого runtime-подтверждения в релевантной среде.
- **unconfirmed** — нет достаточного подтверждения даже на уровне воспроизводимого claim.
- **blocked_env** — подтверждение требует среды, недоступной в текущем Linux-контейнере (в первую очередь macOS runtime).

## A. Базовый рабочий поток

| # | Сценарий | Corrected status | Обоснование | Evidence/source |
|---|---|---|---|---|
| 1 | Создание компании | repository-claimed | Исторически был PASS только по code audit. | FINAL_VERIFICATION_REPORT.md + code-audit claim.
| 2 | Создание клиента | repository-claimed | Нет отдельного runtime сценария create-client UI/e2e в текущем pass. | FINAL_VERIFICATION_REPORT.md.
| 3 | Создание объекта | repository-claimed | Подтверждение только через repository/viewmodel audit path. | FINAL_VERIFICATION_REPORT.md.
| 4 | Создание проекта | repository-claimed | Runtime evidence для полного UI flow отсутствует. | FINAL_VERIFICATION_REPORT.md.
| 5 | Добавление нескольких помещений | repository-claimed | Было основано на code audit `addRoom/duplicateRoom`. | ACCEPTANCE history (audit-only).
| 6 | Автоматический расчёт стен / потолка | repository-claimed | Есть claim по формулам, но нет отдельного runtime acceptance run этого сценария. | FINAL_VERIFICATION_REPORT.md.
| 7 | Ручная корректировка площади | repository-claimed | Подтверждено только на уровне поля/прокидки в коде. | FINAL_VERIFICATION_REPORT.md.
| 8 | Добавление окон / дверей / откосов | repository-claimed | Runtime e2e добавления не зафиксирован. | FINAL_VERIFICATION_REPORT.md.
| 9 | Добавление работ | repository-claimed | Был audit path без runtime proof в acceptance-смысле. | FINAL_VERIFICATION_REPORT.md.
| 10 | Добавление материалов | repository-claimed | Аналогично: claim есть, независимого runtime evidence нет. | FINAL_VERIFICATION_REPORT.md.
| 11 | Выбор разных speed profiles | repository-claimed | Известен code-level claim, не подтверждён отдельным runtime acceptance run. | FINAL_VERIFICATION_REPORT.md.
| 12 | Применение коэффициентов | repository-claimed | Есть вычислительные claims, но нет полноценного acceptance runtime по сценарию. | FINAL_VERIFICATION_REPORT.md.
| 13 | Прозрачный breakdown расчёта | repository-claimed | Только claim по структуре данных, не e2e evidence. | FINAL_VERIFICATION_REPORT.md.
| 14 | Создание версии сметы | repository-claimed | Нет отдельного runtime evidence для user-flow версии сметы. | FINAL_VERIFICATION_REPORT.md.
| 15 | Проверка calculation snapshot | repository-claimed | Есть repository-level claims, но не acceptance runtime в macOS UI. | EVIDENCE/D009_REPOSITORY_FINALIZATION.md.

## B. Документы

| # | Сценарий | Corrected status | Обоснование | Evidence/source |
|---|---|---|---|---|
| 16 | Offert | blocked_env | Нужен macOS UI/PDF runtime pass. | FINAL_VERIFICATION_REPORT.md.
| 17 | Avtal | blocked_env | Нужен macOS UI/PDF runtime pass. | FINAL_VERIFICATION_REPORT.md.
| 18 | Faktura | repository-claimed | Claim по draft/repository path без полного runtime acceptance e2e. | FINAL_VERIFICATION_REPORT.md.
| 19 | Faktura с ROT | repository-claimed | Claim по ROT validation/math, но без acceptance runtime proof. | FINAL_VERIFICATION_REPORT.md.
| 20 | B2B Faktura | repository-claimed | Проверка заявлена на уровне логики, не e2e run. | FINAL_VERIFICATION_REPORT.md.
| 21 | B2B reverse charge Faktura | repository-claimed | Guard в коде подтверждён, но runtime acceptance не закрыт. | FINAL_VERIFICATION_REPORT.md.
| 22 | ÄTA | repository-claimed | Есть generation claims, но нет macOS runtime acceptance. | EVIDENCE/D008_GENERATION_CONTOUR.md.
| 23 | Kreditfaktura | repository-claimed | Repository/linkage claim без самостоятельного acceptance runtime pass. | EVIDENCE/D008_GENERATION_CONTOUR.md.
| 24 | Påminnelse | repository-claimed | Есть path claim, но нет отдельного runtime acceptance e2e. | EVIDENCE/D008_GENERATION_CONTOUR.md.
| 25 | Внутренние отчёты | repository-claimed | Stage5 service claim есть, acceptance runtime не зафиксирован. | FINAL_VERIFICATION_REPORT.md.
| 26 | PDF export | blocked_env | Требуется AppKit/PDFKit + macOS save panel runtime. | FINAL_VERIFICATION_REPORT.md.
| 27 | Preview | blocked_env | Требуется macOS Preview/UI runtime. | FINAL_VERIFICATION_REPORT.md.
| 28 | Print path | blocked_env | Требуется системная печать на macOS. | FINAL_VERIFICATION_REPORT.md.

## C. Финансы

| # | Сценарий | Corrected status | Обоснование | Evidence/source |
|---|---|---|---|---|
| 29 | Partial payment | repository-claimed | Code/repository claim, но без отдельного runtime acceptance run. | FINAL_VERIFICATION_REPORT.md.
| 30 | Full payment | repository-claimed | Аналогично, нет независимого acceptance runtime evidence. | FINAL_VERIFICATION_REPORT.md.
| 31 | Outstanding / overdue | independently confirmed | Подтверждено runtime скриптом stage6 core verification. | EVIDENCE/D014_ACCEPTANCE_AUDIT.md.
| 32 | Reminder flow | repository-claimed | Есть linkage claim, но нет отдельного runtime acceptance сценария. | FINAL_VERIFICATION_REPORT.md.
| 33 | Credit flow | repository-claimed | Проверка по relation fields заявлена, но не как acceptance runtime e2e. | FINAL_VERIFICATION_REPORT.md.
| 34 | ROT internal register | repository-claimed | Поля/агрегации заявлены; независимого acceptance runtime на этом pass нет. | FINAL_VERIFICATION_REPORT.md.
| 35 | VAT internal summary | repository-claimed | Есть code/evidence claims по полям, но не отдельный acceptance runtime. | EVIDENCE/D012_DEFECT_FIX_8B.md.
| 36 | Project profitability | repository-claimed | Service-level claim без отдельного acceptance runtime run. | FINAL_VERIFICATION_REPORT.md.
| 37 | Receivables dashboard | independently confirmed | Runtime-бакетизация подтверждена core verification script. | EVIDENCE/D014_ACCEPTANCE_AUDIT.md.

## D. Данные и операции

| # | Сценарий | Corrected status | Обоснование | Evidence/source |
|---|---|---|---|---|
| 38 | Backup | blocked_env | Требуются NSOpen/NSSave dialogs на macOS. | FINAL_VERIFICATION_REPORT.md.
| 39 | Restore | blocked_env | Требуется реальный restore через macOS runtime. | FINAL_VERIFICATION_REPORT.md.
| 40 | Full export bundle | independently confirmed | Runtime: export manifest consistency в core verification script. | EVIDENCE/D014_ACCEPTANCE_AUDIT.md.
| 41 | CSV import clients | independently confirmed | Runtime: CSV parse/import preview подтверждены core verification script. | EVIDENCE/D014_ACCEPTANCE_AUDIT.md.
| 42 | CSV import materials | repository-claimed | Основано на code-audit import path. | FINAL_VERIFICATION_REPORT.md.
| 43 | CSV import supplier articles/prices | repository-claimed | Основано на code-audit path. | FINAL_VERIFICATION_REPORT.md.
| 44 | Repricing flow | repository-claimed | Service/repository claim без независимого acceptance runtime. | FINAL_VERIFICATION_REPORT.md.
| 45 | Purchase list generation | repository-claimed | Claim есть, но нет отдельного runtime acceptance run. | FINAL_VERIFICATION_REPORT.md.
| 46 | Archive / restore project | repository-claimed | Path claim есть, но macOS runtime/UX acceptance не закрыт. | FINAL_VERIFICATION_REPORT.md.
| 47 | Search / filters / recents | repository-claimed | Подтверждение только статическим аудитом bindings. | FINAL_VERIFICATION_REPORT.md.
| 48 | Bulk export | repository-claimed | Только helper/manifest claim без runtime acceptance e2e. | FINAL_VERIFICATION_REPORT.md.
| 49 | Demo reset | repository-claimed | Wiring claim есть, но нет независимого runtime acceptance evidence. | FINAL_VERIFICATION_REPORT.md.
| 50 | Clean start reset | repository-claimed | Утверждение по наличию utilities, без runtime acceptance proof. | FINAL_VERIFICATION_REPORT.md.

## E. Надёжность

| # | Сценарий | Corrected status | Обоснование | Evidence/source |
|---|---|---|---|---|
| 51 | Перезапуск приложения без потери данных | blocked_env | Нужен реальный macOS restart lifecycle. | FINAL_VERIFICATION_REPORT.md.
| 52 | Открытие старых документов после рестарта | blocked_env | Нужен GUI regression run на macOS. | FINAL_VERIFICATION_REPORT.md.
| 53 | Открытие старых документов после restore | blocked_env | Нужен restore + reopen path на macOS. | FINAL_VERIFICATION_REPORT.md.
| 54 | Крупная смета без развала UI | blocked_env | Нужен нагрузочный GUI runtime. | FINAL_VERIFICATION_REPORT.md.
| 55 | Большой PDF без поломки пагинации | blocked_env | Нужен PDF visual runtime check на macOS. | FINAL_VERIFICATION_REPORT.md.
| 56 | Отсутствие мёртвых кнопок | repository-claimed | Статический аудит + код-фикс, но нет полного runtime UX подтверждения. | FINAL_VERIFICATION_REPORT.md.
| 57 | Отсутствие пустых вкладок | repository-claimed | Статический аудит без runtime acceptance run. | FINAL_VERIFICATION_REPORT.md.
| 58 | Отсутствие битых ссылок между сущностями | repository-claimed | Code-level linkage audit, независимого acceptance runtime e2e нет. | FINAL_VERIFICATION_REPORT.md.

## Итог (после D-014 ревизии)
- **independently confirmed: 4**
- **repository-claimed: 42**
- **unconfirmed: 0**
- **blocked_env: 12**

`PASS/FAIL` в этом документе больше не используются, чтобы исключить optimistic readiness.
