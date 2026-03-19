import XCTest
@testable import SmetaApp

final class DocumentFinalizationContourTests: XCTestCase {
    enum ProbeError: Error {
        case injectedFailure
    }

    func testNormalFinalizePathAssignsNumberAndAdvancesSeries() throws {
        let (repo, dbPath, projectId) = try makeRepository(tag: "normal")
        defer { cleanupSQLiteArtifacts(at: dbPath) }

        _ = try repo.insertDocumentSeries(DocumentSeries(id: 0, documentType: DocumentType.faktura.rawValue, prefix: "FAK", nextNumber: 17, active: true))
        let draftId = try createDraftDocument(repository: repo, projectId: projectId, type: .faktura)

        try repo.finalizeDocumentWithSnapshot(documentId: draftId, templateId: nil) { _, _ in
            "{\"kind\":\"ok\"}"
        }

        let finalized = try XCTUnwrap(repo.businessDocument(documentId: draftId))
        XCTAssertEqual(finalized.status, DocumentStatus.finalized.rawValue)
        XCTAssertEqual(finalized.number, "FAK-000017")

        let series = try XCTUnwrap(repo.documentSeries().first(where: { $0.documentType == DocumentType.faktura.rawValue && $0.active }))
        XCTAssertEqual(series.nextNumber, 18)
    }

    func testRefinalizeDoesNotMutateDocumentOrSeriesOrSnapshots() throws {
        let (repo, dbPath, projectId) = try makeRepository(tag: "refinalize")
        defer { cleanupSQLiteArtifacts(at: dbPath) }

        _ = try repo.insertDocumentSeries(DocumentSeries(id: 0, documentType: DocumentType.avtal.rawValue, prefix: "AVT", nextNumber: 3, active: true))
        let draftId = try createDraftDocument(repository: repo, projectId: projectId, type: .avtal)

        try repo.finalizeDocumentWithSnapshot(documentId: draftId, templateId: nil) { _, _ in
            "{\"kind\":\"first\"}"
        }
        let firstDoc = try XCTUnwrap(repo.businessDocument(documentId: draftId))
        let firstSeries = try XCTUnwrap(repo.documentSeries().first(where: { $0.documentType == DocumentType.avtal.rawValue && $0.active }))
        let snapshotCount = try repo.documentSnapshots(documentId: draftId).count

        try repo.finalizeDocumentWithSnapshot(documentId: draftId, templateId: nil) { _, _ in
            XCTFail("snapshot builder must not be called on re-finalize")
            return "{\"kind\":\"second\"}"
        }

        let secondDoc = try XCTUnwrap(repo.businessDocument(documentId: draftId))
        let secondSeries = try XCTUnwrap(repo.documentSeries().first(where: { $0.documentType == DocumentType.avtal.rawValue && $0.active }))
        let secondSnapshotCount = try repo.documentSnapshots(documentId: draftId).count

        XCTAssertEqual(secondDoc.number, firstDoc.number)
        XCTAssertEqual(secondDoc.status, firstDoc.status)
        XCTAssertEqual(secondSeries.nextNumber, firstSeries.nextNumber)
        XCTAssertEqual(secondSnapshotCount, snapshotCount)
    }

    func testRollbackOnInjectedFailureRestoresDocumentAndSeries() throws {
        let (repo, dbPath, projectId) = try makeRepository(tag: "rollback")
        defer { cleanupSQLiteArtifacts(at: dbPath) }

        _ = try repo.insertDocumentSeries(DocumentSeries(id: 0, documentType: DocumentType.faktura.rawValue, prefix: "FAK", nextNumber: 41, active: true))
        let draftId = try createDraftDocument(repository: repo, projectId: projectId, type: .faktura)

        XCTAssertThrowsError(
            try repo.performDocumentFinalizationWrites(
                documentId: draftId,
                templateId: nil,
                snapshotBuilder: { _, _ in "{\"kind\":\"rollback\"}" },
                failureInjection: { throw ProbeError.injectedFailure }
            )
        )

        let rolledBackDoc = try XCTUnwrap(repo.businessDocument(documentId: draftId))
        XCTAssertEqual(rolledBackDoc.status, DocumentStatus.draft.rawValue)
        XCTAssertEqual(rolledBackDoc.number, "")

        let series = try XCTUnwrap(repo.documentSeries().first(where: { $0.documentType == DocumentType.faktura.rawValue && $0.active }))
        XCTAssertEqual(series.nextNumber, 41)
        XCTAssertTrue(try repo.documentSnapshots(documentId: draftId).isEmpty)
    }

