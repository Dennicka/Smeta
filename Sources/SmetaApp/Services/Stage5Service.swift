import Foundation

struct CSVRow {
    var values: [String: String]
}

final class Stage5Service {
    func parseCSV(_ raw: String) -> [CSVRow] {
        let lines = raw.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let header = lines.first else { return [] }
        let columns = header.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        return lines.dropFirst().map { line in
            let parts = line.split(separator: ",", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            var dict: [String: String] = [:]
            for (idx, col) in columns.enumerated() where idx < parts.count { dict[col] = parts[idx] }
            return CSVRow(values: dict)
        }
    }

    func previewClientImport(rows: [CSVRow], existing: [Client]) -> ImportPreview<Client> {
        var mapped: [Client] = []
        var issues: [ImportIssue] = []
        var createCount = 0
        var updateCount = 0
        for (index, row) in rows.enumerated() {
            let name = row.values["name", default: ""].trimmingCharacters(in: .whitespaces)
            if name.isEmpty {
                issues.append(ImportIssue(row: index + 2, field: "name", message: "Name is required"))
                continue
            }
            let email = row.values["email", default: ""]
            let phone = row.values["phone", default: ""]
            let address = row.values["address", default: ""]
            if let current = existing.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                mapped.append(Client(id: current.id, name: name, email: email, phone: phone, address: address))
                updateCount += 1
            } else {
                mapped.append(Client(id: 0, name: name, email: email, phone: phone, address: address))
                createCount += 1
            }
        }
        return ImportPreview(rows: mapped, issues: issues, createCount: createCount, updateCount: updateCount)
    }

    func profitability(projectId: Int64, estimateLines: [EstimateLine], materials: [MaterialCatalogItem], documents: [BusinessDocument]) -> ProjectProfitability {
        let plannedLabor = estimateLines.filter { $0.type == "work" }.reduce(0) { $0 + $1.unitPrice }
        let plannedMaterial = estimateLines.filter { $0.type == "material" }.reduce(0) { $0 + $1.unitPrice }
        let matCostLookup = Dictionary(uniqueKeysWithValues: materials.map { ($0.id, $0.purchasePrice) })
        let plannedCost = estimateLines.reduce(0) { partial, line in
            let cost = line.materialItemId.flatMap { matCostLookup[$0] } ?? line.unitPrice * 0.45
            return partial + (line.quantity * cost)
        }
        let invoiced = documents.filter { $0.type == DocumentType.faktura.rawValue }.reduce(0) { $0 + $1.totalAmount }
        let paid = documents.reduce(0) { $0 + $1.paidAmount }
        let outstanding = documents.reduce(0) { $0 + $1.balanceDue }
        let credited = documents.filter { $0.type == DocumentType.kreditfaktura.rawValue }.reduce(0) { $0 + $1.totalAmount }
        let expectedRot = documents.reduce(0) { $0 + $1.rotReduction }
        return ProjectProfitability(projectId: projectId,
                                    plannedLaborRevenue: plannedLabor,
                                    plannedMaterialRevenue: plannedMaterial,
                                    plannedCost: plannedCost,
                                    plannedGrossMargin: plannedLabor + plannedMaterial - plannedCost,
                                    actualInvoicedAmount: invoiced,
                                    paidAmount: paid,
                                    outstandingAmount: outstanding,
                                    expectedROTClaimAmount: expectedRot,
                                    creditedAmount: credited)
    }

    func receivablesBuckets(_ docs: [BusinessDocument], now: Date = Date()) -> [ReceivableBucket] {
        let cal = Calendar.current
        var current: [BusinessDocument] = []
        var oneToSeven: [BusinessDocument] = []
        var eightToThirty: [BusinessDocument] = []
        var overThirty: [BusinessDocument] = []

        for doc in docs where doc.balanceDue > 0 {
            guard let due = doc.dueDate else { current.append(doc); continue }
            let days = cal.dateComponents([.day], from: due, to: now).day ?? 0
            switch days {
            case ..<1: current.append(doc)
            case 1...7: oneToSeven.append(doc)
            case 8...30: eightToThirty.append(doc)
            default: overThirty.append(doc)
            }
        }

        func bucket(_ title: String, _ docs: [BusinessDocument]) -> ReceivableBucket {
            ReceivableBucket(title: title, documents: docs, totalOutstanding: docs.reduce(0) { $0 + $1.balanceDue })
        }

        return [
            bucket("current", current),
            bucket("1–7 overdue", oneToSeven),
            bucket("8–30 overdue", eightToThirty),
            bucket("31+ overdue", overThirty)
        ]
    }

    func buildExportManifest(appVersion: String, schemaVersion: String, files: [String]) -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let payload: [String: Any] = [
            "exportTimestamp": timestamp,
            "appVersion": appVersion,
            "schemaVersion": schemaVersion,
            "files": files
        ]
        let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        return String(data: data ?? Data(), encoding: .utf8) ?? "{}"
    }
}
