#if canImport(SwiftUI)
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
    case documents = "Documents"
    case offerEditor = "Offer editor"
    case contractEditor = "Contract editor"
    case invoiceEditor = "Invoice editor"
    case payments = "Payments"
    case extraWork = "Extra work / ÄTA"
    case reminders = "Reminders"
    case templates = "Document templates"
    case numbering = "Document numbering"
    case tax = "Tax settings"
    case stage5 = "Stage 5 Operations"
    case settings = "Настройки"
    var id: String { rawValue }
}

struct RootView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var selected: Screen? = .dashboard

    var body: some View {
        HStack(spacing: 0) {
            List(Screen.allCases, selection: $selected) { screen in
                Text(screen.rawValue).font(.title3)
            }
            .frame(minWidth: 260, maxWidth: 320)

            Divider()

            VStack {
                TextField("Поиск", text: $vm.searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()

                if let info = vm.infoMessage {
                    Text(info)
                        .font(.callout)
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }

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
                case .offerEditor: OfferEditorView()
                case .contractEditor: ContractEditorView()
                case .invoiceEditor: InvoiceEditorView()
                case .payments: PaymentsView()
                case .extraWork: ExtraWorkView()
                case .reminders: RemindersView()
                case .templates: DocumentTemplatesView()
                case .numbering: DocumentNumberingView()
                case .tax: TaxSettingsView()
                case .stage5: Stage5OperationsView()
                case .settings: SettingsView()
                }
            }
            .padding(.horizontal)
        }
    }
}
#endif
