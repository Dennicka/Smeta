import Foundation

struct CalculationRow: Identifiable {
    let id = UUID()
    let roomId: Int64
    let workItemId: Int64?
    let materialItemId: Int64?
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
    let formula: String
}

struct CalculationResult {
    let rows: [CalculationRow]
    let totalHours: Double
    let totalDays: Double
    let totalLabor: Double
    let totalMaterials: Double
    let transportCost: Double
    let equipmentCost: Double
    let wasteCost: Double
    let margin: Double
    let moms: Double
    let grandTotal: Double
}

final class EstimateCalculator {
    func calculate(rooms: [Room],
                   surfacesByRoom: [Int64: [Surface]],
                   openingsByRoom: [Int64: [Opening]],
                   selectedWorks: [Int64: [WorkCatalogItem]],
                   selectedMaterials: [Int64: [MaterialCatalogItem]],
                   speed: SpeedProfile,
                   pricingMode: PricingMode,
                   laborRate: Double,
                   overhead: Double,
                   rules: CalculationRules) -> CalculationResult {
        var rows: [CalculationRow] = []

        for room in rooms {
            let roomSurfaces = surfacesByRoom[room.id, default: []]
            let roomOpenings = openingsByRoom[room.id, default: []]
            let openingSubtract = roomOpenings.filter(\.subtractFromWallArea).reduce(0) { $0 + $1.area }
            let wallArea = max(0, (roomSurfaces.first { $0.type == "wall" }?.effectiveArea ?? room.wallAreaTotal) - openingSubtract)

            for work in selectedWorks[room.id, default: []].filter(\.isActive) {
                let quantity: Double = work.unit.contains("м²") ? wallArea : room.area
                let speedRate = max(rules.minSpeedRate, speed.coefficient * max(work.mediumSpeed > 0 ? work.mediumSpeed : 1, rules.minWorkMediumSpeed))
                let norm = quantity * max(work.baseRatePerUnitHour, rules.minWorkBaseRatePerUnitHour)
                let coeff = overhead * work.complexityCoefficient * work.heightCoefficient * work.conditionCoefficient * work.urgencyCoefficient * work.accessibilityCoefficient
                let hours = (norm / speedRate) * coeff + work.additionalLaborHours
                let days = hours / max(speed.daysDivider, rules.minSpeedDaysDivider)
                let labor = pricingMode == .hourly ? hours * max(work.hourlyPrice, laborRate) : hours * laborRate
                let total = labor
                rows.append(CalculationRow(roomId: room.id,
                                           workItemId: work.id,
                                           materialItemId: nil,
                                           roomName: room.name,
                                           itemName: work.name,
                                           quantity: quantity,
                                           speedCoefficient: speedRate,
                                           normHours: norm,
                                           coefficient: coeff,
                                           hours: hours,
                                           days: days,
                                           laborCost: labor,
                                           materialCost: 0,
                                           total: total,
                                           formula: "(\(quantity)×\(work.baseRatePerUnitHour))/\(speedRate)×\(coeff)+\(work.additionalLaborHours)"))
            }

            for material in selectedMaterials[room.id, default: []].filter(\.isActive) {
                let quantity = max(rules.minMaterialQuantity, room.area * max(material.usagePerWorkUnit, rules.minMaterialUsagePerWorkUnit))
                let materialCost = quantity * (material.basePrice + material.basePrice * material.markupPercent / 100)
                rows.append(CalculationRow(roomId: room.id,
                                           workItemId: nil,
                                           materialItemId: material.id,
                                           roomName: room.name,
                                           itemName: material.name,
                                           quantity: quantity,
                                           speedCoefficient: speed.coefficient,
                                           normHours: 0,
                                           coefficient: 1,
                                           hours: 0,
                                           days: 0,
                                           laborCost: 0,
                                           materialCost: materialCost,
                                           total: materialCost,
                                           formula: "\(quantity)×\(material.basePrice)"))
            }
        }

        let hours = rows.reduce(0) { $0 + $1.hours }
        let days = rows.reduce(0) { $0 + $1.days }
        let labor = rows.reduce(0) { $0 + $1.laborCost }
        let materials = rows.reduce(0) { $0 + $1.materialCost }
        let transport = (labor + materials) * rules.transportPercent
        let equipment = labor * rules.equipmentPercent
        let waste = materials * rules.wastePercent
        let subtotal = labor + materials + transport + equipment + waste
        let margin = subtotal * rules.marginPercent
        let moms = (subtotal + margin) * rules.momsPercent
        return CalculationResult(rows: rows,
                                 totalHours: hours,
                                 totalDays: days,
                                 totalLabor: labor,
                                 totalMaterials: materials,
                                 transportCost: transport,
                                 equipmentCost: equipment,
                                 wasteCost: waste,
                                 margin: margin,
                                 moms: moms,
                                 grandTotal: subtotal + margin + moms)
    }
}
