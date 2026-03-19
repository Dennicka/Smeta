import Foundation
#if canImport(AppKit)
import AppKit
#endif

private enum RuntimeSmokeMode: String {
    case operational
    case controlledFailure = "controlled_failure"
}

enum RuntimeSmokeProbe {
    static func maybeRun(status: StartupBootstrapStatus, viewModel: AppViewModel?) {
        let environment = ProcessInfo.processInfo.environment
        guard environment["SMETA_RUNTIME_SMOKE"] == "1" else { return }

        let mode = RuntimeSmokeMode(rawValue: environment["SMETA_RUNTIME_SMOKE_MODE"] ?? "") ?? .operational
        switch mode {
        case .controlledFailure:
            runControlledFailureProbe(status: status, viewModel: viewModel)
        case .operational:
            runOperationalProbe(status: status, viewModel: viewModel)
        }
    }

    private static func runControlledFailureProbe(status: StartupBootstrapStatus, viewModel: AppViewModel?) {
        switch status {
        case .success:
            emitAndExit(
                pass: false,
                classification: "launch_success_not_allowed",
                details: ["Controlled-failure probe expected launch failure, got success"],
                exitCode: 41
            )
        case .failed(let message):
            let hasFailureScreen = viewModel == nil
            emitAndExit(
                pass: hasFailureScreen,
                classification: hasFailureScreen ? "controlled_launch_failure" : "inconsistent_failure_state",
                details: [
                    "Bootstrap failed as expected: \(message)",
                    "Failure screen path active: \(hasFailureScreen)"
                ],
                exitCode: hasFailureScreen ? 0 : 42
            )
        }
    }