    func testMissingActiveSeriesReturnsControlledErrorAndNoPartialWrites() throws {
        let (repo, dbPath, projectId) = try makeRepository(tag: "missing-series")
        defer { cleanupSQLiteArtifacts(at: dbPath) }

        let draftId = try createDraftDocument(repository: repo, projectId: projectId, type: .paminnelse)
        XCTAssertThrowsError(
            try repo.finalizeDocumentWithSnapshot(documentId: draftId, templateId: nil) { _, _ in "{\"kind\":\"missing\"}" }
        ) { error in
            XCTAssertTrue(String(describing: error).contains("Нет активной серии"))
        }

        let doc = try XCTUnwrap(repo.businessDocument(documentId: draftId))
        XCTAssertEqual(doc.status, DocumentStatus.draft.rawValue)
        XCTAssertEqual(doc.number, "")
        XCTAssertTrue(try repo.documentSnapshots(documentId: draftId).isEmpty)
    }

    func testUsesOnlyActiveSeriesWhenInactiveAlternativeExists() throws {
        let (repo, dbPath, projectId) = try makeRepository(tag: "active-only")
        defer { cleanupSQLiteArtifacts(at: dbPath) }

        _ = try repo.insertDocumentSeries(DocumentSeries(id: 0, documentType: DocumentType.ata.rawValue, prefix: "ATAI", nextNumber: 500, active: false))
        _ = try repo.insertDocumentSeries(DocumentSeries(id: 0, documentType: DocumentType.ata.rawValue, prefix: "ATA", nextNumber: 9, active: true))
        let draftId = try createDraftDocument(repository: repo, projectId: projectId, type: .ata)

        try repo.finalizeDocumentWithSnapshot(documentId: draftId, templateId: nil) { _, _ in "{\"kind\":\"active\"}" }

        let doc = try XCTUnwrap(repo.businessDocument(documentId: draftId))
        XCTAssertEqual(doc.number, "ATA-000009")

        let series = try repo.documentSeries().filter { $0.documentType == DocumentType.ata.rawValue }
        XCTAssertEqual(series.first(where: { $0.active })?.nextNumber, 10)
        XCTAssertEqual(series.first(where: { !$0.active })?.nextNumber, 500)
    }

    func testDifferentDocumentTypesUseOwnSeries() throws {
        let (repo, dbPath, projectId) = try makeRepository(tag: "types")
        defer { cleanupSQLiteArtifacts(at: dbPath) }

        _ = try repo.insertDocumentSeries(DocumentSeries(id: 0, documentType: DocumentType.faktura.rawValue, prefix: "FAK", nextNumber: 1, active: true))
        _ = try repo.insertDocumentSeries(DocumentSeries(id: 0, documentType: DocumentType.kreditfaktura.rawValue, prefix: "KRF", nextNumber: 70, active: true))
        _ = try repo.insertDocumentSeries(DocumentSeries(id: 0, documentType: DocumentType.ata.rawValue, prefix: "ATA", nextNumber: 11, active: true))
        _ = try repo.insertDocumentSeries(DocumentSeries(id: 0, documentType: DocumentType.paminnelse.rawValue, prefix: "PAM", nextNumber: 200, active: true))

        let faktura = try createDraftDocument(repository: repo, projectId: projectId, type: .faktura)
        let kredit = try createDraftDocument(repository: repo, projectId: projectId, type: .kreditfaktura)
        let ata = try createDraftDocument(repository: repo, projectId: projectId, type: .ata)
        let paminnelse = try createDraftDocument(repository: repo, projectId: projectId, type: .paminnelse)

        for id in [faktura, kredit, ata, paminnelse] {
            try repo.finalizeDocumentWithSnapshot(documentId: id, templateId: nil) { _, _ in "{\"kind\":\"types\"}" }
        }

        XCTAssertEqual(try repo.businessDocument(documentId: faktura)?.number, "FAK-000001")
        XCTAssertEqual(try repo.businessDocument(documentId: kredit)?.number, "KRF-000070")
        XCTAssertEqual(try repo.businessDocument(documentId: ata)?.number, "ATA-000011")
        XCTAssertEqual(try repo.businessDocument(documentId: paminnelse)?.number, "PAM-000200")
    }

