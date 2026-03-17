import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var vm: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Stage 1 — рабочий срез").font(.largeTitle).bold()
            HStack {
                StatCard(title: "Клиенты", value: "\(vm.clients.count)")
                StatCard(title: "Проекты", value: "\(vm.projects.count)")
                StatCard(title: "Помещения", value: "\(vm.rooms.count)")
                StatCard(title: "Документы", value: "\(vm.generatedDocuments.count)")
            }
            Spacer()
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.headline)
            Text(value).font(.system(size: 34, weight: .semibold))
        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(.thinMaterial).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
