import Foundation
#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif

@main
struct VerifyDocumentSnapshotBuilder {
    static func main() {
        let builder = DocumentSnapshotBuilder()
        let fixedNow = Date(timeIntervalSince1970: 1_710_000_000)

        let draftDocument = BusinessDocument(
            id: 501,
            projectId: 21,
            type: DocumentType.faktura.rawValue,
            status: DocumentStatus.draft.rawValue,
            number: "",
            title: "Faktura kök",
            issueDate: fixedNow,
            dueDate: fixedNow.addingTimeInterval(30 * 86_400),
            customerType: CustomerType.b2c.rawValue,
            taxMode: TaxMode.normal.rawValue,
            currency: "SEK",
            subtotalLabor: 6500,
            subtotalMaterial: 1080,
            subtotalOther: 250,
            vatRate: 0.25,
            vatAmount: 1957.5,
            rotEligibleLabor: 6500,
            rotReduction: 1950,
            totalAmount: 7837.5,
            paidAmount: 500,
            balanceDue: 7337.5,
            relatedDocumentId: 400,
            notes: "Freeze this invoice"
        )

        let lines = [
            BusinessDocumentLine(id: 1, documentId: 501, lineType: "labor", description: "Painting", quantity: 10, unit: "h", unitPrice: 650, vatRate: 0.25, isRotEligible: true, total: 6500),
            BusinessDocumentLine(id: 2, documentId: 501, lineType: "material", description: "Paint", quantity: 12, unit: "l", unitPrice: 90, vatRate: 0.25, isRotEligible: false, total: 1080),
            BusinessDocumentLine(id: 3, documentId: 501, lineType: "other", description: "Transport", quantity: 1, unit: "st", unitPrice: 250, vatRate: 0.25, isRotEligible: false, total: 250)
        ]

        let context = DocumentSnapshotBuildContext(
            company: Company(id: 1, name: "NordBygg AB", orgNumber: "556000-1234", email: "info@nordbygg.se", phone: "+46 8 555 00 00"),
            client: Client(id: 2, name: "Anna Svensson", email: "anna@client.se", phone: "+46 70 111 22 33", address: "Stockholm"),
            project: Project(id: 21, clientId: 2, propertyId: 3, name: "Kitchen Renovation", speedProfileId: 1, createdAt: fixedNow, pricingMode: PricingMode.fixed.rawValue, isDraft: false),
            property: PropertyObject(id: 3, clientId: 2, name: "Lägenhet Södermalm", address: "Sveavägen 10"),
            sourceEstimateId: 77,
            relatedDocumentNumber: "OFF-000300"
        )

        var failures = 0
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            if condition() {
                print("[PASS] \(message)")
            } else {
                print("[FAIL] \(message)")
                failures += 1
            }
        }

        do {
            let finalizedDocument = finalizeDraftLikeDocument(draftDocument, assignedNumber: "FAK-000501")
            let snapshot = builder.buildImmutableSnapshot(document: finalizedDocument, lines: lines, context: context, templateId: 9, snapshotCreatedAt: fixedNow)
            let json = try builder.serialize(snapshot: snapshot)

            expect(snapshot.schemaVersion == 2, "schema version is full snapshot v2")
            expect(snapshot.document.type == DocumentType.faktura.rawValue, "document meta included")
            expect(snapshot.document.number == "FAK-000501", "snapshot stores assigned final number")
            expect(!snapshot.document.number.isEmpty, "snapshot final number is not empty")
            expect(snapshot.document.statusAtSnapshotTime == DocumentStatus.finalized.rawValue, "snapshot stores finalized status")
            expect(snapshot.company.name == "NordBygg AB", "company display data included")
            expect(snapshot.client.name == "Anna Svensson", "client display data included")
            expect(snapshot.project.objectAddress == "Sveavägen 10", "project/object context included")
            expect(snapshot.lines.count == 3, "frozen lines included")
            expect(snapshot.lines.contains(where: { $0.lineType == "labor" && $0.total == 6500 }), "line totals frozen")
            expect(abs(snapshot.financials.vatAmount - 1957.5) < 0.001, "totals/tax values included")
            expect(snapshot.references.relatedDocumentNumber == "OFF-000300", "references included")

            let parsedNew = try builder.parse(snapshotJSON: json)
            switch parsedNew {
            case .full(let decoded):
                expect(decoded.schemaVersion == 2, "new snapshot recognized as full format")
            case .legacy:
                expect(false, "new snapshot should not be parsed as legacy")
            }

            let legacyJSON = #"{"title":"Legacy","total":1234,"vat":250,"rotReduction":100}"#
            let parsedLegacy = try builder.parse(snapshotJSON: legacyJSON)
            switch parsedLegacy {
            case .legacy(let decoded):
                expect(decoded.total == 1234, "legacy snapshot still readable")
            case .full:
                expect(false, "legacy snapshot should not be parsed as full")
            }

            expect(json.contains("\"lines\""), "serialized JSON contains lines block")
            expect(json.contains("\"financials\""), "serialized JSON contains financials block")
            expect(json.contains("\"references\""), "serialized JSON contains references block")
        } catch {
            print("[FAIL] Unexpected error: \(error.localizedDescription)")
            failures += 1
        }

        if failures == 0 {
            print("RESULT: PASS")
            exit(EXIT_SUCCESS)
        } else {
            print("RESULT: FAIL (\(failures) checks failed)")
            exit(EXIT_FAILURE)
        }
    }

    private static func finalizeDraftLikeDocument(_ draft: BusinessDocument, assignedNumber: String) -> BusinessDocument {
        BusinessDocument(
            id: draft.id,
            projectId: draft.projectId,
            type: draft.type,
            status: DocumentStatus.finalized.rawValue,
            number: assignedNumber,
            title: draft.title,
            issueDate: draft.issueDate,
            dueDate: draft.dueDate,
            customerType: draft.customerType,
            taxMode: draft.taxMode,
            currency: draft.currency,
            subtotalLabor: draft.subtotalLabor,
            subtotalMaterial: draft.subtotalMaterial,
            subtotalOther: draft.subtotalOther,
            vatRate: draft.vatRate,
            vatAmount: draft.vatAmount,
            rotEligibleLabor: draft.rotEligibleLabor,
            rotReduction: draft.rotReduction,
            totalAmount: draft.totalAmount,
            paidAmount: draft.paidAmount,
            balanceDue: draft.balanceDue,
            relatedDocumentId: draft.relatedDocumentId,
            notes: draft.notes
        )
    }
}
