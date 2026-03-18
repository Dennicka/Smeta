import Foundation

@inline(__always)
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@inline(__always)
func expectContains(_ text: String, _ fragment: String, _ message: String) {
    if !text.contains(fragment) {
        fputs("FAIL: \(message). Got: \(text)\n", stderr)
        exit(1)
    }
}

func makeContext(estimateLines: [EstimateLine], b2cVatRate: Double = 0.25) -> DocumentBuildContext {
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
        estimateLines: estimateLines,
        workItemsById: [100: work],
        materialItemsById: [200: material],
        taxProfiles: [
            TaxProfile(id: 1, name: "B2C Moms", customerType: CustomerType.b2c.rawValue, taxMode: TaxMode.normal.rawValue, vatRate: b2cVatRate, rotPercent: 0.3, active: true),
            TaxProfile(id: 2, name: "B2B Moms", customerType: CustomerType.b2b.rawValue, taxMode: TaxMode.normal.rawValue, vatRate: 0.25, rotPercent: 0, active: true),
            TaxProfile(id: 3, name: "B2B Reverse Charge", customerType: CustomerType.b2b.rawValue, taxMode: TaxMode.reverseCharge.rawValue, vatRate: 0, rotPercent: 0, active: true)
        ]
    )
}

@main
struct DocumentDraftBuilderVerification {
    static func main() {
        let builder = DocumentDraftBuilder()
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
        let calendar = Calendar(identifier: .gregorian)

        let populatedLines = [
            EstimateLine(id: 1, estimateId: 4, roomId: 1, workItemId: 100, materialItemId: nil, quantity: 10, unitPrice: 650, coefficient: 1, type: "work"),
            EstimateLine(id: 2, estimateId: 4, roomId: 1, workItemId: nil, materialItemId: 200, quantity: 12, unitPrice: 90, coefficient: 1, type: "material")
        ]

        let readyContext = makeContext(estimateLines: populatedLines)
        let changedVatContext = makeContext(estimateLines: populatedLines, b2cVatRate: 0.12)

        // Scenario A: Offert draft is created from estimate lines
        switch builder.buildOffert(context: readyContext, title: "Offert kök", useRot: true, now: fixedNow, calendar: calendar) {
        case .success(let payload):
            expect(payload.type == .offert, "Offert payload type mismatch")
            expect(payload.lines.count == 2, "Offert line count mismatch")
            expect(payload.lines[0].lineType == "labor", "Offert first line should be labor")
            expect(payload.lines[1].lineType == "material", "Offert second line should be material")
            expect(abs(payload.subtotalLabor - 6500) < 0.001, "Offert subtotalLabor mismatch")
            expect(abs(payload.subtotalMaterial - 1080) < 0.001, "Offert subtotalMaterial mismatch")
            expect(abs(payload.vatAmount - 1895) < 0.001, "Offert VAT mismatch")
            expect(abs(payload.rotReduction - 1950) < 0.001, "Offert ROT mismatch")
        case .incomplete(let reason):
            fputs("FAIL: Offert expected success, got incomplete: \(reason)\n", stderr)
            exit(1)
        }

        // Scenario B: Faktura draft is created from estimate lines
        switch builder.buildFaktura(context: readyContext, title: "Faktura kök", reverseCharge: true, now: fixedNow, calendar: calendar) {
        case .success(let payload):
            expect(payload.type == .faktura, "Faktura payload type mismatch")
            expect(payload.lines.count == 2, "Faktura line count mismatch")
            expect(payload.taxMode == .reverseCharge, "Faktura tax mode mismatch")
            expect(payload.vatRate == 0, "Faktura VAT rate should be 0 in reverse charge")
            expect(payload.vatAmount == 0, "Faktura VAT amount should be 0 in reverse charge")
        case .incomplete(let reason):
            fputs("FAIL: Faktura expected success, got incomplete: \(reason)\n", stderr)
            exit(1)
        }

        // Scenario C: Empty estimate lines should not create draft
        let emptyContext = makeContext(estimateLines: [])
        switch builder.buildOffert(context: emptyContext, title: "Offert tom", useRot: false, now: fixedNow, calendar: calendar) {
        case .success:
            fputs("FAIL: Offert should be incomplete on empty estimate lines\n", stderr)
            exit(1)
        case .incomplete(let reason):
            expectContains(reason, "inga rader", "Offert incomplete reason must be honest")
        }

        switch builder.buildFaktura(context: emptyContext, title: "Faktura tom", reverseCharge: false, now: fixedNow, calendar: calendar) {
        case .success:
            fputs("FAIL: Faktura should be incomplete on empty estimate lines\n", stderr)
            exit(1)
        case .incomplete(let reason):
            expectContains(reason, "inga rader", "Faktura incomplete reason must be honest")
        }

        switch (builder.buildOffert(context: readyContext, title: "Offert VAT 25", useRot: false, now: fixedNow, calendar: calendar),
                builder.buildOffert(context: changedVatContext, title: "Offert VAT 12", useRot: false, now: fixedNow, calendar: calendar)) {
        case (.success(let baseline), .success(let changed)):
            expect(abs(baseline.vatRate - 0.25) < 0.001, "Baseline VAT profile should be used")
            expect(abs(changed.vatRate - 0.12) < 0.001, "Changed VAT profile should be used")
            expect(abs(changed.vatAmount - baseline.vatAmount) > 0.001, "Changing VAT profile must change VAT amount")
        default:
            fputs("FAIL: VAT profile comparison expected success payloads\n", stderr)
            exit(1)
        }

        print("VERIFY_DOCUMENT_DRAFT_BUILDER: PASS")
    }
}
