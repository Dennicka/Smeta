import XCTest
@testable import SmetaCore

final class DocumentDraftBuilderTests: XCTestCase {
    private let builder = DocumentDraftBuilder()

    func testBuildOffertMapsEstimateLinesFromRealData() {
        let context = makeContext()
        let result = builder.buildOffert(
            context: context,
            title: "Offert kök",
            useRot: true,
            now: Date(timeIntervalSince1970: 1_700_000_000),
            calendar: Calendar(identifier: .gregorian)
        )

        guard case .success(let payload) = result else {
            return XCTFail("Expected success payload")
        }

        XCTAssertEqual(payload.type, .offert)
        XCTAssertEqual(payload.lines.count, 2)
        XCTAssertEqual(payload.lines.map(\.lineType), ["labor", "material"])
        XCTAssertEqual(payload.lines[0].description, "Målning")
        XCTAssertEqual(payload.lines[1].description, "Takfärg")
    }

    func testBuildFakturaUsesRealEstimateDataAndTaxMode() {
        let context = makeContext()
        let result = builder.buildFaktura(
            context: context,
            title: "Faktura #1",
            reverseCharge: true,
            now: Date(timeIntervalSince1970: 1_700_000_000),
            calendar: Calendar(identifier: .gregorian)
        )

        guard case .success(let payload) = result else {
            return XCTFail("Expected success payload")
        }

        XCTAssertEqual(payload.type, .faktura)
        XCTAssertEqual(payload.customerType, .b2b)
        XCTAssertEqual(payload.taxMode, .reverseCharge)
        XCTAssertEqual(payload.vatRate, 0)
        XCTAssertEqual(payload.vatAmount, 0)
        XCTAssertEqual(payload.lines.count, 2)
    }

    func testTotalsVatAndRotSplitArePreservedInPayload() {
        let context = makeContext()
        let result = builder.buildOffert(
            context: context,
            title: "Offert med ROT",
            useRot: true,
            now: Date(timeIntervalSince1970: 1_700_000_000),
            calendar: Calendar(identifier: .gregorian)
        )

        guard case .success(let payload) = result else {
            return XCTFail("Expected success payload")
        }

        XCTAssertEqual(payload.subtotalLabor, 10 * 650, accuracy: 0.001)
        XCTAssertEqual(payload.subtotalMaterial, 12 * 90, accuracy: 0.001)
        XCTAssertEqual(payload.vatAmount, (10 * 650 + 12 * 90) * 0.25, accuracy: 0.001)
        XCTAssertEqual(payload.rotEligibleLabor, 10 * 650, accuracy: 0.001)
        XCTAssertEqual(payload.rotReduction, 10 * 650 * 0.3, accuracy: 0.001)
        XCTAssertEqual(payload.totalAmount, payload.subtotalLabor + payload.subtotalMaterial + payload.vatAmount - payload.rotReduction, accuracy: 0.001)
    }

    func testNoFakeFallbackWhenDataIsEmpty() {
        var context = makeContext()
        context.estimateLines = []

        let offert = builder.buildOffert(context: context, title: "Offert", useRot: false)
        let faktura = builder.buildFaktura(context: context, title: "Faktura", reverseCharge: false)

        guard case .incomplete(let offertReason) = offert else {
            return XCTFail("Offert should be incomplete")
        }
        guard case .incomplete(let fakturaReason) = faktura else {
            return XCTFail("Faktura should be incomplete")
        }

        XCTAssertTrue(offertReason.contains("inga rader"))
        XCTAssertTrue(fakturaReason.contains("inga rader"))
    }

    private func makeContext() -> DocumentBuildContext {
        let work = WorkCatalogItem(
            id: 100,
            name: "Paint walls",
            unit: "h",
            baseRatePerUnitHour: 1,
            basePrice: 650,
            swedishName: "Målning",
            sortOrder: 1,
            rotEligible: true
        )
        let material = MaterialCatalogItem(
            id: 200,
            name: "Paint",
            unit: "l",
            basePrice: 90,
            swedishName: "Takfärg",
            sortOrder: 2
        )

        return DocumentBuildContext(
            company: Company(id: 1, name: "Smeta AB", orgNumber: "556000-0000", email: "info@smeta.se", phone: "123"),
            client: Client(id: 2, name: "Client", email: "c@x.se", phone: "1", address: "Street"),
            project: Project(id: 3, clientId: 2, propertyId: 1, name: "Kitchen", speedProfileId: 1, createdAt: Date()),
            estimate: Estimate(id: 4, projectId: 3, speedProfileId: 1, laborRatePerHour: 650, overheadCoefficient: 1.1, createdAt: Date()),
            estimateLines: [
                EstimateLine(id: 1, estimateId: 4, roomId: 1, workItemId: 100, materialItemId: nil, quantity: 10, unitPrice: 650, coefficient: 1, type: "work"),
                EstimateLine(id: 2, estimateId: 4, roomId: 1, workItemId: nil, materialItemId: 200, quantity: 12, unitPrice: 90, coefficient: 1, type: "material")
            ],
            workItemsById: [100: work],
            materialItemsById: [200: material]
        )
    }
}
