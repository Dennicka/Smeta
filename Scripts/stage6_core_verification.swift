import Foundation

@discardableResult
func assert(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
    if condition() {
        print("PASS: \(message)")
        return true
    }
    print("FAIL: \(message)")
    return false
}

func run() -> Int32 {
    let service = Stage5Service()
    var failures = 0

    let rows = service.parseCSV("""
name,email
,foo@x.se
Anna,anna@x.se
""")
    let preview = service.previewClientImport(rows: rows, existing: [])
    if !assert(preview.issues.count == 1, "CSV import validation catches missing name") { failures += 1 }
    if !assert(preview.createCount == 1, "CSV preview counts create operations") { failures += 1 }

    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let docs = [
        BusinessDocument(id: 1, projectId: 1, type: "faktura", status: "sent", number: "A", title: "A", issueDate: now, dueDate: now.addingTimeInterval(-2*86400), customerType: "b2c", taxMode: "normal", currency: "SEK", subtotalLabor: 0, subtotalMaterial: 0, subtotalOther: 0, vatRate: 0, vatAmount: 0, rotEligibleLabor: 0, rotReduction: 0, totalAmount: 100, paidAmount: 0, balanceDue: 100, relatedDocumentId: nil, notes: ""),
        BusinessDocument(id: 2, projectId: 1, type: "faktura", status: "sent", number: "B", title: "B", issueDate: now, dueDate: now.addingTimeInterval(-40*86400), customerType: "b2c", taxMode: "normal", currency: "SEK", subtotalLabor: 0, subtotalMaterial: 0, subtotalOther: 0, vatRate: 0, vatAmount: 0, rotEligibleLabor: 0, rotReduction: 0, totalAmount: 200, paidAmount: 0, balanceDue: 200, relatedDocumentId: nil, notes: "")
    ]

    let buckets = service.receivablesBuckets(docs, now: now)
    if !assert(buckets.first(where: { $0.title == "1–7 overdue" })?.documents.count == 1, "Receivables bucket 1–7 overdue") { failures += 1 }
    if !assert(buckets.first(where: { $0.title == "31+ overdue" })?.totalOutstanding == 200, "Receivables bucket 31+ overdue total") { failures += 1 }

    let manifest = service.buildExportManifest(appVersion: "1", schemaVersion: "6", files: ["a.csv", "b.csv"])
    if !assert(manifest.contains("\"schemaVersion\"") && manifest.contains("\"6\""), "Manifest contains schemaVersion") { failures += 1 }
    if !assert(manifest.contains("a.csv") && manifest.contains("b.csv"), "Manifest contains export files") { failures += 1 }

    print("SUMMARY: \(failures == 0 ? "PASS" : "FAIL")")
    return failures == 0 ? 0 : 1
}
