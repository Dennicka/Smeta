#if canImport(SwiftUI)
import SwiftUI

struct RoomsView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var name = ""
    @State private var roomType = ""
    @State private var length = ""
    @State private var width = ""
    @State private var area = ""
    @State private var height = "2.7"
    @State private var wallAdjustment = "0"
    @State private var openingWidth = "1.0"
    @State private var openingHeight = "1.2"
    @State private var openingCount = "1"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerSection
            contentSection
        }
    }

    private var headerSection: some View {
        Text("Помещения и поверхности").font(.largeTitle).bold()
    }

    @ViewBuilder
    private var contentSection: some View {
        if let project = vm.selectedProject {
            Text("Проект: \(project.name)").font(.headline)
            addRoomSection(projectId: project.id)
            roomsTable(projectId: project.id)
            openingsSection(projectId: project.id)
        } else {
            Text("Сначала выберите проект")
        }
    }

    private func addRoomSection(projectId: Int64) -> some View {
        HStack {
            TextField("Название", text: $name)
            TextField("Тип", text: $roomType)
            TextField("Длина", text: $length)
            TextField("Ширина", text: $width)
            TextField("Площадь пола", text: $area)
            TextField("Высота", text: $height)
            TextField("Корр. стен", text: $wallAdjustment)
            Button("Добавить") {
                vm.addRoom(projectId: projectId,
                           name: name,
                           area: Double(area) ?? 0,
                           height: Double(height) ?? 2.7,
                           length: Double(length) ?? 0,
                           width: Double(width) ?? 0,
                           manualWallAdjustment: Double(wallAdjustment) ?? 0,
                           roomType: roomType)
            }
        }
    }

    private func roomsTable(projectId: Int64) -> some View {
        Table(vm.rooms.filter { $0.projectId == projectId }) {
            TableColumn("Название", value: \.name)
            TableColumn("Тип") { Text($0.roomType) }
            TableColumn("Пол") { Text(String(format: "%.1f", $0.floorArea)) }
            TableColumn("Стены (авто)") { Text(String(format: "%.1f", $0.wallAreaAuto)) }
            TableColumn("Корр.") { Text(String(format: "%.1f", $0.wallAreaManualAdjustment)) }
            TableColumn("Стены (итог)") { Text(String(format: "%.1f", $0.wallAreaTotal)).bold() }
            TableColumn("Высота") { Text(String(format: "%.1f", $0.height)) }
            TableColumn("Действия") { room in
                Button("Дублировать") { vm.duplicateRoom(room) }
            }
        }
    }

    private func openingsSection(projectId: Int64) -> some View {
        VStack(alignment: .leading) {
            Divider().padding(.vertical, 4)
            Text("Проёмы").font(.headline)
            ForEach(vm.rooms.filter { $0.projectId == projectId }) { room in
                openingRow(room: room)
            }
        }
    }

    private func openingRow(room: Room) -> some View {
        VStack(alignment: .leading) {
            Text(room.name).bold()
            HStack {
                TextField("Ширина", text: $openingWidth)
                TextField("Высота", text: $openingHeight)
                TextField("Кол-во", text: $openingCount)
                Button("+ Окно") {
                    vm.addOpening(roomId: room.id, type: "window", name: "Окно", width: Double(openingWidth) ?? 1, height: Double(openingHeight) ?? 1.2, count: Int(openingCount) ?? 1, subtract: true)
                }
                Button("+ Дверь") {
                    vm.addOpening(roomId: room.id, type: "door", name: "Дверь", width: 0.9, height: 2.1, count: 1, subtract: true)
                }
            }
            openingsList(roomId: room.id)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func openingsList(roomId: Int64) -> some View {
        let openings = vm.openingsByRoom[roomId, default: []]
        if openings.isEmpty {
            Text("Нет проёмов").font(.caption)
        } else {
            ForEach(openings) { opening in
                Text("• \(opening.name) \(opening.width, specifier: "%.2f")×\(opening.height, specifier: "%.2f") ×\(opening.count) | вычет: \(opening.subtractFromWallArea ? "да" : "нет") | площадь: \(opening.area, specifier: "%.2f")")
                    .font(.caption)
            }
        }
    }
}
#endif
