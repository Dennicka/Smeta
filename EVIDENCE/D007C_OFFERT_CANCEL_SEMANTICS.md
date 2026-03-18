# D-007c — Offert cancel semantics: zero persistence side-effects before user confirmation

Дата: 2026-03-18 (UTC)
Среда: Linux container (без macOS AppKit runtime)

## Цель
Убрать side effects в persistence layer до пользовательского подтверждения пути сохранения в `saveEstimateAndGenerateDocument()` и зафиксировать честные ограничения верификации.

## 1) Exact commands / raw outputs / exit codes

### Command 1 — code-path proof (порядок операций в Offert flow)
```bash
nl -ba Sources/SmetaApp/ViewModels/AppViewModel.swift | sed -n '198,255p'
```
Exit code: `0`
Raw output (ключевой фрагмент):
```text
228            let panel = NSSavePanel()
231            guard panel.runModal() == .OK, let url = panel.url else {
232                infoMessage = "Генерация Offert отменена пользователем"
233                return
234            }
236            try pdfService.generateOffertSwedish(...)
238            let estimateId = try repository.insertEstimate(...)
243                    try repository.insertEstimateLine(...)
246            try repository.insertGeneratedDocument(...)
```

### Command 2 — Linux runtime regression check (core/test graph)
```bash
swift test
```
Exit code: `0`
Raw output (tail):
```text
Test Suite 'All tests' passed at 2026-03-18 20:08:48.053
    Executed 16 tests, with 0 failures (0 unexpected) in 0.393 (0.393) seconds
```

### Command 3 — graph scope proof (почему `swift test` не подтверждает SmetaApp UI-layer)
```bash
sed -n '1,220p' Package.swift
```
Exit code: `0`
Raw output (ключевой фрагмент):
```text
var products: [Product] = [
    .library(name: "SmetaCore", targets: ["SmetaCore"])
]
...
#if os(macOS)
products.insert(.executable(name: "SmetaApp", targets: ["SmetaApp"]), at: 0)
...
#endif
```

## 2) Где был дефект и что исправлено

## Было (до D-007c)
- В `saveEstimateAndGenerateDocument()` выполнялись `insertEstimate(...)` и `insertEstimateLine(...)` **до** `NSSavePanel`.
- При Cancel пользователь видел info-message об отмене, но persistence side effects уже были в БД.

## Стало (после D-007c)
- Порядок операций изменён на Variant A:
  1. валидация preconditions;
  2. `NSSavePanel` и user confirm;
  3. PDF generation;
  4. только затем persistence: `insertEstimate` → `insertEstimateLine` → `insertGeneratedDocument`.
- Следствие: Cancel path завершает flow до любых insert-операций.

## Инвариант D-007c
- После Cancel в Offert generation:
  - пользователь получает `infoMessage`;
  - persistence side effects (`estimates`, `estimate_lines`, `generated_documents`) в этом flow не создаются.

## 3) Честная классификация подтверждений

- **Runtime подтверждено в текущей среде (Linux):**
  - `swift test` по Linux test graph проходит успешно.
- **Подтверждено code-path audit:**
  - порядок операций в `saveEstimateAndGenerateDocument()` (confirm/cancel перед любыми insert).
- **Blocked by environment:**
  - реальный AppKit runtime сценарий с `NSSavePanel` (нажатие Cancel в UI) и end-to-end UI verification требует macOS.

## 4) Verdict
- D-007c code-level fix: **выполнен**.
- D-007 общий статус: **PARTIAL** до macOS runtime UX/e2e верификации.
