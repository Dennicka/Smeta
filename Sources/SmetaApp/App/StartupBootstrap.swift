import Foundation

enum StartupBootstrapStatus: Equatable {
    case success
    case failed(String)
}

struct StartupBootstrapResult {
    let status: StartupBootstrapStatus
    let viewModel: AppViewModel?
}

struct StartupBootstrapRunner {
    typealias DependencyFactory = () throws -> AppViewModel
    typealias BootstrapAction = (AppViewModel) throws -> Void
    typealias LaunchServicesAction = () throws -> Void

    let createViewModel: DependencyFactory
    let bootstrapViewModel: BootstrapAction
    let startLaunchServices: LaunchServicesAction

    init(createViewModel: @escaping DependencyFactory,
         bootstrapViewModel: @escaping BootstrapAction,
         startLaunchServices: @escaping LaunchServicesAction = {}) {
        self.createViewModel = createViewModel
        self.bootstrapViewModel = bootstrapViewModel
        self.startLaunchServices = startLaunchServices
    }

    func run() -> StartupBootstrapResult {
        do {
            let vm = try createViewModel()
            try bootstrapViewModel(vm)
            try startLaunchServices()
            return StartupBootstrapResult(status: .success, viewModel: vm)
        } catch {
            return StartupBootstrapResult(status: .failed(error.localizedDescription), viewModel: nil)
        }
    }
}
