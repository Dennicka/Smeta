import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var selectedClientId: Int64 = 0
    @State private var selectedPropertyId: Int64 = 0
    @State private var name = ""

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
                TextField("Название проекта", text: $name)
                Button("Создать") { vm.addProject(clientId: selectedClientId, propertyId: selectedPropertyId, name: name); name = "" }
            }
            Table(vm.projects) {
                TableColumn("Проект") { p in Text(p.name) }
                TableColumn("Дата") { p in Text(p.createdAt.formatted()) }
                TableColumn("Открыть") { p in Button("Выбрать") { vm.selectedProject = p } }
            }
        }
        .onAppear {
            selectedClientId = vm.clients.first?.id ?? 0
            selectedPropertyId = vm.properties.first?.id ?? 0
        }
    }
}
