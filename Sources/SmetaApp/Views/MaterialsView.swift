#if canImport(SwiftUI)
import SwiftUI

struct MaterialsView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var draft = MaterialCatalogItem(id: 0, name: "", unit: "л", basePrice: 0, swedishName: "", sortOrder: 0)
    @State private var createCategoryIdText = ""
    @State private var createSupplierIdText = ""
    @State private var createValidationMessage: String?
    @State private var query = ""
    @State private var editingMaterial: MaterialCatalogItem?

    var filtered: [MaterialCatalogItem] {
        vm.materials.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.swedishName.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Каталог материалов").font(.largeTitle).bold()
            TextField("Поиск", text: $query)
            VStack {
                HStack {
                    TextField("RU", text: $draft.name)
                    TextField("SV", text: $draft.swedishName)
                    TextField("Ед.", text: $draft.unit)
                    TextField("Продажа", value: $draft.basePrice, format: .number)
                    TextField("Закупка", value: $draft.purchasePrice, format: .number)
                }
                HStack {
                    TextField("Наценка %", value: $draft.markupPercent, format: .number)
                    TextField("SKU", text: $draft.sku)
                    TextField("Расход/ед", value: $draft.usagePerWorkUnit, format: .number)
                    TextField("Упаковка", value: $draft.packageSize, format: .number)
                    TextField("Остаток", value: $draft.stock, format: .number)
                    TextField("Category ID", text: $createCategoryIdText)
                    TextField("Supplier ID", text: $createSupplierIdText)
                    TextField("Комментарий", text: $draft.comment)
                    Button("Добавить") {
                        guard let validatedDraft = validatedCreateDraft() else { return }
                        guard vm.addMaterial(validatedDraft) else {
                            createValidationMessage = vm.errorMessage ?? "Не удалось добавить материал"
                            return
                        }
                        draft = MaterialCatalogItem(id: 0, name: "", unit: "л", basePrice: 0, swedishName: "", sortOrder: 0)
                        createCategoryIdText = ""
                        createSupplierIdText = ""
                        createValidationMessage = nil
                    }
                }
            }
            if let createValidationMessage {
                Text(createValidationMessage).foregroundStyle(.red).font(.caption)
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
                    Button("Редактировать") { editingMaterial = item }
                    Button("Дубль") {
                        var copy = item
                        copy.id = 0
                        copy.name += " (копия)"
                        vm.addMaterial(copy)
                    }
                    Button("Удалить", role: .destructive) {
                        vm.deleteMaterial(item)
                    }
                }
            }
        }
        .sheet(item: $editingMaterial) { item in
            MaterialEditSheet(item: item) { updated in
                vm.updateMaterial(updated) ? nil : (vm.errorMessage ?? "Не удалось обновить материал")
            }
        }
    }

    private func validatedCreateDraft() -> MaterialCatalogItem? {
        do {
            var copy = draft
            copy.categoryId = try parseOptionalInt64(createCategoryIdText, fieldName: "Category ID")
            copy.supplierId = try parseOptionalInt64(createSupplierIdText, fieldName: "Supplier ID")
            createValidationMessage = nil
            return copy
        } catch {
            createValidationMessage = error.localizedDescription
            return nil
        }
    }

    private func parseOptionalInt64(_ raw: String, fieldName: String) throws -> Int64? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        guard let value = Int64(trimmed) else {
            throw NSError(domain: "MaterialsView.Validation", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(fieldName) должен быть целым числом или пустым значением"])
        }
        return value
    }
}

private struct MaterialEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: MaterialCatalogItem
    @State private var categoryIdText: String
    @State private var supplierIdText: String
    @State private var validationMessage: String?
    let onSave: (MaterialCatalogItem) -> String?

    init(item: MaterialCatalogItem, onSave: @escaping (MaterialCatalogItem) -> String?) {
        _draft = State(initialValue: item)
        _categoryIdText = State(initialValue: item.categoryId.map(String.init) ?? "")
        _supplierIdText = State(initialValue: item.supplierId.map(String.init) ?? "")
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("Редактирование материала").font(.headline)
            TextField("RU", text: $draft.name)
            TextField("SV", text: $draft.swedishName)
            TextField("Ед.", text: $draft.unit)
            TextField("Цена продажи", value: $draft.basePrice, format: .number)
            TextField("Закупка", value: $draft.purchasePrice, format: .number)
            TextField("Наценка %", value: $draft.markupPercent, format: .number)
            TextField("SKU", text: $draft.sku)
            TextField("Расход/ед", value: $draft.usagePerWorkUnit, format: .number)
            TextField("Упаковка", value: $draft.packageSize, format: .number)
            TextField("Остаток", value: $draft.stock, format: .number)
            TextField("Category ID", text: $categoryIdText)
            TextField("Supplier ID", text: $supplierIdText)
            TextField("Комментарий", text: $draft.comment)
            Toggle("Активен", isOn: $draft.isActive)
            HStack {
                Button("Отмена") { dismiss() }
                Button("Сохранить") {
                    guard applyValidatedReferences() else { return }
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

    private func applyValidatedReferences() -> Bool {
        do {
            draft.categoryId = try parseOptionalInt64(categoryIdText, fieldName: "Category ID")
            draft.supplierId = try parseOptionalInt64(supplierIdText, fieldName: "Supplier ID")
            validationMessage = nil
            return true
        } catch {
            validationMessage = error.localizedDescription
            return false
        }
    }

    private func parseOptionalInt64(_ raw: String, fieldName: String) throws -> Int64? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        guard let value = Int64(trimmed) else {
            throw NSError(domain: "MaterialEditSheet.Validation", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(fieldName) должен быть целым числом или пустым значением"])
        }
        return value
    }
}
#endif
