import Foundation

struct CSVRow {
    var values: [String: String]
}

final class Stage5Service {
    private let emailRegex = try! NSRegularExpression(
        pattern: "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$",
        options: [.caseInsensitive]
    )

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
        let report = buildClientImportReport(rows: rows, existing: existing)
        let mapped = report.actions.compactMap { action -> Client? in
            switch action {
            case .create(let client), .update(let client):
                return client
            case .skip, .invalid:
                return nil
            }
        }
        return ImportPreview(rows: mapped,
                             issues: report.issues,
                             createCount: report.created,
                             updateCount: report.updated,
                             skippedCount: report.skipped,
                             invalidCount: report.invalid)
    }

    func buildClientImportReport(rows: [CSVRow], existing: [Client]) -> ClientImportReport {
        let existingByEmail = Dictionary(uniqueKeysWithValues: existing.compactMap { client -> (String, Client)? in
            let normalized = normalizeEmail(client.email)
            return normalized.isEmpty ? nil : (normalized, client)
        })
        let existingByExternalId = Dictionary(uniqueKeysWithValues: existing.map { (String($0.id), $0) })

        var actions: [ClientImportAction] = []
        var issues: [ImportIssue] = []
        var seenKeys: Set<String> = []
        var created = 0
        var updated = 0
        var skipped = 0
        var invalid = 0

        for (index, row) in rows.enumerated() {
            let rowNumber = index + 2
            let name = row.values["name", default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            let rawEmail = row.values["email", default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            let email = normalizeEmail(rawEmail)
            let externalId = row.values["externalid", default: row.values["external_id", default: ""]]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let phone = row.values["phone", default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            let address = row.values["address", default: ""].trimmingCharacters(in: .whitespacesAndNewlines)

            guard !name.isEmpty else {
                let issue = ImportIssue(row: rowNumber, field: "name", message: "Name is required")
                actions.append(.invalid(issue: issue))
                issues.append(issue)
                invalid += 1
                continue
            }

            let matchingKey: String
            let keyType: String
            if !email.isEmpty {
                guard isValidEmail(email) else {
                    let issue = ImportIssue(row: rowNumber, field: "email", message: "Email is invalid")
                    actions.append(.invalid(issue: issue))
                    issues.append(issue)
                    invalid += 1
                    continue
                }
                matchingKey = "email:\(email)"
                keyType = "email"
            } else if !externalId.isEmpty {
                matchingKey = "externalId:\(externalId)"
                keyType = "externalId"
            } else {
                let issue = ImportIssue(row: rowNumber, field: "email|externalId", message: "Stable key required: valid email or externalId")
                actions.append(.invalid(issue: issue))
                issues.append(issue)
                invalid += 1
                continue
            }

            if seenKeys.contains(matchingKey) {
                actions.append(.skip(reason: "Duplicate key in import batch (\(matchingKey))"))
                skipped += 1
                continue
            }
            seenKeys.insert(matchingKey)

            if keyType == "email" {
                if let current = existingByEmail[email] {
                    actions.append(.update(Client(id: current.id, name: name, email: email, phone: phone, address: address)))
                    updated += 1
                } else {
                    actions.append(.create(Client(id: 0, name: name, email: email, phone: phone, address: address)))
                    created += 1
                }
                continue
            }

            if let current = existingByExternalId[externalId] {
                actions.append(.update(Client(id: current.id, name: name, email: email, phone: phone, address: address)))
                updated += 1
            } else {
                actions.append(.skip(reason: "externalId not found: \(externalId)"))
                skipped += 1
            }
        }

        return ClientImportReport(actions: actions, created: created, updated: updated, skipped: skipped, invalid: invalid, issues: issues)
    }

    private func isValidEmail(_ email: String) -> Bool {
        let range = NSRange(email.startIndex..<email.endIndex, in: email)
        return emailRegex.firstMatch(in: email, options: [], range: range) != nil
    }

    private func normalizeEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
