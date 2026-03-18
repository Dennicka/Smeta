import SwiftUI

struct DocumentsView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var draft = DocumentTemplate(id: 0, name: "", language: "sv", headerText: "", footerText: "", sortOrder: 0)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Документы").font(.largeTitle).bold()
            HStack {
                TextField("Шаблон", text: $draft.name)
                TextField("Язык", text: $draft.language)
                TextField("Заголовок", text: $draft.headerText)
                TextField("Подвал", text: $draft.footerText)
                Button("Добавить шаблон") { vm.addTemplate(draft) }
            }
            HStack {
                Button("Сгенерировать Offert PDF") { vm.saveEstimateAndGenerateDocument() }
            }
            List(vm.filteredBusinessDocuments) { doc in
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(doc.type.uppercased()) \(doc.number.isEmpty ? "DRAFT" : doc.number)").bold()
                        Text("\(doc.status) / Total \(doc.totalAmount, specifier: "%.2f") / Баланс \(doc.balanceDue, specifier: "%.2f")").font(.caption)
                    }
                    Spacer()
                    if doc.status == DocumentStatus.draft.rawValue {
                        Button("Finalize") { vm.finalizeDocument(doc) }
                    }
                }
            }
        }
    }
}
