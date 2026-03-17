import Foundation

struct CalculationRow: Identifiable {
    let id = UUID()
    let roomName: String
    let itemName: String
    let quantity: Double
    let speedCoefficient: Double
    let normHours: Double
    let coefficient: Double
    let hours: Double
    let days: Double
    let laborCost: Double
    let materialCost: Double
    let total: Double
}

struct CalculationResult {
    let rows: [CalculationRow]
    let totalHours: Double
    let totalDays: Double
    let totalLabor: Double
    let totalMaterials: Double
    let grandTotal: Double
}

final class EstimateCalculator {
    func calculate(rooms: [Room],
                   selectedWorks: [Int64: [WorkCatalogItem]],
                   selectedMaterials: [Int64: [MaterialCatalogItem]],
                   speed: SpeedProfile,
                   laborRate: Double,
                   overhead: Double) -> CalculationResult {
        var rows: [CalculationRow] = []

        for room in rooms {
            for work in selectedWorks[room.id, default: []] {
                let quantity = room.area
                let norm = quantity * work.baseRatePerUnitHour
                let hours = norm * speed.coefficient * overhead
                let days = hours / max(speed.daysDivider, 0.1)
                let labor = hours * laborRate
                let total = labor
                rows.append(CalculationRow(roomName: room.name, itemName: work.name, quantity: quantity, speedCoefficient: speed.coefficient, normHours: norm, coefficient: overhead, hours: hours, days: days, laborCost: labor, materialCost: 0, total: total))
            }

            for material in selectedMaterials[room.id, default: []] {
                let quantity = room.area * 0.2
                let materialCost = quantity * material.basePrice
                rows.append(CalculationRow(roomName: room.name, itemName: material.name, quantity: quantity, speedCoefficient: speed.coefficient, normHours: 0, coefficient: overhead, hours: 0, days: 0, laborCost: 0, materialCost: materialCost, total: materialCost))
            }
        }

        let hours = rows.reduce(0) { $0 + $1.hours }
        let days = rows.reduce(0) { $0 + $1.days }
        let labor = rows.reduce(0) { $0 + $1.laborCost }
        let materials = rows.reduce(0) { $0 + $1.materialCost }
        return CalculationResult(rows: rows, totalHours: hours, totalDays: days, totalLabor: labor, totalMaterials: materials, grandTotal: labor + materials)
    }
}
