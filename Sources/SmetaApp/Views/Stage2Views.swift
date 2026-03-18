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

    var body: some View {
        VStack(alignment: .leading) {
            Text("Payments").font(.largeTitle).bold()
            ForEach(vm.businessDocuments.filter { $0.type == DocumentType.faktura.rawValue }) { doc in
                HStack {
                    Text("\(doc.number.isEmpty ? "draft" : doc.number) saldo: \(doc.balanceDue, specifier: "%.2f")")
                    TextField("Сумма", value: paymentBinding(for: doc.id), format: .number)
                        .frame(width: 120)
                    Button("Внести") {
                        let amount = amountsByDocument[doc.id, default: 0]
                        vm.addPayment(documentId: doc.id, amount: amount, method: "Bankgiro", reference: "manual")
                    }
                }
            }
        }
    }

    private func paymentBinding(for documentId: Int64) -> Binding<Double> {
        Binding(
            get: { amountsByDocument[documentId, default: 0] },
            set: { amountsByDocument[documentId] = $0 }
        )
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
    var body: some View {
        VStack(alignment: .leading) {
            Text("Document templates").font(.largeTitle).bold()
            List(vm.templates) { t in
                VStack(alignment: .leading) {
                    Text(t.name).bold()
                    Text(t.headerText)
                }
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
#endif
