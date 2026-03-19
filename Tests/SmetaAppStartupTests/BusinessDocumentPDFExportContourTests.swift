import XCTest
import SQLite3
@testable import SmetaApp

@MainActor
final class BusinessDocumentPDFExportContourTests: XCTestCase {
    enum ProbeError: Error {
        case injectedPDFFailure
        case injectedDBFailure
        case injectedPromoteFailure
    }

    func testProductionContourSuccessPersistsExportLogAndFinalPDF() throws {
        let fixture = try makeFixture(tag: "success")
        defer { cleanupArtifacts(fixture: fixture) }

        let viewModel = try makeViewModel(fixture: fixture, destinationURL: fixture.finalURL)
        let doc = try XCTUnwrap(viewModel.businessDocuments.first(where: { $0.id == fixture.documentId }))
        viewModel.exportDocumentPDF(doc)

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.finalURL.path))
        XCTAssertEqual(try exportLogCount(repository: fixture.repository), 1)
        XCTAssertFalse(containsContingencyArtifacts(near: fixture.finalURL))
    }

    func testProductionContourCancelGuardStopsBeforeAnyWrites() throws {
        let fixture = try makeFixture(tag: "cancel")
        defer { cleanupArtifacts(fixture: fixture) }

        let viewModel = try makeViewModel(fixture: fixture, destinationURL: nil)
        let doc = try XCTUnwrap(viewModel.businessDocuments.first(where: { $0.id == fixture.documentId }))
        viewModel.exportDocumentPDF(doc)

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.infoMessage, "Экспорт PDF отменён пользователем")
        XCTAssertEqual(try exportLogCount(repository: fixture.repository), 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.finalURL.path))
        XCTAssertFalse(containsContingencyArtifacts(near: fixture.finalURL))
    }

    func testProductionContourPDFFailureLeavesNoDBWritesAndNoArtifacts() throws {
        let fixture = try makeFixture(tag: "pdf-failure")
        defer { cleanupArtifacts(fixture: fixture) }

        let viewModel = try makeViewModel(fixture: fixture, destinationURL: fixture.finalURL, pdfShouldFail: true)
        let doc = try XCTUnwrap(viewModel.businessDocuments.first(where: { $0.id == fixture.documentId }))
        viewModel.exportDocumentPDF(doc)

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(try exportLogCount(repository: fixture.repository), 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.finalURL.path))
        XCTAssertFalse(containsContingencyArtifacts(near: fixture.finalURL))
    }

    func testProductionContourPromoteFailureRestoresExistingFileAndRollsBack() throws {
        let fixture = try makeFixture(tag: "promote-failure")
        defer { cleanupArtifacts(fixture: fixture) }

        let original = Data("original-existing-pdf".utf8)
        FileManager.default.createFile(atPath: fixture.finalURL.path, contents: original)

        let viewModel = try makeViewModel(
            fixture: fixture,
            destinationURL: fixture.finalURL,
            failureInjection: BusinessDocumentExportFailureInjection(
                persistentWriteFailure: nil,
                beforePromoteFailure: { throw ProbeError.injectedPromoteFailure }
            )
        )
        let doc = try XCTUnwrap(viewModel.businessDocuments.first(where: { $0.id == fixture.documentId }))
        viewModel.exportDocumentPDF(doc)

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(try Data(contentsOf: fixture.finalURL), original)
        XCTAssertEqual(try exportLogCount(repository: fixture.repository), 0)
        XCTAssertFalse(containsContingencyArtifacts(near: fixture.finalURL))
    }

    func testProductionContourDBFailureRollsBackAndLeavesNoFalseExportLog() throws {
        let fixture = try makeFixture(tag: "db-failure")
        defer { cleanupArtifacts(fixture: fixture) }

        let original = Data("existing-file-before-db-failure".utf8)
        FileManager.default.createFile(atPath: fixture.finalURL.path, contents: original)

        let viewModel = try makeViewModel(
            fixture: fixture,
            destinationURL: fixture.finalURL,
            failureInjection: BusinessDocumentExportFailureInjection(
                persistentWriteFailure: { throw ProbeError.injectedDBFailure },
                beforePromoteFailure: nil
            )
        )
        let doc = try XCTUnwrap(viewModel.businessDocuments.first(where: { $0.id == fixture.documentId }))
        viewModel.exportDocumentPDF(doc)

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(try Data(contentsOf: fixture.finalURL), original)
        XCTAssertEqual(try exportLogCount(repository: fixture.repository), 0)
        XCTAssertFalse(containsContingencyArtifacts(near: fixture.finalURL))
    }

    func testProductionContourRepeatedRunAfterFailureDoesNotAccumulateGarbageAndThenSucceeds() throws {
        let fixture = try makeFixture(tag: "repeat")
        defer { cleanupArtifacts(fixture: fixture) }

        let failing = try makeViewModel(
            fixture: fixture,
            destinationURL: fixture.finalURL,
            failureInjection: BusinessDocumentExportFailureInjection(
                persistentWriteFailure: nil,
                beforePromoteFailure: { throw ProbeError.injectedPromoteFailure }
            )
        )
        let failingDoc = try XCTUnwrap(failing.businessDocuments.first(where: { $0.id == fixture.documentId }))
        failing.exportDocumentPDF(failingDoc)
        XCTAssertNotNil(failing.errorMessage)
        XCTAssertEqual(try exportLogCount(repository: fixture.repository), 0)
        XCTAssertFalse(containsContingencyArtifacts(near: fixture.finalURL))

        let succeeding = try makeViewModel(fixture: fixture, destinationURL: fixture.finalURL)
        let succeedingDoc = try XCTUnwrap(succeeding.businessDocuments.first(where: { $0.id == fixture.documentId }))
        succeeding.exportDocumentPDF(succeedingDoc)
        XCTAssertNil(succeeding.errorMessage)
        XCTAssertEqual(try exportLogCount(repository: fixture.repository), 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.finalURL.path))
        XCTAssertFalse(containsContingencyArtifacts(near: fixture.finalURL))
    }

    func testReloadReadsStayStableAfterSuccessfulBusinessDocumentExport() throws {
        let fixture = try makeFixture(tag: "reload-stable")
        defer { cleanupArtifacts(fixture: fixture) }

        let viewModel = try makeViewModel(fixture: fixture, destinationURL: fixture.finalURL)
        let doc = try XCTUnwrap(viewModel.businessDocuments.first(where: { $0.id == fixture.documentId }))
        viewModel.exportDocumentPDF(doc)

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.businessDocuments.filter { $0.id == fixture.documentId }.count, 1)
        XCTAssertEqual(try fixture.repository.businessDocuments().filter { $0.id == fixture.documentId }.count, 1)
    }

    private struct Fixture {
        let db: SQLiteDatabase
        let repository: AppRepository
        let dbPath: URL
        let documentId: Int64
        let finalURL: URL
        let tempRoot: URL
    }

    private struct StubBusinessDestinationProvider: BusinessDocumentDestinationProviding {
        let url: URL?
        func chooseDestination(defaultFileName: String) throws -> URL? { url }
    }

    private struct StubBusinessPDFGenerator: BusinessDocumentPDFGenerating {
        let shouldFail: Bool
        func generateBusinessDocumentPDF(title: String, body: String, saveURL: URL) throws {
            if shouldFail {
                throw ProbeError.injectedPDFFailure
            }
            try Data("%PDF-1.4 business".utf8).write(to: saveURL)
        }
    }

    private func makeFixture(tag: String) throws -> Fixture {
        let db = try SQLiteDatabase(filename: "business-export-\(tag)-\(UUID().uuidString).sqlite")
        try db.initializeSchema()
        let repository = AppRepository(db: db)
        try repository.performLaunchBootstrapWrites()

        let clientId = try repository.insertClient(Client(id: 0, name: "Client", email: "client@example.com", phone: "101", address: "Street"))
        let propertyId = try repository.insertProperty(PropertyObject(id: 0, clientId: clientId, name: "Flat", address: "Address"))
        let speedId = try repository.insertSpeedProfile(SpeedProfile(id: 0, name: "Default", coefficient: 1, daysDivider: 7, sortOrder: 0))
        let projectId = try repository.insertProject(Project(id: 0, clientId: clientId, propertyId: propertyId, name: "Project", speedProfileId: speedId, createdAt: Date()))

        let docId = try repository.createBusinessDocument(
            BusinessDocument(
                id: 0,
                projectId: projectId,
                type: DocumentType.faktura.rawValue,
                status: DocumentStatus.draft.rawValue,
                number: "",
                title: "Faktura test",
                issueDate: Date(),
                dueDate: Date().addingTimeInterval(7 * 24 * 3600),
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
                notes: "note"
            ),
            lines: [
                BusinessDocumentLine(
                    id: 0,
                    documentId: 0,
                    lineType: "labor",
                    description: "Line",
                    quantity: 1,
                    unit: "h",
                    unitPrice: 100,
                    vatRate: 0.25,
                    isRotEligible: false,
                    total: 100
                )
            ]
        )

        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("business-export-\(tag)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let finalURL = tempRoot.appendingPathComponent("Faktura-Test.pdf")

        return Fixture(db: db, repository: repository, dbPath: db.dbPath, documentId: docId, finalURL: finalURL, tempRoot: tempRoot)
    }

    private func makeViewModel(
        fixture: Fixture,
        destinationURL: URL?,
        pdfShouldFail: Bool = false,
        failureInjection: BusinessDocumentExportFailureInjection? = nil
    ) throws -> AppViewModel {
        let backupService = BackupService(db: fixture.db)
        let viewModel = AppViewModel(
            repository: fixture.repository,
            backupService: backupService,
            businessDocumentPDFGenerator: StubBusinessPDFGenerator(shouldFail: pdfShouldFail),
            businessDocumentDestinationProvider: StubBusinessDestinationProvider(url: destinationURL),
            businessDocumentExportFailureInjection: failureInjection
        )
        try viewModel.reloadAll()
        return viewModel
    }

    private func exportLogCount(repository: AppRepository) throws -> Int {
        var count = 0
        try repository.db.withStatement("SELECT COUNT(*) FROM export_logs WHERE kind='business_document_pdf'") { stmt in
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
        }
        return count
    }

    private func containsContingencyArtifacts(near finalURL: URL) -> Bool {
        guard let files = try? FileManager.default.contentsOfDirectory(at: finalURL.deletingLastPathComponent(), includingPropertiesForKeys: nil) else {
            return false
        }
        return files.contains { url in
            let name = url.lastPathComponent
            return name.contains("business-document-pending") || name.contains(".backup-")
        }
    }

    private func cleanupArtifacts(fixture: Fixture) {
        let fm = FileManager.default
        try? fm.removeItem(at: fixture.tempRoot)
        try? fm.removeItem(at: fixture.dbPath)
        try? fm.removeItem(at: URL(fileURLWithPath: fixture.dbPath.path + "-wal"))
        try? fm.removeItem(at: URL(fileURLWithPath: fixture.dbPath.path + "-shm"))
    }
}
