#if canImport(SwiftUI)
import SwiftUI

struct OfferEditorView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var title = "Offert"
    @State private var useRot = false

    var body: some View {
        VStack(alignment: .leading) {
            Text("Offer editor").font(.largeTitle).bold()
            TextField("Titel", text: $title)
            Toggle("ROT tillämplig", isOn: $useRot)
            Text("Документ будет собран только из реальных данных проекта/сметы.")
                .font(.footnote)
                .foregroundColor(.secondary)
            Button("Skapa Offert-utkast") {
                vm.createOffertDraftFromSelectedProject(title: title, useRot: useRot)
            }
        }
    }
}

struct ContractEditorView: View {
    @EnvironmentObject private var vm: AppViewModel
    var body: some View {
        VStack(alignment: .leading) {
            Text("Contract editor").font(.largeTitle).bold()
            Text("Avtal строится только из финализированной Offert текущего проекта.")
                .font(.footnote)
                .foregroundColor(.secondary)
            Button("Создать Avtal draft") {
                vm.createAvtalDraftFromSelectedProject()
            }
            List(vm.businessDocuments.filter { $0.type == DocumentType.offert.rawValue || $0.type == DocumentType.avtal.rawValue }) { doc in
                Text("\(doc.type.uppercased()) \(doc.number.isEmpty ? "DRAFT" : doc.number) — \(doc.title)")
            }
        }
    }
}

struct InvoiceEditorView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var reverseCharge = false
    var body: some View {
        VStack(alignment: .leading) {
            Text("Invoice editor").font(.largeTitle).bold()
            Text("Faktura строится из project/estimate state без demo-строк.")
                .font(.footnote)
                .foregroundColor(.secondary)
            Button("Создать Faktura draft") {
                vm.createFakturaDraftFromSelectedProject(reverseCharge: reverseCharge)
            }
            Toggle("B2B omvänd betalningsskyldighet", isOn: $reverseCharge)
        }
    }
}

