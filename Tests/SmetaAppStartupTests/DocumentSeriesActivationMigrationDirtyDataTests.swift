import XCTest
import SQLite3
@testable import SmetaApp

final class DocumentSeriesActivationMigrationDirtyDataTests: XCTestCase {
    func testDuplicateActiveSeriesNormalizedDeterministicallyAndFinalizationStillWorks() throws {
        let (db, dbPath) = try makeLegacyMigrationFixture(tag: "duplicate-active")
        defer { cleanupSQLiteArtifacts(at: dbPath) }

        try db.execute("""
        INSERT INTO document_series (id, document_type, prefix, next_number, active) VALUES
            (101, 'faktura', 'F-LEG-1', 10, 1),
            (102, 'faktura', 'F-LEG-2', 20, 1),
            (103, 'faktura', 'F-LEG-3', 30, 0);
        """)

        try db.initializeSchema()

        let series = try fetchSeries(db: db, documentType: "faktura")
        XCTAssertEqual(series.count, 3)
        XCTAssertEqual(series.filter(\.active).count, 1)
        XCTAssertEqual(series.first(where: { $0.active })?.id, 101)
        XCTAssertEqual(series.first(where: { $0.id == 102 })?.active, false)
        XCTAssertEqual(series.first(where: { $0.id == 103 })?.active, false)

        XCTAssertTrue(try indexExists(db: db, name: "idx_document_series_type_lookup"))
        XCTAssertTrue(try indexExists(db: db, name: "idx_document_series_active_unique"))

        let repo = AppRepository(db: db)
        let projectId = try seedProject(repository: repo)
        let draftId = try createDraftDocument(repository: repo, projectId: projectId, type: .faktura)
        try repo.finalizeDocumentWithSnapshot(documentId: draftId, templateId: nil) { _, _ in
            "{\"kind\":\"duplicate-active\"}"
        }

        let finalized = try XCTUnwrap(repo.businessDocument(documentId: draftId))
        XCTAssertEqual(finalized.number, "F-LEG-1-000010")
    }

    func testNoActiveSeriesAmongDuplicatesPromotesDeterministicWinnerAndFinalizationUsesIt() throws {
        let (db, dbPath) = try makeLegacyMigrationFixture(tag: "no-active")
        defer { cleanupSQLiteArtifacts(at: dbPath) }

        try db.execute("""
        INSERT INTO document_series (id, document_type, prefix, next_number, active) VALUES
            (201, 'ata', 'ATA-L1', 7, 0),
            (202, 'ata', 'ATA-L2', 8, 0),
            (203, 'ata', 'ATA-L3', 9, 0);
        """)

        try db.initializeSchema()

        let series = try fetchSeries(db: db, documentType: "ata")
        XCTAssertEqual(series.filter(\.active).count, 1)
        XCTAssertEqual(series.first(where: { $0.active })?.id, 201)

        XCTAssertTrue(try indexExists(db: db, name: "idx_document_series_type_lookup"))
        XCTAssertTrue(try indexExists(db: db, name: "idx_document_series_active_unique"))

        let repo = AppRepository(db: db)
        let projectId = try seedProject(repository: repo)
        let draftId = try createDraftDocument(repository: repo, projectId: projectId, type: .ata)
        try repo.finalizeDocumentWithSnapshot(documentId: draftId, templateId: nil) { _, _ in
            "{\"kind\":\"no-active\"}"
        }

        let finalized = try XCTUnwrap(repo.businessDocument(documentId: draftId))
        XCTAssertEqual(finalized.number, "ATA-L1-000007")
    }

    func testMultipleDocumentTypesNormalizeIndependently() throws {
        let (db, dbPath) = try makeLegacyMigrationFixture(tag: "multi-types")
        defer { cleanupSQLiteArtifacts(at: dbPath) }

        try db.execute("""
        INSERT INTO document_series (id, document_type, prefix, next_number, active) VALUES
            (301, 'faktura', 'FAK-A', 100, 1),
            (302, 'faktura', 'FAK-B', 200, 1),
            (303, 'faktura', 'FAK-C', 300, 0),
            (401, 'ata', 'ATA-A', 10, 0),
            (402, 'ata', 'ATA-B', 20, 0),
            (501, 'paminnelse', 'PAM-A', 1, 1);
        """)

        try db.initializeSchema()

        let faktura = try fetchSeries(db: db, documentType: "faktura")
        XCTAssertEqual(faktura.filter(\.active).count, 1)
        XCTAssertEqual(faktura.first(where: { $0.active })?.id, 301)

        let ata = try fetchSeries(db: db, documentType: "ata")
        XCTAssertEqual(ata.filter(\.active).count, 1)
        XCTAssertEqual(ata.first(where: { $0.active })?.id, 401)

        let pam = try fetchSeries(db: db, documentType: "paminnelse")
        XCTAssertEqual(pam.filter(\.active).count, 1)
        XCTAssertEqual(pam.first(where: { $0.active })?.id, 501)
    }

    func testCleanControlCaseKeepsSeriesAndPayloadFieldsUnchanged() throws {
        let (db, dbPath) = try makeLegacyMigrationFixture(tag: "clean-control")
        defer { cleanupSQLiteArtifacts(at: dbPath) }

        try db.execute("""
        INSERT INTO document_series (id, document_type, prefix, next_number, active) VALUES
            (601, 'kreditfaktura', 'KRF-A', 55, 1),
            (602, 'kreditfaktura', 'KRF-B', 99, 0);
        """)

        let before = try fetchSeries(db: db, documentType: "kreditfaktura")
        try db.initializeSchema()
        let afterFirstPass = try fetchSeries(db: db, documentType: "kreditfaktura")
        try db.initializeSchema()
        let afterSecondPass = try fetchSeries(db: db, documentType: "kreditfaktura")

        XCTAssertEqual(before, afterFirstPass)
        XCTAssertEqual(afterFirstPass, afterSecondPass)
        XCTAssertTrue(try indexExists(db: db, name: "idx_document_series_type_lookup"))
        XCTAssertTrue(try indexExists(db: db, name: "idx_document_series_active_unique"))
    }

