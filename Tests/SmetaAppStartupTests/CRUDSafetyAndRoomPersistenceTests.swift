import XCTest
import SQLite3
@testable import SmetaApp

final class CRUDSafetyAndRoomPersistenceTests: XCTestCase {
    func testBlockedDeletesForReferencedEntities() throws {
        let (repo, dbPath) = try makeRepository(tag: "blocked-deletes")
        defer { cleanupSQLiteArtifacts(at: dbPath) }
        try repo.performLaunchBootstrapWrites()

        let client = try XCTUnwrap(try repo.clients().first)
        XCTAssertThrowsError(try repo.deleteClient(id: client.id))

        let property = try XCTUnwrap(try repo.properties().first)
        XCTAssertThrowsError(try repo.deleteProperty(id: property.id))

        let project = try XCTUnwrap(try repo.projects().first)
        XCTAssertThrowsError(try repo.deleteProject(id: project.id))

        let room = try XCTUnwrap(try repo.rooms(projectId: project.id).first)
        XCTAssertNoThrow(try repo.deleteRoom(id: room.id))

        let speedProfileId = try XCTUnwrap(try repo.projects().first?.speedProfileId)
        XCTAssertThrowsError(try repo.deleteSpeedProfile(id: speedProfileId))

        let roomForEstimate = try repo.insertRoom(Room(id: 0, projectId: project.id, name: "Delete guards room", area: 10, height: 2.6))
        let estimateIdForLine = try repo.insertEstimate(Estimate(id: 0, projectId: project.id, speedProfileId: speedProfileId, laborRatePerHour: 100, overheadCoefficient: 1, createdAt: Date()))
        let work = try XCTUnwrap(try repo.workItems().first)
        let material = try XCTUnwrap(try repo.materialItems().first)
        try repo.insertEstimateLine(EstimateLine(id: 0, estimateId: estimateIdForLine, roomId: roomForEstimate, workItemId: work.id, materialItemId: material.id, quantity: 1, unitPrice: 100, coefficient: 1, type: "work"))
        XCTAssertThrowsError(try repo.deleteWorkItem(id: work.id)) { error in
            XCTAssertTrue(error.localizedDescription.contains("строках сметы"))
        }
        XCTAssertThrowsError(try repo.deleteMaterialItem(id: material.id)) { error in
            XCTAssertTrue(error.localizedDescription.contains("строках сметы"))
        }

        let template = try XCTUnwrap(try repo.templates().first)
        let projectId = try XCTUnwrap(try repo.projects().first?.id)
        let estimateId = try repo.insertEstimate(Estimate(id: 0, projectId: projectId, speedProfileId: speedProfileId, laborRatePerHour: 100, overheadCoefficient: 1, createdAt: Date()))
        try repo.insertGeneratedDocument(GeneratedDocument(id: 0, estimateId: estimateId, templateId: template.id, title: "x", path: "/tmp/x", generatedAt: Date()))
        XCTAssertThrowsError(try repo.deleteTemplate(id: template.id)) { error in
            XCTAssertTrue(error.localizedDescription.contains("используется"))
        }
    }

    @MainActor
    func testRoomAssignmentsPersistAcrossReloadAndRoomUpdateRecalculatesGeometry() throws {
        let (repo, dbPath) = try makeRepository(tag: "assignments-and-geometry")
        defer { cleanupSQLiteArtifacts(at: dbPath) }
        try repo.performLaunchBootstrapWrites()
        let vm = AppViewModel(repository: repo, backupService: BackupService(db: repo.db))
        try vm.reloadAll()
        let room = try XCTUnwrap(vm.rooms.first)
        let work = try XCTUnwrap(vm.works.first)
        let material = try XCTUnwrap(vm.materials.first)

        vm.toggleWorkSelection(roomId: room.id, work: work)
        vm.toggleMaterialSelection(roomId: room.id, material: material)
        try vm.reloadAll()

        XCTAssertTrue(vm.selectedWorksByRoom[room.id, default: []].contains(where: { $0.id == work.id }))
        XCTAssertTrue(vm.selectedMaterialsByRoom[room.id, default: []].contains(where: { $0.id == material.id }))

        var edited = room
        edited.length = 4
        edited.width = 3
        edited.height = 2.5
        edited.area = 1
        vm.updateRoom(edited)

        let updated = try XCTUnwrap(try repo.rooms(projectId: room.projectId).first(where: { $0.id == room.id }))
        XCTAssertEqual(updated.area, 12, accuracy: 0.001)
        XCTAssertEqual(updated.ceilingArea, 12, accuracy: 0.001)
        XCTAssertEqual(updated.wallAreaAuto, 35, accuracy: 0.001)
    }

