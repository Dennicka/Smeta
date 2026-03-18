import Foundation

func write(_ text: String, to url: URL) throws {
    try text.data(using: .utf8)!.write(to: url)
}

func read(_ url: URL) throws -> String {
    String(data: try Data(contentsOf: url), encoding: .utf8) ?? ""
}

@discardableResult
func check(_ condition: @autoclosure () -> Bool, _ message: String) throws -> Bool {
    guard condition() else { throw NSError(domain: "D007g2", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    return true
}

@main
struct Main {
    static func main() throws {
        let fm = FileManager.default
        let orchestrator = PDFFileStateOrchestrator(manager: fm)
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("d007g2-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        func makeURL(_ name: String) -> URL { root.appendingPathComponent(name) }

        var results: [String] = []

        // S1: no existing file, fail before move
        try {
            let finalURL = makeURL("s1-final.pdf")
            let tempURL = makeURL("s1-temp.pdf")
            try write("new", to: tempURL)
            try orchestrator.recoverAfterFailedCommit(finalURL: finalURL, backupURL: nil, didPromote: false)
            try orchestrator.removeTemporaryFileIfPresent(at: tempURL)
            try check(!fm.fileExists(atPath: finalURL.path), "S1 final should not exist")
            results.append("S1 PASS")
        }()

        // S2: no existing file, fail after move/before commit
        try {
            let finalURL = makeURL("s2-final.pdf")
            let tempURL = makeURL("s2-temp.pdf")
            try write("new", to: tempURL)
            try orchestrator.promotePreparedPDF(from: tempURL, to: finalURL)
            try orchestrator.recoverAfterFailedCommit(finalURL: finalURL, backupURL: nil, didPromote: true)
            try check(!fm.fileExists(atPath: finalURL.path), "S2 final should be removed")
            results.append("S2 PASS")
        }()

        // S3: existing file, fail before move (after backup)
        try {
            let finalURL = makeURL("s3-final.pdf")
            try write("old", to: finalURL)
            let backupURL = try orchestrator.backupExistingFileIfNeeded(at: finalURL)
            try check(backupURL != nil, "S3 backup should exist")
            try orchestrator.recoverAfterFailedCommit(finalURL: finalURL, backupURL: backupURL, didPromote: false)
            try check(fm.fileExists(atPath: finalURL.path), "S3 final should be restored")
            let s3Content = try read(finalURL)
            try check(s3Content == "old", "S3 final content should be old")
            results.append("S3 PASS")
        }()

        // S4: existing file, fail after move/before commit
        try {
            let finalURL = makeURL("s4-final.pdf")
            let tempURL = makeURL("s4-temp.pdf")
            try write("old", to: finalURL)
            let backupURL = try orchestrator.backupExistingFileIfNeeded(at: finalURL)
            try write("new", to: tempURL)
            try orchestrator.promotePreparedPDF(from: tempURL, to: finalURL)
            try orchestrator.recoverAfterFailedCommit(finalURL: finalURL, backupURL: backupURL, didPromote: true)
            let s4Content = try read(finalURL)
            try check(s4Content == "old", "S4 final should be restored old")
            results.append("S4 PASS")
        }()

        // S5: success path + backup cleanup
        try {
            let finalURL = makeURL("s5-final.pdf")
            let tempURL = makeURL("s5-temp.pdf")
            try write("old", to: finalURL)
            let backupURL = try orchestrator.backupExistingFileIfNeeded(at: finalURL)
            try write("new", to: tempURL)
            try orchestrator.promotePreparedPDF(from: tempURL, to: finalURL)
            try orchestrator.cleanupBackupAfterCommit(backupURL: backupURL)
            let s5Content = try read(finalURL)
            try check(s5Content == "new", "S5 final should be new")
            if let backupURL {
                try check(!fm.fileExists(atPath: backupURL.path), "S5 backup should be cleaned")
            }
            results.append("S5 PASS")
        }()

        // S6: explicit recovery failure path
        try {
            let brokenParent = root.appendingPathComponent("missing-parent")
            let finalURL = brokenParent.appendingPathComponent("s6-final.pdf")
            let backupURL = makeURL("s6-backup.pdf")
            try write("old", to: backupURL)
            do {
                try orchestrator.recoverAfterFailedCommit(finalURL: finalURL, backupURL: backupURL, didPromote: false)
                throw NSError(domain: "D007g2", code: 2, userInfo: [NSLocalizedDescriptionKey: "S6 expected recovery failure"])
            } catch {
                results.append("S6 PASS (expected failure: \(error.localizedDescription))")
            }
        }()

        print("D007G2_FILE_RECOVERY_RESULTS")
        results.forEach { print($0) }
        print("TOTAL=\(results.count)")
    }
}
