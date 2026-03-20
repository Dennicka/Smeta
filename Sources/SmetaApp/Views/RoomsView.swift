#if canImport(SwiftUI)
import SwiftUI
import SmetaCore

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
    @State private var createRoomValidationMessage: String?
    @State private var editingRoom: Room?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerSection
            contentSection
        }
        .sheet(item: $editingRoom) { room in
            RoomEditSheet(room: room) { updated in
                vm.updateRoom(updated) ? nil : (vm.errorMessage ?? "Не удалось обновить помещение")
            }
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Название", text: $name)
                TextField("Тип", text: $roomType)
                TextField("Длина", text: $length)
                TextField("Ширина", text: $width)
                TextField("Площадь пола", text: $area)
                TextField("Высота", text: $height)
                TextField("Корр. стен", text: $wallAdjustment)
                Button("Добавить") {
                    guard let input = validateRoomCreateInput() else { return }
                    createRoomValidationMessage = nil
                    vm.addRoom(projectId: projectId,
                               name: name,
                               area: input.area,
                               height: input.height,
                               length: input.length,
                               width: input.width,
                               manualWallAdjustment: input.manualWallAdjustment,
                               roomType: roomType)
                }
            }
            if let createRoomValidationMessage {
                Text(createRoomValidationMessage).foregroundStyle(.red).font(.caption)
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
                Button("Редактировать") { editingRoom = room }
                Button("Дублировать") { vm.duplicateRoom(room) }
                Button("Удалить", role: .destructive) { vm.deleteRoom(room) }
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
            Spacer()
            Button("Удалить", role: .destructive) {
                vm.deleteOpening(opening)
            }
        }
        .font(.caption)
    }

    private func format1(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func validateRoomCreateInput() -> (area: Double, length: Double, width: Double, height: Double, manualWallAdjustment: Double)? {
        switch RoomCreateInputValidator.validate(
            area: area,
            length: length,
            width: width,
            height: height,
            wallAdjustment: wallAdjustment
        ) {
        case .success(let input):
            return (area: input.area,
                    length: input.length,
                    width: input.width,
                    height: input.height,
                    manualWallAdjustment: input.manualWallAdjustment)
        case .failure(let error):
            createRoomValidationMessage = error.messageText
            return nil
        }
    }
}

private struct RoomEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Room
    @State private var areaText: String
    @State private var lengthText: String
    @State private var widthText: String
    @State private var heightText: String
    @State private var adjustmentText: String
    @State private var roomTemplateIdText: String
    @State private var validationMessage: String?
    let onSave: (Room) -> String?

    init(room: Room, onSave: @escaping (Room) -> String?) {
        _draft = State(initialValue: room)
        let usesDimensions = room.length > 0 && room.width > 0
        _areaText = State(initialValue: usesDimensions ? "" : String(room.area))
        _lengthText = State(initialValue: usesDimensions ? String(room.length) : "")
        _widthText = State(initialValue: usesDimensions ? String(room.width) : "")
        _heightText = State(initialValue: String(room.height))
        _adjustmentText = State(initialValue: String(room.wallAreaManualAdjustment))
        _roomTemplateIdText = State(initialValue: room.roomTemplateId.map(String.init) ?? "")
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("Редактирование помещения").font(.headline)
            Group {
                TextField("Название", text: $draft.name)
                TextField("Тип", text: $draft.roomType)
                TextField("Состояние поверхности", text: $draft.surfaceCondition)
                TextField("Площадь", text: $areaText)
                TextField("Длина", text: $lengthText)
                TextField("Ширина", text: $widthText)
            }
            Group {
                TextField("Высота", text: $heightText)
                TextField("Корр. стен", text: $adjustmentText)
                TextField("Заметки", text: $draft.notes)
                TextField("Фото path", text: $draft.photoPath)
                TextField("RoomTemplate ID", text: $roomTemplateIdText)
            }
            HStack {
                Button("Отмена") { dismiss() }
                Button("Сохранить") {
                    guard applyValidatedTemplateId() else { return }
                    guard applyValidatedNumericInputs() else { return }
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

    private func applyValidatedTemplateId() -> Bool {
        let trimmed = roomTemplateIdText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            draft.roomTemplateId = nil
            validationMessage = nil
            return true
        }
        guard let parsed = Int64(trimmed) else {
            validationMessage = "RoomTemplate ID должен быть целым числом или пустым значением"
            return false
        }
        draft.roomTemplateId = parsed
        validationMessage = nil
        return true
    }

    private func applyValidatedNumericInputs() -> Bool {
        switch RoomCreateInputValidator.validate(
            area: areaText,
            length: lengthText,
            width: widthText,
            height: heightText,
            wallAdjustment: adjustmentText
        ) {
        case .success(let input):
            draft.area = input.area
            draft.length = input.length
            draft.width = input.width
            draft.height = input.height
            draft.wallAreaManualAdjustment = input.manualWallAdjustment
            validationMessage = nil
            return true
        case .failure(let error):
            validationMessage = error.messageText
            return false
        }
    }
}
#endif
