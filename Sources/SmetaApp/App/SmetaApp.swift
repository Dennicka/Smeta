#if canImport(SwiftUI)
import SwiftUI

@main
struct SmetaApp: App {
    @StateObject private var launcher: AppLauncher

    init() {
        _launcher = StateObject(wrappedValue: AppLauncher())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let vm = launcher.viewModel {
                    RootView()
                        .environmentObject(vm)
                } else {
                    StartupFailureView(message: launcher.launchErrorMessage ?? "Ошибка запуска приложения")
                }
            }
            .frame(minWidth: 1200, minHeight: 780)
        }
    }
}

@MainActor
private final class AppLauncher: ObservableObject {
    let viewModel: AppViewModel?
    let launchErrorMessage: String?

    init() {
        let environment = ProcessInfo.processInfo.environment
        let runner = StartupBootstrapRunner(createViewModel: {
            let db = try SQLiteDatabase()
            try db.initializeSchema()
            let repo = AppRepository(db: db)
            let backup = BackupService(db: db)
            return AppViewModel(repository: repo, backupService: backup)
        }, bootstrapViewModel: { vm in
            if environment["SMETA_FORCE_BOOTSTRAP_FAILURE"] == "1" {
                throw NSError(
                    domain: "Smeta.RuntimeProbe",
                    code: 9001,
                    userInfo: [NSLocalizedDescriptionKey: "forced bootstrap failure for runtime verification"]
                )
            }
            try vm.performBootstrap()
            try vm.ensureUISmokeBootstrapDataIfNeeded()
            vm.bootstrapStatus = .success
        })

        let result = runner.run()
        viewModel = result.viewModel
        switch result.status {
        case .success:
            launchErrorMessage = nil
        case .failed(let message):
            launchErrorMessage = "Ошибка запуска: \(message)"
        }

        RuntimeSmokeProbe.maybeRun(
            status: result.status,
            viewModel: result.viewModel
        )
    }
}

private struct StartupFailureView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Не удалось запустить приложение")
                .font(.title2)
                .bold()
                .accessibilityIdentifier("smoke.startup.failure.title")
            Text(message)
                .foregroundColor(.red)
                .font(.body)
            Text("Исправьте проблему с базой/доступом к файлам и перезапустите приложение.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
#endif
