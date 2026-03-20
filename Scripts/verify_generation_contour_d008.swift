import Foundation

@inline(__always)
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() {
        print("[PASS] \(message)")
    } else {
        fputs("[FAIL] \(message)\n", stderr)
        exit(1)
    }
}

func makeBaseContext() -> DocumentBuildContext {
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
        materialItemsById: [200: material],
        businessDocuments: [],
        businessDocumentLinesByDocumentId: [:],
        taxProfiles: [
            TaxProfile(id: 1, name: "B2C Moms", customerType: CustomerType.b2c.rawValue, taxMode: TaxMode.normal.rawValue, vatRate: 0.25, rotPercent: 0.3, active: true),
            TaxProfile(id: 2, name: "B2B Moms", customerType: CustomerType.b2b.rawValue, taxMode: TaxMode.normal.rawValue, vatRate: 0.25, rotPercent: 0, active: true),
            TaxProfile(id: 3, name: "B2B Reverse Charge", customerType: CustomerType.b2b.rawValue, taxMode: TaxMode.reverseCharge.rawValue, vatRate: 0, rotPercent: 0, active: true)
        ]
    )
}

@main
struct VerifyD008GenerationContour {
    static func main() {
        let builder = DocumentDraftBuilder()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        var context = makeBaseContext()
        let offert = BusinessDocument(id: 501, projectId: 3, type: DocumentType.offert.rawValue, status: DocumentStatus.finalized.rawValue, number: "OFF-501", title: "Offert", issueDate: now, dueDate: nil, customerType: CustomerType.b2c.rawValue, taxMode: TaxMode.normal.rawValue, currency: "SEK", subtotalLabor: 6500, subtotalMaterial: 1080, subtotalOther: 0, vatRate: 0.25, vatAmount: 1895, rotEligibleLabor: 6500, rotReduction: 0, totalAmount: 9475, paidAmount: 0, balanceDue: 9475, relatedDocumentId: nil, notes: "")
        let faktura = BusinessDocument(id: 601, projectId: 3, type: DocumentType.faktura.rawValue, status: DocumentStatus.finalized.rawValue, number: "FAK-601", title: "Faktura", issueDate: now.addingTimeInterval(60), dueDate: nil, customerType: CustomerType.b2b.rawValue, taxMode: TaxMode.normal.rawValue, currency: "SEK", subtotalLabor: 6500, subtotalMaterial: 1080, subtotalOther: 0, vatRate: 0.25, vatAmount: 1895, rotEligibleLabor: 0, rotReduction: 0, totalAmount: 9475, paidAmount: 0, balanceDue: 3000, relatedDocumentId: nil, notes: "")
        context.businessDocuments = [offert, faktura]
        context.businessDocumentLinesByDocumentId = [
            offert.id: [
                BusinessDocumentLine(id: 1, documentId: offert.id, lineType: "labor", description: "OFF-LINE", quantity: 10, unit: "h", unitPrice: 650, vatRate: 0.25, isRotEligible: true, total: 6500)
            ],
            faktura.id: [
                BusinessDocumentLine(id: 2, documentId: faktura.id, lineType: "material", description: "FAK-LINE", quantity: 12, unit: "l", unitPrice: 90, vatRate: 0.25, isRotEligible: false, total: 1080)
            ]
        ]

        switch builder.buildAvtal(context: context, title: "") {
        case .success(let payload):
            expect(payload.type == .avtal, "avtal: payload type")
            expect(payload.relatedDocumentId == offert.id, "avtal: related finalized offert")
            expect(payload.lines.contains(where: { $0.description == "OFF-LINE" }), "avtal: lines copied from repository offert")
        case .incomplete(let reason):
            fputs("[FAIL] avtal should be success, got: \(reason)\n", stderr)
            exit(1)
        }

        switch builder.buildKreditfaktura(context: context, title: "") {
        case .success(let payload):
            expect(payload.type == .kreditfaktura, "kreditfaktura: payload type")
            expect(payload.relatedDocumentId == faktura.id, "kreditfaktura: related finalized faktura")
            expect(payload.lines.contains(where: { $0.description == "FAK-LINE" && $0.total < 0 }), "kreditfaktura: negative lines from faktura")
        case .incomplete(let reason):
            fputs("[FAIL] kreditfaktura should be success, got: \(reason)\n", stderr)
            exit(1)
        }

        switch builder.buildAta(context: context, title: "") {
        case .success(let payload):
            expect(payload.type == .ata, "ata: payload type")
            expect(payload.lines.count == 2, "ata: lines mapped from estimate")
            expect(payload.notes.contains("kalkyl"), "ata: source notes mention estimate")
        case .incomplete(let reason):
            fputs("[FAIL] ata should be success, got: \(reason)\n", stderr)
            exit(1)
        }

        switch builder.buildPaminnelse(context: context, title: "") {
        case .success(let payload):
            expect(payload.type == .paminnelse, "paminnelse: payload type")
            expect(payload.relatedDocumentId == faktura.id, "paminnelse: related invoice id")
            expect(payload.lines.count == 1 && payload.lines[0].total == 3000, "paminnelse: amount from invoice balance")
        case .incomplete(let reason):
            fputs("[FAIL] paminnelse should be success, got: \(reason)\n", stderr)
            exit(1)
        }

        var missingContext = makeBaseContext()
        missingContext.businessDocuments = []
        switch builder.buildAvtal(context: missingContext, title: "") {
        case .success:
            fputs("[FAIL] avtal missing source must be incomplete\n", stderr)
            exit(1)
        case .incomplete(let reason):
            expect(reason.contains("finaliserad Offert"), "avtal: honest incomplete path")
        }

        switch builder.buildPaminnelse(context: missingContext, title: "") {
        case .success:
            fputs("[FAIL] paminnelse missing source must be incomplete\n", stderr)
            exit(1)
        case .incomplete(let reason):
            expect(reason.contains("obetald Faktura"), "paminnelse: honest incomplete path")
        }

        print("RESULT: PASS")
    }
}