    @MainActor
    func testAssignmentsPersistAfterNewViewModelAndReload() throws {
        let (repo, dbPath) = try makeRepository(tag: "restart-persistence")
        defer { cleanupSQLiteArtifacts(at: dbPath) }
        try repo.performLaunchBootstrapWrites()
        var vm = AppViewModel(repository: repo, backupService: BackupService(db: repo.db))
        try vm.reloadAll()
        let room = try XCTUnwrap(vm.rooms.first)
        let work = try XCTUnwrap(vm.works.first)
        vm.toggleWorkSelection(roomId: room.id, work: work)

        vm = AppViewModel(repository: repo, backupService: BackupService(db: repo.db))
        try vm.reloadAll()
        XCTAssertTrue(vm.selectedWorksByRoom[room.id, default: []].contains(where: { $0.id == work.id }))
        try vm.selectProject(try XCTUnwrap(vm.projects.first))
        vm.calculate()
        XCTAssertNotNil(vm.calculationResult)
        XCTAssertGreaterThan(vm.calculationResult?.rows.count ?? 0, 0)
    }

    @MainActor
    func testSyncAutoSurfacesDoesNotBreakOpeningsBoundToSurface() throws {
        let (repo, dbPath) = try makeRepository(tag: "openings-surface-sync")
        defer { cleanupSQLiteArtifacts(at: dbPath) }
        try repo.performLaunchBootstrapWrites()
        let vm = AppViewModel(repository: repo, backupService: BackupService(db: repo.db))
        try vm.reloadAll()
        let room = try XCTUnwrap(vm.rooms.first)
        let initialWallSurface = try XCTUnwrap(try repo.surfaces(roomId: room.id).first(where: { $0.type == "wall" }))
        try repo.addOpening(Opening(id: 0, roomId: room.id, surfaceId: initialWallSurface.id, type: "window", name: "Bound opening", width: 1, height: 1, count: 1, subtractFromWallArea: true))

        var edited = room
        edited.length = 5
        edited.width = 4
        edited.height = 2.8
        edited.area = 20
        AppViewModel(repository: repo, backupService: BackupService(db: repo.db)).updateRoom(edited)

        let openings = try repo.openings(roomId: room.id)
        XCTAssertEqual(openings.count, 1)
        XCTAssertNil(openings.first?.surfaceId, "opening surface binding must be nulled before replacing auto surfaces")
        let refreshedSurfaces = try repo.surfaces(roomId: room.id)
        XCTAssertEqual(refreshedSurfaces.filter { $0.source == "auto" }.count, 4)
        let wallSurface = try XCTUnwrap(refreshedSurfaces.first(where: { $0.type == "wall" }))
        XCTAssertGreaterThan(wallSurface.area, 0)
    }

    @MainActor
    func testCRUDRuntimeFlowClientPropertyProjectRoom() throws {
        let (repo, dbPath) = try makeRepository(tag: "crud-runtime")
        defer { cleanupSQLiteArtifacts(at: dbPath) }
        try repo.performLaunchBootstrapWrites()
        let vm = AppViewModel(repository: repo, backupService: BackupService(db: repo.db))
        try vm.reloadAll()

        vm.addClient(name: "Runtime Client", email: "r@c.se", phone: "1", address: "A")
        let client = try XCTUnwrap(vm.clients.first(where: { $0.name == "Runtime Client" }))

        vm.addProperty(clientId: client.id, name: "Runtime Property", address: "B")
        let property = try XCTUnwrap(vm.properties.first(where: { $0.name == "Runtime Property" }))

        vm.addProject(clientId: client.id, propertyId: property.id, name: "Runtime Project")
        let project = try XCTUnwrap(vm.projects.first(where: { $0.name == "Runtime Project" }))
        try vm.selectProject(project)

        vm.addRoom(projectId: project.id, name: "Runtime Room", area: 15, height: 2.7)
        let room = try XCTUnwrap(vm.rooms.first(where: { $0.projectId == project.id && $0.name == "Runtime Room" }))
        var roomEdited = room
        roomEdited.height = 3
        vm.updateRoom(roomEdited)
        vm.deleteRoom(room)
    }

