# EVIDENCE — D-005 Stage6 core verification runner stabilization

Дата: 2026-03-18 (UTC)  
Среда: Linux container (`/workspace/Smeta`)

## Контекст дефекта

Цель D-005: стабилизировать запуск `Scripts/stage6_core_verification.swift` без ручной магии и зафиксировать один официальный воспроизводимый path.

Реальная причина падения `swift Scripts/stage6_core_verification.swift` состоит из двух частей:
1. Исторически в файле был `@main`, что в interpreter-режиме `swift` давало `main attribute cannot be used in a module that contains top-level code` (scope mismatch).
2. Даже после устранения `@main` прямой `swift Scripts/...` не видит типы `Stage5Service` / `BusinessDocument`, потому что они объявлены в отдельных исходниках `Sources/SmetaCore/...`, которые не подключаются автоматически этим вызовом.

Вывод: прямой path `swift Scripts/stage6_core_verification.swift` **не является корректным standalone запуском** для данного сценария в этом репозитории.

## Сделанное исправление

- `Scripts/stage6_core_verification.swift` переведён в библиотечный script layout (без `@main`).
- Добавлен явный entrypoint `Scripts/stage6_core_verification/main.swift`.
- Зафиксирован единый официальный compile-and-run path одной командой (см. ниже).

## Команды, raw output, exit codes

### 1) Доказательство, что прямой `swift Scripts/...` остаётся некорректным path (после фикса `@main`)

Команда:
```bash
swift Scripts/stage6_core_verification.swift; echo EXIT_CODE:$?
```

Raw output:
```text
Scripts/stage6_core_verification.swift:14:19: error: cannot find 'Stage5Service' in scope
12 |
13 | func run() -> Int32 {
14 |     let service = Stage5Service()
   |                   `- error: cannot find 'Stage5Service' in scope
15 |     var failures = 0
16 |

Scripts/stage6_core_verification.swift:28:9: error: cannot find 'BusinessDocument' in scope
26 |     let now = Date(timeIntervalSince1970: 1_700_000_000)
27 |     let docs = [
28 |         BusinessDocument(id: 1, projectId: 1, type: "faktura", status: "sent", number: "A", title: "A", issueDate: now, dueDate: now.addingTimeInterval(-2*86400), customerType: "b2c", taxMode: "normal", currency: "SEK", subtotalLabor: 0, subtotalMaterial: 0, subtotalOther: 0, vatRate: 0, vatAmount: 0, rotEligibleLabor: 0, rotReduction: 0, totalAmount: 100, paidAmount: 0, balanceDue: 100, relatedDocumentId: nil, notes: ""),
   |         `- error: cannot find 'BusinessDocument' in scope
29 |         BusinessDocument(id: 2, projectId: 1, type: "faktura", status: "sent", number: "B", title: "B", issueDate: now, dueDate: now.addingTimeInterval(-40*86400), customerType: "b2c", taxMode: "normal", currency: "SEK", subtotalLabor: 0, subtotalMaterial: 0, subtotalOther: 0, vatRate: 0, vatAmount: 0, rotEligibleLabor: 0, rotReduction: 0, totalAmount: 200, paidAmount: 0, balanceDue: 200, relatedDocumentId: nil, notes: "")
30 |     ]

Scripts/stage6_core_verification.swift:29:9: error: cannot find 'BusinessDocument' in scope
27 |     let docs = [
28 |         BusinessDocument(id: 1, projectId: 1, type: "faktura", status: "sent", number: "A", title: "A", issueDate: now, dueDate: now.addingTimeInterval(-2*86400), customerType: "b2c", taxMode: "normal", currency: "SEK", subtotalLabor: 0, subtotalMaterial: 0, subtotalOther: 0, vatRate: 0, vatAmount: 0, rotEligibleLabor: 0, rotReduction: 0, totalAmount: 100, paidAmount: 0, balanceDue: 100, relatedDocumentId: nil, notes: ""),
29 |         BusinessDocument(id: 2, projectId: 1, type: "faktura", status: "sent", number: "B", title: "B", issueDate: now, dueDate: now.addingTimeInterval(-40*86400), customerType: "b2c", taxMode: "normal", currency: "SEK", subtotalLabor: 0, subtotalMaterial: 0, subtotalOther: 0, vatRate: 0, vatAmount: 0, rotEligibleLabor: 0, rotReduction: 0, totalAmount: 200, paidAmount: 0, balanceDue: 200, relatedDocumentId: nil, notes: "")
   |         `- error: cannot find 'BusinessDocument' in scope
30 |     ]
31 |

Scripts/stage6_core_verification.swift:27:9: error: the compiler is unable to type-check this expression in reasonable time; try breaking up the expression into distinct sub-expressions
25 |
26 |     let now = Date(timeIntervalSince1970: 1_700_000_000)
27 |     let docs = [
   |         `- error: the compiler is unable to type-check this expression in reasonable time; try breaking up the expression into distinct sub-expressions
28 |         BusinessDocument(id: 1, projectId: 1, type: "faktura", status: "sent", number: "A", title: "A", issueDate: now, dueDate: now.addingTimeInterval(-2*86400), customerType: "b2c", taxMode: "normal", currency: "SEK", subtotalLabor: 0, subtotalMaterial: 0, subtotalOther: 0, vatRate: 0, vatAmount: 0, rotEligibleLabor: 0, rotReduction: 0, totalAmount: 100, paidAmount: 0, balanceDue: 100, relatedDocumentId: nil, notes: ""),
29 |         BusinessDocument(id: 2, projectId: 1, type: "faktura", status: "sent", number: "B", title: "B", issueDate: now, dueDate: now.addingTimeInterval(-40*86400), customerType: "b2c", taxMode: "normal", currency: "SEK", subtotalLabor: 0, subtotalMaterial: 0, subtotalOther: 0, vatRate: 0, vatAmount: 0, rotEligibleLabor: 0, rotReduction: 0, totalAmount: 200, paidAmount: 0, balanceDue: 200, relatedDocumentId: nil, notes: "")
EXIT_CODE:1
```

### 2) Официальный воспроизводимый path (одна команда)

Команда:
```bash
swiftc Sources/SmetaCore/Models/Entities.swift Sources/SmetaCore/Services/Stage5Service.swift Scripts/stage6_core_verification.swift Scripts/stage6_core_verification/main.swift -o /tmp/stage6_core_verification && /tmp/stage6_core_verification; echo EXIT_CODE:$?
```

Raw output:
```text
PASS: CSV import validation catches missing name
PASS: CSV preview counts create operations
PASS: Receivables bucket 1–7 overdue
PASS: Receivables bucket 31+ overdue total
PASS: Manifest contains schemaVersion
PASS: Manifest contains export files
SUMMARY: PASS
EXIT_CODE:0
```

## Итог D-005

- В текущем Linux контейнере есть одна документированная воспроизводимая команда запуска `stage6_core_verification`.
- Команда проходит детерминированно.
- Статус D-005: `RESOLVED`.
