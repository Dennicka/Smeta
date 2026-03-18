# D-007a — user-facing error handling и удаление silent failure paths

Дата: 2026-03-18 (UTC)
Среда: Linux container (без macOS AppKit runtime)

## 1) Exact commands, raw outputs, exit codes

### Command 1 — baseline scan по `print(error)` / print-paths
```bash
rg -n "print\(error\)|print\(" Sources/SmetaApp Sources/SmetaCore
```
Exit code: `1`
Raw output:
```text
<empty>
```

### Command 2 — scan потенциальных swallow-paths (`guard ... return`, `try?`) в покрытом scope
```bash
rg -n "guard .* else \{ return \}|try\?" Sources/SmetaApp/ViewModels/AppViewModel.swift Sources/SmetaApp/Services/BackupService.swift Sources/SmetaApp/Views/Stage5OperationsView.swift
```
Exit code: `0`
Raw output:
```text
Sources/SmetaApp/ViewModels/AppViewModel.swift:97:        suppliers = (try? repository.suppliers()) ?? []
Sources/SmetaApp/ViewModels/AppViewModel.swift:98:        receivableBuckets = stage5Service.receivablesBuckets((try? repository.receivablesDocuments()) ?? [])
Sources/SmetaApp/ViewModels/AppViewModel.swift:101:            projectNotes = (try? repository.projectNotes(projectId: project.id)) ?? []
Sources/SmetaApp/ViewModels/AppViewModel.swift:421:            clients.first(where: { $0.id == project.clientId }) ?? (try? repository.clients().first(where: { $0.id == project.clientId }))
Sources/SmetaApp/ViewModels/AppViewModel.swift:546:        if let company = try? repository.companies().first {
Sources/SmetaApp/ViewModels/AppViewModel.swift:553:        projects.first(where: { $0.id == projectId }) ?? (try? repository.projects().first(where: { $0.id == projectId }))
Sources/SmetaApp/ViewModels/AppViewModel.swift:558:        return properties.first(where: { $0.id == project.propertyId }) ?? (try? repository.properties().first(where: { $0.id == project.propertyId }))
```

### Command 3 — regression check
```bash
swift test
```
Exit code: `0`
Raw output (tail):
```text
Test Suite 'All tests' passed at 2026-03-18 19:59:36.217
	 Executed 16 tests, with 0 failures (0 unexpected) in 0.485 (0.485) seconds
◇ Test run started.
↳ Testing Library Version: 6.1.3 (1d1f7e489c9c606)
↳ Target Platform: x86_64-unknown-linux-gnu
✔ Test run with 0 tests passed after 0.001 seconds.
```

## 2) Где было / что исправлено

| Area | Было (silent/non-user-facing path) | Исправление | Статус |
|---|---|---|---|
| Draft generation / calculation preconditions | `calculate()` делал `return` без сообщения при `selectedProject=nil` или отсутствии speed profile. | Добавлены явные `errorMessage` для обоих guard-путей. | Covered/FIXED |
| Document generation (Offert) | `saveEstimateAndGenerateDocument()` имел агрегированный `guard ... else { return }` + `try?` для company; пользователь получал «тишину». | Preconditions развернуты в явные проверки с `errorMessage`; отмена SavePanel теперь даёт `infoMessage`. | Covered/FIXED |
| Business-document export PDF | При отмене `NSSavePanel` не было feedback пользователю. | Добавлен user-facing `infoMessage = "Экспорт PDF отменён пользователем"`. | Covered/FIXED |
| Backup/Restore | В `BackupService` отмена диалогов возвращалась «молча», а `AppViewModel` показывал success даже при cancel. | Введён `BackupServiceError` (cancel/decline), service кидает typed errors, VM отображает user-facing info вместо ложного успеха. | Covered/FIXED |
| Import/Export bundle | При отмене выбора папки — silent return; CSV/manifest запись через optional chaining `try ...?` могла silently пропустить запись. | Добавлен info-message при cancel; для CSV/manifest добавлены explicit UTF-8 guards и явные error messages. | Covered/FIXED |
| Lifecycle/notes critical action | В UI-кнопке Add note пустой текст отбрасывался guard-return в View без user-facing feedback. | Убрана view-level silent guard; в VM добавлен validation errorMessage на пустую заметку. | Covered/FIXED |
| Critical cleanup action | `clearTempExports()` использовал `try? removeItem` и проглатывал ошибки удаления файлов. | Переведено на per-file do/catch с агрегированным user-facing error report при частичных fail. | Covered/FIXED |
| Profitability action | `refreshProjectProfitability` молча завершался без estimate (`guard ... return`). | Добавлен явный `errorMessage` + reset `selectedProjectProfitability = nil`. | Covered/FIXED |

## 3) Что осталось и почему

| Path | Почему осталось | Вердикт |
|---|---|---|
| `try?` в `reloadAll()` для `suppliers/receivables/projectNotes` | Это non-blocking secondary data hydration для dashboard/ops; не финальный критичный write/export flow. Ошибка тут не маскирует commit-like пользовательское действие (create/finalize/export/backup/restore). | Not covered (by design for this task) |
| `try?` в snapshot fallback (`companiesSnapshotValue/projectForSnapshot/propertyForSnapshot`) | Snapshot-context enrichment intentionally optional; финализация документа продолжает давать user-facing error при реальных fail в finalize path. | Not covered (acceptable optional context fallback) |
| Runtime UX E2E на macOS AppKit | Текущая среда Linux, реальные AppKit UI-диалоги не исполнимы. | Blocked_env |

## 4) Coverage map

- **Covered/FIXED:** document generation / draft preconditions / finalize-export adjacent guards / import-export bundle / backup-restore / project note lifecycle / profitability action.
- **Not covered intentionally:** non-critical optional hydration/read-side fallbacks (`try?`) без commit-like user action.
- **Blocked:** macOS runtime визуальное подтверждение user-facing сообщений в AppKit UI.
