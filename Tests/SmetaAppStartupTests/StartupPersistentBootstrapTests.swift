import XCTest
@testable import SmetaApp

final class StartupPersistentBootstrapTests: XCTestCase {
    enum ProbeError: Error {
        case injectedFailure
    }

    func testNormalBootstrapSeedsExpectedPersistentData() throws {
        let (repo, dbPath) = try makeRepository(tag: "normal")
        defer { cleanupSQLiteArtifacts(at: dbPath) }

        try repo.performLaunchBootstrapWrites()

        XCTAssertEqual(try repo.clients().count, 2)
        XCTAssertEqual(try repo.projects().count, 1)
        XCTAssertEqual(try repo.documentSeries().count, 6)
        XCTAssertEqual(try repo.taxProfiles().count, 3)
    }

    func testInjectedFailureRollsBackAllBootstrapWrites() throws {
        let (repo, dbPath) = try makeRepository(tag: "rollback")
        defer { cleanupSQLiteArtifacts(at: dbPath) }

        XCTAssertThrowsError(
            try repo.performLaunchBootstrapWrites(failureInjection: {
                throw ProbeError.injectedFailure
            })
        )

        XCTAssertTrue(try repo.clients().isEmpty)
        XCTAssertTrue(try repo.projects().isEmpty)
        XCTAssertTrue(try repo.documentSeries().isEmpty)
        XCTAssertTrue(try repo.taxProfiles().isEmpty)
    }

    func testRepeatedBootstrapAfterFailureRemainsConsistentWithoutGarbageGrowth() throws {
        let (repo, dbPath) = try makeRepository(tag: "repeat")
        defer { cleanupSQLiteArtifacts(at: dbPath) }

        XCTAssertThrowsError(
            try repo.performLaunchBootstrapWrites(failureInjection: {
                throw ProbeError.injectedFailure
            })
        )

        try repo.performLaunchBootstrapWrites()
        XCTAssertEqual(try repo.clients().count, 2)
        XCTAssertEqual(try repo.projects().count, 1)
        XCTAssertEqual(try repo.documentSeries().count, 6)
        XCTAssertEqual(try repo.taxProfiles().count, 3)

        try repo.performLaunchBootstrapWrites()
        XCTAssertEqual(try repo.clients().count, 2)
        XCTAssertEqual(try repo.projects().count, 1)
        XCTAssertEqual(try repo.documentSeries().count, 6)
        XCTAssertEqual(try repo.taxProfiles().count, 3)
    }

    private func makeRepository(tag: String) throws -> (AppRepository, URL) {
        let db = try SQLiteDatabase(filename: "startup-tests-\(tag)-\(UUID().uuidString).sqlite")
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
