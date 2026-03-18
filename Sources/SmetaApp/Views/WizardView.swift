#if canImport(SwiftUI)
import SwiftUI

struct WizardView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var clientName = ""
    @State private var propertyName = ""
    @State private var projectName = ""
    @State private var lastClientId: Int64?
    @State private var lastPropertyId: Int64?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create Estimate Wizard").font(.largeTitle).bold()
            GroupBox("Шаг 1: Клиент") {
                HStack { TextField("Имя клиента", text: $clientName); Button("Сохранить") { vm.addClient(name: clientName, email: "", phone: "", address: ""); lastClientId = vm.clients.first?.id } }
            }
            GroupBox("Шаг 2: Объект") {
                HStack { TextField("Название объекта", text: $propertyName); Button("Сохранить") { if let client = lastClientId ?? vm.clients.first?.id { vm.addProperty(clientId: client, name: propertyName, address: "") ; lastPropertyId = vm.properties.first?.id } } }
            }
            GroupBox("Шаг 3: Проект") {
                HStack { TextField("Название проекта", text: $projectName); Button("Сохранить") { if let client = lastClientId ?? vm.clients.first?.id, let property = lastPropertyId ?? vm.properties.first?.id { vm.addProject(clientId: client, propertyId: property, name: projectName) } } }
            }
            Spacer()
        }
    }
}
#endif
