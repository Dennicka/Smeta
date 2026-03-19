import Foundation

protocol ExportArtifactFileManaging {
    func fileExists(atPath path: String) -> Bool
    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey: Any]?) throws
    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions) throws -> [URL]
    func removeItem(at URL: URL) throws
}

extension FileManager: ExportArtifactFileManaging {}

public struct ExportCleanupFailure: Equatable {
    public let path: String
    public let reason: String

    public init(path: String, reason: String) {
        self.path = path
        self.reason = reason
    }
}

public struct ExportCleanupReport: Equatable {
    public let scannedCount: Int
    public let deletedCount: Int
    public let failures: [ExportCleanupFailure]

    public init(scannedCount: Int, deletedCount: Int, failures: [ExportCleanupFailure]) {
        self.scannedCount = scannedCount
        self.deletedCount = deletedCount
        self.failures = failures
    }

    public var isNoOp: Bool {
        scannedCount == 0 && deletedCount == 0 && failures.isEmpty
    }

    public var isPartialFailure: Bool {
        !failures.isEmpty && deletedCount > 0
    }
}

public final class ExportArtifactCoordinator {
    private let manager: ExportArtifactFileManaging

    public init() {
        self.manager = FileManager.default
    }

    init(manager: ExportArtifactFileManaging) {
        self.manager = manager
    }

    /// App-owned root for export staging/temp artifacts.
    func managedRoot(dataFolder: URL) -> URL {
        dataFolder
            .appendingPathComponent("export-artifacts", isDirectory: true)
    }

    /// App-owned temporary location for in-progress project bundle exports.
    func projectBundleStagingRoot(dataFolder: URL) -> URL {
        managedRoot(dataFolder: dataFolder)
            .appendingPathComponent("project-bundle-staging", isDirectory: true)
    }

    public func prepareProjectBundleStagingFolder(dataFolder: URL, projectId: Int64, timestamp: Int) throws -> URL {
        let root = projectBundleStagingRoot(dataFolder: dataFolder)
        try manager.createDirectory(at: root, withIntermediateDirectories: true, attributes: nil)
        let folderName = "smeta-project-\(projectId)-\(timestamp)-staging-\(UUID().uuidString)"
        let stagingFolder = root.appendingPathComponent(folderName, isDirectory: true)
        try manager.createDirectory(at: stagingFolder, withIntermediateDirectories: false, attributes: nil)
        return stagingFolder
    }

    public func cleanupManagedArtifacts(dataFolder: URL) -> ExportCleanupReport {
        let stagingRoot = projectBundleStagingRoot(dataFolder: dataFolder)
        guard manager.fileExists(atPath: stagingRoot.path) else {
            return ExportCleanupReport(scannedCount: 0, deletedCount: 0, failures: [])
        }

        let stagedItems: [URL]
        do {
            stagedItems = try manager.contentsOfDirectory(at: stagingRoot, includingPropertiesForKeys: nil, options: [])
        } catch {
            return ExportCleanupReport(
                scannedCount: 1,
                deletedCount: 0,
                failures: [ExportCleanupFailure(path: stagingRoot.path, reason: error.localizedDescription)]
            )
        }

        var deletedCount = 0
        var failures: [ExportCleanupFailure] = []
        for item in stagedItems {
            do {
                try manager.removeItem(at: item)
                deletedCount += 1
            } catch {
                failures.append(ExportCleanupFailure(path: item.path, reason: error.localizedDescription))
            }
        }

        do {
            let leftovers = try manager.contentsOfDirectory(at: stagingRoot, includingPropertiesForKeys: nil, options: [])
            if leftovers.isEmpty {
                try manager.removeItem(at: stagingRoot)
                let managedRoot = managedRoot(dataFolder: dataFolder)
                if manager.fileExists(atPath: managedRoot.path) {
                    let managedLeftovers = try manager.contentsOfDirectory(at: managedRoot, includingPropertiesForKeys: nil, options: [])
                    if managedLeftovers.isEmpty {
                        try manager.removeItem(at: managedRoot)
                    }
                }
            }
        } catch {
            failures.append(ExportCleanupFailure(path: stagingRoot.path, reason: error.localizedDescription))
        }

        return ExportCleanupReport(scannedCount: stagedItems.count, deletedCount: deletedCount, failures: failures)
    }
}
