import XCTest
@testable import SmetaCore

final class ExportArtifactCoordinatorTests: XCTestCase {
    func testCleanupOnEmptyTempAreaIsNoOp() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let coordinator = ExportArtifactCoordinator()

        let report = coordinator.cleanupManagedArtifacts(dataFolder: root)

        XCTAssertTrue(report.isNoOp)
        XCTAssertEqual(report.deletedCount, 0)
        XCTAssertTrue(report.failures.isEmpty)
    }

    func testCleanupRemovesRealAppOwnedTempArtifacts() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let coordinator = ExportArtifactCoordinator()
        let first = try coordinator.prepareProjectBundleStagingFolder(dataFolder: root, projectId: 1, timestamp: 100)
        let second = try coordinator.prepareProjectBundleStagingFolder(dataFolder: root, projectId: 2, timestamp: 200)
        try Data("a".utf8).write(to: first.appendingPathComponent("manifest.json"))
        try Data("b".utf8).write(to: second.appendingPathComponent("invoice_register.csv"))

        let report = coordinator.cleanupManagedArtifacts(dataFolder: root)

        XCTAssertEqual(report.scannedCount, 2)
        XCTAssertEqual(report.deletedCount, 2)
        XCTAssertTrue(report.failures.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.path))
    }

    func testFinalUserExportOutsideManagedAreaIsNotDeleted() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let coordinator = ExportArtifactCoordinator()
        _ = try coordinator.prepareProjectBundleStagingFolder(dataFolder: root, projectId: 1, timestamp: 100)

        let userFolder = root.appendingPathComponent("user-picked-folder", isDirectory: true)
        try FileManager.default.createDirectory(at: userFolder, withIntermediateDirectories: true)
        let userExport = userFolder.appendingPathComponent("smeta-project-1-100", isDirectory: true)
        try FileManager.default.createDirectory(at: userExport, withIntermediateDirectories: true)
        try Data("final".utf8).write(to: userExport.appendingPathComponent("manifest.json"))

        _ = coordinator.cleanupManagedArtifacts(dataFolder: root)

        XCTAssertTrue(FileManager.default.fileExists(atPath: userExport.path))
    }

    func testCleanupCanReportPartialFailure() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let realManager = FileManager.default
        let coordinator = ExportArtifactCoordinator(manager: FailingRemoveFileManager(failingSuffix: "fail", base: realManager))
        let okDir = root
            .appendingPathComponent("export-artifacts", isDirectory: true)
            .appendingPathComponent("project-bundle-staging", isDirectory: true)
            .appendingPathComponent("ok", isDirectory: true)
        let failDir = root
            .appendingPathComponent("export-artifacts", isDirectory: true)
            .appendingPathComponent("project-bundle-staging", isDirectory: true)
            .appendingPathComponent("will-fail", isDirectory: true)
        try realManager.createDirectory(at: okDir, withIntermediateDirectories: true)
        try realManager.createDirectory(at: failDir, withIntermediateDirectories: true)

        let report = coordinator.cleanupManagedArtifacts(dataFolder: root)

        XCTAssertEqual(report.scannedCount, 2)
        XCTAssertEqual(report.deletedCount, 1)
        XCTAssertEqual(report.failures.count, 1)
        XCTAssertTrue(report.isPartialFailure)
        XCTAssertTrue(realManager.fileExists(atPath: failDir.path))
    }

    func testCreationPathAndCleanupPathAreAligned() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let coordinator = ExportArtifactCoordinator()

        let staged = try coordinator.prepareProjectBundleStagingFolder(dataFolder: root, projectId: 42, timestamp: 777)
        XCTAssertTrue(staged.path.contains("/export-artifacts/project-bundle-staging/"))
        let report = coordinator.cleanupManagedArtifacts(dataFolder: root)

        XCTAssertEqual(report.deletedCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: staged.path))
    }

    private func makeTempRoot() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("export-artifacts-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}

private struct FailingRemoveFileManager: ExportArtifactFileManaging {
    let failingSuffix: String
    let base: FileManager

    func fileExists(atPath path: String) -> Bool {
        base.fileExists(atPath: path)
    }

    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions) throws -> [URL] {
        try base.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: mask)
    }

    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey: Any]?) throws {
        try base.createDirectory(at: url, withIntermediateDirectories: createIntermediates, attributes: attributes)
    }

    func removeItem(at URL: URL) throws {
        if URL.lastPathComponent.hasSuffix(failingSuffix) {
            throw NSError(domain: "ExportArtifactCoordinatorTests", code: 77, userInfo: [NSLocalizedDescriptionKey: "synthetic remove failure"])
        }
        try base.removeItem(at: URL)
    }
}
