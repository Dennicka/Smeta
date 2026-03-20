#if canImport(SwiftUI)
import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var speedName = ""
    @State private var speedCoeff = 1.0
    @State private var speedDays = 7.0
    @State private var createSpeedError: String?
    @State private var editingSpeed: SpeedProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Настройки").font(.largeTitle).bold()
            GroupBox("Скорости") {
                HStack {
                    TextField("Название", text: $speedName)
                    TextField("Коэффициент", value: $speedCoeff, format: .number)
                    TextField("Норма дней", value: $speedDays, format: .number)
                    Button("Добавить") {
                        guard vm.addSpeed(SpeedProfile(id: 0, name: speedName, coefficient: speedCoeff, daysDivider: speedDays, sortOrder: vm.speedProfiles.count)) else {
                            createSpeedError = vm.errorMessage ?? "Не удалось добавить профиль скорости"
                            return
                        }
                        speedName = ""
                        speedCoeff = 1.0
                        speedDays = 7.0
                        createSpeedError = nil
                    }
                }
                if let createSpeedError {
                    Text(createSpeedError).foregroundStyle(.red).font(.caption)
                }
                List(vm.speedProfiles) { s in
                    HStack {
                        Text("\(s.name) / коэф. \(s.coefficient, specifier: "%.2f") / \(s.daysDivider, specifier: "%.2f") ч/д")
                        Spacer()
                        Button("Редактировать") { editingSpeed = s }
                        Button("Удалить", role: .destructive) {
                            vm.deleteSpeed(s)
                        }
                    }
                }
            }

            GroupBox("Данные и backup") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Папка данных:")
                    Text(vm.dataLocationPath())
                        .font(.callout)
                        .textSelection(.enabled)
                    HStack {
                        Button("Открыть папку") {
                            NSWorkspace.shared.open(URL(fileURLWithPath: vm.dataLocationPath()))
                        }
                        Button("Backup базы") { vm.backupDatabase() }
                        Button("Restore базы") { vm.restoreDatabase() }
                        Button("Reset demo") { vm.resetDemoData() }
                        Button("Clear export artifacts") { vm.clearTempExports() }
                    }
                }
            }
            Spacer()
        }
        .sheet(item: $editingSpeed) { speed in
            SpeedEditSheet(speed: speed) { updated in
                vm.updateSpeed(updated) ? nil : (vm.errorMessage ?? "Не удалось обновить профиль скорости")
            }
        }
    }
}

private struct SpeedEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SpeedProfile
    @State private var validationMessage: String?
    let onSave: (SpeedProfile) -> String?

    init(speed: SpeedProfile, onSave: @escaping (SpeedProfile) -> String?) {
        _draft = State(initialValue: speed)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("Редактирование скорости").font(.headline)
            TextField("Название", text: $draft.name)
            TextField("Коэффициент", value: $draft.coefficient, format: .number)
            TextField("Норма дней", value: $draft.daysDivider, format: .number)
            TextField("Порядок", value: $draft.sortOrder, format: .number)
            HStack {
                Button("Отмена") { dismiss() }
                Button("Сохранить") {
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
        .frame(minWidth: 380)
    }
}
#endif
