#if canImport(SwiftUI)
import SwiftUI

struct CalculationView: View {
    @EnvironmentObject private var vm: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleSection
            contentSection
        }
    }

    private var titleSection: some View {
        Text("Расчёт").font(.largeTitle).bold()
    }

    @ViewBuilder
    private var contentSection: some View {
        if let project = vm.selectedProject {
            Text("Проект: \(project.name)").font(.headline)
            controlsSection
            roomsSelectionList(projectId: project.id)
            resultSection
        } else {
            Text("Выберите проект на вкладке 'Проекты'")
        }
    }

    private var controlsSection: some View {
        HStack {
            Picker(
                "Скорость",
                selection: Binding(
                    get: { vm.selectedSpeedId },
                    set: { vm.setSelectedSpeedProfile($0) }
                )
            ) {
                ForEach(vm.speedProfiles) { Text($0.name).tag($0.id) }
            }
            Picker("Режим цены", selection: $vm.pricingMode) {
                ForEach(PricingMode.allCases) { Text($0.rawValue).tag($0) }
            }.frame(width: 180)
            TextField("Ставка труда/ч", value: $vm.laborRatePerHour, format: .number)
            TextField("Коэф.", value: $vm.overheadCoefficient, format: .number)
            Button("Рассчитать") { vm.calculate() }
                .accessibilityIdentifier("smoke.calculate.run")
                .disabled(SmokeRuntimeConfig.shouldDisableCalculationAction)
        }
    }

    private func roomsSelectionList(projectId: Int64) -> some View {
        List(vm.rooms.filter { $0.projectId == projectId }) { room in
            VStack(alignment: .leading) {
                Text(room.name).bold()
                worksChooser(roomId: room.id)
                materialsChooser(roomId: room.id)
            }
        }
    }

    private func worksChooser(roomId: Int64) -> some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(vm.works) { work in
                    Button(work.name) {
                        vm.selectedWorksByRoom[roomId, default: []].append(work)
                    }
                }
            }
        }
    }

    private func materialsChooser(roomId: Int64) -> some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(vm.materials) { material in
                    Button(material.name) {
                        vm.selectedMaterialsByRoom[roomId, default: []].append(material)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        if let result = vm.calculationResult {
            List {
                Section("Строки расчёта") {
                    ForEach(Array(result.rows.enumerated()), id: \.offset) { _, row in
                        calculationRow(row)
                    }
                }
            }
            calculationTotals(result)
        }
    }

    private func calculationRow(_ row: CalculationRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(row.roomName).bold()
                Text("•")
                Text(row.itemName)
            }
            HStack(spacing: 10) {
                Text("Объём: \(format2(row.quantity))")
                Text("Скорость: \(format2(row.speedCoefficient))")
                Text("Норма: \(format2(row.normHours))")
                Text("Коэф: \(format2(row.coefficient))")
            }
            .font(.caption)
            HStack(spacing: 10) {
                Text("Часы: \(format2(row.hours))")
                Text("Дни: \(format2(row.days))")
                Text("Труд: \(format2(row.laborCost))")
                Text("Материалы: \(format2(row.materialCost))")
                Text("Итог: \(format2(row.total))").bold()
            }
            .font(.caption)
            Text("Формула: \(row.formula)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func calculationTotals(_ result: CalculationResult) -> some View {
        Group {
            Text("Труд: \(result.totalLabor, specifier: "%.2f")")
            Text("Материалы: \(result.totalMaterials, specifier: "%.2f")")
            Text("Transport: \(result.transportCost, specifier: "%.2f") | Equipment: \(result.equipmentCost, specifier: "%.2f") | Waste: \(result.wasteCost, specifier: "%.2f")")
            Text("Margin: \(result.margin, specifier: "%.2f") | Moms: \(result.moms, specifier: "%.2f")")
            Text("Итого: \(result.grandTotal, specifier: "%.2f")").font(.title3).bold()
        }
    }

    private func format2(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
#endif