    @MainActor
    func testFullCRUDCycleClientPropertyProjectRoomToDeleteClient() throws {
        let (repo, dbPath) = try makeRepository(tag: "full-crud-cycle")
        defer { cleanupSQLiteArtifacts(at: dbPath) }
        try repo.performLaunchBootstrapWrites()
        let vm = AppViewModel(repository: repo, backupService: BackupService(db: repo.db))
        try vm.reloadAll()

        vm.addClient(name: "Full Cycle Client", email: "full@cycle.se", phone: "111", address: "X")
        let client = try XCTUnwrap(vm.clients.first(where: { $0.name == "Full Cycle Client" }))
        vm.addProperty(clientId: client.id, name: "Full Cycle Property", address: "Y")
        let property = try XCTUnwrap(vm.properties.first(where: { $0.name == "Full Cycle Property" }))
        vm.addProject(clientId: client.id, propertyId: property.id, name: "Full Cycle Project")
        let project = try XCTUnwrap(vm.projects.first(where: { $0.name == "Full Cycle Project" }))
        try vm.selectProject(project)
        vm.addRoom(projectId: project.id, name: "Full Cycle Room", area: 12, height: 2.7)
        let room = try XCTUnwrap(vm.rooms.first(where: { $0.projectId == project.id && $0.name == "Full Cycle Room" }))
        vm.deleteRoom(room)
        vm.deleteProject(project)
        vm.deleteProperty(property)
        vm.deleteClient(client)

        XCTAssertFalse(vm.clients.contains(where: { $0.id == client.id }))
        XCTAssertFalse(vm.properties.contains(where: { $0.id == property.id }))
        XCTAssertFalse(vm.projects.contains(where: { $0.id == project.id }))
        XCTAssertFalse(vm.rooms.contains(where: { $0.id == room.id }))
    }

    @MainActor
    func testRoundTripForExtendedEditableFields() throws {
        let (repo, dbPath) = try makeRepository(tag: "extended-field-roundtrip")
        defer { cleanupSQLiteArtifacts(at: dbPath) }
        try repo.performLaunchBootstrapWrites()

        let vm = AppViewModel(repository: repo, backupService: BackupService(db: repo.db))
        try vm.reloadAll()

        let workCategoryId = try XCTUnwrap(firstId(in: "work_categories", db: repo.db))
        let workSubcategoryId = try XCTUnwrap(firstWorkSubcategoryId(categoryId: workCategoryId, db: repo.db))
        let materialCategoryId = try XCTUnwrap(firstId(in: "material_categories", db: repo.db))
        let supplierId = try XCTUnwrap(firstId(in: "suppliers", db: repo.db))
        let roomTemplateId = try XCTUnwrap(firstId(in: "room_templates", db: repo.db))
        let speedProfileId = try XCTUnwrap(vm.speedProfiles.last?.id)

        var work = try XCTUnwrap(vm.works.first)
        work.description = "Подробное описание"
        work.applicability = "b2b"
        work.categoryId = workCategoryId
        work.subcategoryId = workSubcategoryId
        work.includeInStandardOffer = false
        work.complexityCoefficient = 1.3
        work.heightCoefficient = 1.2
        work.conditionCoefficient = 1.15
        work.urgencyCoefficient = 1.4
        work.accessibilityCoefficient = 1.1
        work.additionalLaborHours = 2.5
        work.additionalMaterialUsage = 0.75
        vm.updateWork(work)
        try vm.reloadAll()
        let reloadedWork = try XCTUnwrap(vm.works.first(where: { $0.id == work.id }))
        XCTAssertEqual(reloadedWork.description, "Подробное описание")
        XCTAssertEqual(reloadedWork.applicability, "b2b")
        XCTAssertEqual(reloadedWork.categoryId, workCategoryId)
        XCTAssertEqual(reloadedWork.subcategoryId, workSubcategoryId)
        XCTAssertEqual(reloadedWork.includeInStandardOffer, false)
        XCTAssertEqual(reloadedWork.complexityCoefficient, 1.3, accuracy: 0.0001)
        XCTAssertEqual(reloadedWork.heightCoefficient, 1.2, accuracy: 0.0001)
        XCTAssertEqual(reloadedWork.conditionCoefficient, 1.15, accuracy: 0.0001)
        XCTAssertEqual(reloadedWork.urgencyCoefficient, 1.4, accuracy: 0.0001)
        XCTAssertEqual(reloadedWork.accessibilityCoefficient, 1.1, accuracy: 0.0001)
        XCTAssertEqual(reloadedWork.additionalLaborHours, 2.5, accuracy: 0.0001)
        XCTAssertEqual(reloadedWork.additionalMaterialUsage, 0.75, accuracy: 0.0001)

        var material = try XCTUnwrap(vm.materials.first)
        material.categoryId = materialCategoryId
        material.supplierId = supplierId
        material.comment = "Комментарий к материалу"
        vm.updateMaterial(material)
        try vm.reloadAll()
        let reloadedMaterial = try XCTUnwrap(vm.materials.first(where: { $0.id == material.id }))
        XCTAssertEqual(reloadedMaterial.categoryId, materialCategoryId)
        XCTAssertEqual(reloadedMaterial.supplierId, supplierId)
        XCTAssertEqual(reloadedMaterial.comment, "Комментарий к материалу")

        let project = try XCTUnwrap(vm.projects.first)
        vm.addRoom(projectId: project.id, name: "Roundtrip Room", area: 11, height: 2.7)
        var room = try XCTUnwrap(vm.rooms.first(where: { $0.projectId == project.id && $0.name == "Roundtrip Room" }))
        room.surfaceCondition = "needs_prep"
        room.notes = "Нужна дополнительная защита пола"
        room.photoPath = "/tmp/room-photo.png"
        room.roomTemplateId = roomTemplateId
        vm.updateRoom(room)
        try vm.reloadAll()
        let reloadedRoom = try XCTUnwrap(vm.rooms.first(where: { $0.id == room.id }))
        XCTAssertEqual(reloadedRoom.surfaceCondition, "needs_prep")
        XCTAssertEqual(reloadedRoom.notes, "Нужна дополнительная защита пола")
        XCTAssertEqual(reloadedRoom.photoPath, "/tmp/room-photo.png")
        XCTAssertEqual(reloadedRoom.roomTemplateId, roomTemplateId)

        let client = try XCTUnwrap(vm.clients.first)
        let property = try XCTUnwrap(vm.properties.first(where: { $0.clientId == client.id }))
        vm.addProject(clientId: client.id, propertyId: property.id, speedProfileId: speedProfileId, pricingMode: PricingMode.combined.rawValue, isDraft: false, name: "Roundtrip Project")
        try vm.reloadAll()
        let createdProject = try XCTUnwrap(vm.projects.first(where: { $0.name == "Roundtrip Project" }))
        XCTAssertEqual(createdProject.speedProfileId, speedProfileId)
        XCTAssertEqual(createdProject.pricingMode, PricingMode.combined.rawValue)
        XCTAssertEqual(createdProject.isDraft, false)
    }

