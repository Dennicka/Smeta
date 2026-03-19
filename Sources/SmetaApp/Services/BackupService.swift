#if canImport(AppKit)
import Foundation
import AppKit

enum BackupServiceError: LocalizedError {
    case backupCancelled
    case restoreCancelled
    case restoreConfirmationDeclined

    var errorDescription: String? {
        switch self {
        case .backupCancelled:
            return "Пользователь отменил создание backup."
        case .restoreCancelled:
            return "Пользователь отменил выбор файла для restore."
        case .restoreConfirmationDeclined:
            return "Restore отменён на шаге подтверждения."
        }
    }
}

final class BackupService {
    private let db: SQLiteDatabase

    init(db: SQLiteDatabase) { self.db = db }

    func backupViaDialog() throws {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = backupFileName()
        panel.allowedFileTypes = ["sqlite", "db"]
        guard panel.runModal() == .OK, let url = panel.url else {
            throw BackupServiceError.backupCancelled
        }
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try db.copyDatabase(to: url)
    }

    func restoreViaDialog() throws {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["sqlite", "db"]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else {
            throw BackupServiceError.restoreCancelled
        }
        guard confirmRestore(for: url) else {
            throw BackupServiceError.restoreConfirmationDeclined
        }
        try db.restoreDatabase(from: url)
    }

    func dataLocation() -> URL {
        db.dataFolder()
    }

    private func backupFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "smeta-backup-\(formatter.string(from: Date())).sqlite"
    }

    private func confirmRestore(for url: URL) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Restore database?"
        alert.informativeText = "Текущая рабочая база будет заменена файлом \(url.lastPathComponent). Рекомендуется сделать backup перед восстановлением."
        alert.addButton(withTitle: "Restore")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
#else
import Foundation

enum BackupServiceError: LocalizedError {
    case unsupportedPlatform

    var errorDescription: String? {
        "Backup/restore dialogs are supported only on AppKit platforms."
    }
}

final class BackupService {
    init(db: SQLiteDatabase) {}

    func backupViaDialog() throws { throw BackupServiceError.unsupportedPlatform }
    func restoreViaDialog() throws { throw BackupServiceError.unsupportedPlatform }
}
#endif
