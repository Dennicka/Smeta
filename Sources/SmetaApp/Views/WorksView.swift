import SwiftUI

struct WorksView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var draft = WorkCatalogItem(id: 0, name: "", unit: "м²", baseRatePerUnitHour: 0.2, basePrice: 0, swedishName: "", sortOrder: 0)
    @State private var query = ""
    @State private var activeOnly = true

    var filtered: [WorkCatalogItem] {
        vm.works.filter { (!activeOnly || $0.isActive) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.swedishName.localizedCaseInsensitiveContains(query)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Каталог работ").font(.largeTitle).bold()
            HStack {
                TextField("Поиск", text: $query)
                Toggle("Только активные", isOn: $activeOnly)
            }
            HStack {
                TextField("RU", text: $draft.name)
                TextField("SV", text: $draft.swedishName)
                TextField("Ед.", text: $draft.unit)
                TextField("Норма ч/ед", value: $draft.baseRatePerUnitHour, format: .number)
                TextField("Цена продажи", value: $draft.basePrice, format: .number)
                TextField("Цена закупки", value: $draft.basePurchasePrice, format: .number)
                TextField("Скорость slow", value: $draft.slowSpeed, format: .number)
                TextField("Скорость med", value: $draft.mediumSpeed, format: .number)
                TextField("Скорость fast", value: $draft.fastSpeed, format: .number)
                Button("Добавить") {
                    vm.addWork(draft)
                    draft = WorkCatalogItem(id: 0, name: "", unit: "м²", baseRatePerUnitHour: 0.2, basePrice: 0, swedishName: "", sortOrder: 0)
                }
            }
            List(filtered) { item in
                HStack {
                    VStack(alignment: .leading) {
                        Text(item.name).bold()
                        Text(item.swedishName).font(.caption)
                        Text("\(item.unit), норма \(item.baseRatePerUnitHour, specifier: "%.2f"), coeff: c\(item.complexityCoefficient, specifier: "%.2f") h\(item.heightCoefficient, specifier: "%.2f")")
                            .font(.caption2)
                    }
                    Spacer()
                    Button(item.isActive ? "Деактивировать" : "Активировать") {
                        var copy = item
                        copy.isActive.toggle()
                        vm.updateWork(copy)
                    }
                    Button("Дубль") {
                        var copy = item
                        copy.id = 0
                        copy.name += " (копия)"
                        vm.addWork(copy)
                    }
                }
            }
        }
    }
}