    private static func runOperationalProbe(status: StartupBootstrapStatus, viewModel: AppViewModel?) {
        guard case .success = status, let viewModel else {
            emitAndExit(
                pass: false,
                classification: "launch_failed",
                details: ["Operational probe requires successful bootstrap"],
                exitCode: 31
            )
        }

        #if canImport(AppKit)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            Task { @MainActor in
                let negativeInjection = ProcessInfo.processInfo.environment["SMETA_RUNTIME_KILL_INTERACTION_CHAIN"] == "1"
                let result = evaluateOperationalState(viewModel: viewModel, negativeInjection: negativeInjection)
                emitAndExit(
                    pass: result.failures.isEmpty,
                    classification: result.failures.isEmpty ? "operational_runtime_success" : "operational_runtime_failure",
                    details: result.failures.isEmpty ? result.successNotes : result.failures,
                    exitCode: result.failures.isEmpty ? 0 : 32
                )
            }
        }
        #else
        emitAndExit(
            pass: false,
            classification: "unsupported_platform",
            details: ["Operational runtime probe requires AppKit"],
            exitCode: 33
        )
        #endif
    }

    #if canImport(AppKit)
    private struct ProbeResult {
        var successNotes: [String] = []
        var failures: [String] = []
    }

    @MainActor
    private static func evaluateOperationalState(viewModel: AppViewModel, negativeInjection: Bool) -> ProbeResult {
        var result = ProbeResult()

        guard let window = waitForWindow(timeout: 8.0) else {
            result.failures.append("Main window was not discovered within timeout")
            return result
        }
        result.successNotes.append("Window exists")

        NSApp.activate(ignoringOtherApps: true)
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))

        if !NSApp.isActive {
            result.failures.append("App is not active")
        } else {
            result.successNotes.append("App became active")
        }

        if !window.isVisible {
            result.failures.append("Window is not visible")
        }
        if window.ignoresMouseEvents {
            result.failures.append("Window ignores mouse events")
        }
        if window.isMiniaturized {
            result.failures.append("Window is miniaturized")
        }
        if window.alphaValue <= 0.01 {
            result.failures.append("Window alpha indicates hidden/blocked state")
        }
        if window.contentView == nil {
            result.failures.append("Window has no content view")
        }

        window.makeKeyAndOrderFront(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        if !(window.isKeyWindow || window.isMainWindow) {
            result.failures.append("Window is neither key nor main after activation")
        } else {
            result.successNotes.append("Window is key/main")
        }

        if viewModel.bootstrapStatus != .success {
            result.failures.append("ViewModel bootstrap status is not success")
        } else {
            result.successNotes.append("ViewModel bootstrap status is success")
        }

        let initialProject = viewModel.selectedProject ?? viewModel.projects.first
        guard let initialProject else {
            result.failures.append("No project available for interaction probe")
            return result
        }

        do {
            if viewModel.selectedProject?.id != initialProject.id {
                try viewModel.selectProject(initialProject)
            }

            let alternateProject = try ensureAlternateProject(viewModel: viewModel, excluding: initialProject.id)
            try viewModel.selectProject(alternateProject)
            if viewModel.selectedProject?.id != alternateProject.id {
                result.failures.append("Project selection click chain is dead (no selectedProject update)")
            } else {
                result.successNotes.append("Project selection updates selected state")
            }

            try viewModel.selectProject(initialProject)
            if viewModel.selectedProject?.id != initialProject.id {
                result.failures.append("Unable to return to original project after selection switch")
            }

            guard let room = viewModel.rooms.first(where: { $0.projectId == initialProject.id }) else {
                result.failures.append("Selected project has no room for calculation chain")
                return result
            }
            guard let work = viewModel.works.first, let material = viewModel.materials.first else {
                result.failures.append("Catalog data is missing for calculation chain")
                return result
            }

            if negativeInjection {
                viewModel.selectedWorksByRoom[room.id] = []
                viewModel.selectedMaterialsByRoom[room.id] = []
            } else {
                viewModel.selectedWorksByRoom[room.id] = [work]
                viewModel.selectedMaterialsByRoom[room.id] = [material]
            }

            let previousTotal = viewModel.calculationResult?.grandTotal
            viewModel.calculate()

            guard let calculation = viewModel.calculationResult else {
                result.failures.append("Calculation did not produce result object")
                return result
            }

            if calculation.rows.isEmpty || calculation.grandTotal <= 0 {
                result.failures.append("Calculation chain produced empty/no-op result")
            } else {
                result.successNotes.append("Calculation chain produced non-empty result")
            }

            if let previousTotal, abs(previousTotal - calculation.grandTotal) < 0.0001 {
                result.failures.append("Calculation output did not change (possible dead action chain)")
            }
        } catch {
            result.failures.append("Interaction probe failed with error: \(error.localizedDescription)")
        }

        if viewModel.errorMessage != nil {
            result.failures.append("ViewModel contains runtime error message: \(viewModel.errorMessage ?? "")")
        }

        return result
    }

    @MainActor
    private static func ensureAlternateProject(viewModel: AppViewModel, excluding projectId: Int64) throws -> Project {
        if let existing = viewModel.projects.first(where: { $0.id != projectId }) {
            return existing
        }
        guard let clientId = viewModel.clients.first?.id else {
            throw NSError(domain: "Smeta.RuntimeProbe", code: 9201, userInfo: [NSLocalizedDescriptionKey: "No client to create probe project"])
        }
        guard let propertyId = viewModel.properties.first(where: { $0.clientId == clientId })?.id ?? viewModel.properties.first?.id else {
            throw NSError(domain: "Smeta.RuntimeProbe", code: 9202, userInfo: [NSLocalizedDescriptionKey: "No property to create probe project"])
        }

        viewModel.addProject(
            clientId: clientId,
            propertyId: propertyId,
            name: "runtime-probe-\(Int(Date().timeIntervalSince1970))"
        )
        if let error = viewModel.errorMessage {
            throw NSError(domain: "Smeta.RuntimeProbe", code: 9203, userInfo: [NSLocalizedDescriptionKey: error])
        }
        guard let created = viewModel.projects.first(where: { $0.id != projectId }) else {
            throw NSError(domain: "Smeta.RuntimeProbe", code: 9204, userInfo: [NSLocalizedDescriptionKey: "Probe project was not created"])
        }
        return created
    }

    private static func waitForWindow(timeout: TimeInterval) -> NSWindow? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let window = NSApp.windows.first(where: { $0.isVisible }) {
                return window
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return NSApp.windows.first
    }
    #endif

    private static func emitAndExit(pass: Bool, classification: String, details: [String], exitCode: Int32) {
        let joinedDetails = details.joined(separator: " | ")
        print("SMETA_RUNTIME_SMOKE verdict=\(pass ? "PASS" : "FAIL") classification=\(classification) details=\(joinedDetails)")
        fflush(stdout)
        exit(exitCode)
    }
}
