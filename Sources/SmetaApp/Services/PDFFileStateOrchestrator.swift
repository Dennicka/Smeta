import Foundation

enum PDFFileStateError: LocalizedError {
    case incompleteRecovery(finalPath: String, backupPath: String?, issues: [String])
    case backupCleanupFailed(path: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .incompleteRecovery(let finalPath, let backupPath, let issues):
            let backupInfo = backupPath ?? "<none>"
            return "Не удалось полностью восстановить состояние PDF. final=\(finalPath), backup=\(backupInfo), проблемы: \(issues.joined(separator: " | "))"
        case .backupCleanupFailed(let path, let reason):
            return "PDF сохранён, но не удалось удалить backup файл \(path): \(reason)"
        }
    }
}

struct PDFFileStateOrchestrator {
    private let manager: FileManager

    init(manager: FileManager = .default) {
        self.manager = manager
    }

    func temporaryPDFURL(near finalURL: URL, prefix: String) -> URL {
        finalURL.deletingLastPathComponent()
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
            .appendingPathExtension("pdf")
    }

    func backupExistingFileIfNeeded(at destinationURL: URL) throws -> URL? {
        guard manager.fileExists(atPath: destinationURL.path) else { return nil }
        let backupURL = destinationURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(destinationURL.lastPathComponent).backup-\(UUID().uuidString)")
        try manager.moveItem(at: destinationURL, to: backupURL)
        return backupURL
    }

    func promotePreparedPDF(from sourceURL: URL, to destinationURL: URL) throws {
        try manager.moveItem(at: sourceURL, to: destinationURL)
    }

    func removeTemporaryFileIfPresent(at url: URL) throws {
        if manager.fileExists(atPath: url.path) {
            try manager.removeItem(at: url)
        }
    }

    func cleanupBackupAfterCommit(backupURL: URL?) throws {
        guard let backupURL else { return }
        do {
            if manager.fileExists(atPath: backupURL.path) {
                try manager.removeItem(at: backupURL)
            }
        } catch {
            throw PDFFileStateError.backupCleanupFailed(path: backupURL.path, reason: error.localizedDescription)
        }
    }

    func recoverAfterFailedCommit(finalURL: URL, backupURL: URL?, didPromote: Bool) throws {
        var issues: [String] = []

        if didPromote, manager.fileExists(atPath: finalURL.path) {
            do {
                try manager.removeItem(at: finalURL)
            } catch {
                issues.append("не удалось удалить новый final файл: \(error.localizedDescription)")
            }
        }

        if let backupURL {
            if manager.fileExists(atPath: backupURL.path) {
                do {
                    if manager.fileExists(atPath: finalURL.path) {
                        try manager.removeItem(at: finalURL)
                    }
                    try manager.moveItem(at: backupURL, to: finalURL)
                } catch {
                    issues.append("не удалось восстановить backup \(backupURL.path): \(error.localizedDescription)")
                }
            } else {
                issues.append("backup файл не найден: \(backupURL.path)")
            }
        }

        if !issues.isEmpty {
            throw PDFFileStateError.incompleteRecovery(finalPath: finalURL.path, backupPath: backupURL?.path, issues: issues)
        }
    }
}