    func testReloadReadsStayStableAfterSuccessfulFinalize() throws {
        let (repo, dbPath, projectId) = try makeRepository(tag: "reload")
        defer { cleanupSQLiteArtifacts(at: dbPath) }

        _ = try repo.insertDocumentSeries(DocumentSeries(id: 0, documentType: DocumentType.faktura.rawValue, prefix: "FAK", nextNumber: 31, active: true))
        let draftId = try createDraftDocument(repository: repo, projectId: projectId, type: .faktura)

        try repo.finalizeDocumentWithSnapshot(documentId: draftId, templateId: nil) { _, _ in "{\"kind\":\"reload\"}" }
        let beforeReload = try XCTUnwrap(repo.businessDocument(documentId: draftId))

        let afterReload = try repo.businessDocuments().first(where: { $0.id == draftId })
        XCTAssertEqual(afterReload?.number, beforeReload.number)
        XCTAssertEqual(afterReload?.status, DocumentStatus.finalized.rawValue)
    }

    private func makeRepository(tag: String) throws -> (AppRepository, URL, Int64) {
        let db = try SQLiteDatabase(filename: "finalization-tests-\(tag)-\(UUID().uuidString).sqlite")
        try db.initializeSchema()
        let repository = AppRepository(db: db)

        let clientId = try repository.insertClient(Client(id: 0, name: "Client", email: "client@example.com", phone: "100", address: "Street"))
        let propertyId = try repository.insertProperty(PropertyObject(id: 0, clientId: clientId, name: "Flat", address: "Address"))
        let speedId = try repository.insertSpeedProfile(SpeedProfile(id: 0, name: "Default", coefficient: 1, daysDivider: 7, sortOrder: 0))
        let projectId = try repository.insertProject(Project(id: 0, clientId: clientId, propertyId: propertyId, name: "Project", speedProfileId: speedId, createdAt: Date()))

        return (repository, db.dbPath, projectId)
    }

    private func createDraftDocument(repository: AppRepository, projectId: Int64, type: DocumentType) throws -> Int64 {
        let draft = BusinessDocument(
            id: 0,
            projectId: projectId,
            type: type.rawValue,
            status: DocumentStatus.draft.rawValue,
            number: "",
            title: "Draft \(type.rawValue)",
            issueDate: Date(timeIntervalSince1970: 1_710_000_000),
            dueDate: nil,
            customerType: CustomerType.b2c.rawValue,
            taxMode: TaxMode.normal.rawValue,
            currency: "SEK",
            subtotalLabor: 100,
            subtotalMaterial: 0,
            subtotalOther: 0,
            vatRate: 0.25,
            vatAmount: 25,
            rotEligibleLabor: 0,
            rotReduction: 0,
            totalAmount: 125,
            paidAmount: 0,
            balanceDue: 125,
            relatedDocumentId: nil,
            notes: "contour test"
        )

        return try repository.createBusinessDocument(draft, lines: [
            BusinessDocumentLine(id: 0, documentId: 0, lineType: "labor", description: "Line", quantity: 1, unit: "h", unitPrice: 100, vatRate: 0.25, isRotEligible: false, total: 100)
        ])
    }

    private func cleanupSQLiteArtifacts(at dbPath: URL) {
        let fm = FileManager.default
        try? fm.removeItem(at: dbPath)
        try? fm.removeItem(at: URL(fileURLWithPath: dbPath.path + "-wal"))
        try? fm.removeItem(at: URL(fileURLWithPath: dbPath.path + "-shm"))
    }
}