    @MainActor
    func testWorkValidationRejectsSubcategoryWithoutCategory() throws {
        let (repo, dbPath) = try makeRepository(tag: "subcategory-without-category")
        defer { cleanupSQLiteArtifacts(at: dbPath) }
        try repo.performLaunchBootstrapWrites()
        let vm = AppViewModel(repository: repo, backupService: BackupService(db: repo.db))
        try vm.reloadAll()

        let workSubcategoryId = try XCTUnwrap(firstId(in: "work_subcategories", db: repo.db))
        var work = try XCTUnwrap(vm.works.first)
        work.categoryId = nil
        work.subcategoryId = workSubcategoryId

        let updateResult = vm.updateWork(work)
        XCTAssertFalse(updateResult)
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.errorMessage?.contains("Subcategory ID можно указать только вместе с Category ID") ?? false)
    }

    @MainActor
    func testUpdateValidationRejectsEmptyRequiredFields() throws {
        let (repo, dbPath) = try makeRepository(tag: "update-required-fields")
        defer { cleanupSQLiteArtifacts(at: dbPath) }
        try repo.performLaunchBootstrapWrites()
        let vm = AppViewModel(repository: repo, backupService: BackupService(db: repo.db))
        try vm.reloadAll()

        var client = try XCTUnwrap(vm.clients.first)
        client.name = "   "
        XCTAssertFalse(vm.updateClient(client))
        XCTAssertEqual(vm.errorMessage, "Имя клиента обязательно")

        var property = try XCTUnwrap(vm.properties.first)
        property.name = ""
        XCTAssertFalse(vm.updateProperty(property))
        XCTAssertEqual(vm.errorMessage, "Название объекта обязательно")

        var project = try XCTUnwrap(vm.projects.first)
        project.name = "   "
        XCTAssertFalse(vm.updateProject(project))
        XCTAssertEqual(vm.errorMessage, "Название проекта обязательно")

        var work = try XCTUnwrap(vm.works.first)
        work.name = ""
        XCTAssertFalse(vm.updateWork(work))
        XCTAssertTrue(vm.errorMessage?.contains("Название работы обязательно") ?? false)

        var material = try XCTUnwrap(vm.materials.first)
        material.unit = " "
        XCTAssertFalse(vm.updateMaterial(material))
        XCTAssertTrue(vm.errorMessage?.contains("Единица измерения материала обязательна") ?? false)
    }

    @MainActor
    func testCreateValidationRejectsEmptyRequiredFields() throws {
        let (repo, dbPath) = try makeRepository(tag: "create-required-fields")
        defer { cleanupSQLiteArtifacts(at: dbPath) }
        try repo.performLaunchBootstrapWrites()
        let vm = AppViewModel(repository: repo, backupService: BackupService(db: repo.db))
        try vm.reloadAll()

        XCTAssertFalse(vm.addClient(name: " ", email: "", phone: "", address: ""))
        XCTAssertEqual(vm.errorMessage, "Имя клиента обязательно")

        let client = try XCTUnwrap(vm.clients.first)
        XCTAssertFalse(vm.addProperty(clientId: client.id, name: " ", address: ""))
        XCTAssertEqual(vm.errorMessage, "Название объекта обязательно")

        let property = try XCTUnwrap(vm.properties.first(where: { $0.clientId == client.id }))
        let speedId = try XCTUnwrap(vm.speedProfiles.first?.id)
        XCTAssertFalse(vm.addProject(clientId: client.id, propertyId: property.id, speedProfileId: speedId, pricingMode: PricingMode.fixed.rawValue, isDraft: true, name: " "))
        XCTAssertEqual(vm.errorMessage, "Название проекта обязательно")

        XCTAssertFalse(vm.addSpeed(SpeedProfile(id: 0, name: " ", coefficient: 1, daysDivider: 7, sortOrder: 0)))
        XCTAssertEqual(vm.errorMessage, "Название профиля скорости обязательно")

        XCTAssertFalse(vm.addTemplate(DocumentTemplate(id: 0, name: " ", language: "sv", headerText: "", footerText: "", sortOrder: 0)))
        XCTAssertEqual(vm.errorMessage, "Название шаблона обязательно")
    }

    @MainActor
    func testReloadAllRollbackRestoresRoomAssignmentsOnFailure() throws {
        let (repo, dbPath) = try makeRepository(tag: "rollback-room-assignments")
        defer { cleanupSQLiteArtifacts(at: dbPath) }
        try repo.performLaunchBootstrapWrites()
        let vm = AppViewModel(repository: repo, backupService: BackupService(db: repo.db))
        try vm.reloadAll()

        let room = try XCTUnwrap(vm.rooms.first)
        let work = try XCTUnwrap(vm.works.first)
        let material = try XCTUnwrap(vm.materials.first)
        vm.toggleWorkSelection(roomId: room.id, work: work)
        vm.toggleMaterialSelection(roomId: room.id, material: material)

        let expectedWorks = vm.selectedWorksByRoom
        let expectedMaterials = vm.selectedMaterialsByRoom

        try repo.db.execute("DROP TABLE calculation_rules;")
        XCTAssertThrowsError(try vm.reloadAll())

        XCTAssertEqual(vm.selectedWorksByRoom[room.id]?.map(\.id), expectedWorks[room.id]?.map(\.id))
        XCTAssertEqual(vm.selectedMaterialsByRoom[room.id]?.map(\.id), expectedMaterials[room.id]?.map(\.id))
    }

    private func makeRepository(tag: String) throws -> (AppRepository, URL) {
        let db = try SQLiteDatabase(filename: "crud-safety-\(tag)-\(UUID().uuidString).sqlite")
        try db.initializeSchema()
        return (AppRepository(db: db), db.dbPath)
    }

    private func cleanupSQLiteArtifacts(at dbPath: URL) {
        let fm = FileManager.default
        try? fm.removeItem(at: dbPath)
        try? fm.removeItem(at: URL(fileURLWithPath: dbPath.path + "-wal"))
        try? fm.removeItem(at: URL(fileURLWithPath: dbPath.path + "-shm"))
    }

    private func firstId(in table: String, db: SQLiteDatabase) throws -> Int64? {
        var id: Int64?
        try db.withStatement("SELECT id FROM \(table) ORDER BY id LIMIT 1") { stmt in
            guard sqlite3_step(stmt) == SQLITE_ROW else { return }
            id = sqlite3_column_int64(stmt, 0)
        }
        return id
    }

    private func firstWorkSubcategoryId(categoryId: Int64, db: SQLiteDatabase) throws -> Int64? {
        var id: Int64?
        try db.withStatement("SELECT id FROM work_subcategories WHERE category_id=? ORDER BY id LIMIT 1") { stmt in
            sqlite3_bind_int64(stmt, 1, categoryId)
            guard sqlite3_step(stmt) == SQLITE_ROW else { return }
            id = sqlite3_column_int64(stmt, 0)
        }
        return id
    }
}
