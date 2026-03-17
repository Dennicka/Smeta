import SwiftUI

struct WorksView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var draft = WorkCatalogItem(id: 0, name: "", unit: "м²", baseRatePerUnitHour: 0.2, basePrice: 0, swedishName: "", sortOrder: 0)

    var body: some View {
        VStack(alignment: .leading) {
            Text("Работы").font(.largeTitle).bold()
            HStack {
                TextField("Название", text: $draft.name)
                TextField("Ед.", text: $draft.unit)
                TextField("Норма часов", value: $draft.baseRatePerUnitHour, format: .number)
                TextField("Баз. цена", value: $draft.basePrice, format: .number)
                TextField("Название (sv)", text: $draft.swedishName)
                TextField("Порядок", value: $draft.sortOrder, format: .number)
                Button("Добавить") { vm.addWork(draft); draft = WorkCatalogItem(id: 0, name: "", unit: "м²", baseRatePerUnitHour: 0.2, basePrice: 0, swedishName: "", sortOrder: 0) }
            }
            List(vm.works) { item in
                HStack { Text(item.name); Spacer(); Text(item.swedishName); Text("\(item.baseRatePerUnitHour, specifier: "%.2f") ч") }
            }
        }
    }
}
