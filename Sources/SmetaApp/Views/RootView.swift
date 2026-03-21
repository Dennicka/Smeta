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
    @State private var selected: Screen = .dashboard
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Screen.allCases) { screen in
                    sidebarRow(for: screen)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
        }
        .frame(minWidth: 260, idealWidth: 280, maxWidth: 320, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func sidebarRow(for screen: Screen) -> some View {
        let isSelected = selected == screen
        return Button {
            selected = screen
        } label: {
            HStack(spacing: 8) {
                Text(screen.rawValue)
                    .font(.title3)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.22) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(sidebarAccessibilityIdentifier(for: screen))
    }

    private var detail: some View {
        VStack(spacing: 0) {
            TextField("Поиск", text: $vm.searchText)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)
                .padding()

            if let info = vm.infoMessage {
                Text(info)
                    .font(.callout)
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            if let error = vm.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            if SmokeRuntimeConfig.isUISmokeEnabled {
                smokeRuntimeStatus
            }

            currentScreenView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal)
                .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var smokeRuntimeStatus: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("operational-root")
                .font(.caption2)
                .accessibilityIdentifier("smoke.operational.marker")
            Text("selected-project-id:\(vm.selectedProject?.id ?? -1)")
                .font(.caption2)
                .accessibilityIdentifier("smoke.selectedProject")
            Text("selected-project-name:\(vm.selectedProject?.name ?? "<none>")")
                .font(.caption2)
                .accessibilityIdentifier("smoke.selectedProjectName")
            Text("calculation-rows:\(vm.calculationResult?.rows.count ?? 0)")
                .font(.caption2)
                .accessibilityIdentifier("smoke.calculationRows")
            Text("calculation-invocations:\(vm.calculationInvocationCount)")
                .font(.caption2)
                .accessibilityIdentifier("smoke.calculationInvocationCount")
            Text("error-message:\(vm.errorMessage ?? "<none>")")
                .font(.caption2)
                .accessibilityIdentifier("smoke.errorMessage")
            Text("info-message:\(vm.infoMessage ?? "<none>")")
                .font(.caption2)
                .accessibilityIdentifier("smoke.infoMessage")
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal)
    }

    private func sidebarAccessibilityIdentifier(for screen: Screen) -> String {
        switch screen {
        case .projects:
            return "smoke.nav.projects"
        case .calculation:
            return "smoke.nav.calculation"
        default:
            return "smoke.nav.\(screen.id)"
        }
    }

    @ViewBuilder
    private var currentScreenView: some View {
        switch selected {
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
}
#endif
