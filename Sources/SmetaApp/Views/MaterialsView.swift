#if canImport(SwiftUI)
import SwiftUI

struct MaterialsView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var draft = MaterialCatalogItem(id: 0, name: "", unit: "л", basePrice: 0, swedishName: "", sortOrder: 0)
    @State private var query = ""

    var filtered: [MaterialCatalogItem] {
        vm.materials.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.swedishName.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Каталог материалов").font(.largeTitle).bold()
            TextField("Поиск", text: $query)
            HStack {
                TextField("RU", text: $draft.name)
                TextField("SV", text: $draft.swedishName)
                TextField("Ед.", text: $draft.unit)
                TextField("Продажа", value: $draft.basePrice, format: .number)
                TextField("Закупка", value: $draft.purchasePrice, format: .number)
                TextField("Наценка %", value: $draft.markupPercent, format: .number)
                TextField("SKU", text: $draft.sku)
                TextField("Расход/ед", value: $draft.usagePerWorkUnit, format: .number)
                TextField("Упаковка", value: $draft.packageSize, format: .number)
                TextField("Остаток", value: $draft.stock, format: .number)
                Button("Добавить") {
                    vm.addMaterial(draft)
                    draft = MaterialCatalogItem(id: 0, name: "", unit: "л", basePrice: 0, swedishName: "", sortOrder: 0)
                }
            }
            List(filtered) { item in
                HStack {
                    VStack(alignment: .leading) {
                        Text(item.name).bold()
                        Text("SKU: \(item.sku), расход \(item.usagePerWorkUnit, specifier: "%.2f")")
                            .font(.caption)
                    }
                    Spacer()
                    Button(item.isActive ? "Деактивировать" : "Активировать") {
                        var copy = item
                        copy.isActive.toggle()
                        vm.updateMaterial(copy)
                    }
                    Button("Дубль") {
                        var copy = item
                        copy.id = 0
                        copy.name += " (копия)"
                        vm.addMaterial(copy)
                    }
                }
            }
        }
    }
}
#endif
