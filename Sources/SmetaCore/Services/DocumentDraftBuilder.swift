import Foundation

struct DocumentBuildContext {
    var company: Company?
    var client: Client?
    var project: Project?
    var estimate: Estimate?
    var estimateLines: [EstimateLine]
    var workItemsById: [Int64: WorkCatalogItem]
    var materialItemsById: [Int64: MaterialCatalogItem]
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
        calendar: Calendar
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
        guard total >= 0 else { return .incomplete("Ogiltigt totalsaldo") }

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
                totalAmount: total
            )
        )
    }
}
