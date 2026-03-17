import Foundation
import AppKit

final class BackupService {
    private let db: SQLiteDatabase

    init(db: SQLiteDatabase) { self.db = db }

    func backupViaDialog() throws {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "smeta-backup.sqlite"
        panel.allowedFileTypes = ["sqlite","db"]
        if panel.runModal() == .OK, let url = panel.url {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try db.copyDatabase(to: url)
        }
    }

    func restoreViaDialog() throws {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["sqlite","db"]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            try db.restoreDatabase(from: url)
        }
    }
}
