import XCTest
@testable import SmetaCore

final class DocumentSnapshotBuilderTests: XCTestCase {
    private let builder = DocumentSnapshotBuilder()

    func testBuildFullSnapshotForOffertLikeDocument() throws {
        let fixedNow = Date(timeIntervalSince1970: 1_710_000_000)
        let document = makeDocument(
            type: DocumentType.offert.rawValue,
            status: DocumentStatus.finalized.rawValue,
            number: "OFF-000321"
        )
        let lines = makeLines(documentId: document.id)
        let context = makeContext(relatedNumber: "FAK-000111")

        let snapshot = builder.buildImmutableSnapshot(
            document: document,
            lines: lines,
            context: context,
            templateId: 9,
            snapshotCreatedAt: fixedNow
        )

        XCTAssertEqual(snapshot.schemaVersion, 2)
        XCTAssertEqual(snapshot.document.type, DocumentType.offert.rawValue)
        XCTAssertEqual(snapshot.document.number, "OFF-000321")
        XCTAssertEqual(snapshot.document.statusAtSnapshotTime, DocumentStatus.finalized.rawValue)
        XCTAssertEqual(snapshot.document.templateId, 9)
        XCTAssertEqual(snapshot.project.projectName, "Kitchen Renovation")
        XCTAssertEqual(snapshot.project.objectAddress, "Sveavägen 10")
        XCTAssertEqual(snapshot.references.relatedDocumentNumber, "FAK-000111")
    }

    func testFinalizedSnapshotUsesAssignedFinalNumberNotDraftNumber() {
        let draft = makeDocument(type: DocumentType.faktura.rawValue, status: DocumentStatus.draft.rawValue, number: "")
        let finalized = BusinessDocument(
            id: draft.id,
            projectId: draft.projectId,
            type: draft.type,
            status: DocumentStatus.finalized.rawValue,
            number: "FAK-000777",
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

        let snapshot = builder.buildImmutableSnapshot(
            document: finalized,
            lines: makeLines(documentId: finalized.id),
            context: makeContext(relatedNumber: nil),
            templateId: 2,
            snapshotCreatedAt: Date(timeIntervalSince1970: 1_710_000_050)
        )

        XCTAssertEqual(snapshot.document.number, "FAK-000777")
        XCTAssertFalse(snapshot.document.number.isEmpty)
        XCTAssertEqual(snapshot.document.statusAtSnapshotTime, DocumentStatus.finalized.rawValue)
    }

    func testSnapshotFreezesLinesTotalsAndTax() {
        let document = makeDocument(type: DocumentType.faktura.rawValue, status: DocumentStatus.sent.rawValue)
        let lines = makeLines(documentId: document.id)

        let snapshot = builder.buildImmutableSnapshot(
            document: document,
            lines: lines,
            context: makeContext(relatedNumber: nil),
            templateId: nil,
            snapshotCreatedAt: Date(timeIntervalSince1970: 1_710_000_001)
        )

        XCTAssertEqual(snapshot.lines.count, 2)
        XCTAssertEqual(snapshot.lines[0].lineType, "labor")
        XCTAssertEqual(snapshot.lines[0].quantity, 10)
        XCTAssertEqual(snapshot.lines[1].lineType, "material")
        XCTAssertEqual(snapshot.financials.subtotalLabor, 6500, accuracy: 0.001)
        XCTAssertEqual(snapshot.financials.subtotalMaterial, 1080, accuracy: 0.001)
        XCTAssertEqual(snapshot.financials.vatRate, 0.25, accuracy: 0.001)
        XCTAssertEqual(snapshot.financials.vatAmount, 1895, accuracy: 0.001)
        XCTAssertEqual(snapshot.financials.rotReduction, 1950, accuracy: 0.001)
        XCTAssertEqual(snapshot.financials.totalAmount, 7525, accuracy: 0.001)
    }

    func testSnapshotSerializationAndParseDistinguishesFormats() throws {
        let document = makeDocument(type: DocumentType.faktura.rawValue, status: DocumentStatus.sent.rawValue)
        let snapshot = builder.buildImmutableSnapshot(
            document: document,
            lines: makeLines(documentId: document.id),
            context: makeContext(relatedNumber: "OFF-000001"),
            templateId: 1,
            snapshotCreatedAt: Date(timeIntervalSince1970: 1_710_000_002)
        )

        let fullJSON = try builder.serialize(snapshot: snapshot)
        let parsedFull = try builder.parse(snapshotJSON: fullJSON)
        switch parsedFull {
        case .full(let decoded):
            XCTAssertEqual(decoded.schemaVersion, 2)
            XCTAssertEqual(decoded.references.relatedDocumentNumber, "OFF-000001")
            XCTAssertEqual(parsedFull.format, "full-v2")
        case .legacy:
            XCTFail("Expected full snapshot")
        }

        let legacyJSON = #"{"title":"Legacy","total":1000,"vat":250,"rotReduction":0}"#
        let parsedLegacy = try builder.parse(snapshotJSON: legacyJSON)
        switch parsedLegacy {
        case .legacy(let legacy):
            XCTAssertEqual(legacy.title, "Legacy")
            XCTAssertEqual(legacy.total, 1000)
            XCTAssertEqual(parsedLegacy.format, "legacy-v1")
        case .full:
            XCTFail("Expected legacy snapshot")
        }
    }

    private func makeContext(relatedNumber: String?) -> DocumentSnapshotBuildContext {
        DocumentSnapshotBuildContext(
            company: Company(id: 1, name: "NordBygg AB", orgNumber: "556000-1234", email: "info@nordbygg.se", phone: "+46 8 555 00 00"),
            client: Client(id: 11, name: "Anna Svensson", email: "anna@client.se", phone: "+46 70 111 22 33", address: "Stockholm"),
            project: Project(id: 21, clientId: 11, propertyId: 31, name: "Kitchen Renovation", speedProfileId: 1, createdAt: Date(timeIntervalSince1970: 1_709_000_000), pricingMode: PricingMode.fixed.rawValue, isDraft: false),
            property: PropertyObject(id: 31, clientId: 11, name: "Lägenhet Södermalm", address: "Sveavägen 10"),
            sourceEstimateId: 41,
            relatedDocumentNumber: relatedNumber
        )
    }

    private func makeDocument(type: String, status: String, number: String = "TMP-1") -> BusinessDocument {
        BusinessDocument(
            id: 51,
            projectId: 21,
            type: type,
            status: status,
            number: number,
            title: "Kök dokument",
            issueDate: Date(timeIntervalSince1970: 1_710_000_000),
            dueDate: Date(timeIntervalSince1970: 1_710_864_000),
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
            paidAmount: 1200,
            balanceDue: 6325,
            relatedDocumentId: 7,
            notes: "Snapshot note"
        )
    }

    private func makeLines(documentId: Int64) -> [BusinessDocumentLine] {
        [
            BusinessDocumentLine(id: 1, documentId: documentId, lineType: "labor", description: "Painting walls", quantity: 10, unit: "h", unitPrice: 650, vatRate: 0.25, isRotEligible: true, total: 6500),
            BusinessDocumentLine(id: 2, documentId: documentId, lineType: "material", description: "Primer", quantity: 12, unit: "l", unitPrice: 90, vatRate: 0.25, isRotEligible: false, total: 1080)
        ]
    }
}
