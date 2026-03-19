import Foundation

enum SmokeRuntimeConfig {
    static var isUISmokeEnabled: Bool {
        ProcessInfo.processInfo.environment["SMETA_UI_SMOKE"] == "1"
    }

    static var shouldDisableCalculationAction: Bool {
        ProcessInfo.processInfo.environment["SMETA_SMOKE_DISABLE_CALCULATE"] == "1"
    }
}
