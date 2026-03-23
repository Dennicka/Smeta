import XCTest
import SQLite3
@testable import SmetaApp

@MainActor
final class PracticalEstimateOffertContourTests: XCTestCase {
    func testEstimateSaveAndReloadContourPersistsLinesAndTotals() throws {
        let fixture = try makeFixture(tag: "estimate-save-reload")
        defer { cleanupArtifacts(fixture: fixture) }

        let vm = try makeViewModel(fixture: fixture)
        try prepareCalculatedState(vm: vm, projectId: fixture.primary.projectId)

        let totalBeforeSave = try XCTUnwrap(vm.calculationResult).totalLabor + try XCTUnwrap(vm.calculationResult).totalMaterials
        vm.saveEstimate()

        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.infoMessage, "Смета сохранена")

        let savedEstimate = try XCTUnwrap(try fixture.repository.estimates(projectId: fixture.primary.projectId).first)
        let savedLines = try fixture.repository.estimateLines(estimateId: savedEstimate.id)
        XCTAssertEqual(savedLines.count, 2)
        let savedTotal = savedLines.reduce(0) { $0 + ($1.quantity * $1.unitPrice) }
        XCTAssertEqual(savedTotal, totalBeforeSave, accuracy: 0.0001)

        let vmReloaded = try makeViewModel(fixture: fixture)
        XCTAssertEqual(try fixture.repository.estimates(projectId: fixture.primary.projectId).count, 1)
        XCTAssertNil(vmReloaded.errorMessage)
    }

    func testSelectedProjectCalculateSaveContourPersistsOnlySelectedProjectRooms() throws {
        let fixture = try makeFixture(tag: "selected-project")
        defer { cleanupArtifacts(fixture: fixture) }

        let vm = try makeViewModel(fixture: fixture)
        try prepareCalculatedState(vm: vm, projectId: fixture.primary.projectId)
        vm.saveEstimate()

        let estimate = try XCTUnwrap(try fixture.repository.estimates(projectId: fixture.primary.projectId).first)
        let estimateLines = try fixture.repository.estimateLines(estimateId: estimate.id)
        XCTAssertFalse(estimateLines.isEmpty)
        XCTAssertTrue(estimateLines.allSatisfy { $0.roomId == fixture.primary.roomId })
        XCTAssertTrue(try fixture.repository.estimates(projectId: fixture.secondary.projectId).isEmpty)
    }

    func testCreateOffertDraftFromSavedEstimateContourUsesRealProjectData() throws {
        let fixture = try makeFixture(tag: "offert-draft")
        defer { cleanupArtifacts(fixture: fixture) }

        let vm = try makeViewModel(fixture: fixture)
        try prepareCalculatedState(vm: vm, projectId: fixture.primary.projectId)
        vm.saveEstimate()
        vm.createOffertDraftFromSelectedProject(title: "Offert \(fixture.primary.projectName)", useRot: false)

        XCTAssertNil(vm.errorMessage)
        let offert = try XCTUnwrap(vm.businessDocuments.first(where: { $0.type == DocumentType.offert.rawValue }))
        XCTAssertEqual(offert.projectId, fixture.primary.projectId)
        XCTAssertEqual(offert.title, "Offert \(fixture.primary.projectName)")
        XCTAssertEqual(offert.status, DocumentStatus.draft.rawValue)

        let lines = try fixture.repository.businessDocumentLines(documentId: offert.id)
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines.allSatisfy { !$0.description.lowercased().contains("demo") && !$0.description.lowercased().contains("mock") })
    }

    func testOffertPDFExportContourFromRealSavedState() throws {
        let fixture = try makeFixture(tag: "offert-export")
        defer { cleanupArtifacts(fixture: fixture) }

        let vm = try makeViewModel(
            fixture: fixture,
            destinationURL: fixture.finalURL,
            businessPDFGenerator: StubBusinessPDFGenerator()
        )
        try prepareCalculatedState(vm: vm, projectId: fixture.primary.projectId)
        vm.saveEstimate()
        vm.createOffertDraftFromSelectedProject(title: "Offert \(fixture.primary.projectName)", useRot: false)

        let offert = try XCTUnwrap(vm.businessDocuments.first(where: { $0.type == DocumentType.offert.rawValue }))
        vm.exportDocumentPDF(offert)

        XCTAssertNil(vm.errorMessage)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.finalURL.path))
        XCTAssertEqual(try exportLogCount(repository: fixture.repository), 1)
    }

    func testRepeatabilityReloadViewModelDocumentStateRemainsValid() throws {
        let fixture = try makeFixture(tag: "repeatability")
        defer { cleanupArtifacts(fixture: fixture) }

        let vm1 = try makeViewModel(fixture: fixture)
        try prepareCalculatedState(vm: vm1, projectId: fixture.primary.projectId)
        vm1.saveEstimate()
        vm1.createOffertDraftFromSelectedProject(title: "Offert \(fixture.primary.projectName)", useRot: false)

        let vm2 = try makeViewModel(
            fixture: fixture,
            destinationURL: fixture.finalURL,
            businessPDFGenerator: StubBusinessPDFGenerator()
        )
        try vm2.selectProject(try XCTUnwrap(vm2.projects.first(where: { $0.id == fixture.primary.projectId })))
        let offert = try XCTUnwrap(vm2.businessDocuments.first(where: { $0.type == DocumentType.offert.rawValue }))
        let lines = try fixture.repository.businessDocumentLines(documentId: offert.id)
        XCTAssertEqual(lines.count, 2)

        vm2.exportDocumentPDF(offert)
        XCTAssertNil(vm2.errorMessage)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.finalURL.path))
    }

    private struct ProjectFixture {
        let projectId: Int64
        let projectName: String
        let roomId: Int64
        let workId: Int64
        let materialId: Int64
    }

    private struct Fixture {
        let db: SQLiteDatabase
        let repository: AppRepository
        let dbPath: URL
        let primary: ProjectFixture
        let secondary: ProjectFixture
        let finalURL: URL
        let tempRoot: URL
    }

    private struct StubBusinessDestinationProvider: BusinessDocumentDestinationProviding {
        let url: URL?
        func chooseDestination(defaultFileName: String) throws -> URL? { url }
    }

    private struct StubBusinessPDFGenerator: BusinessDocumentPDFGenerating {
        func generateBusinessDocumentPDF(title: String, body: String, saveURL: URL) throws {
            try Data("%PDF-1.4 offert".utf8).write(to: saveURL)
        }
    }

    private func makeFixture(tag: String) throws -> Fixture {
        let db = try SQLiteDatabase(filename: "practical-offert-\(tag)-\(UUID().uuidString).sqlite")
        try db.initializeSchema()
        let repository = AppRepository(db: db)
        try repository.performLaunchBootstrapWrites()

        let clientId = try repository.insertClient(Client(id: 0, name: "Contour Client", email: "client@example.com", phone: "100", address: "Street 1"))
        let propertyId = try repository.insertProperty(PropertyObject(id: 0, clientId: clientId, name: "Contour Home", address: "Street 1"))
        let speedId = try repository.insertSpeedProfile(SpeedProfile(id: 0, name: "Contour Speed", coefficient: 1, daysDivider: 7, sortOrder: 50))

        let primaryProjectId = try repository.insertProject(Project(id: 0, clientId: clientId, propertyId: propertyId, name: "Primary contour", speedProfileId: speedId, createdAt: Date()))
        let secondaryProjectId = try repository.insertProject(Project(id: 0, clientId: clientId, propertyId: propertyId, name: "Secondary contour", speedProfileId: speedId, createdAt: Date()))

        let primaryRoomId = try repository.createRoomWithAutoSurfaces(Room(id: 0, projectId: primaryProjectId, name: "Primary room", area: 12, height: 2.6))
        let secondaryRoomId = try repository.createRoomWithAutoSurfaces(Room(id: 0, projectId: secondaryProjectId, name: "Secondary room", area: 9, height: 2.4))

        let primaryWorkId = try repository.insertWorkItem(WorkCatalogItem(id: 0, name: "Primary work", unit: "h", baseRatePerUnitHour: 1, basePrice: 100, swedishName: "Primary arbete", sortOrder: 90))
        let secondaryWorkId = try repository.insertWorkItem(WorkCatalogItem(id: 0, name: "Secondary work", unit: "h", baseRatePerUnitHour: 1, basePrice: 50, swedishName: "Secondary arbete", sortOrder: 91))
        let primaryMaterialId = try repository.insertMaterialItem(MaterialCatalogItem(id: 0, name: "Primary material", unit: "st", basePrice: 70, swedishName: "Primary material", sortOrder: 90))
        let secondaryMaterialId = try repository.insertMaterialItem(MaterialCatalogItem(id: 0, name: "Secondary material", unit: "st", basePrice: 30, swedishName: "Secondary material", sortOrder: 91))

        try repository.replaceRoomWorkAssignments(roomId: primaryRoomId, workIds: [primaryWorkId])
        try repository.replaceRoomMaterialAssignments(roomId: primaryRoomId, materialIds: [primaryMaterialId])
        try repository.replaceRoomWorkAssignments(roomId: secondaryRoomId, workIds: [secondaryWorkId])
        try repository.replaceRoomMaterialAssignments(roomId: secondaryRoomId, materialIds: [secondaryMaterialId])

        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("practical-offert-\(tag)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let finalURL = tempRoot.appendingPathComponent("Offert-\(tag).pdf")

        return Fixture(
            db: db,
            repository: repository,
            dbPath: db.dbPath,
            primary: ProjectFixture(projectId: primaryProjectId, projectName: "Primary contour", roomId: primaryRoomId, workId: primaryWorkId, materialId: primaryMaterialId),
            secondary: ProjectFixture(projectId: secondaryProjectId, projectName: "Secondary contour", roomId: secondaryRoomId, workId: secondaryWorkId, materialId: secondaryMaterialId),
            finalURL: finalURL,
            tempRoot: tempRoot
        )
    }

    private func makeViewModel(
        fixture: Fixture,
        destinationURL: URL? = nil,
        businessPDFGenerator: BusinessDocumentPDFGenerating = StubBusinessPDFGenerator()
    ) throws -> AppViewModel {
        let viewModel = AppViewModel(
            repository: fixture.repository,
            backupService: BackupService(db: fixture.db),
            businessDocumentPDFGenerator: businessPDFGenerator,
            businessDocumentDestinationProvider: StubBusinessDestinationProvider(url: destinationURL)
        )
        try viewModel.reloadAll()
        return viewModel
    }

    private func prepareCalculatedState(vm: AppViewModel, projectId: Int64) throws {
        let project = try XCTUnwrap(vm.projects.first(where: { $0.id == projectId }))
        try vm.selectProject(project)
        vm.pricingMode = .fixed
        vm.laborRatePerHour = 100
        vm.overheadCoefficient = 1
        vm.calculate()

        let result = try XCTUnwrap(vm.calculationResult)
        XCTAssertFalse(result.rows.isEmpty)
        let validRoomIds = Set(vm.rooms.filter { $0.projectId == projectId }.map(\.id))
        XCTAssertTrue(result.rows.allSatisfy { validRoomIds.contains($0.roomId) })
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

    private func cleanupArtifacts(fixture: Fixture) {
        let fm = FileManager.default
        try? fm.removeItem(at: fixture.tempRoot)
        try? fm.removeItem(at: fixture.dbPath)
        try? fm.removeItem(at: URL(fileURLWithPath: fixture.dbPath.path + "-wal"))
        try? fm.removeItem(at: URL(fileURLWithPath: fixture.dbPath.path + "-shm"))
    }
}
