import SwiftUI

struct MaterialsView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var draft = MaterialCatalogItem(id: 0, name: "", unit: "л", basePrice: 0, swedishName: "", sortOrder: 0)

    var body: some View {
        VStack(alignment: .leading) {
            Text("Материалы").font(.largeTitle).bold()
            HStack {
                TextField("Название", text: $draft.name)
                TextField("Ед.", text: $draft.unit)
                TextField("Баз. цена", value: $draft.basePrice, format: .number)
                TextField("Название (sv)", text: $draft.swedishName)
                TextField("Порядок", value: $draft.sortOrder, format: .number)
                Button("Добавить") { vm.addMaterial(draft); draft = MaterialCatalogItem(id: 0, name: "", unit: "л", basePrice: 0, swedishName: "", sortOrder: 0) }
            }
            List(vm.materials) { item in
                HStack { Text(item.name); Spacer(); Text(item.swedishName); Text("\(item.basePrice, specifier: "%.2f")") }
            }
        }
    }
}
