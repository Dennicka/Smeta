import XCTest
@testable import SmetaApp

final class BackupRestoreContourTests: XCTestCase {
    func testBackupSuccessCreatesBackupArtifact() throws {
        let (repo, backupService, dbPath) = try makeSystem(tag: "backup-success")
        defer { cleanupSQLiteArtifacts(at: dbPath) }

        try repo.performLaunchBootstrapWrites()
        let clientId = try repo.insertClient(Client(id: 0, name: "Contour baseline", email: "", phone: "", address: ""))
        XCTAssertNotEqual(clientId, 0)

        let backupURL = dbPath.deletingLastPathComponent().appendingPathComponent("backup-success-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: backupURL) }

        try backupService.backupDatabase(to: backupURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))
        let attributes = try FileManager.default.attributesOfItem(atPath: backupURL.path)
        let backupSize = try XCTUnwrap(attributes[.size] as? NSNumber)
        XCTAssertGreaterThan(backupSize.intValue, 0)
    }

    func testRestoreSuccessRollsDataBackToBackupSnapshot() throws {
        let (repo, backupService, dbPath) = try makeSystem(tag: "restore-success")
        defer { cleanupSQLiteArtifacts(at: dbPath) }

        try repo.performLaunchBootstrapWrites()
        _ = try repo.insertClient(Client(id: 0, name: "Snapshot A", email: "", phone: "", address: ""))

        let backupURL = dbPath.deletingLastPathComponent().appendingPathComponent("restore-success-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: backupURL) }
        try backupService.backupDatabase(to: backupURL)

        _ = try repo.insertClient(Client(id: 0, name: "Mutation B", email: "", phone: "", address: ""))
        XCTAssertTrue(try repo.clients().contains(where: { $0.name == "Mutation B" }))

        try backupService.restoreDatabase(from: backupURL)

        let namesAfterRestore = try repo.clients().map(\.name)
        XCTAssertTrue(namesAfterRestore.contains("Snapshot A"))
        XCTAssertFalse(namesAfterRestore.contains("Mutation B"))
    }

    func testRestoreFailureFromInvalidBackupLeavesLiveDatabaseUntouched() throws {
        let (repo, backupService, dbPath) = try makeSystem(tag: "restore-invalid")
        defer { cleanupSQLiteArtifacts(at: dbPath) }

        try repo.performLaunchBootstrapWrites()
        _ = try repo.insertClient(Client(id: 0, name: "Stable client", email: "", phone: "", address: ""))
        let expectedNames = try Set(repo.clients().map(\.name))

        let invalidBackupURL = dbPath.deletingLastPathComponent().appendingPathComponent("restore-invalid-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: invalidBackupURL) }
        try Data("not-a-sqlite-backup".utf8).write(to: invalidBackupURL)

        XCTAssertThrowsError(try backupService.restoreDatabase(from: invalidBackupURL))

        let actualNames = try Set(repo.clients().map(\.name))
        XCTAssertEqual(actualNames, expectedNames)
    }

    func testRepeatedBackupRestoreCyclesStayDeterministicWithoutGarbage() throws {
        let (repo, backupService, dbPath) = try makeSystem(tag: "restore-repeat")
        defer { cleanupSQLiteArtifacts(at: dbPath) }

        try repo.performLaunchBootstrapWrites()
        _ = try repo.insertClient(Client(id: 0, name: "Cycle baseline", email: "", phone: "", address: ""))

        let backupURL = dbPath.deletingLastPathComponent().appendingPathComponent("restore-repeat-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: backupURL) }

        for cycle in 1...3 {
            try backupService.backupDatabase(to: backupURL)
            _ = try repo.insertClient(Client(id: 0, name: "Cycle mutation \(cycle)", email: "", phone: "", address: ""))
            XCTAssertTrue(try repo.clients().contains(where: { $0.name == "Cycle mutation \(cycle)" }))

            try backupService.restoreDatabase(from: backupURL)

            let names = try repo.clients().map(\.name)
            XCTAssertTrue(names.contains("Cycle baseline"))
            XCTAssertFalse(names.contains("Cycle mutation \(cycle)"))

            let directoryItems = try FileManager.default.contentsOfDirectory(atPath: dbPath.deletingLastPathComponent().path)
            XCTAssertFalse(directoryItems.contains(where: { $0.contains("restore-replacement-") || $0.contains("restore-rollback-") }))
        }
    }

    @MainActor
    func testReloadingNewViewModelAfterRestoreReadsRestoredState() throws {
        let (repo, backupService, dbPath) = try makeSystem(tag: "restore-viewmodel")
        defer { cleanupSQLiteArtifacts(at: dbPath) }

        try repo.performLaunchBootstrapWrites()
        _ = try repo.insertClient(Client(id: 0, name: "VM snapshot", email: "", phone: "", address: ""))

        let backupURL = dbPath.deletingLastPathComponent().appendingPathComponent("restore-viewmodel-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: backupURL) }
        try backupService.backupDatabase(to: backupURL)

        _ = try repo.insertClient(Client(id: 0, name: "VM mutation", email: "", phone: "", address: ""))

        try backupService.restoreDatabase(from: backupURL)

        let reloadedVM = AppViewModel(repository: repo, backupService: backupService)
        try reloadedVM.reloadAll()

        let clientNames = Set(reloadedVM.clients.map(\.name))
        XCTAssertTrue(clientNames.contains("VM snapshot"))
        XCTAssertFalse(clientNames.contains("VM mutation"))
    }

    private func makeSystem(tag: String) throws -> (AppRepository, BackupService, URL) {
        let db = try SQLiteDatabase(filename: "backup-restore-tests-\(tag)-\(UUID().uuidString).sqlite")
        try db.initializeSchema()
        let repo = AppRepository(db: db)
        return (repo, BackupService(db: db), db.dbPath)
    }

    private func cleanupSQLiteArtifacts(at dbPath: URL) {
        let manager = FileManager.default
        try? manager.removeItem(at: dbPath)
        try? manager.removeItem(at: URL(fileURLWithPath: dbPath.path + "-wal"))
        try? manager.removeItem(at: URL(fileURLWithPath: dbPath.path + "-shm"))
    }
}
