import Foundation

enum SimError: Error {
    case generationFail
    case tempPreparedFail
    case beginFail
    case txFail
    case commitFail
    case refreshFail
    case backupCleanupFail
}

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
    let warnings: [String]
}

func simulate(
    orchestrator: PDFFileStateOrchestrator,
    root: URL,
    existingFinal: Bool,
    failGeneration: Bool = false,
    failAfterTempPrepared: Bool = false,
    failBegin: Bool = false,
    failTx: Bool = false,
    failCommit: Bool = false,
    failRefresh: Bool = false,
    failBackupCleanup: Bool = false
) throws -> RunResult {
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
        if failAfterTempPrepared { throw SimError.tempPreparedFail }

        try db.begin()

        if failTx { throw SimError.txFail }
        backupURL = try orchestrator.backupExistingFileIfNeeded(at: finalURL)
        try orchestrator.promotePreparedPDF(from: tempURL, to: finalURL)
        didMove = true
        try db.commit()

        try orchestrator.removeTemporaryFileIfPresent(at: tempURL)

        var warnings: [String] = []
        if let backupURL {
            do {
                if failBackupCleanup { throw SimError.backupCleanupFail }
                try orchestrator.cleanupBackupAfterCommit(backupURL: backupURL)
            } catch {
                warnings.append("backup cleanup failed")
            }
        }

        if failRefresh {
            warnings.append("refresh failed")
        }

        return RunResult(committed: true, warnings: warnings)
    } catch {
        if db.began && !db.committed { try? db.rollback() }
        if db.began {
            try? orchestrator.recoverAfterFailedCommit(finalURL: finalURL, backupURL: backupURL, didPromote: didMove)
        }
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

        // 1) Temp artifact created, then pre-BEGIN fail -> temp must be cleaned
        do {
            _ = try simulate(orchestrator: orchestrator, root: root, existingFinal: false, failAfterTempPrepared: true)
            throw SimError.tempPreparedFail
        } catch SimError.tempPreparedFail {
            let leftovers = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
            if leftovers.allSatisfy({ !$0.lastPathComponent.contains("g3-") }) {
                passes.append("C1 PASS")
            }
        } catch {}

        // 2) BEGIN fails after temp generation -> no temp leak
        do {
            _ = try simulate(orchestrator: orchestrator, root: root, existingFinal: false, failBegin: true)
            throw SimError.beginFail
        } catch {
            let leftovers = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
            if leftovers.allSatisfy({ !$0.lastPathComponent.contains("g3-") }) {
                passes.append("C2 PASS")
            }
        }

        // 3) commit succeeds but refresh fails -> operation success with warning
        let r3 = try simulate(orchestrator: orchestrator, root: root, existingFinal: true, failRefresh: true)
        if r3.committed && r3.warnings.contains("refresh failed") {
            passes.append("C3 PASS")
        }

        // 4) commit succeeds but backup cleanup warns -> operation success with warning
        let r4 = try simulate(orchestrator: orchestrator, root: root, existingFinal: true, failBackupCleanup: true)
        if r4.committed && r4.warnings.contains("backup cleanup failed") {
            passes.append("C4 PASS")
        }

        print("D007G3_RESULTS")
        passes.forEach { print($0) }
        print("TOTAL=\(passes.count)")
    }
}
