import XCTest
@testable import SmetaApp

@MainActor
final class OffertGenerationContourTests: XCTestCase {
    enum ProbeError: Error {
        case injectedPDFFailure
        case injectedDBFailure
        case injectedPromoteFailure
    }

    func testProductionContourSuccessPersistsEstimateLinesGeneratedDocumentAndFinalPDF() throws {
        let fixture = try makeFixture(tag: "success")
        defer { cleanupArtifacts(fixture: fixture) }

        let viewModel = try makeViewModel(fixture: fixture, destinationURL: fixture.finalURL)
        viewModel.saveEstimateAndGenerateDocument()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.infoMessage, "Offert сохранён")
        let estimates = try fixture.repository.estimates(projectId: fixture.projectId)
        XCTAssertEqual(estimates.count, 1)
        let estimateId = try XCTUnwrap(estimates.first?.id)
        XCTAssertEqual(try fixture.repository.estimateLines(estimateId: estimateId).count, 2)
        let generated = try fixture.repository.generatedDocuments()
        XCTAssertEqual(generated.count, 1)
        XCTAssertEqual(generated.first?.estimateId, estimateId)
        XCTAssertEqual(generated.first?.path, fixture.finalURL.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.finalURL.path))
        XCTAssertFalse(containsContingencyArtifacts(near: fixture.finalURL))
    }

    func testProductionContourDBFailureRollsBackDatabaseAndLeavesNoFinalArtifacts() throws {
        let fixture = try makeFixture(tag: "db-failure")
        defer { cleanupArtifacts(fixture: fixture) }

        let viewModel = try makeViewModel(
            fixture: fixture,
            destinationURL: fixture.finalURL,
            failureInjection: OffertContourFailureInjection(
                persistentWriteFailure: { throw ProbeError.injectedDBFailure },
                beforePromoteFailure: nil
            )
        )
        viewModel.saveEstimateAndGenerateDocument()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(try fixture.repository.estimates(projectId: fixture.projectId).isEmpty)
        XCTAssertTrue(try fixture.repository.generatedDocuments().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.finalURL.path))
        XCTAssertFalse(containsContingencyArtifacts(near: fixture.finalURL))
    }

    func testProductionContourPDFFailureBeforeWritesLeavesNoDBStateAndNoArtifacts() throws {
        let fixture = try makeFixture(tag: "pdf-failure")
        defer { cleanupArtifacts(fixture: fixture) }

        let viewModel = try makeViewModel(fixture: fixture, destinationURL: fixture.finalURL, pdfShouldFail: true)
        viewModel.saveEstimateAndGenerateDocument()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(try fixture.repository.estimates(projectId: fixture.projectId).isEmpty)
        XCTAssertTrue(try fixture.repository.generatedDocuments().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.finalURL.path))
        XCTAssertFalse(containsContingencyArtifacts(near: fixture.finalURL))
    }

    func testProductionContourPromoteFailureRestoresExistingFileAndRollsBackDB() throws {
        let fixture = try makeFixture(tag: "promote-failure")
        defer { cleanupArtifacts(fixture: fixture) }

        let original = Data("original-existing-pdf".utf8)
        FileManager.default.createFile(atPath: fixture.finalURL.path, contents: original)

        let viewModel = try makeViewModel(
            fixture: fixture,
            destinationURL: fixture.finalURL,
            failureInjection: OffertContourFailureInjection(
                persistentWriteFailure: nil,
                beforePromoteFailure: { throw ProbeError.injectedPromoteFailure }
            )
        )
        viewModel.saveEstimateAndGenerateDocument()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(try Data(contentsOf: fixture.finalURL), original)
        XCTAssertTrue(try fixture.repository.estimates(projectId: fixture.projectId).isEmpty)
        XCTAssertTrue(try fixture.repository.generatedDocuments().isEmpty)
        XCTAssertFalse(containsContingencyArtifacts(near: fixture.finalURL))
    }

    func testProductionContourRepeatedRunAfterFailureDoesNotAccumulateGarbageAndThenSucceeds() throws {
        let fixture = try makeFixture(tag: "repeat")
        defer { cleanupArtifacts(fixture: fixture) }

        let failing = try makeViewModel(
            fixture: fixture,
            destinationURL: fixture.finalURL,
            failureInjection: OffertContourFailureInjection(
                persistentWriteFailure: nil,
                beforePromoteFailure: { throw ProbeError.injectedPromoteFailure }
            )
        )
        failing.saveEstimateAndGenerateDocument()
        XCTAssertNotNil(failing.errorMessage)
        XCTAssertFalse(containsContingencyArtifacts(near: fixture.finalURL))
        XCTAssertTrue(try fixture.repository.generatedDocuments().isEmpty)

        let succeeding = try makeViewModel(fixture: fixture, destinationURL: fixture.finalURL)
        succeeding.saveEstimateAndGenerateDocument()
        XCTAssertNil(succeeding.errorMessage)
        XCTAssertEqual(try fixture.repository.generatedDocuments().count, 1)
        XCTAssertFalse(containsContingencyArtifacts(near: fixture.finalURL))
    }

    func testCancelGuardPathStopsContourBeforeAnyWrites() throws {
        let fixture = try makeFixture(tag: "cancel")
        defer { cleanupArtifacts(fixture: fixture) }

        let viewModel = try makeViewModel(fixture: fixture, destinationURL: nil)
        viewModel.saveEstimateAndGenerateDocument()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.infoMessage, "Генерация Offert отменена пользователем")
        XCTAssertTrue(try fixture.repository.estimates(projectId: fixture.projectId).isEmpty)
        XCTAssertTrue(try fixture.repository.generatedDocuments().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.finalURL.path))
        XCTAssertFalse(containsContingencyArtifacts(near: fixture.finalURL))
    }

    private struct Fixture {
        let db: SQLiteDatabase
        let repository: AppRepository
        let dbPath: URL
        let projectId: Int64
        let roomId: Int64
        let workId: Int64
        let materialId: Int64
        let finalURL: URL
        let tempRoot: URL
    }

    private struct StubDestinationProvider: OffertDestinationProviding {
        let url: URL?
        func chooseDestination(defaultFileName: String) throws -> URL? { url }
    }

    private struct StubOffertPDFGenerator: OffertPDFGenerating {
        let shouldFail: Bool
        func generateOffertSwedish(template: DocumentTemplate, company: Company, client: Client, project: Project, result: CalculationResult, saveURL: URL) throws {
            if shouldFail {
                throw ProbeError.injectedPDFFailure
            }
            try Data("%PDF-1.4 simulated".utf8).write(to: saveURL)
        }
    }

    private func makeFixture(tag: String) throws -> Fixture {
        let db = try SQLiteDatabase(filename: "offert-generation-\(tag)-\(UUID().uuidString).sqlite")
        try db.initializeSchema()
        let repository = AppRepository(db: db)

        _ = try repository.insertCompany(Company(id: 0, name: "Smeta AB", orgNumber: "556000-0000", email: "info@smeta.se", phone: "100"))
        let clientId = try repository.insertClient(Client(id: 0, name: "Client", email: "client@example.com", phone: "101", address: "Street"))
        let propertyId = try repository.insertProperty(PropertyObject(id: 0, clientId: clientId, name: "Flat", address: "Address"))
        let speedId = try repository.insertSpeedProfile(SpeedProfile(id: 0, name: "Default", coefficient: 1, daysDivider: 7, sortOrder: 0))
        let projectId = try repository.insertProject(Project(id: 0, clientId: clientId, propertyId: propertyId, name: "Project", speedProfileId: speedId, createdAt: Date()))
        let roomId = try repository.insertRoom(Room(id: 0, projectId: projectId, name: "Room", area: 12, height: 2.6))
        let workId = try repository.insertWorkItem(WorkCatalogItem(id: 0, name: "Work", unit: "h", baseRatePerUnitHour: 1, basePrice: 100, swedishName: "Arbete", sortOrder: 0))
        let materialId = try repository.insertMaterialItem(MaterialCatalogItem(id: 0, name: "Material", unit: "st", basePrice: 80, swedishName: "Material", sortOrder: 0))
        _ = try repository.insertTemplate(DocumentTemplate(id: 0, name: "Offert", language: "sv", headerText: "OFFERT", footerText: "Footer", sortOrder: 0))

        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("offert-generation-\(tag)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let finalURL = tempRoot.appendingPathComponent("Offert-Project.pdf")

        return Fixture(db: db, repository: repository, dbPath: db.dbPath, projectId: projectId, roomId: roomId, workId: workId, materialId: materialId, finalURL: finalURL, tempRoot: tempRoot)
    }

    private func makeViewModel(
        fixture: Fixture,
        destinationURL: URL?,
        pdfShouldFail: Bool = false,
        failureInjection: OffertContourFailureInjection? = nil
    ) throws -> AppViewModel {
        let backupService = BackupService(db: fixture.db)
        let viewModel = AppViewModel(
            repository: fixture.repository,
            backupService: backupService,
            offertPDFGenerator: StubOffertPDFGenerator(shouldFail: pdfShouldFail),
            offertDestinationProvider: StubDestinationProvider(url: destinationURL),
            offertFailureInjection: failureInjection
        )
        try viewModel.reloadAll()
        viewModel.selectedProject = try XCTUnwrap(viewModel.projects.first(where: { $0.id == fixture.projectId }))
        viewModel.calculationResult = CalculationResult(
            rows: [
                CalculationRow(roomId: fixture.roomId, workItemId: fixture.workId, materialItemId: nil, roomName: "Room", itemName: "Work", quantity: 1, speedCoefficient: 1, normHours: 1, coefficient: 1, hours: 1, days: 0.1, laborCost: 100, materialCost: 0, total: 100, formula: "work"),
                CalculationRow(roomId: fixture.roomId, workItemId: nil, materialItemId: fixture.materialId, roomName: "Room", itemName: "Material", quantity: 2, speedCoefficient: 1, normHours: 0, coefficient: 1, hours: 0, days: 0, laborCost: 0, materialCost: 80, total: 80, formula: "material")
            ],
            totalHours: 1,
            totalDays: 0.1,
            totalLabor: 100,
            totalMaterials: 80,
            transportCost: 0,
            equipmentCost: 0,
            wasteCost: 0,
            margin: 0,
            moms: 0,
            grandTotal: 180
        )
        return viewModel
    }

    private func containsContingencyArtifacts(near finalURL: URL) -> Bool {
        guard let files = try? FileManager.default.contentsOfDirectory(at: finalURL.deletingLastPathComponent(), includingPropertiesForKeys: nil) else {
            return false
        }
        return files.contains { url in
            let name = url.lastPathComponent
            return name.contains("offert-pending") || name.contains(".backup-")
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
