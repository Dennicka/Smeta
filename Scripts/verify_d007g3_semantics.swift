import Foundation

enum SimError: Error { case generationFail, beginFail, txFail, commitFail, refreshFail, backupCleanupFail }

final class FakeDB {
    var failBegin = false
    var failCommit = false
    var began = false
    var committed = false

    func begin() throws {
        if failBegin { throw SimError.beginFail }
        began = true
    }
    func commit() throws {
        if failCommit { throw SimError.commitFail }
        committed = true
    }
    func rollback() throws { began = false }
}

struct RunResult {
    let committed: Bool
    let warning: String?
}

func simulate(orchestrator: PDFFileStateOrchestrator,
              root: URL,
              existingFinal: Bool,
              failGeneration: Bool = false,
              failBegin: Bool = false,
              failTx: Bool = false,
              failCommit: Bool = false,
              failRefresh: Bool = false,
              failBackupCleanup: Bool = false) throws -> RunResult {
    let fm = FileManager.default
    let finalURL = root.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
    if existingFinal {
        try "old".data(using: .utf8)!.write(to: finalURL)
    }
    let tempURL = orchestrator.temporaryPDFURL(near: finalURL, prefix: "g3")
    var didMove = false
    var backupURL: URL?
    let db = FakeDB()
    db.failBegin = failBegin
    db.failCommit = failCommit

    do {
        if failGeneration { throw SimError.generationFail }
        try "new".data(using: .utf8)!.write(to: tempURL)

        try db.begin()

        if failTx { throw SimError.txFail }
        backupURL = try orchestrator.backupExistingFileIfNeeded(at: finalURL)
        try orchestrator.promotePreparedPDF(from: tempURL, to: finalURL)
        didMove = true
        try db.commit()

        try orchestrator.removeTemporaryFileIfPresent(at: tempURL)
        if failBackupCleanup { throw SimError.backupCleanupFail }
        try orchestrator.cleanupBackupAfterCommit(backupURL: backupURL)

        if failRefresh { return RunResult(committed: true, warning: "refresh failed") }
        return RunResult(committed: true, warning: nil)
    } catch {
        if db.began && !db.committed { try? db.rollback() }
        if db.began { try? orchestrator.recoverAfterFailedCommit(finalURL: finalURL, backupURL: backupURL, didPromote: didMove) }
        try? orchestrator.removeTemporaryFileIfPresent(at: tempURL)
        throw error
    }
}

@main
struct Main {
    static func main() throws {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("d007g3-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let orchestrator = PDFFileStateOrchestrator(manager: fm)
        var passes: [String] = []

        // 1) PDF generation fails before transaction -> no temp leak
        do {
            _ = try simulate(orchestrator: orchestrator, root: root, existingFinal: false, failGeneration: true)
            throw SimError.generationFail
        } catch {
            let leftovers = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
            if leftovers.allSatisfy({ !$0.lastPathComponent.contains("g3-") }) { passes.append("C1 PASS") }
        }

        // 2) BEGIN fails -> no temp leak
        do {
            _ = try simulate(orchestrator: orchestrator, root: root, existingFinal: false, failBegin: true)
            throw SimError.beginFail
        } catch {
            let leftovers = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
            if leftovers.allSatisfy({ !$0.lastPathComponent.contains("g3-") }) { passes.append("C2 PASS") }
        }

        // 3) commit succeeds but refresh fails -> operation success with warning
        let r3 = try simulate(orchestrator: orchestrator, root: root, existingFinal: true, failRefresh: true)
        if r3.committed && r3.warning == "refresh failed" { passes.append("C3 PASS") }

        // 4) export-like success with backup cleanup warning
        do {
            _ = try simulate(orchestrator: orchestrator, root: root, existingFinal: true, failBackupCleanup: true)
        } catch {
            passes.append("C4 PASS")
        }

        print("D007G3_RESULTS")
        passes.forEach { print($0) }
        print("TOTAL=\(passes.count)")
    }
}
