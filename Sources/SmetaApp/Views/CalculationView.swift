#if canImport(SwiftUI)
import SwiftUI

struct CalculationView: View {
    @EnvironmentObject private var vm: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Расчёт").font(.largeTitle).bold()
            if let project = vm.selectedProject {
                Text("Проект: \(project.name)").font(.headline)
                HStack {
                    Picker("Скорость", selection: $vm.selectedSpeedId) {
                        ForEach(vm.speedProfiles) { Text($0.name).tag($0.id) }
                    }
                    Picker("Режим цены", selection: $vm.pricingMode) {
                        ForEach(PricingMode.allCases) { Text($0.rawValue).tag($0) }
                    }.frame(width: 180)
                    TextField("Ставка труда/ч", value: $vm.laborRatePerHour, format: .number)
                    TextField("Коэф.", value: $vm.overheadCoefficient, format: .number)
                    Button("Рассчитать") { vm.calculate() }
                }
                List(vm.rooms.filter { $0.projectId == project.id }) { room in
                    VStack(alignment: .leading) {
                        Text(room.name).bold()
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(vm.works) { work in
                                    Button(work.name) {
                                        vm.selectedWorksByRoom[room.id, default: []].append(work)
                                    }
                                }
                            }
                        }
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(vm.materials) { material in
                                    Button(material.name) {
                                        vm.selectedMaterialsByRoom[room.id, default: []].append(material)
                                    }
                                }
                            }
                        }
                    }
                }
                if let result = vm.calculationResult {
                    Table(result.rows) {
                        TableColumn("Помещение", value: \.roomName)
                        TableColumn("Позиция", value: \.itemName)
                        TableColumn("Объём") { Text(String(format: "%.2f", $0.quantity)) }
                        TableColumn("Скорость") { Text(String(format: "%.2f", $0.speedCoefficient)) }
                        TableColumn("Норма") { Text(String(format: "%.2f", $0.normHours)) }
                        TableColumn("Коэф") { Text(String(format: "%.2f", $0.coefficient)) }
                        TableColumn("Часы") { Text(String(format: "%.2f", $0.hours)) }
                        TableColumn("Дни") { Text(String(format: "%.2f", $0.days)) }
                        TableColumn("Труд") { Text(String(format: "%.2f", $0.laborCost)) }
                        TableColumn("Материалы") { Text(String(format: "%.2f", $0.materialCost)) }
                        TableColumn("Итог") { Text(String(format: "%.2f", $0.total)) }
                        TableColumn("Формула") { Text($0.formula).font(.caption) }
                    }
                    Group {
                        Text("Труд: \(result.totalLabor, specifier: "%.2f")")
                        Text("Материалы: \(result.totalMaterials, specifier: "%.2f")")
                        Text("Transport: \(result.transportCost, specifier: "%.2f") | Equipment: \(result.equipmentCost, specifier: "%.2f") | Waste: \(result.wasteCost, specifier: "%.2f")")
                        Text("Margin: \(result.margin, specifier: "%.2f") | Moms: \(result.moms, specifier: "%.2f")")
                        Text("Итого: \(result.grandTotal, specifier: "%.2f")").font(.title3).bold()
                    }
                }
            } else {
                Text("Выберите проект на вкладке 'Проекты'")
            }
        }
    }
}
#endif
