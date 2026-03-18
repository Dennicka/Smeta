# D-010 — macOS runtime E2E evidence for real PDF export (business documents)

Date (UTC): 2026-03-18
Environment: Linux container (`x86_64-unknown-linux-gnu`), not macOS.

## 1) Exact steps / commands

1. `date -u +"%Y-%m-%dT%H:%M:%SZ"`
2. `uname -a`
3. `swift --version`
4. `swift build --product SmetaApp`
5. `swiftc Sources/SmetaApp/Services/PDFDocumentService.swift -o /tmp/pdf_service_check`
6. `mkdir -p /tmp/d010_export_outputs && find /tmp/d010_export_outputs -maxdepth 1 -type f -name '*.pdf' -print`
7. `find /tmp/d010_export_outputs -maxdepth 1 -type f -name '*.pdf' -exec stat -c '%n %s' {} \;`

## 2) Raw outputs / logs

### Command output block A

```text
$ date -u +"%Y-%m-%dT%H:%M:%SZ"
2026-03-18T19:38:38Z
$ uname -a
Linux 2b6b50cb399b 6.12.47 #1 SMP Mon Oct 27 10:01:15 UTC 2025 x86_64 x86_64 x86_64 GNU/Linux
$ swift --version
Swift version 6.1.3 (swift-6.1.3-RELEASE)
Target: x86_64-unknown-linux-gnu
$ swift build --product SmetaApp
error: no product named 'SmetaApp'
Building for debugging...
error: no product named 'SmetaApp'
```

### Command output block B

```text
$ swiftc Sources/SmetaApp/Services/PDFDocumentService.swift -o /tmp/pdf_service_check
Sources/SmetaApp/Services/PDFDocumentService.swift:37:53: error: unterminated string literal
35 |
36 |     func generateBusinessDocumentPDF(title: String, body: String, saveURL: URL) throws {
37 |         let attributed = NSAttributedString(string: "\(title)
   |                                                     `- error: unterminated string literal
38 |
39 | \(body)", attributes: [.font: NSFont.systemFont(ofSize: 13)])

Sources/SmetaApp/Services/PDFDocumentService.swift:39:8: error: unterminated string literal
37 |         let attributed = NSAttributedString(string: "\(title)
38 |
39 | \(body)", attributes: [.font: NSFont.systemFont(ofSize: 13)])
   |        `- error: unterminated string literal
40 |         let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 595, height: 842))
41 |         textView.textStorage?.setAttributedString(attributed)
```

### Command output block C

```text
$ find /tmp/d010_export_outputs -maxdepth 1 -type f -name '*.pdf' -print
# (no output)

$ find /tmp/d010_export_outputs -maxdepth 1 -type f -name '*.pdf' -exec stat -c '%n %s' {} \;
# (no output)
```

## 3) Created PDF files list

No PDF files were created in this run.

## 4) File sizes

No file sizes are available because no PDF files were created.

## 5) Screenshot / runtime proof

- Honest runtime proof collected: host is Linux (`uname -a`), not macOS runtime.
- AppKit flow cannot be executed end-to-end in this container.
- Browser/screenshot tooling for native macOS AppKit runtime is not available in this environment.

## 6) Type-by-type verdict (PASS / FAIL)

| Document type | Verdict | Breakpoint |
|---|---|---|
| Avtal | FAIL (BLOCKED_ENV) | Cannot execute macOS AppKit export runtime in Linux container; build product `SmetaApp` unavailable here. |
| Faktura | FAIL (BLOCKED_ENV) | Same breakpoint: no macOS runtime/AppKit execution path available in current environment. |
| Kreditfaktura | FAIL (BLOCKED_ENV) | Same breakpoint before export-flow UI/save panel stage. |
| ÄTA | FAIL (BLOCKED_ENV) | Same breakpoint before export-flow UI/save panel stage. |
| Påminnelse | FAIL (BLOCKED_ENV) | Same breakpoint before export-flow UI/save panel stage. |

## 7) Failure classification (important split)

1. **Real code defect (resolved in D-010a):** earlier compile-time syntax error in `PDFDocumentService.swift` (`unterminated string literal`) was a code defect, not an environment limitation.
2. **Current blocker for full E2E:** true macOS runtime/AppKit export is still blocked in this Linux container (`swift build --product SmetaApp` -> `no product named 'SmetaApp'`).
3. **Result in this run:** no real PDF export artifacts for any of the 5 document types in Linux.

## 8) D-010a follow-up evidence: compile blocker removed

### Exact commands
1. `date -u +"%Y-%m-%dT%H:%M:%SZ"`
2. `swiftc -typecheck Sources/SmetaApp/Services/PDFDocumentService.swift`
3. `swift build --product SmetaApp`

### Raw output
```text
$ date -u +"%Y-%m-%dT%H:%M:%SZ"
2026-03-18T19:46:28Z
$ swiftc -typecheck Sources/SmetaApp/Services/PDFDocumentService.swift
EXIT_CODE:0
$ swift build --product SmetaApp
error: no product named 'SmetaApp'
Building for debugging...
error: no product named 'SmetaApp'
EXIT_CODE:1
```

### Exit code summary
- `swiftc -typecheck Sources/SmetaApp/Services/PDFDocumentService.swift` → `0` (compile-time syntax blocker removed).
- `swift build --product SmetaApp` → `1` (environment/runtime limitation in Linux remains).

## D-010 status after this evidence

- `D-010` remains **PARTIAL**.
- `D-010a` (compile blocker removal) is complete in repository code.
- Required next step for `D-010 RESOLVED`: execute real macOS runtime E2E (AppKit export flow + saved PDF artifacts + non-empty file checks) for each document type on an actual macOS host.
