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
            Button("Skapa Offert-utkast") {
                guard let project = vm.selectedProject else { return }
                let lines = [
                    BusinessDocumentLine(id: 0, documentId: 0, lineType: "labor", description: "Målning väggar", quantity: 10, unit: "h", unitPrice: 650, vatRate: 0.25, isRotEligible: true, total: 6500),
                    BusinessDocumentLine(id: 0, documentId: 0, lineType: "material", description: "Färg", quantity: 12, unit: "l", unitPrice: 90, vatRate: 0.25, isRotEligible: false, total: 1080)
                ]
                vm.createDraftDocument(type: .offert, projectId: project.id, title: title, customerType: .b2c, taxMode: .normal, lines: lines, rotPercent: useRot ? 0.3 : 0)
            }
        }
    }
}

struct ContractEditorView: View {
    @EnvironmentObject private var vm: AppViewModel
    var body: some View {
        VStack(alignment: .leading) {
            Text("Contract editor").font(.largeTitle).bold()
            Text("Создайте avtal на основе финализированной offert в Documents.")
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
            Button("Создать Faktura draft") {
                guard let project = vm.selectedProject else { return }
                let lines = [BusinessDocumentLine(id: 0, documentId: 0, lineType: "labor", description: "Arbete", quantity: 20, unit: "h", unitPrice: 700, vatRate: reverseCharge ? 0 : 0.25, isRotEligible: false, total: 14_000)]
                vm.createDraftDocument(type: .faktura, projectId: project.id, title: "Faktura \(project.name)", customerType: reverseCharge ? .b2b : .b2c, taxMode: reverseCharge ? .reverseCharge : .normal, lines: lines)
            }
            Toggle("B2B omvänd betalningsskyldighet", isOn: $reverseCharge)
        }
    }
}

struct PaymentsView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var amount: Double = 0
    var body: some View {
        VStack(alignment: .leading) {
            Text("Payments").font(.largeTitle).bold()
            ForEach(vm.businessDocuments.filter { $0.type == DocumentType.faktura.rawValue }) { doc in
                HStack {
                    Text("\(doc.number.isEmpty ? "draft" : doc.number) saldo: \(doc.balanceDue, specifier: "%.2f")")
                    TextField("Сумма", value: $amount, format: .number)
                    Button("Внести") { vm.addPayment(documentId: doc.id, amount: amount, method: "Bankgiro", reference: "manual") }
                }
            }
        }
    }
}

struct ExtraWorkView: View {
    @EnvironmentObject private var vm: AppViewModel
    var body: some View {
        VStack(alignment: .leading) {
            Text("Extra work / ÄTA").font(.largeTitle).bold()
            Button("Создать ÄTA") {
                guard let project = vm.selectedProject else { return }
                let lines = [BusinessDocumentLine(id: 0, documentId: 0, lineType: "other", description: "ÄTA extra spackling", quantity: 1, unit: "st", unitPrice: 3000, vatRate: 0.25, isRotEligible: false, total: 3000)]
                vm.createDraftDocument(type: .ata, projectId: project.id, title: "ÄTA \(project.name)", customerType: .b2c, taxMode: .normal, lines: lines)
            }
        }
    }
}

struct RemindersView: View {
    @EnvironmentObject private var vm: AppViewModel
    var body: some View {
        VStack(alignment: .leading) {
            Text("Reminders").font(.largeTitle).bold()
            Button("Создать Påminnelse по первой faktura") {
                guard let invoice = vm.businessDocuments.first(where: { $0.type == DocumentType.faktura.rawValue }) else { return }
                let lines = [BusinessDocumentLine(id: 0, documentId: 0, lineType: "other", description: "Påminnelse för \(invoice.number)", quantity: 1, unit: "st", unitPrice: invoice.balanceDue, vatRate: 0, isRotEligible: false, total: invoice.balanceDue)]
                vm.createDraftDocument(type: .paminnelse, projectId: invoice.projectId, title: "Påminnelse \(invoice.number)", customerType: .b2b, taxMode: .normal, lines: lines)
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
