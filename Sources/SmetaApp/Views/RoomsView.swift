import SwiftUI

struct RoomsView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var name = ""
    @State private var area = ""
    @State private var height = "2.7"

    var body: some View {
        VStack(alignment: .leading) {
            Text("Помещения").font(.largeTitle).bold()
            if let project = vm.selectedProject {
                Text("Проект: \(project.name)").font(.headline)
                HStack {
                    TextField("Название", text: $name)
                    TextField("Площадь", text: $area)
                    TextField("Высота", text: $height)
                    Button("Добавить") {
                        vm.addRoom(projectId: project.id, name: name, area: Double(area) ?? 0, height: Double(height) ?? 2.7)
                    }
                }
                Table(vm.rooms.filter { $0.projectId == project.id }) {
                    TableColumn("Название", value: \.name)
                    TableColumn("Площадь") { Text(String(format: "%.1f", $0.area)) }
                    TableColumn("Высота") { Text(String(format: "%.1f", $0.height)) }
                }
            } else {
                Text("Сначала выберите проект")
            }
        }
    }
}
