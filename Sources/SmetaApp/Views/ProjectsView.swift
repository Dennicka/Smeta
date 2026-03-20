#if canImport(SwiftUI)
import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var selectedClientId: Int64 = 0
    @State private var selectedPropertyId: Int64 = 0
    @State private var selectedSpeedProfileId: Int64 = 0
    @State private var selectedPricingMode: PricingMode = .fixed
    @State private var isDraft = true
    @State private var createName = ""
    @State private var createErrorMessage: String?
    @State private var editingProject: Project?

    var body: some View {
        VStack(alignment: .leading) {
            Text("Проекты").font(.largeTitle).bold()
            HStack {
                Picker("Клиент", selection: $selectedClientId) {
                    ForEach(vm.clients) { Text($0.name).tag($0.id) }
                }
                Picker("Объект", selection: $selectedPropertyId) {
                    ForEach(vm.properties.filter { selectedClientId == 0 ? true : $0.clientId == selectedClientId }) { Text($0.name).tag($0.id) }
                }
                Picker("Скорость", selection: $selectedSpeedProfileId) {
                    ForEach(vm.speedProfiles) { Text($0.name).tag($0.id) }
                }
                Picker("Pricing", selection: $selectedPricingMode) {
                    ForEach(PricingMode.allCases) { Text($0.rawValue).tag($0) }
                }
                Toggle("Draft", isOn: $isDraft)
                TextField("Название проекта", text: $createName)
                Button("Создать") {
                    guard vm.addProject(clientId: selectedClientId, propertyId: selectedPropertyId, speedProfileId: selectedSpeedProfileId, pricingMode: selectedPricingMode.rawValue, isDraft: isDraft, name: createName) else {
                        createErrorMessage = vm.errorMessage ?? "Не удалось создать проект"
                        return
                    }
                    createName = ""
                    createErrorMessage = nil
                }
            }
            if let createErrorMessage {
                Text(createErrorMessage).foregroundStyle(.red).font(.caption)
            }
            Table(vm.projects) {
                TableColumn("Проект") { p in
                    HStack {
                        Text(p.name)
                        if vm.selectedProject?.id == p.id {
                            Text("● selected").foregroundStyle(.green)
                        }
                    }
                }
                TableColumn("Дата") { p in Text(p.createdAt.formatted()) }
                TableColumn("Действия") { p in
                    HStack {
                        Button("Выбрать") {
                            do {
                                try vm.selectProject(p)
                            } catch {
                                vm.errorMessage = "Не удалось выбрать проект: \(error.localizedDescription)"
                            }
                        }
                            .accessibilityIdentifier("smoke.project.select.\(p.id)")
                        Button("Редактировать") { editingProject = p }
                        Button("Архив") { vm.archiveProject(p.id) }
                        Button("Разархив") { vm.restoreProjectFromArchive(p.id) }
                        Button("Удалить", role: .destructive) { vm.deleteProject(p) }
                    }
                }
            }
        }
        .onAppear {
            selectedClientId = vm.clients.first?.id ?? 0
            selectedPropertyId = vm.properties.first(where: { $0.clientId == selectedClientId })?.id ?? 0
            selectedSpeedProfileId = vm.speedProfiles.first?.id ?? 0
        }
        .onChange(of: selectedClientId) { clientId in
            if !vm.properties.contains(where: { $0.id == selectedPropertyId && $0.clientId == clientId }) {
                selectedPropertyId = vm.properties.first(where: { $0.clientId == clientId })?.id ?? 0
            }
        }
        .sheet(item: $editingProject) { project in
            ProjectEditSheet(project: project, clients: vm.clients, properties: vm.properties, speedProfiles: vm.speedProfiles) { updated in
                vm.updateProject(updated) ? nil : (vm.errorMessage ?? "Не удалось обновить проект")
            }
        }
    }
}

private struct ProjectEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Project
    @State private var validationMessage: String?
    let clients: [Client]
    let properties: [PropertyObject]
    let speedProfiles: [SpeedProfile]
    let onSave: (Project) -> String?

    init(project: Project, clients: [Client], properties: [PropertyObject], speedProfiles: [SpeedProfile], onSave: @escaping (Project) -> String?) {
        _draft = State(initialValue: project)
        self.clients = clients
        self.properties = properties
        self.speedProfiles = speedProfiles
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("Редактирование проекта").font(.headline)
            Picker("Клиент", selection: $draft.clientId) {
                ForEach(clients) { Text($0.name).tag($0.id) }
            }
            Picker("Объект", selection: $draft.propertyId) {
                ForEach(properties.filter { $0.clientId == draft.clientId }) { Text($0.name).tag($0.id) }
            }
            Picker("Скорость", selection: $draft.speedProfileId) {
                ForEach(speedProfiles) { Text($0.name).tag($0.id) }
            }
            Picker("Pricing mode", selection: $draft.pricingMode) {
                ForEach(PricingMode.allCases) { Text($0.rawValue).tag($0.rawValue) }
            }
            TextField("Название", text: $draft.name)
            Toggle("Draft", isOn: $draft.isDraft)
            HStack {
                Button("Отмена") { dismiss() }
                Button("Сохранить") {
                    guard validatePropertySelection() else { return }
                    if let saveError = onSave(draft) {
                        validationMessage = saveError
                        return
                    }
                    dismiss()
                }
            }
            if let validationMessage {
                Text(validationMessage).foregroundStyle(.red).font(.caption)
            }
        }
        .onChange(of: draft.clientId) { _ in
            _ = validatePropertySelection()
        }
        .padding()
        .frame(minWidth: 460)
    }

    @discardableResult
    private func validatePropertySelection() -> Bool {
        let validProperties = properties.filter { $0.clientId == draft.clientId }
        if validProperties.contains(where: { $0.id == draft.propertyId }) {
            validationMessage = nil
            return true
        }
        if let firstValidPropertyId = validProperties.first?.id {
            draft.propertyId = firstValidPropertyId
            validationMessage = nil
            return true
        }
        validationMessage = "Для выбранного клиента нет доступных объектов."
        return false
    }
}
#endif
