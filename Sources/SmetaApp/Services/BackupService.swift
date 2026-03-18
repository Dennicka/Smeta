import Foundation
import AppKit

final class BackupService {
    private let db: SQLiteDatabase

    init(db: SQLiteDatabase) { self.db = db }

    func backupViaDialog() throws {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = backupFileName()
        panel.allowedFileTypes = ["sqlite", "db"]
        if panel.runModal() == .OK, let url = panel.url {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try db.copyDatabase(to: url)
        }
    }

    func restoreViaDialog() throws {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["sqlite", "db"]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            guard confirmRestore(for: url) else { return }
            try db.restoreDatabase(from: url)
        }
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
