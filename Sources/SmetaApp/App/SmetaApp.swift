import SwiftUI

@main
struct SmetaApp: App {
    @StateObject private var vm: AppViewModel

    init() {
        do {
            let db = try SQLiteDatabase()
            try db.initializeSchema()
            let repo = AppRepository(db: db)
            let backup = BackupService(db: db)
            _vm = StateObject(wrappedValue: AppViewModel(repository: repo, backupService: backup))
        } catch {
            fatalError("DB init failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(vm)
                .onAppear { vm.bootstrap() }
                .frame(minWidth: 1200, minHeight: 780)
        }
    }
}