    func testPostMigrationFinalizationContinuityUsesActiveSeriesAdvancesCounterAndCreatesSnapshot() throws {
        let (db, dbPath) = try makeLegacyMigrationFixture(tag: "continuity")
        defer { cleanupSQLiteArtifacts(at: dbPath) }

        try db.execute("""
        INSERT INTO document_series (id, document_type, prefix, next_number, active) VALUES
            (701, 'faktura', 'CF', 12, 1),
            (702, 'faktura', 'CF-OLD', 90, 1),
            (703, 'faktura', 'CF-Z', 77, 0);
        """)

        try db.initializeSchema()

        let repo = AppRepository(db: db)
        let projectId = try seedProject(repository: repo)
        let draftId = try createDraftDocument(repository: repo, projectId: projectId, type: .faktura)

        try repo.finalizeDocumentWithSnapshot(documentId: draftId, templateId: nil) { _, _ in
            "{\"kind\":\"continuity\"}"
        }

        let document = try XCTUnwrap(repo.businessDocument(documentId: draftId))
        XCTAssertEqual(document.status, DocumentStatus.finalized.rawValue)
        XCTAssertEqual(document.number, "CF-000012")

        let snapshot = try repo.documentSnapshots(documentId: draftId)
        XCTAssertEqual(snapshot.count, 1)

        let series = try fetchSeries(db: db, documentType: "faktura")
        XCTAssertEqual(series.first(where: { $0.id == 701 })?.active, true)
        XCTAssertEqual(series.first(where: { $0.id == 701 })?.nextNumber, 13)
        XCTAssertEqual(series.first(where: { $0.id == 702 })?.nextNumber, 90)
        XCTAssertEqual(series.first(where: { $0.id == 703 })?.nextNumber, 77)
    }

    private func makeLegacyMigrationFixture(tag: String) throws -> (SQLiteDatabase, URL) {
        let db = try SQLiteDatabase(filename: "document-series-activation-\(tag)-\(UUID().uuidString).sqlite")
        try db.initializeSchema()

        try db.execute("DELETE FROM document_series;")
        try db.execute("DELETE FROM schema_migrations WHERE version = 4;")
        try db.execute("DROP INDEX IF EXISTS idx_document_series_type_lookup;")
        try db.execute("DROP INDEX IF EXISTS idx_document_series_active_unique;")
        try db.execute("DROP INDEX IF EXISTS idx_document_series_type_unique;")

        return (db, db.dbPath)
    }

    private func seedProject(repository: AppRepository) throws -> Int64 {
        let clientId = try repository.insertClient(Client(id: 0, name: "Client", email: "client@example.com", phone: "100", address: "Street"))
        let propertyId = try repository.insertProperty(PropertyObject(id: 0, clientId: clientId, name: "Flat", address: "Address"))
        let speedId = try repository.insertSpeedProfile(SpeedProfile(id: 0, name: "Default", coefficient: 1, daysDivider: 7, sortOrder: 0))
        return try repository.insertProject(Project(id: 0, clientId: clientId, propertyId: propertyId, name: "Project", speedProfileId: speedId, createdAt: Date()))
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
            notes: "migration contour test"
        )

        return try repository.createBusinessDocument(draft, lines: [
            BusinessDocumentLine(id: 0, documentId: 0, lineType: "labor", description: "Line", quantity: 1, unit: "h", unitPrice: 100, vatRate: 0.25, isRotEligible: false, total: 100)
        ])
    }

    private func fetchSeries(db: SQLiteDatabase, documentType: String) throws -> [SeriesRow] {
        let statement = try db.prepare("SELECT id, prefix, next_number, active FROM document_series WHERE document_type = ? ORDER BY id;")
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, documentType, -1, SQLITE_TRANSIENT)

        var rows: [SeriesRow] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int64(sqlite3_column_int64(statement, 0))
            let prefix = String(cString: sqlite3_column_text(statement, 1))
            let nextNumber = Int(sqlite3_column_int(statement, 2))
            let active = sqlite3_column_int(statement, 3) == 1
            rows.append(SeriesRow(id: id, prefix: prefix, nextNumber: nextNumber, active: active))
        }
        return rows
    }

    private func indexExists(db: SQLiteDatabase, name: String) throws -> Bool {
        let statement = try db.prepare("SELECT 1 FROM sqlite_master WHERE type='index' AND name=? LIMIT 1;")
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, name, -1, SQLITE_TRANSIENT)
        return sqlite3_step(statement) == SQLITE_ROW
    }

    private func cleanupSQLiteArtifacts(at dbPath: URL) {
        let fm = FileManager.default
        try? fm.removeItem(at: dbPath)
        try? fm.removeItem(at: URL(fileURLWithPath: dbPath.path + "-wal"))
        try? fm.removeItem(at: URL(fileURLWithPath: dbPath.path + "-shm"))
    }
}

private struct SeriesRow: Equatable {
    let id: Int64
    let prefix: String
    let nextNumber: Int
    let active: Bool
}
