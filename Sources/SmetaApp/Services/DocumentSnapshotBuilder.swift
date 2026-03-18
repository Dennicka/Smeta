import Foundation

struct DocumentSnapshotBuildContext {
    var company: Company?
    var client: Client?
    var project: Project?
    var property: PropertyObject?
    var sourceEstimateId: Int64?
    var relatedDocumentNumber: String?
}

enum ParsedDocumentSnapshot {
    case full(ImmutableDocumentSnapshot)
    case legacy(LegacyDocumentSnapshot)

    var format: String {
        switch self {
        case .full: return "full-v2"
        case .legacy: return "legacy-v1"
        }
    }
}

final class DocumentSnapshotBuilder {
    static let currentSchemaVersion = 2

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func buildImmutableSnapshot(
        document: BusinessDocument,
        lines: [BusinessDocumentLine],
        context: DocumentSnapshotBuildContext,
        templateId: Int64?,
        snapshotCreatedAt: Date = Date()
    ) -> ImmutableDocumentSnapshot {
        ImmutableDocumentSnapshot(
            schemaVersion: Self.currentSchemaVersion,
            snapshotCreatedAt: snapshotCreatedAt,
            document: DocumentMetaSnapshot(
                documentId: document.id,
                templateId: templateId,
                type: document.type,
                number: document.number,
                title: document.title,
                statusAtSnapshotTime: document.status,
                issueDate: document.issueDate,
                dueDate: document.dueDate,
                currency: document.currency
            ),
            company: CompanyDisplaySnapshot(
                name: context.company?.name ?? "",
                orgNumber: context.company?.orgNumber ?? "",
                email: context.company?.email ?? "",
                phone: context.company?.phone ?? ""
            ),
            client: ClientDisplaySnapshot(
                name: context.client?.name ?? "",
                email: context.client?.email ?? "",
                phone: context.client?.phone ?? "",
                address: context.client?.address ?? ""
            ),
            project: ProjectSnapshotContext(
                projectId: document.projectId,
                projectName: context.project?.name ?? "",
                propertyObjectName: context.property?.name,
                objectAddress: context.property?.address
            ),
            financials: DocumentFinancialSnapshot(
                customerType: document.customerType,
                taxMode: document.taxMode,
                subtotalLabor: document.subtotalLabor,
                subtotalMaterial: document.subtotalMaterial,
                subtotalOther: document.subtotalOther,
                vatRate: document.vatRate,
                vatAmount: document.vatAmount,
                rotEligibleLabor: document.rotEligibleLabor,
                rotReduction: document.rotReduction,
                totalAmount: document.totalAmount,
                paidAmount: document.paidAmount,
                balanceDue: document.balanceDue
            ),
            lines: lines.map {
                DocumentLineSnapshot(
                    lineType: $0.lineType,
                    description: $0.description,
                    quantity: $0.quantity,
                    unit: $0.unit,
                    unitPrice: $0.unitPrice,
                    vatRate: $0.vatRate,
                    isRotEligible: $0.isRotEligible,
                    total: $0.total
                )
            },
            references: DocumentReferenceSnapshot(
                relatedDocumentId: document.relatedDocumentId,
                relatedDocumentNumber: context.relatedDocumentNumber,
                sourceEstimateId: context.sourceEstimateId,
                sourceProjectId: context.project?.id,
                sourceProjectName: context.project?.name
            ),
            notes: document.notes
        )
    }

    func serialize(snapshot: ImmutableDocumentSnapshot) throws -> String {
        let data = try encoder.encode(snapshot)
        guard let json = String(data: data, encoding: .utf8) else {
            throw SnapshotError.serializationFailed
        }
        return json
    }

    func parse(snapshotJSON: String) throws -> ParsedDocumentSnapshot {
        let data = Data(snapshotJSON.utf8)

        if let fullSnapshot = try? decoder.decode(ImmutableDocumentSnapshot.self, from: data),
           fullSnapshot.schemaVersion >= Self.currentSchemaVersion {
            return .full(fullSnapshot)
        }

        if let legacySnapshot = try? decoder.decode(LegacyDocumentSnapshot.self, from: data) {
            return .legacy(legacySnapshot)
        }

        throw SnapshotError.unsupportedFormat
    }
}

enum SnapshotError: LocalizedError {
    case serializationFailed
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .serializationFailed:
            return "Не удалось сериализовать snapshot"
        case .unsupportedFormat:
            return "Неподдерживаемый формат snapshot"
        }
    }
}
