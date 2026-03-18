import Foundation

#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif

enum VerifyError: Error {
    case expectedFailure(String)
}

@main
struct VerifyFinalizeDocumentWithSnapshot {
    static func main() {
        var failures = 0
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            if condition() {
                print("[PASS] \(message)")
            } else {
                print("[FAIL] \(message)")
                failures += 1
            }
        }

        let dbFileName = "verify-finalize-\(UUID().uuidString).sqlite"

        do {
            let db = try SQLiteDatabase(filename: dbFileName)
            try db.initializeSchema()
            let repository = AppRepository(db: db)
            let snapshotBuilder = DocumentSnapshotBuilder()

            let companyId = try repository.insertCompany(Company(id: 0, name: "NordBygg AB", orgNumber: "556000-1234", email: "info@nordbygg.se", phone: "+46 8 555 00 00"))
            _ = companyId
            let clientId = try repository.insertClient(Client(id: 0, name: "Anna Svensson", email: "anna@client.se", phone: "+46 70 111 22 33", address: "Stockholm"))
            let propertyId = try repository.insertProperty(PropertyObject(id: 0, clientId: clientId, name: "Lägenhet", address: "Sveavägen 10"))
            let speedId = try repository.insertSpeedProfile(SpeedProfile(id: 0, name: "Стандарт", coefficient: 1.0, daysDivider: 7.0, sortOrder: 0))
            let projectId = try repository.insertProject(Project(id: 0, clientId: clientId, propertyId: propertyId, name: "Kitchen", speedProfileId: speedId, createdAt: Date()))

            _ = try repository.insertDocumentSeries(DocumentSeries(id: 0, documentType: DocumentType.faktura.rawValue, prefix: "FAK", nextNumber: 1, active: true))

            let draft = BusinessDocument(
                id: 0,
                projectId: projectId,
                type: DocumentType.faktura.rawValue,
                status: DocumentStatus.draft.rawValue,
                number: "",
                title: "Faktura kitchen",
                issueDate: Date(timeIntervalSince1970: 1_710_000_000),
                dueDate: Date(timeIntervalSince1970: 1_710_000_000 + 30 * 86_400),
                customerType: CustomerType.b2c.rawValue,
                taxMode: TaxMode.normal.rawValue,
                currency: "SEK",
                subtotalLabor: 6500,
                subtotalMaterial: 1080,
                subtotalOther: 0,
                vatRate: 0.25,
                vatAmount: 1895,
                rotEligibleLabor: 6500,
                rotReduction: 1950,
                totalAmount: 7525,
                paidAmount: 0,
                balanceDue: 7525,
                relatedDocumentId: nil,
                notes: "Repository flow check"
            )

            let lines = [
                BusinessDocumentLine(id: 0, documentId: 0, lineType: "labor", description: "Painting", quantity: 10, unit: "h", unitPrice: 650, vatRate: 0.25, isRotEligible: true, total: 6500),
                BusinessDocumentLine(id: 0, documentId: 0, lineType: "material", description: "Primer", quantity: 12, unit: "l", unitPrice: 90, vatRate: 0.25, isRotEligible: false, total: 1080)
            ]
            let draftId = try repository.createBusinessDocument(draft, lines: lines)

            try repository.finalizeDocumentWithSnapshot(documentId: draftId, templateId: nil) { finalizedDocument, finalizedLines in
                let context = DocumentSnapshotBuildContext(
                    company: try repository.companies().first,
                    client: try repository.clients().first(where: { $0.id == clientId }),
                    project: try repository.projects().first(where: { $0.id == projectId }),
                    property: try repository.properties().first(where: { $0.id == propertyId }),
                    sourceEstimateId: nil,
                    relatedDocumentNumber: nil
                )
                let snapshot = snapshotBuilder.buildImmutableSnapshot(
                    document: finalizedDocument,
                    lines: finalizedLines,
                    context: context,
                    templateId: nil
                )
                return try snapshotBuilder.serialize(snapshot: snapshot)
            }

            guard let finalized = try repository.businessDocument(documentId: draftId) else {
                throw VerifyError.expectedFailure("Finalized document not found")
            }
            let snapshots = try repository.documentSnapshots(documentId: draftId)
            guard let storedSnapshot = snapshots.first else {
                throw VerifyError.expectedFailure("Snapshot not stored")
            }

            expect(finalized.status == DocumentStatus.finalized.rawValue, "document status set to finalized")
            expect(!finalized.number.isEmpty, "document number assigned")

            let parsed = try snapshotBuilder.parse(snapshotJSON: storedSnapshot.snapshotJSON)
            switch parsed {
            case .full(let full):
                expect(full.document.number == finalized.number, "snapshot stores assigned final number")
                expect(full.document.statusAtSnapshotTime == DocumentStatus.finalized.rawValue, "snapshot stores finalized status")
                expect(!full.lines.isEmpty, "snapshot stores lines")
                expect(!full.document.title.isEmpty, "snapshot meta populated")
                expect(full.financials.totalAmount > 0, "snapshot totals populated")
            case .legacy:
                expect(false, "new repository flow must store full-v2 snapshot")
            }

            let secondDraft = BusinessDocument(
                id: 0,
                projectId: projectId,
                type: DocumentType.faktura.rawValue,
                status: DocumentStatus.draft.rawValue,
                number: "",
                title: "Faktura rollback",
                issueDate: Date(),
                dueDate: Date().addingTimeInterval(30 * 86_400),
                customerType: CustomerType.b2c.rawValue,
                taxMode: TaxMode.normal.rawValue,
                currency: "SEK",
                subtotalLabor: 100,
                subtotalMaterial: 0,
                subtotalOther: 0,
                vatRate: 0.25,
                vatAmount: 25,
                rotEligibleLabor: 0,
                rotReduction: 0,
                totalAmount: 125,
                paidAmount: 0,
                balanceDue: 125,
                relatedDocumentId: nil,
                notes: "rollback case"
            )
            let secondDraftId = try repository.createBusinessDocument(secondDraft, lines: [
                BusinessDocumentLine(id: 0, documentId: 0, lineType: "labor", description: "Rollback line", quantity: 1, unit: "h", unitPrice: 100, vatRate: 0.25, isRotEligible: false, total: 100)
            ])

            do {
                try repository.finalizeDocumentWithSnapshot(documentId: secondDraftId, templateId: nil) { _, _ in
                    throw VerifyError.expectedFailure("forced snapshot build failure")
                }
                expect(false, "snapshot builder failure should throw")
            } catch {
                print("[PASS] snapshot builder failure throws and triggers rollback")
            }

            if let rolledBackDoc = try repository.businessDocument(documentId: secondDraftId) {
                expect(rolledBackDoc.status == DocumentStatus.draft.rawValue, "rollback keeps document in draft status")
            } else {
                expect(false, "rollback doc still exists")
            }
            let rolledBackSnapshots = try repository.documentSnapshots(documentId: secondDraftId)
            expect(rolledBackSnapshots.isEmpty, "rollback prevents snapshot insertion")

            let legacyJSON = #"{"title":"Legacy","total":200,"vat":50,"rotReduction":0}"#
            let legacyParsed = try snapshotBuilder.parse(snapshotJSON: legacyJSON)
            if case .legacy = legacyParsed {
                print("[PASS] legacy snapshot parse still works")
            } else {
                print("[FAIL] legacy snapshot parse must return legacy format")
                failures += 1
            }

            if failures == 0 {
                print("RESULT: PASS")
                exit(EXIT_SUCCESS)
            } else {
                print("RESULT: FAIL (\(failures) checks failed)")
                exit(EXIT_FAILURE)
            }
        } catch {
            print("[FAIL] Unexpected verification error: \(error)")
            print("RESULT: FAIL")
            exit(EXIT_FAILURE)
        }
    }
}
