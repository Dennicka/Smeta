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
            roomsList(projectId: project.id)
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

    private func roomsList(projectId: Int64) -> some View {
        List(filteredRooms(projectId)) { room in
            roomRow(room)
        }
    }

    private func filteredRooms(_ projectId: Int64) -> [Room] {
        vm.rooms.filter { $0.projectId == projectId }
    }

    private func roomRow(_ room: Room) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(room.name).bold()
                if !room.roomType.isEmpty {
                    Text("(\(room.roomType))").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Дублировать") { vm.duplicateRoom(room) }
            }
            HStack(spacing: 10) {
                Text("Пол: \(format1(room.floorArea))")
                Text("Стены (авто): \(format1(room.wallAreaAuto))")
                Text("Корр.: \(format1(room.wallAreaManualAdjustment))")
                Text("Стены (итог): \(format1(room.wallAreaTotal))").bold()
                Text("Высота: \(format1(room.height))")
            }
            .font(.caption)
        }
        .padding(.vertical, 2)
    }

    private func openingsSection(projectId: Int64) -> some View {
        VStack(alignment: .leading) {
            Divider().padding(.vertical, 4)
            Text("Проёмы").font(.headline)
            ForEach(filteredRooms(projectId)) { room in
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
                openingLine(opening)
            }
        }
    }

    private func openingLine(_ opening: Opening) -> some View {
        HStack(spacing: 8) {
            Text("• \(opening.name)")
            Text("\(opening.width, specifier: "%.2f")×\(opening.height, specifier: "%.2f")")
            Text("×\(opening.count)")
            Text("вычет: \(opening.subtractFromWallArea ? "да" : "нет")")
            Text("площадь: \(opening.area, specifier: "%.2f")")
        }
        .font(.caption)
    }

    private func format1(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
#endif
