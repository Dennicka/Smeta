#if canImport(SwiftUI)
import SwiftUI

struct WorksView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var draft = WorkCatalogItem(id: 0, name: "", unit: "м²", baseRatePerUnitHour: 0.2, basePrice: 0, swedishName: "", sortOrder: 0)
    @State private var createCategoryIdText = ""
    @State private var createSubcategoryIdText = ""
    @State private var createValidationMessage: String?
    @State private var query = ""
    @State private var activeOnly = true
    @State private var editingWork: WorkCatalogItem?

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
                Group {
                    TextField("RU", text: $draft.name)
                    TextField("SV", text: $draft.swedishName)
                    TextField("Ед.", text: $draft.unit)
                    TextField("Норма ч/ед", value: $draft.baseRatePerUnitHour, format: .number)
                    TextField("Цена продажи", value: $draft.basePrice, format: .number)
                    TextField("Цена закупки", value: $draft.basePurchasePrice, format: .number)
                    TextField("Скорость slow", value: $draft.slowSpeed, format: .number)
                }
                Group {
                    TextField("Скорость med", value: $draft.mediumSpeed, format: .number)
                    TextField("Скорость fast", value: $draft.fastSpeed, format: .number)
                    TextField("Описание", text: $draft.description)
                    TextField("Applicability", text: $draft.applicability)
                    TextField("Category ID", text: $createCategoryIdText)
                    TextField("Subcategory ID", text: $createSubcategoryIdText)
                }
            }
            HStack {
                TextField("Complexity", value: $draft.complexityCoefficient, format: .number)
                TextField("Height coef", value: $draft.heightCoefficient, format: .number)
                TextField("Condition coef", value: $draft.conditionCoefficient, format: .number)
                TextField("Urgency coef", value: $draft.urgencyCoefficient, format: .number)
                TextField("Accessibility coef", value: $draft.accessibilityCoefficient, format: .number)
                TextField("Доп. часы", value: $draft.additionalLaborHours, format: .number)
                TextField("Доп. расход", value: $draft.additionalMaterialUsage, format: .number)
                Toggle("ROT", isOn: $draft.rotEligible)
                Toggle("В стандартную оферту", isOn: $draft.includeInStandardOffer)
                Button("Добавить") {
                    guard let validatedDraft = validatedCreateDraft() else { return }
                    guard vm.addWork(validatedDraft) else {
                        createValidationMessage = vm.errorMessage ?? "Не удалось добавить работу"
                        return
                    }
                    draft = WorkCatalogItem(id: 0, name: "", unit: "м²", baseRatePerUnitHour: 0.2, basePrice: 0, swedishName: "", sortOrder: 0)
                    createCategoryIdText = ""
                    createSubcategoryIdText = ""
                    createValidationMessage = nil
                }
            }
            if let createValidationMessage {
                Text(createValidationMessage).foregroundStyle(.red).font(.caption)
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
                    Button("Редактировать") { editingWork = item }
                    Button("Дубль") {
                        var copy = item
                        copy.id = 0
                        copy.name += " (копия)"
                        vm.addWork(copy)
                    }
                    Button("Удалить", role: .destructive) {
                        vm.deleteWork(item)
                    }
                }
            }
        }
        .sheet(item: $editingWork) { item in
            WorkEditSheet(item: item) { updated in
                vm.updateWork(updated) ? nil : (vm.errorMessage ?? "Не удалось обновить работу")
            }
        }
    }

    private func validatedCreateDraft() -> WorkCatalogItem? {
        do {
            var copy = draft
            copy.categoryId = try parseOptionalInt64(createCategoryIdText, fieldName: "Category ID")
            copy.subcategoryId = try parseOptionalInt64(createSubcategoryIdText, fieldName: "Subcategory ID")
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
            throw NSError(domain: "WorksView.Validation", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(fieldName) должен быть целым числом или пустым значением"])
        }
        return value
    }
}

private struct WorkEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: WorkCatalogItem
    @State private var categoryIdText: String
    @State private var subcategoryIdText: String
    @State private var validationMessage: String?
    let onSave: (WorkCatalogItem) -> String?

    init(item: WorkCatalogItem, onSave: @escaping (WorkCatalogItem) -> String?) {
        _draft = State(initialValue: item)
        _categoryIdText = State(initialValue: item.categoryId.map(String.init) ?? "")
        _subcategoryIdText = State(initialValue: item.subcategoryId.map(String.init) ?? "")
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("Редактирование работы").font(.headline)
            Group {
                TextField("RU", text: $draft.name)
                TextField("SV", text: $draft.swedishName)
                TextField("Ед.", text: $draft.unit)
                TextField("Норма", value: $draft.baseRatePerUnitHour, format: .number)
                TextField("Цена", value: $draft.basePrice, format: .number)
                TextField("Закупка", value: $draft.basePurchasePrice, format: .number)
                TextField("Почасовая", value: $draft.hourlyPrice, format: .number)
            }
            Group {
                TextField("Slow", value: $draft.slowSpeed, format: .number)
                TextField("Med", value: $draft.mediumSpeed, format: .number)
                TextField("Fast", value: $draft.fastSpeed, format: .number)
                TextField("Описание", text: $draft.description)
                TextField("Applicability", text: $draft.applicability)
                TextField("Category ID", text: $categoryIdText)
                TextField("Subcategory ID", text: $subcategoryIdText)
            }
            Group {
                TextField("Complexity", value: $draft.complexityCoefficient, format: .number)
                TextField("Height coef", value: $draft.heightCoefficient, format: .number)
                TextField("Condition coef", value: $draft.conditionCoefficient, format: .number)
                TextField("Urgency coef", value: $draft.urgencyCoefficient, format: .number)
                TextField("Accessibility coef", value: $draft.accessibilityCoefficient, format: .number)
                TextField("Доп. часы", value: $draft.additionalLaborHours, format: .number)
                TextField("Доп. расход", value: $draft.additionalMaterialUsage, format: .number)
            }
            Group {
                Toggle("Активна", isOn: $draft.isActive)
                Toggle("ROT", isOn: $draft.rotEligible)
                Toggle("В стандартную оферту", isOn: $draft.includeInStandardOffer)
            }
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
            draft.subcategoryId = try parseOptionalInt64(subcategoryIdText, fieldName: "Subcategory ID")
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
            throw NSError(domain: "WorkEditSheet.Validation", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(fieldName) должен быть целым числом или пустым значением"])
        }
        return value
    }
}
#endif
