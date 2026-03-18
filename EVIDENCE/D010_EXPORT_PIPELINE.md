# D-010 Export Pipeline Evidence

Date (UTC): 2026-03-18

## 1. Exact commands

1. `rg -n "generateOffertSwedish|generateBusinessDocumentPDF|exportDocumentPDF|Export PDF|DocumentExportPipeline|business_document_pdf" Sources/SmetaApp Sources/SmetaCore Scripts/verify_document_export_pipeline.swift`
2. `swiftc Sources/SmetaCore/Models/Entities.swift Sources/SmetaCore/Services/DocumentSnapshotBuilder.swift Sources/SmetaCore/Services/DocumentExportPipeline.swift Scripts/verify_document_export_pipeline.swift -o /tmp/verify_document_export_pipeline && /tmp/verify_document_export_pipeline`

## 2. Full raw outputs

### Command 1 output (export/document paths)
```text
Scripts/verify_document_export_pipeline.swift:4:struct VerifyDocumentExportPipeline {
Scripts/verify_document_export_pipeline.swift:7:        let exportPipeline = DocumentExportPipeline(snapshotBuilder: snapshotBuilder)
Sources/SmetaApp/Services/PDFDocumentService.swift:6:    func generateOffertSwedish(template: DocumentTemplate,
Sources/SmetaApp/Services/PDFDocumentService.swift:36:    func generateBusinessDocumentPDF(title: String, body: String, saveURL: URL) throws {
Sources/SmetaApp/Services/DocumentExportPipeline.swift:14:enum DocumentExportPipelineError: LocalizedError {
Sources/SmetaApp/Services/DocumentExportPipeline.swift:25:final class DocumentExportPipeline {
Sources/SmetaApp/Services/DocumentExportPipeline.swift:80:            throw DocumentExportPipelineError.missingLines(documentType: document.type)
Sources/SmetaCore/Services/DocumentExportPipeline.swift:14:enum DocumentExportPipelineError: LocalizedError {
Sources/SmetaCore/Services/DocumentExportPipeline.swift:25:final class DocumentExportPipeline {
Sources/SmetaCore/Services/DocumentExportPipeline.swift:80:            throw DocumentExportPipelineError.missingLines(documentType: document.type)
Sources/SmetaApp/Views/DocumentsView.swift:32:                        Button("Export PDF") { vm.exportDocumentPDF(doc) }
Sources/SmetaApp/ViewModels/AppViewModel.swift:57:    private let documentExportPipeline = DocumentExportPipeline()
Sources/SmetaApp/ViewModels/AppViewModel.swift:216:                try pdfService.generateOffertSwedish(template: template, company: company, client: client, project: project, result: calc, saveURL: url)
Sources/SmetaApp/ViewModels/AppViewModel.swift:391:    func exportDocumentPDF(_ doc: BusinessDocument) {
Sources/SmetaApp/ViewModels/AppViewModel.swift:414:                try pdfService.generateBusinessDocumentPDF(title: payload.title, body: payload.body, saveURL: url)
Sources/SmetaApp/ViewModels/AppViewModel.swift:415:                try repository.logExport(kind: "business_document_pdf", scope: "document_\(doc.id)_\(doc.type)_\(payload.source.rawValue)", path: url.path)
```

### Command 2 output (pipeline verification for 5 document types)
```text
[PASS] avtal: expected source snapshot
[PASS] avtal: title contains document type
[PASS] avtal: payload contains real marker from source
[PASS] faktura: expected source repository
[PASS] faktura: title contains document type
[PASS] faktura: payload contains real marker from source
[PASS] kreditfaktura: expected source snapshot
[PASS] kreditfaktura: title contains document type
[PASS] kreditfaktura: payload contains real marker from source
[PASS] ata: expected source snapshot
[PASS] ata: title contains document type
[PASS] ata: payload contains real marker from source
[PASS] paminnelse: expected source repository
[PASS] paminnelse: title contains document type
[PASS] paminnelse: payload contains real marker from source
[PASS] missing lines rejected without fake fallback
RESULT: PASS
```

## 3. Exit codes

- Command 1: `0`
- Command 2: `0`

## 4. Mapping `document type → proof`

| Document type | Content source proved in runtime script | Proof line(s) |
|---|---|---|
| Avtal | `snapshot` | `[PASS] avtal: expected source snapshot`, `[PASS] avtal: payload contains real marker from source` |
| Faktura | `repository` | `[PASS] faktura: expected source repository`, `[PASS] faktura: payload contains real marker from source` |
| Kreditfaktura | `snapshot` | `[PASS] kreditfaktura: expected source snapshot`, `[PASS] kreditfaktura: payload contains real marker from source` |
| ÄTA | `snapshot` | `[PASS] ata: expected source snapshot`, `[PASS] ata: payload contains real marker from source` |
| Påminnelse | `repository` | `[PASS] paminnelse: expected source repository`, `[PASS] paminnelse: payload contains real marker from source` |

## 5. PASS / FAIL summary

### PASS
- Unified document export payload builder is wired in app and core (`DocumentExportPipeline`) and used by `AppViewModel.exportDocumentPDF(...)` for Avtal/Faktura/Kreditfaktura/ÄTA/Påminnelse.
- No decorative fake fallback in export path: empty lines now cause explicit error (`missingLines`) instead of synthetic/demo content.
- Runtime verification script (core/service level) confirms all 5 target types go through the same pipeline and carry real markers from snapshot/repository source.

### FAIL / BLOCKED_ENV
- Full runtime PDF e2e for actual AppKit save panel + file write is **not** independently confirmed in this Linux container; this remains blocked for macOS runtime verification.

## 6. Merge verdict for D-010

- **Code-level + service-level verification: PASS**.
- **macOS runtime PDF e2e evidence: BLOCKED_ENV in this environment**.
- Honest backlog status after this task: **D-010 = PARTIAL**.
