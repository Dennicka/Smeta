import Foundation

struct DocumentBuildContext {
    var company: Company?
    var client: Client?
    var project: Project?
    var estimate: Estimate?
    var estimateLines: [EstimateLine]
    var workItemsById: [Int64: WorkCatalogItem]
    var materialItemsById: [Int64: MaterialCatalogItem]
    var businessDocuments: [BusinessDocument] = []
    var businessDocumentLinesByDocumentId: [Int64: [BusinessDocumentLine]] = [:]
}

struct DocumentDraftPayload {
    var type: DocumentType
    var projectId: Int64
    var title: String
    var customerType: CustomerType
    var taxMode: TaxMode
    var currency: String
    var issueDate: Date
    var dueDate: Date?
    var notes: String
    var lines: [BusinessDocumentLine]
    var subtotalLabor: Double
    var subtotalMaterial: Double
    var subtotalOther: Double
    var vatRate: Double
    var vatAmount: Double
    var rotEligibleLabor: Double
    var rotReduction: Double
    var totalAmount: Double
    var relatedDocumentId: Int64?
}

enum DocumentBuildResult {
    case success(DocumentDraftPayload)
    case incomplete(String)
}

struct DocumentDraftBuilder {
    func buildOffert(
        context: DocumentBuildContext,
        title: String,
        useRot: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DocumentBuildResult {
        guard let project = context.project else { return .incomplete("Projekt saknas") }
        guard context.company != nil else { return .incomplete("Företagsuppgifter saknas") }
        guard context.client != nil else { return .incomplete("Kunduppgifter saknas") }
        guard context.estimate != nil else { return .incomplete("Kalkyl saknas för projektet") }

        let mappedLines = mapEstimateLines(context: context, vatRate: 0.25)
        guard !mappedLines.isEmpty else {
            return .incomplete("Offert kan inte skapas: kalkylen innehåller inga rader")
        }

        return buildPayload(
            type: .offert,
            project: project,
            title: title,
            customerType: .b2c,
            taxMode: .normal,
            notes: "Källa: projekt/kalkyl",
            lines: mappedLines,
            vatRate: 0.25,
            rotPercent: useRot ? 0.3 : 0,
            now: now,
            calendar: calendar
        )
    }

    func buildFaktura(
        context: DocumentBuildContext,
        title: String,
        reverseCharge: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DocumentBuildResult {
        guard let project = context.project else { return .incomplete("Projekt saknas") }
        guard context.company != nil else { return .incomplete("Företagsuppgifter saknas") }
        guard context.client != nil else { return .incomplete("Kunduppgifter saknas") }
        guard context.estimate != nil else { return .incomplete("Faktura kan inte skapas utan kalkyl") }

        let vatRate = reverseCharge ? 0 : 0.25
        let mappedLines = mapEstimateLines(context: context, vatRate: vatRate)
        guard !mappedLines.isEmpty else {
            return .incomplete("Faktura kan inte skapas: kalkylen innehåller inga rader")
        }

        return buildPayload(
            type: .faktura,
            project: project,
            title: title,
            customerType: reverseCharge ? .b2b : .b2c,
            taxMode: reverseCharge ? .reverseCharge : .normal,
            notes: "Källa: projekt/kalkyl",
            lines: mappedLines,
            vatRate: vatRate,
            rotPercent: 0,
            now: now,
            calendar: calendar
        )
    }

    func buildAvtal(
        context: DocumentBuildContext,
        title: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DocumentBuildResult {
        guard let project = context.project else { return .incomplete("Projekt saknas") }
        guard context.company != nil else { return .incomplete("Företagsuppgifter saknas") }
        guard context.client != nil else { return .incomplete("Kunduppgifter saknas") }

        guard let offert = latestSourceDocument(in: context, type: .offert) else {
            return .incomplete("Avtal kan inte skapas utan finaliserad Offert")
        }
        guard let sourceLines = context.businessDocumentLinesByDocumentId[offert.id], !sourceLines.isEmpty else {
            return .incomplete("Avtal kan inte skapas: Offert saknar rader")
        }

        let lines = cloneLines(sourceLines)
        let payloadTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Avtal \(project.name)" : title
        return buildPayload(
            type: .avtal,
            project: project,
            title: payloadTitle,
            customerType: CustomerType(rawValue: offert.customerType) ?? .b2c,
            taxMode: TaxMode(rawValue: offert.taxMode) ?? .normal,
            notes: "Källa: finaliserad Offert \(offert.number)",
            lines: lines,
            vatRate: offert.vatRate,
            rotPercent: 0,
            now: now,
            calendar: calendar,
            relatedDocumentId: offert.id
        )
    }

    func buildKreditfaktura(
        context: DocumentBuildContext,
        title: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DocumentBuildResult {
        guard let project = context.project else { return .incomplete("Projekt saknas") }
        guard context.company != nil else { return .incomplete("Företagsuppgifter saknas") }
        guard context.client != nil else { return .incomplete("Kunduppgifter saknas") }

        guard let faktura = latestSourceDocument(in: context, type: .faktura) else {
            return .incomplete("Kreditfaktura kan inte skapas utan finaliserad Faktura")
        }
        guard let sourceLines = context.businessDocumentLinesByDocumentId[faktura.id], !sourceLines.isEmpty else {
            return .incomplete("Kreditfaktura kan inte skapas: Faktura saknar rader")
        }

        let lines = sourceLines.map { line in
            BusinessDocumentLine(
                id: 0,
                documentId: 0,
                lineType: line.lineType,
                description: line.description,
                quantity: abs(line.quantity),
                unit: line.unit,
                unitPrice: -abs(line.unitPrice),
                vatRate: line.vatRate,
                isRotEligible: line.isRotEligible,
                total: -abs(line.total)
            )
        }

        let payloadTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Kreditfaktura \(faktura.number)" : title
        return buildPayload(
            type: .kreditfaktura,
            project: project,
            title: payloadTitle,
            customerType: CustomerType(rawValue: faktura.customerType) ?? .b2c,
            taxMode: TaxMode(rawValue: faktura.taxMode) ?? .normal,
            notes: "Källa: finaliserad Faktura \(faktura.number)",
            lines: lines,
            vatRate: faktura.vatRate,
            rotPercent: 0,
            now: now,
            calendar: calendar,
            allowNegativeTotal: true,
            relatedDocumentId: faktura.id
        )
    }

    func buildAta(
        context: DocumentBuildContext,
        title: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DocumentBuildResult {
        guard let project = context.project else { return .incomplete("Projekt saknas") }
        guard context.company != nil else { return .incomplete("Företagsuppgifter saknas") }
        guard context.client != nil else { return .incomplete("Kunduppgifter saknas") }
        guard context.estimate != nil else { return .incomplete("ÄTA kan inte skapas utan kalkyl") }

        let mappedLines = mapEstimateLines(context: context, vatRate: 0.25)
        guard !mappedLines.isEmpty else {
            return .incomplete("ÄTA kan inte skapas: kalkylen innehåller inga rader")
        }

        let payloadTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "ÄTA \(project.name)" : title
        return buildPayload(
            type: .ata,
            project: project,
            title: payloadTitle,
            customerType: .b2c,
            taxMode: .normal,
            notes: "Källa: projekt/kalkyl (ÄTA-underlag)",
            lines: mappedLines,
            vatRate: 0.25,
            rotPercent: 0,
            now: now,
            calendar: calendar
        )
    }

    func buildPaminnelse(
        context: DocumentBuildContext,
        title: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DocumentBuildResult {
        guard let project = context.project else { return .incomplete("Projekt saknas") }
        guard context.company != nil else { return .incomplete("Företagsuppgifter saknas") }
        guard context.client != nil else { return .incomplete("Kunduppgifter saknas") }

        guard let invoice = latestSourceDocument(in: context, type: .faktura, requiringBalanceDue: true) else {
            return .incomplete("Påminnelse kan inte skapas utan obetald Faktura")
        }

        let line = BusinessDocumentLine(
            id: 0,
            documentId: 0,
            lineType: "other",
            description: "Påminnelse för faktura \(invoice.number.isEmpty ? "DRAFT-\(invoice.id)" : invoice.number)",
            quantity: 1,
            unit: "st",
            unitPrice: invoice.balanceDue,
            vatRate: 0,
            isRotEligible: false,
            total: invoice.balanceDue
        )
        let payloadTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Påminnelse \(invoice.number)" : title
        return buildPayload(
            type: .paminnelse,
            project: project,
            title: payloadTitle,
            customerType: CustomerType(rawValue: invoice.customerType) ?? .b2c,
            taxMode: .normal,
            notes: "Källa: obetald Faktura \(invoice.number)",
            lines: [line],
            vatRate: 0,
            rotPercent: 0,
            now: now,
            calendar: calendar,
            relatedDocumentId: invoice.id
        )
    }

    private func mapEstimateLines(context: DocumentBuildContext, vatRate: Double) -> [BusinessDocumentLine] {
        context.estimateLines.compactMap { line in
            guard line.quantity > 0, line.unitPrice >= 0 else { return nil }

            if let workId = line.workItemId,
               let work = context.workItemsById[workId] {
                return BusinessDocumentLine(
                    id: 0,
                    documentId: 0,
                    lineType: "labor",
                    description: work.swedishName.isEmpty ? work.name : work.swedishName,
                    quantity: line.quantity,
                    unit: work.unit,
                    unitPrice: line.unitPrice,
                    vatRate: vatRate,
                    isRotEligible: work.rotEligible,
                    total: line.quantity * line.unitPrice
                )
            }

            if let materialId = line.materialItemId,
               let material = context.materialItemsById[materialId] {
                return BusinessDocumentLine(
                    id: 0,
                    documentId: 0,
                    lineType: "material",
                    description: material.swedishName.isEmpty ? material.name : material.swedishName,
                    quantity: line.quantity,
                    unit: material.unit,
                    unitPrice: line.unitPrice,
                    vatRate: vatRate,
                    isRotEligible: false,
                    total: line.quantity * line.unitPrice
                )
            }

            return nil
        }
    }

    private func buildPayload(
        type: DocumentType,
        project: Project,
        title: String,
        customerType: CustomerType,
        taxMode: TaxMode,
        notes: String,
        lines: [BusinessDocumentLine],
        vatRate: Double,
        rotPercent: Double,
        now: Date,
        calendar: Calendar,
        allowNegativeTotal: Bool = false,
        relatedDocumentId: Int64? = nil
    ) -> DocumentBuildResult {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return .incomplete("Titel saknas") }

        let labor = lines.filter { $0.lineType == "labor" }.reduce(0) { $0 + $1.total }
        let material = lines.filter { $0.lineType == "material" }.reduce(0) { $0 + $1.total }
        let other = lines.filter { $0.lineType == "other" }.reduce(0) { $0 + $1.total }
        let subtotal = labor + material + other
        let rotEligible = lines.filter { $0.isRotEligible }.reduce(0) { $0 + $1.total }
        let rotReduction = rotEligible * rotPercent
        let vatAmount = subtotal * vatRate
        let total = subtotal + vatAmount - rotReduction
        guard allowNegativeTotal || total >= 0 else { return .incomplete("Ogiltigt totalsaldo") }

        return .success(
            DocumentDraftPayload(
                type: type,
                projectId: project.id,
                title: trimmedTitle,
                customerType: customerType,
                taxMode: taxMode,
                currency: "SEK",
                issueDate: now,
                dueDate: calendar.date(byAdding: .day, value: 30, to: now),
                notes: notes,
                lines: lines,
                subtotalLabor: labor,
                subtotalMaterial: material,
                subtotalOther: other,
                vatRate: vatRate,
                vatAmount: vatAmount,
                rotEligibleLabor: rotEligible,
                rotReduction: rotReduction,
                totalAmount: total,
                relatedDocumentId: relatedDocumentId
            )
        )
    }

    private func latestSourceDocument(
        in context: DocumentBuildContext,
        type: DocumentType,
        requiringBalanceDue: Bool = false
    ) -> BusinessDocument? {
        context.businessDocuments
            .filter { $0.type == type.rawValue && $0.status == DocumentStatus.finalized.rawValue }
            .filter { !requiringBalanceDue || $0.balanceDue > 0 }
            .sorted(by: { $0.issueDate > $1.issueDate })
            .first
    }

    private func cloneLines(_ lines: [BusinessDocumentLine]) -> [BusinessDocumentLine] {
        lines.map {
            BusinessDocumentLine(
                id: 0,
                documentId: 0,
                lineType: $0.lineType,
                description: $0.description,
                quantity: $0.quantity,
                unit: $0.unit,
                unitPrice: $0.unitPrice,
                vatRate: $0.vatRate,
                isRotEligible: $0.isRotEligible,
                total: $0.total
            )
        }
    }
}
