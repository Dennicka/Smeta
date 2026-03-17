import SwiftUI

struct ClientsView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var address = ""

    var body: some View {
        VStack(alignment: .leading) {
            Text("Клиенты").font(.largeTitle).bold()
            HStack {
                TextField("Имя", text: $name)
                TextField("Email", text: $email)
                TextField("Телефон", text: $phone)
                TextField("Адрес", text: $address)
                Button("Добавить") { vm.addClient(name: name, email: email, phone: phone, address: address); name = "" }
            }
            Table(vm.clients.filter { vm.searchText.isEmpty ? true : $0.name.localizedCaseInsensitiveContains(vm.searchText) }) {
                TableColumn("Имя", value: \.name)
                TableColumn("Email", value: \.email)
                TableColumn("Телефон", value: \.phone)
                TableColumn("Адрес", value: \.address)
            }
        }
    }
}
