import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var speedName = ""
    @State private var speedCoeff = 1.0
    @State private var speedDays = 7.0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Настройки").font(.largeTitle).bold()
            GroupBox("Скорости") {
                HStack {
                    TextField("Название", text: $speedName)
                    TextField("Коэффициент", value: $speedCoeff, format: .number)
                    TextField("Норма дней", value: $speedDays, format: .number)
                    Button("Добавить") { vm.addSpeed(SpeedProfile(id: 0, name: speedName, coefficient: speedCoeff, daysDivider: speedDays, sortOrder: vm.speedProfiles.count)) }
                }
                List(vm.speedProfiles) { s in
                    Text("\(s.name) / коэф. \(s.coefficient, specifier: "%.2f") / \(s.daysDivider, specifier: "%.2f") ч/д")
                }
            }
            HStack {
                Button("Backup базы") { vm.backupDatabase() }
                Button("Restore базы") { vm.restoreDatabase() }
            }
            Spacer()
        }
    }
}
