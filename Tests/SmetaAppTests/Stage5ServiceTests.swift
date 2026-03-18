import XCTest
@testable import SmetaApp

final class Stage5ServiceTests: XCTestCase {
    let service = Stage5Service()

    func testClientImportValidationDetectsMissingName() {
        let rows = service.parseCSV("name,email\n,foo@x.se\nAnna,anna@x.se")
        let preview = service.previewClientImport(rows: rows, existing: [])
        XCTAssertEqual(preview.issues.count, 1)
        XCTAssertEqual(preview.createCount, 1)
    }

    func testReceivablesBuckets() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let docs = [
            BusinessDocument(id: 1, projectId: 1, type: "faktura", status: "sent", number: "A", title: "A", issueDate: now, dueDate: now.addingTimeInterval(-2*86400), customerType: "b2c", taxMode: "normal", currency: "SEK", subtotalLabor: 0, subtotalMaterial: 0, subtotalOther: 0, vatRate: 0, vatAmount: 0, rotEligibleLabor: 0, rotReduction: 0, totalAmount: 100, paidAmount: 0, balanceDue: 100, relatedDocumentId: nil, notes: ""),
            BusinessDocument(id: 2, projectId: 1, type: "faktura", status: "sent", number: "B", title: "B", issueDate: now, dueDate: now.addingTimeInterval(-40*86400), customerType: "b2c", taxMode: "normal", currency: "SEK", subtotalLabor: 0, subtotalMaterial: 0, subtotalOther: 0, vatRate: 0, vatAmount: 0, rotEligibleLabor: 0, rotReduction: 0, totalAmount: 200, paidAmount: 0, balanceDue: 200, relatedDocumentId: nil, notes: "")
        ]
        let buckets = service.receivablesBuckets(docs, now: now)
        XCTAssertEqual(buckets.first(where: { $0.title == "1–7 overdue" })?.documents.count, 1)
        XCTAssertEqual(buckets.first(where: { $0.title == "31+ overdue" })?.totalOutstanding, 200)
    }

    func testManifestHasSchema() {
        let manifest = service.buildExportManifest(appVersion: "1", schemaVersion: "5", files: ["a.csv"])
        XCTAssertTrue(manifest.contains("schemaVersion"))
        XCTAssertTrue(manifest.contains("a.csv"))
    }
}
