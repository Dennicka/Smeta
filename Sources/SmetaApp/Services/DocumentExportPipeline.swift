import Foundation

enum DocumentExportSource: String {
    case snapshot
    case repository
}

struct DocumentExportPayload {
    var title: String
    var body: String
    var source: DocumentExportSource
}

enum DocumentExportPipelineError: LocalizedError {
    case missingLines(documentType: String)

    var errorDescription: String? {
        switch self {
        case .missingLines(let documentType):
            return "Невозможно экспортировать \(documentType): отсутствуют строки документа"
        }
    }
}

final class DocumentExportPipeline {
    private let snapshotBuilder: DocumentSnapshotBuilder

    init(snapshotBuilder: DocumentSnapshotBuilder = DocumentSnapshotBuilder()) {
        self.snapshotBuilder = snapshotBuilder
    }

    func buildPayload(
        document: BusinessDocument,
        lines: [BusinessDocumentLine],
        snapshots: [DocumentSnapshot]
    ) throws -> DocumentExportPayload {
        if let snapshot = try latestFullSnapshot(from: snapshots) {
            return renderFromSnapshot(snapshot)
        }
        return try renderFromRepository(document: document, lines: lines)
    }

    private func latestFullSnapshot(from snapshots: [DocumentSnapshot]) throws -> ImmutableDocumentSnapshot? {
        for snapshot in snapshots {
            let parsed = try snapshotBuilder.parse(snapshotJSON: snapshot.snapshotJSON)
            if case .full(let fullSnapshot) = parsed {
                return fullSnapshot
            }
        }
        return nil
    }

    private func renderFromSnapshot(_ snapshot: ImmutableDocumentSnapshot) -> DocumentExportPayload {
        let title = "\(displayTypeName(snapshot.document.type)) \(documentIdentifier(number: snapshot.document.number, fallbackId: snapshot.document.documentId))"
        let lineItems = snapshot.lines.enumerated().map { index, line in
            "\(index + 1). \(line.description) — \(format(line.total)) \(snapshot.document.currency)"
        }.joined(separator: "\n")

        let body = """
        Titel: \(snapshot.document.title)
        Kund: \(snapshot.client.name)
        Projekt: \(snapshot.project.projectName)
        Status: \(snapshot.document.statusAtSnapshotTime)

        Rader:
        \(lineItems)

        Subtotal: \(format(snapshot.financials.subtotalLabor + snapshot.financials.subtotalMaterial + snapshot.financials.subtotalOther)) \(snapshot.document.currency)
        Moms: \(format(snapshot.financials.vatAmount)) \(snapshot.document.currency)
        ROT: \(format(snapshot.financials.rotReduction)) \(snapshot.document.currency)
        Total: \(format(snapshot.financials.totalAmount)) \(snapshot.document.currency)
        Kvar att betala: \(format(snapshot.financials.balanceDue)) \(snapshot.document.currency)
        """

        return DocumentExportPayload(title: title, body: body, source: .snapshot)
    }

    private func renderFromRepository(document: BusinessDocument, lines: [BusinessDocumentLine]) throws -> DocumentExportPayload {
        guard !lines.isEmpty else {
            throw DocumentExportPipelineError.missingLines(documentType: document.type)
        }

        let title = "\(displayTypeName(document.type)) \(documentIdentifier(number: document.number, fallbackId: document.id))"
        let lineItems = lines.enumerated().map { index, line in
            "\(index + 1). \(line.description) — \(format(line.total)) \(document.currency)"
        }.joined(separator: "\n")
        let subtotal = document.subtotalLabor + document.subtotalMaterial + document.subtotalOther

        let body = """
        Titel: \(document.title)
        Status: \(document.status)

        Rader:
        \(lineItems)

        Subtotal: \(format(subtotal)) \(document.currency)
        Moms: \(format(document.vatAmount)) \(document.currency)
        ROT: \(format(document.rotReduction)) \(document.currency)
        Total: \(format(document.totalAmount)) \(document.currency)
        Kvar att betala: \(format(document.balanceDue)) \(document.currency)
        """

        return DocumentExportPayload(title: title, body: body, source: .repository)
    }

    private func displayTypeName(_ rawType: String) -> String {
        switch rawType {
        case DocumentType.avtal.rawValue: return "Avtal"
        case DocumentType.faktura.rawValue: return "Faktura"
        case DocumentType.kreditfaktura.rawValue: return "Kreditfaktura"
        case DocumentType.ata.rawValue: return "ÄTA"
        case DocumentType.paminnelse.rawValue: return "Påminnelse"
        case DocumentType.offert.rawValue: return "Offert"
        default: return rawType.capitalized
        }
    }

    private func documentIdentifier(number: String, fallbackId: Int64) -> String {
        let trimmed = number.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "DRAFT-\(fallbackId)" : trimmed
    }

    private func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
