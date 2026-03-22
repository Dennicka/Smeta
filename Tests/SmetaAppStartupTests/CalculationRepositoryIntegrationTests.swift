import XCTest
@testable import SmetaApp

final class CalculationRepositoryIntegrationTests: XCTestCase {
    @MainActor
    func testCalculationPathThroughRepositoryAndViewModelProducesExpectedTotals() throws {
        let (repository, dbPath) = try makeRepository(tag: "calc-path")
        defer { cleanupSQLiteArtifacts(at: dbPath) }
        try repository.performLaunchBootstrapWrites()

        let project = try XCTUnwrap(try repository.projects().first)
        let speedId = try repository.insertSpeedProfile(SpeedProfile(id: 0, name: "Oracle speed", coefficient: 1, daysDivider: 5, sortOrder: 999))
        try repository.updateProjectSpeedProfile(projectId: project.id, speedProfileId: speedId)

        let roomId = try repository.createRoomWithAutoSurfaces(
            Room(id: 0, projectId: project.id, name: "Oracle room", area: 12, height: 2.5, length: 4, width: 3, ceilingArea: 12, wallAreaAuto: 35)
        )
        let workId = try repository.insertWorkItem(
            WorkCatalogItem(id: 0, name: "Oracle work", unit: "м²", baseRatePerUnitHour: 0.5, basePrice: 0, swedishName: "", sortOrder: 777, mediumSpeed: 2)
        )
        let materialId = try repository.insertMaterialItem(
            MaterialCatalogItem(id: 0, name: "Oracle material", unit: "l", basePrice: 20, swedishName: "", sortOrder: 777, markupPercent: 0, usagePerWorkUnit: 0.5)
        )

        try repository.replaceRoomWorkAssignments(roomId: roomId, workIds: [workId])
        try repository.replaceRoomMaterialAssignments(roomId: roomId, materialIds: [materialId])
        try repository.upsertCalculationRules(
            CalculationRules(
                id: 1,
                transportPercent: 0,
                equipmentPercent: 0,
                wastePercent: 0,
                marginPercent: 0,
                momsPercent: 0,
                minSpeedRate: 0.01,
                minWorkMediumSpeed: 0.1,
                minWorkBaseRatePerUnitHour: 0.01,
                minSpeedDaysDivider: 0.1,
                minMaterialUsagePerWorkUnit: 0.01,
                minMaterialQuantity: 0.01
            )
        )

        let vm = AppViewModel(repository: repository, backupService: BackupService(db: repository.db))
        try vm.reloadAll()
        try vm.selectProject(project)
        vm.setSelectedSpeedProfile(speedId)
        vm.pricingMode = .fixed
        vm.laborRatePerHour = 100
        vm.overheadCoefficient = 1

        vm.calculate()

        let result = try XCTUnwrap(vm.calculationResult)
        // work: quantity 35 (wall), norm 35*0.5=17.5, speedRate 1*2=2, hours 8.75, labor 875
        XCTAssertEqual(result.totalHours, 8.75, accuracy: 0.0001)
        XCTAssertEqual(result.totalLabor, 875, accuracy: 0.0001)
        // material: 12 * 0.5 = 6, cost = 6 * 20 = 120
        XCTAssertEqual(result.totalMaterials, 120, accuracy: 0.0001)
        XCTAssertEqual(result.grandTotal, 995, accuracy: 0.0001)
    }

    @MainActor
    func testCalculationResultIsRepeatableAcrossRepeatedCalculateAndRecreatedViewModel() throws {
        let (repository, dbPath) = try makeRepository(tag: "calc-repeat")
        defer { cleanupSQLiteArtifacts(at: dbPath) }
        try repository.performLaunchBootstrapWrites()

        let project = try XCTUnwrap(try repository.projects().first)
        let roomId = try repository.createRoomWithAutoSurfaces(
            Room(id: 0, projectId: project.id, name: "Repeat room", area: 10, height: 2.6, length: 4, width: 2.5, ceilingArea: 10, wallAreaAuto: 33.8)
        )
        let workId = try repository.insertWorkItem(
            WorkCatalogItem(id: 0, name: "Repeat work", unit: "м²", baseRatePerUnitHour: 0.3, basePrice: 0, swedishName: "", sortOrder: 778, mediumSpeed: 1.5)
        )
        let materialId = try repository.insertMaterialItem(
            MaterialCatalogItem(id: 0, name: "Repeat material", unit: "kg", basePrice: 12, swedishName: "", sortOrder: 778, markupPercent: 25, usagePerWorkUnit: 0.4)
        )
        try repository.replaceRoomWorkAssignments(roomId: roomId, workIds: [workId])
        try repository.replaceRoomMaterialAssignments(roomId: roomId, materialIds: [materialId])

        let vm1 = AppViewModel(repository: repository, backupService: BackupService(db: repository.db))
        try vm1.reloadAll()
        try vm1.selectProject(project)
        vm1.laborRatePerHour = 110
        vm1.overheadCoefficient = 1.15

        vm1.calculate()
        let first = try XCTUnwrap(vm1.calculationResult)

        vm1.calculate()
        let second = try XCTUnwrap(vm1.calculationResult)

        XCTAssertEqual(first.totalHours, second.totalHours, accuracy: 0.0000001)
        XCTAssertEqual(first.totalLabor, second.totalLabor, accuracy: 0.0000001)
        XCTAssertEqual(first.totalMaterials, second.totalMaterials, accuracy: 0.0000001)
        XCTAssertEqual(first.grandTotal, second.grandTotal, accuracy: 0.0000001)

        let vm2 = AppViewModel(repository: repository, backupService: BackupService(db: repository.db))
        try vm2.reloadAll()
        try vm2.selectProject(project)
        vm2.laborRatePerHour = 110
        vm2.overheadCoefficient = 1.15
        vm2.calculate()
        let third = try XCTUnwrap(vm2.calculationResult)

        XCTAssertEqual(first.totalHours, third.totalHours, accuracy: 0.0000001)
        XCTAssertEqual(first.totalLabor, third.totalLabor, accuracy: 0.0000001)
        XCTAssertEqual(first.totalMaterials, third.totalMaterials, accuracy: 0.0000001)
        XCTAssertEqual(first.grandTotal, third.grandTotal, accuracy: 0.0000001)
    }

    private func makeRepository(tag: String) throws -> (AppRepository, URL) {
        let db = try SQLiteDatabase(filename: "calculation-integration-\(tag)-\(UUID().uuidString).sqlite")
        try db.initializeSchema()
        return (AppRepository(db: db), db.dbPath)
    }

    private func cleanupSQLiteArtifacts(at dbPath: URL) {
        let fm = FileManager.default
        try? fm.removeItem(at: dbPath)
        try? fm.removeItem(at: URL(fileURLWithPath: dbPath.path + "-wal"))
        try? fm.removeItem(at: URL(fileURLWithPath: dbPath.path + "-shm"))
    }
}
