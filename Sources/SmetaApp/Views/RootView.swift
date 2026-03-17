import SwiftUI

enum Screen: String, CaseIterable, Identifiable {
    case dashboard = "Дашборд"
    case clients = "Клиенты"
    case projects = "Проекты"
    case wizard = "Мастер сметы"
    case rooms = "Помещения"
    case works = "Работы"
    case materials = "Материалы"
    case calculation = "Расчёт"
    case documents = "Документы"
    case settings = "Настройки"
    var id: String { rawValue }
}

struct RootView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var selected: Screen? = .dashboard

    var body: some View {
        NavigationSplitView {
            List(Screen.allCases, selection: $selected) { screen in
                Text(screen.rawValue).font(.title3)
            }
        } detail: {
            VStack {
                TextField("Поиск", text: $vm.searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()

                switch selected ?? .dashboard {
                case .dashboard: DashboardView()
                case .clients: ClientsView()
                case .projects: ProjectsView()
                case .wizard: WizardView()
                case .rooms: RoomsView()
                case .works: WorksView()
                case .materials: MaterialsView()
                case .calculation: CalculationView()
                case .documents: DocumentsView()
                case .settings: SettingsView()
                }
            }
            .padding(.horizontal)
        }
    }
}