struct PaymentsView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var amountsByDocument: [Int64: Double] = [:]
    @State private var methodsByDocument: [Int64: String] = [:]
    @State private var referencesByDocument: [Int64: String] = [:]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Payments").font(.largeTitle).bold()
            ForEach(vm.businessDocuments.filter { $0.type == DocumentType.faktura.rawValue }) { doc in
                let isPayable = isDocumentPayable(doc)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(doc.number.isEmpty ? "draft" : doc.number) [\(doc.status)]")
                        Spacer()
                        Text("Paid: \(doc.paidAmount, specifier: "%.2f")  Due: \(doc.balanceDue, specifier: "%.2f")")
                    }
                    HStack {
                        TextField("Сумма", value: paymentBinding(for: doc.id), format: .number)
                            .frame(width: 120)
                        TextField("Method", text: methodBinding(for: doc.id))
                            .frame(width: 140)
                        TextField("Reference", text: referenceBinding(for: doc.id))
                            .frame(width: 140)
                        Button("Внести") {
                            let amount = amountsByDocument[doc.id, default: 0]
                            let method = methodsByDocument[doc.id, default: "Bankgiro"]
                            let reference = referencesByDocument[doc.id, default: "manual"]
                            if vm.addPayment(documentId: doc.id, amount: amount, method: method, reference: reference) {
                                amountsByDocument[doc.id] = 0
                            }
                        }
                        .disabled(!isPayable)
                    }

                    if !isPayable {
                        Text("Оплата недоступна: документ должен быть final/sent/partial с положительным остатком")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    let payments = vm.paymentsByDocumentId[doc.id, default: []]
                    if payments.isEmpty {
                        Text("Платежей пока нет")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(payments) { payment in
                            Text("• \(payment.amount, specifier: "%.2f") \(payment.method) \(payment.reference)")
                                .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func paymentBinding(for documentId: Int64) -> Binding<Double> {
        Binding(
            get: { amountsByDocument[documentId, default: 0] },
            set: { amountsByDocument[documentId] = $0 }
        )
    }

    private func methodBinding(for documentId: Int64) -> Binding<String> {
        Binding(
            get: { methodsByDocument[documentId, default: "Bankgiro"] },
            set: { methodsByDocument[documentId] = $0 }
        )
    }

    private func referenceBinding(for documentId: Int64) -> Binding<String> {
        Binding(
            get: { referencesByDocument[documentId, default: "manual"] },
            set: { referencesByDocument[documentId] = $0 }
        )
    }

    private func isDocumentPayable(_ doc: BusinessDocument) -> Bool {
        guard doc.type == DocumentType.faktura.rawValue else { return false }
        guard doc.balanceDue > 0 else { return false }
        let allowed = Set([
            DocumentStatus.finalized.rawValue,
            DocumentStatus.sent.rawValue,
            DocumentStatus.partiallyPaid.rawValue
        ])
        return allowed.contains(doc.status)
    }
}

struct ExtraWorkView: View {
    @EnvironmentObject private var vm: AppViewModel
    var body: some View {
        VStack(alignment: .leading) {
            Text("Extra work / ÄTA").font(.largeTitle).bold()
            Text("ÄTA строится из repository-backed estimate/project данных.")
                .font(.footnote)
                .foregroundColor(.secondary)
            Button("Создать ÄTA") {
                vm.createAtaDraftFromSelectedProject()
            }
        }
    }
}

struct RemindersView: View {
    @EnvironmentObject private var vm: AppViewModel
    var body: some View {
        VStack(alignment: .leading) {
            Text("Reminders").font(.largeTitle).bold()
            Text("Påminnelse строится только из фактической задолженности по Faktura.")
                .font(.footnote)
                .foregroundColor(.secondary)
            Button("Создать Påminnelse по первой faktura") {
                vm.createPaminnelseDraftFromSelectedProject()
            }
            Button("Создать Kreditfaktura по финализированной faktura") {
                vm.createKreditfakturaDraftFromSelectedProject()
            }
        }
    }
}

struct DocumentTemplatesView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var name = ""
    @State private var language = "sv"
    @State private var header = ""
    @State private var footer = ""
    @State private var createTemplateError: String?
    @State private var editingTemplate: DocumentTemplate?
    var body: some View {
        VStack(alignment: .leading) {
            Text("Document templates").font(.largeTitle).bold()
            HStack {
                TextField("Name", text: $name)
                TextField("Lang", text: $language)
                TextField("Header", text: $header)
                TextField("Footer", text: $footer)
                Button("Create") {
                    guard vm.addTemplate(DocumentTemplate(id: 0, name: name, language: language, headerText: header, footerText: footer, sortOrder: vm.templates.count)) else {
                        createTemplateError = vm.errorMessage ?? "Не удалось создать шаблон"
                        return
                    }
                    name = ""
                    language = "sv"
                    header = ""
                    footer = ""
                    createTemplateError = nil
                }
            }
            if let createTemplateError {
                Text(createTemplateError).foregroundStyle(.red).font(.caption)
            }
            List(vm.templates) { t in
                HStack {
                    VStack(alignment: .leading) {
                        Text(t.name).bold()
                        Text(t.headerText)
                    }
                    Spacer()
                    Button("Edit") { editingTemplate = t }
                    Button("Delete", role: .destructive) {
                        vm.deleteTemplate(t)
                    }
                }
            }
        }
        .sheet(item: $editingTemplate) { template in
            TemplateEditSheet(template: template) { updated in
                vm.updateTemplate(updated) ? nil : (vm.errorMessage ?? "Не удалось обновить шаблон")
            }
        }
    }
}

struct DocumentNumberingView: View {
    @EnvironmentObject private var vm: AppViewModel
    var body: some View {
        VStack(alignment: .leading) {
            Text("Document numbering").font(.largeTitle).bold()
            List(vm.documentSeries) { series in
                Text("\(series.documentType): \(series.prefix)-\(series.nextNumber)")
            }
        }
    }
}

struct TaxSettingsView: View {
    @EnvironmentObject private var vm: AppViewModel
    var body: some View {
        VStack(alignment: .leading) {
            Text("Tax settings").font(.largeTitle).bold()
            List(vm.taxProfiles) { profile in
                Text("\(profile.name) VAT \(profile.vatRate * 100, specifier: "%.0f")% ROT \(profile.rotPercent * 100, specifier: "%.0f")%")
            }
        }
    }
}

private struct TemplateEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: DocumentTemplate
    @State private var validationMessage: String?
    let onSave: (DocumentTemplate) -> String?

    init(template: DocumentTemplate, onSave: @escaping (DocumentTemplate) -> String?) {
        _draft = State(initialValue: template)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("Edit template").font(.headline)
            TextField("Name", text: $draft.name)
            TextField("Lang", text: $draft.language)
            TextField("Header", text: $draft.headerText)
            TextField("Footer", text: $draft.footerText)
            TextField("Sort", value: $draft.sortOrder, format: .number)
            HStack {
                Button("Cancel") { dismiss() }
                Button("Save") {
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
