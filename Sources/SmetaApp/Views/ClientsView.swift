#if canImport(SwiftUI)
import SwiftUI

struct ClientsView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var createName = ""
    @State private var createEmail = ""
    @State private var createPhone = ""
    @State private var createAddress = ""
    @State private var createClientError: String?
    @State private var selectedClientId: Int64?

    @State private var propertyName = ""
    @State private var propertyAddress = ""
    @State private var createPropertyError: String?
    @State private var editingClient: Client?
    @State private var editingProperty: PropertyObject?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Клиенты и объекты").font(.largeTitle).bold()
            HStack {
                TextField("Имя", text: $createName)
                TextField("Email", text: $createEmail)
                TextField("Телефон", text: $createPhone)
                TextField("Адрес", text: $createAddress)
                Button("Создать") {
                    guard vm.addClient(name: createName, email: createEmail, phone: createPhone, address: createAddress) else {
                        createClientError = vm.errorMessage ?? "Не удалось создать клиента"
                        return
                    }
                    createName = ""; createEmail = ""; createPhone = ""; createAddress = ""
                    createClientError = nil
                }
            }
            if let createClientError {
                Text(createClientError).foregroundStyle(.red).font(.caption)
            }

            List(vm.clients.filter { vm.searchText.isEmpty ? true : $0.name.localizedCaseInsensitiveContains(vm.searchText) }) { client in
                HStack {
                    VStack(alignment: .leading) {
                        Text(client.name).bold()
                        Text("\(client.email) | \(client.phone) | \(client.address)").font(.caption)
                    }
                    Spacer()
                    if selectedClientId == client.id { Text("выбран").foregroundStyle(.green) }
                    Button("Выбрать") {
                        selectedClientId = client.id
                        propertyName = ""
                        propertyAddress = ""
                    }
                    Button("Редактировать") { editingClient = client }
                    Button("Удалить", role: .destructive) {
                        vm.deleteClient(client)
                        if selectedClientId == client.id { selectedClientId = nil }
                    }
                }
            }

            Divider()
            Text("Объекты").font(.title2).bold()
            if let clientId = selectedClientId {
                HStack {
                    TextField("Название объекта", text: $propertyName)
                    TextField("Адрес объекта", text: $propertyAddress)
                    Button("Создать объект") {
                        guard vm.addProperty(clientId: clientId, name: propertyName, address: propertyAddress) else {
                            createPropertyError = vm.errorMessage ?? "Не удалось создать объект"
                            return
                        }
                        propertyName = ""
                        propertyAddress = ""
                        createPropertyError = nil
                    }
                }
                if let createPropertyError {
                    Text(createPropertyError).foregroundStyle(.red).font(.caption)
                }
                List(vm.properties.filter { $0.clientId == clientId }) { property in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(property.name).bold()
                            Text(property.address).font(.caption)
                        }
                        Spacer()
                        Button("Редактировать") { editingProperty = property }
                        Button("Удалить", role: .destructive) { vm.deleteProperty(property) }
                    }
                }
            } else {
                Text("Выберите клиента, чтобы управлять его объектами")
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(item: $editingClient) { client in
            ClientEditSheet(client: client) { updated in
                vm.updateClient(updated) ? nil : (vm.errorMessage ?? "Не удалось обновить клиента")
            }
        }
        .sheet(item: $editingProperty) { property in
            PropertyEditSheet(property: property) { updated in
                vm.updateProperty(updated) ? nil : (vm.errorMessage ?? "Не удалось обновить объект")
            }
        }
    }
}

private struct ClientEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Client
    @State private var validationMessage: String?
    let onSave: (Client) -> String?

    init(client: Client, onSave: @escaping (Client) -> String?) {
        _draft = State(initialValue: client)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("Редактирование клиента").font(.headline)
            TextField("Имя", text: $draft.name)
            TextField("Email", text: $draft.email)
            TextField("Телефон", text: $draft.phone)
            TextField("Адрес", text: $draft.address)
            HStack {
                Button("Отмена") { dismiss() }
                Button("Сохранить") {
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
        .padding()
        .frame(minWidth: 420)
    }
}

private struct PropertyEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: PropertyObject
    @State private var validationMessage: String?
    let onSave: (PropertyObject) -> String?

    init(property: PropertyObject, onSave: @escaping (PropertyObject) -> String?) {
        _draft = State(initialValue: property)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("Редактирование объекта").font(.headline)
            TextField("Название", text: $draft.name)
            TextField("Адрес", text: $draft.address)
            HStack {
                Button("Отмена") { dismiss() }
                Button("Сохранить") {
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
        .padding()
        .frame(minWidth: 420)
    }
}
#endif
