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
            List(vm.generatedDocuments) { doc in
                VStack(alignment: .leading) {
                    Text(doc.title).bold()
                    Text(doc.path).font(.caption)
                }
            }
        }
    }
}
