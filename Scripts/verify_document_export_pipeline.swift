import Foundation

@main
struct VerifyDocumentExportPipeline {
    static func main() {
        let snapshotBuilder = DocumentSnapshotBuilder()
        let exportPipeline = DocumentExportPipeline(snapshotBuilder: snapshotBuilder)
        let now = Date(timeIntervalSince1970: 1_710_000_000)

        var failures = 0

        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            if condition() {
                print("[PASS] \(message)")
            } else {
                failures += 1
                print("[FAIL] \(message)")
            }
        }

        func makeDocument(id: Int64, type: DocumentType, status: DocumentStatus, title: String) -> BusinessDocument {
            BusinessDocument(
                id: id,
                projectId: 100 + id,
                type: type.rawValue,
                status: status.rawValue,
                number: "DOC-\(String(format: "%03d", id))",
                title: title,
                issueDate: now,
                dueDate: now.addingTimeInterval(86400 * 30),
                customerType: CustomerType.b2c.rawValue,
                taxMode: TaxMode.normal.rawValue,
                currency: "SEK",
                subtotalLabor: 100,
                subtotalMaterial: 50,
                subtotalOther: 0,
                vatRate: 0.25,
                vatAmount: 37.5,
                rotEligibleLabor: 0,
                rotReduction: 0,
                totalAmount: 187.5,
                paidAmount: 0,
                balanceDue: 187.5,
                relatedDocumentId: nil,
                notes: ""
            )
        }

        func makeLine(documentId: Int64, marker: String, total: Double = 100) -> BusinessDocumentLine {
            BusinessDocumentLine(
                id: 0,
                documentId: documentId,
                lineType: "labor",
                description: marker,
                quantity: 1,
                unit: "st",
                unitPrice: total,
                vatRate: 0.25,
                isRotEligible: false,
                total: total
            )
        }

        func makeFullSnapshot(document: BusinessDocument, lineMarker: String) throws -> DocumentSnapshot {
            let snapshot = snapshotBuilder.buildImmutableSnapshot(
                document: document,
                lines: [makeLine(documentId: document.id, marker: lineMarker, total: 111)],
                context: DocumentSnapshotBuildContext(
                    company: Company(id: 1, name: "Smeta AB", orgNumber: "556677-8899", email: "info@smeta.se", phone: "070-000000"),
                    client: Client(id: 1, name: "Client AB", email: "client@example.com", phone: "070-111111", address: "Kundgatan 1"),
                    project: Project(id: document.projectId, clientId: 1, propertyId: 1, name: "Kitchen", speedProfileId: 1, createdAt: now),
                    property: PropertyObject(id: 1, clientId: 1, name: "Objekt", address: "Adress"),
                    sourceEstimateId: 10,
                    relatedDocumentNumber: nil
                ),
                templateId: 1,
                snapshotCreatedAt: now
            )
            let json = try snapshotBuilder.serialize(snapshot: snapshot)
            return DocumentSnapshot(id: 1, documentId: document.id, templateId: 1, snapshotJSON: json, createdAt: now)
        }

        do {
            let cases: [(DocumentType, DocumentExportSource, String)] = [
                (.avtal, .snapshot, "SNAP-AVTAL"),
                (.faktura, .repository, "REPO-FAKTURA"),
                (.kreditfaktura, .snapshot, "SNAP-KRF"),
                (.ata, .snapshot, "SNAP-ATA"),
                (.paminnelse, .repository, "REPO-PAM")
            ]

            for (index, testCase) in cases.enumerated() {
                let doc = makeDocument(id: Int64(index + 1), type: testCase.0, status: .finalized, title: "Title-\(testCase.0.rawValue)")
                let repoLines = [makeLine(documentId: doc.id, marker: testCase.2)]
                let snapshots: [DocumentSnapshot]
                if testCase.1 == .snapshot {
                    snapshots = [try makeFullSnapshot(document: doc, lineMarker: testCase.2)]
                } else {
                    snapshots = []
                }

                let payload = try exportPipeline.buildPayload(document: doc, lines: repoLines, snapshots: snapshots)
                let expectedTitleToken: String = switch testCase.0 {
                case .ata: "äta"
                case .paminnelse: "påminnelse"
                default: testCase.0.rawValue
                }
                expect(payload.source == testCase.1, "\(testCase.0.rawValue): expected source \(testCase.1.rawValue)")
                expect(payload.title.lowercased().contains(expectedTitleToken), "\(testCase.0.rawValue): title contains document type")
                expect(payload.body.contains(testCase.2), "\(testCase.0.rawValue): payload contains real marker from source")
            }

            let missingLinesDoc = makeDocument(id: 99, type: .faktura, status: .draft, title: "No lines")
            do {
                _ = try exportPipeline.buildPayload(document: missingLinesDoc, lines: [], snapshots: [])
                expect(false, "missing lines should fail")
            } catch {
                expect(true, "missing lines rejected without fake fallback")
            }
        } catch {
            failures += 1
            print("[FAIL] Unexpected error: \(error)")
        }

        if failures == 0 {
            print("RESULT: PASS")
        } else {
            print("RESULT: FAIL (\(failures) checks failed)")
            exit(1)
        }
    }
}
