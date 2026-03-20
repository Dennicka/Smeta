import XCTest
import Foundation
@testable import SmetaApp

final class RuntimeUISmokeHarnessTests: XCTestCase {
    func testRuntimeUISmokeHarness() throws {
        guard ProcessInfo.processInfo.environment["SMETA_ENABLE_RUNTIME_UI_SMOKE"] == "1" else {
            throw XCTSkip("Runtime UI smoke is opt-in. Set SMETA_ENABLE_RUNTIME_UI_SMOKE=1 on macOS host with AX permission.")
        }

        let repoRoot = try Self.locateRepositoryRoot()
        let scriptURL = repoRoot.appendingPathComponent("Scripts/macos_smoke_check.sh")
        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path), "Missing runtime smoke script")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path]
        process.currentDirectoryURL = repoRoot

        var environment = ProcessInfo.processInfo.environment
        environment["SMETA_ENABLE_RUNTIME_UI_SMOKE"] = "1"
        process.environment = environment

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: outputData, as: UTF8.self)

        XCTAssertEqual(
            process.terminationStatus,
            0,
            "Runtime UI smoke failed with status \(process.terminationStatus). Output:\n\(output)"
        )
    }

    private static func locateRepositoryRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.path != "/" {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        throw NSError(
            domain: "RuntimeUISmokeHarnessTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Cannot locate repository root from #filePath"]
        )
    }
}
