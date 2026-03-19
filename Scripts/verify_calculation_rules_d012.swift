import Foundation

@main
struct VerifyCalculationRulesD012 {
    private static let tolerance = 1e-9

    private struct VerificationFailure: Error {
        let message: String
    }

    private static func assertApprox(_ actual: Double, _ expected: Double, _ label: String) throws {
        if abs(actual - expected) > tolerance {
            throw VerificationFailure(message: "\(label): expected \(expected), got \(actual)")
        }
        print(String(format: "[PASS] %@ (expected=%.6f, actual=%.6f)", label, expected, actual))
    }

    private static func assertTrue(_ condition: @autoclosure () -> Bool, _ label: String) throws {
        if !condition() {
            throw VerificationFailure(message: label)
        }
        print("[PASS] \(label)")
    }

    private static func makeRoom(id: Int64, area: Double, wallAuto: Double, wallAdjust: Double = 0) -> Room {
        Room(id: id,
             projectId: 77,
             name: "Room-\(id)",
             area: area,
             height: 2.7,
             wallAreaAuto: wallAuto,
             wallAreaManualAdjustment: wallAdjust)
    }

    private static func calculate(
        rooms: [Room],
        surfacesByRoom: [Int64: [Surface]],
        openingsByRoom: [Int64: [Opening]],
        selectedWorks: [Int64: [WorkCatalogItem]],
        selectedMaterials: [Int64: [MaterialCatalogItem]],
        speed: SpeedProfile,
        pricingMode: PricingMode,
        laborRate: Double,
        overhead: Double,
        rules: CalculationRules
    ) -> CalculationResult {
        EstimateCalculator().calculate(
            rooms: rooms,
            surfacesByRoom: surfacesByRoom,
            openingsByRoom: openingsByRoom,
            selectedWorks: selectedWorks,
            selectedMaterials: selectedMaterials,
            speed: speed,
            pricingMode: pricingMode,
            laborRate: laborRate,
            overhead: overhead,
            rules: rules
        )
    }

    private static func row(_ result: CalculationResult, workId: Int64? = nil, materialId: Int64? = nil) throws -> CalculationRow {
        guard let found = result.rows.first(where: { $0.workItemId == workId && $0.materialItemId == materialId }) else {
            throw VerificationFailure(message: "Missing row workId=\(String(describing: workId)) materialId=\(String(describing: materialId))")
        }
        return found
    }

    private static func verifyBaselineWorkScenario(rules: CalculationRules) throws {
        let room = makeRoom(id: 1, area: 40, wallAuto: 100)
        let wall = Surface(id: 1, roomId: room.id, type: "wall", name: "wall", area: 100, perimeter: 0, isCustom: false, source: "auto", manualAdjustment: 0)
        let work = WorkCatalogItem(id: 501, name: "Paint", unit: "м²", baseRatePerUnitHour: 0.5, basePrice: 0, swedishName: "", sortOrder: 0, mediumSpeed: 1.2, additionalLaborHours: 2)
        let speed = SpeedProfile(id: 1, name: "standard", coefficient: 1.0, daysDivider: 8, sortOrder: 0)
        let result = calculate(rooms: [room],
                               surfacesByRoom: [room.id: [wall]],
                               openingsByRoom: [:],
                               selectedWorks: [room.id: [work]],
                               selectedMaterials: [:],
                               speed: speed,
                               pricingMode: .fixed,
                               laborRate: 500,
                               overhead: 1,
                               rules: rules)
        let workRow = try row(result, workId: work.id)

        try assertApprox(workRow.quantity, 100, "A.quantity from wall area")
        try assertApprox(workRow.normHours, 50, "A.norm hours")
        try assertApprox(workRow.hours, 43.666666666666664, "A.hours")
        try assertApprox(workRow.days, 5.458333333333333, "A.days")
        try assertApprox(workRow.laborCost, 21833.333333333332, "A.laborCost")
        try assertApprox(workRow.total, workRow.laborCost, "A.total equals labor")
        try assertTrue(result.rows.count == 1, "A.row appears in result")
    }

    private static func verifyOpeningsSubtractionAndFloor(rules: CalculationRules) throws {
        let room = makeRoom(id: 2, area: 40, wallAuto: 50)
        let wall = Surface(id: 2, roomId: room.id, type: "wall", name: "wall", area: 50, perimeter: 0, isCustom: false, source: "auto", manualAdjustment: 0)
        let work = WorkCatalogItem(id: 502, name: "Primer", unit: "м²", baseRatePerUnitHour: 1, basePrice: 0, swedishName: "", sortOrder: 0, mediumSpeed: 1, additionalLaborHours: 0)
        let speed = SpeedProfile(id: 2, name: "std", coefficient: 1, daysDivider: 8, sortOrder: 0)

        let subtractingOpenings = [
            Opening(id: 1, roomId: room.id, surfaceId: wall.id, type: "window", name: "w", width: 2, height: 5, count: 3, subtractFromWallArea: true),
            Opening(id: 2, roomId: room.id, surfaceId: wall.id, type: "door", name: "d", width: 1, height: 2, count: 1, subtractFromWallArea: false)
        ]
        let result = calculate(rooms: [room],
                               surfacesByRoom: [room.id: [wall]],
                               openingsByRoom: [room.id: subtractingOpenings],
                               selectedWorks: [room.id: [work]],
                               selectedMaterials: [:],
                               speed: speed,
                               pricingMode: .fixed,
                               laborRate: 500,
                               overhead: 1,
                               rules: rules)
        let workRow = try row(result, workId: work.id)
        try assertApprox(workRow.quantity, 20, "B.openings subtract only subtractFromWallArea=true")

        let hugeOpenings = [
            Opening(id: 3, roomId: room.id, surfaceId: wall.id, type: "window", name: "huge", width: 10, height: 10, count: 1, subtractFromWallArea: true)
        ]
        let resultHuge = calculate(rooms: [room],
                                   surfacesByRoom: [room.id: [wall]],
                                   openingsByRoom: [room.id: hugeOpenings],
                                   selectedWorks: [room.id: [work]],
                                   selectedMaterials: [:],
                                   speed: speed,
                                   pricingMode: .fixed,
                                   laborRate: 500,
                                   overhead: 1,
                                   rules: rules)
        let hugeRow = try row(resultHuge, workId: work.id)
        try assertApprox(hugeRow.quantity, 0, "B.max(0, wallArea - openings)")
    }

    private static func verifyNonSquareUnitUsesRoomArea(rules: CalculationRules) throws {
        let room = makeRoom(id: 3, area: 12, wallAuto: 90)
        let wall = Surface(id: 3, roomId: room.id, type: "wall", name: "wall", area: 90, perimeter: 0, isCustom: false, source: "auto", manualAdjustment: 0)
        let work = WorkCatalogItem(id: 503, name: "Floor prep", unit: "шт", baseRatePerUnitHour: 1, basePrice: 0, swedishName: "", sortOrder: 0, mediumSpeed: 1, additionalLaborHours: 0)
        let speed = SpeedProfile(id: 3, name: "std", coefficient: 1, daysDivider: 8, sortOrder: 0)
        let result = calculate(rooms: [room],
                               surfacesByRoom: [room.id: [wall]],
                               openingsByRoom: [:],
                               selectedWorks: [room.id: [work]],
                               selectedMaterials: [:],
                               speed: speed,
                               pricingMode: .fixed,
                               laborRate: 500,
                               overhead: 1,
                               rules: rules)
        let row = try row(result, workId: work.id)
        try assertApprox(row.quantity, 12, "C.non-м² quantity uses room.area")
    }

    private static func verifySpeedAndBaseRateGuardsWithCoefficients(rules: CalculationRules) throws {
        let room = makeRoom(id: 4, area: 10, wallAuto: 30)
        let wall = Surface(id: 4, roomId: room.id, type: "wall", name: "wall", area: 30, perimeter: 0, isCustom: false, source: "auto", manualAdjustment: 0)
        let work = WorkCatalogItem(id: 504,
                                   name: "Guarded",
                                   unit: "м²",
                                   baseRatePerUnitHour: 0,
                                   basePrice: 0,
                                   swedishName: "",
                                   sortOrder: 0,
                                   mediumSpeed: 0,
                                   complexityCoefficient: 1.2,
                                   heightCoefficient: 1.1,
                                   conditionCoefficient: 1.3,
                                   urgencyCoefficient: 1.4,
                                   accessibilityCoefficient: 1.5,
                                   additionalLaborHours: 2)
        let speed = SpeedProfile(id: 4, name: "low", coefficient: 0, daysDivider: 0, sortOrder: 0)

        var guardedRules = rules
        guardedRules.minSpeedRate = 0.2
        guardedRules.minWorkMediumSpeed = 2
        guardedRules.minWorkBaseRatePerUnitHour = 0.5
        guardedRules.minSpeedDaysDivider = 5

        let result = calculate(rooms: [room],
                               surfacesByRoom: [room.id: [wall]],
                               openingsByRoom: [:],
                               selectedWorks: [room.id: [work]],
                               selectedMaterials: [:],
                               speed: speed,
                               pricingMode: .fixed,
                               laborRate: 100,
                               overhead: 1.1,
                               rules: guardedRules)
        let row = try row(result, workId: work.id)

        let expectedCoefficient = 1.1 * 1.2 * 1.1 * 1.3 * 1.4 * 1.5
        try assertApprox(row.speedCoefficient, 0.2, "D.minSpeedRate guard")
        try assertApprox(row.normHours, 15, "D.minWorkBaseRatePerUnitHour guard")
        try assertApprox(row.coefficient, expectedCoefficient, "E.combined coefficients include overhead")
        try assertApprox(row.hours, 299.297, "E.coefficients + additional labor feed hours")
        try assertApprox(row.days, 59.8594, "D.minSpeedDaysDivider guard")
    }

    private static func verifyMinWorkMediumSpeedGuard(rules: CalculationRules) throws {
        let room = makeRoom(id: 41, area: 20, wallAuto: 20)
        let wall = Surface(id: 41, roomId: room.id, type: "wall", name: "wall", area: 20, perimeter: 0, isCustom: false, source: "auto", manualAdjustment: 0)
        let work = WorkCatalogItem(id: 541, name: "Medium speed guard", unit: "м²", baseRatePerUnitHour: 1, basePrice: 0, swedishName: "", sortOrder: 0, mediumSpeed: 0.4, additionalLaborHours: 0)
        let speed = SpeedProfile(id: 41, name: "fast", coefficient: 2, daysDivider: 8, sortOrder: 0)

        var guardedRules = rules
        guardedRules.minSpeedRate = 0.2
        guardedRules.minWorkMediumSpeed = 1.5

        var unguardedRules = rules
        unguardedRules.minSpeedRate = 0.2
        unguardedRules.minWorkMediumSpeed = 0.1

        let guarded = calculate(rooms: [room],
                                surfacesByRoom: [room.id: [wall]],
                                openingsByRoom: [:],
                                selectedWorks: [room.id: [work]],
                                selectedMaterials: [:],
                                speed: speed,
                                pricingMode: .fixed,
                                laborRate: 500,
                                overhead: 1,
                                rules: guardedRules)
        let unguarded = calculate(rooms: [room],
                                  surfacesByRoom: [room.id: [wall]],
                                  openingsByRoom: [:],
                                  selectedWorks: [room.id: [work]],
                                  selectedMaterials: [:],
                                  speed: speed,
                                  pricingMode: .fixed,
                                  laborRate: 500,
                                  overhead: 1,
                                  rules: unguardedRules)

        let guardedRow = try row(guarded, workId: work.id)
        let unguardedRow = try row(unguarded, workId: work.id)

        try assertApprox(guardedRow.speedCoefficient, 3.0, "D.minWorkMediumSpeed guard sets speedRate from minWorkMediumSpeed")
        try assertApprox(unguardedRow.speedCoefficient, 0.8, "D.control without minWorkMediumSpeed guard")
        try assertTrue(abs(guardedRow.speedCoefficient - unguardedRow.speedCoefficient) > 0.001,
                       "D.minWorkMediumSpeed changes speedRate independently of minSpeedRate")
    }

    private static func verifyPricingModes(rules: CalculationRules) throws {
        let room = makeRoom(id: 5, area: 20, wallAuto: 20)
        let wall = Surface(id: 5, roomId: room.id, type: "wall", name: "wall", area: 20, perimeter: 0, isCustom: false, source: "auto", manualAdjustment: 0)
        let work = WorkCatalogItem(id: 505, name: "Pricing", unit: "м²", baseRatePerUnitHour: 1, basePrice: 0, swedishName: "", sortOrder: 0, hourlyPrice: 700, mediumSpeed: 1, additionalLaborHours: 0)
        let speed = SpeedProfile(id: 5, name: "std", coefficient: 1, daysDivider: 8, sortOrder: 0)

        let fixed = calculate(rooms: [room],
                              surfacesByRoom: [room.id: [wall]],
                              openingsByRoom: [:],
                              selectedWorks: [room.id: [work]],
                              selectedMaterials: [:],
                              speed: speed,
                              pricingMode: .fixed,
                              laborRate: 500,
                              overhead: 1,
                              rules: rules)
        let hourly = calculate(rooms: [room],
                               surfacesByRoom: [room.id: [wall]],
                               openingsByRoom: [:],
                               selectedWorks: [room.id: [work]],
                               selectedMaterials: [:],
                               speed: speed,
                               pricingMode: .hourly,
                               laborRate: 500,
                               overhead: 1,
                               rules: rules)
        let fixedRow = try row(fixed, workId: work.id)
        let hourlyRow = try row(hourly, workId: work.id)

        try assertApprox(fixedRow.laborCost, 10000, "F.fixed/estimated path uses laborRate")
        try assertApprox(hourlyRow.laborCost, 14000, "F.hourly path uses max(work.hourlyPrice, laborRate)")
        try assertTrue(hourlyRow.laborCost > fixedRow.laborCost, "F.non-hourly and hourly paths are distinct")
    }

    private static func verifyMaterialUsageGuard(rules: CalculationRules) throws {
        let room = makeRoom(id: 6, area: 25, wallAuto: 25)
        let material = MaterialCatalogItem(id: 601, name: "Paint", unit: "l", basePrice: 100, swedishName: "", sortOrder: 0, markupPercent: 20, usagePerWorkUnit: 0)

        var usageGuardRules = rules
        usageGuardRules.minMaterialUsagePerWorkUnit = 0.4
        usageGuardRules.minMaterialQuantity = 0.5

        var controlRules = rules
        controlRules.minMaterialUsagePerWorkUnit = 0.05
        controlRules.minMaterialQuantity = 0.5

        let guarded = calculate(rooms: [room],
                                surfacesByRoom: [:],
                                openingsByRoom: [:],
                                selectedWorks: [:],
                                selectedMaterials: [room.id: [material]],
                                speed: SpeedProfile(id: 6, name: "std", coefficient: 1, daysDivider: 8, sortOrder: 0),
                                pricingMode: .fixed,
                                laborRate: 500,
                                overhead: 1,
                                rules: usageGuardRules)
        let control = calculate(rooms: [room],
                                surfacesByRoom: [:],
                                openingsByRoom: [:],
                                selectedWorks: [:],
                                selectedMaterials: [room.id: [material]],
                                speed: SpeedProfile(id: 61, name: "std", coefficient: 1, daysDivider: 8, sortOrder: 0),
                                pricingMode: .fixed,
                                laborRate: 500,
                                overhead: 1,
                                rules: controlRules)
        let guardedRow = try row(guarded, materialId: material.id)
        let controlRow = try row(control, materialId: material.id)

        try assertApprox(guardedRow.quantity, 10, "G.minMaterialUsagePerWorkUnit guard drives quantity")
        try assertApprox(guardedRow.materialCost, 1200, "G.materialCost reflects usage guard quantity")
        try assertApprox(controlRow.quantity, 1.25, "G.control without usage guard")
        try assertTrue(abs(guardedRow.quantity - controlRow.quantity) > 0.001,
                       "G.minMaterialUsagePerWorkUnit changes quantity independently of minMaterialQuantity")
    }

    private static func verifyMaterialQuantityGuard(rules: CalculationRules) throws {
        let room = makeRoom(id: 62, area: 10, wallAuto: 10)
        let material = MaterialCatalogItem(id: 602, name: "Primer", unit: "l", basePrice: 80, swedishName: "", sortOrder: 0, markupPercent: 10, usagePerWorkUnit: 0.1)

        var floorRules = rules
        floorRules.minMaterialUsagePerWorkUnit = 0.1
        floorRules.minMaterialQuantity = 12

        var controlRules = rules
        controlRules.minMaterialUsagePerWorkUnit = 0.1
        controlRules.minMaterialQuantity = 0.5

        let floored = calculate(rooms: [room],
                                surfacesByRoom: [:],
                                openingsByRoom: [:],
                                selectedWorks: [:],
                                selectedMaterials: [room.id: [material]],
                                speed: SpeedProfile(id: 62, name: "std", coefficient: 1, daysDivider: 8, sortOrder: 0),
                                pricingMode: .fixed,
                                laborRate: 500,
                                overhead: 1,
                                rules: floorRules)
        let control = calculate(rooms: [room],
                                surfacesByRoom: [:],
                                openingsByRoom: [:],
                                selectedWorks: [:],
                                selectedMaterials: [room.id: [material]],
                                speed: SpeedProfile(id: 63, name: "std", coefficient: 1, daysDivider: 8, sortOrder: 0),
                                pricingMode: .fixed,
                                laborRate: 500,
                                overhead: 1,
                                rules: controlRules)
        let flooredRow = try row(floored, materialId: material.id)
        let controlRow = try row(control, materialId: material.id)

        try assertApprox(flooredRow.quantity, 12, "G.minMaterialQuantity guard")
        try assertApprox(flooredRow.materialCost, 1056, "G.materialCost reflects quantity floor")
        try assertApprox(controlRow.quantity, 1, "G.control without minMaterialQuantity floor")
        try assertTrue(abs(flooredRow.quantity - controlRow.quantity) > 0.001,
                       "G.minMaterialQuantity changes quantity independently of usage guard")
        try assertTrue(floored.rows.count == 1, "G.material row appears in result")
    }

    private static func verifyInactiveFiltering(rules: CalculationRules) throws {
        let room = makeRoom(id: 7, area: 10, wallAuto: 10)
        let work = WorkCatalogItem(id: 701, name: "inactive work", unit: "м²", baseRatePerUnitHour: 1, basePrice: 0, swedishName: "", sortOrder: 0, isActive: false, mediumSpeed: 1)
        let material = MaterialCatalogItem(id: 702, name: "inactive mat", unit: "kg", basePrice: 100, swedishName: "", sortOrder: 0, usagePerWorkUnit: 1, isActive: false)

        let result = calculate(rooms: [room],
                               surfacesByRoom: [:],
                               openingsByRoom: [:],
                               selectedWorks: [room.id: [work]],
                               selectedMaterials: [room.id: [material]],
                               speed: SpeedProfile(id: 7, name: "std", coefficient: 1, daysDivider: 8, sortOrder: 0),
                               pricingMode: .fixed,
                               laborRate: 500,
                               overhead: 1,
                               rules: rules)

        try assertTrue(result.rows.isEmpty, "I.inactive work/material are filtered from rows")
        try assertApprox(result.totalLabor, 0, "I.inactive filtering keeps labor at zero")
        try assertApprox(result.totalMaterials, 0, "I.inactive filtering keeps materials at zero")
    }

    private static func verifyMixedScenarioAndAggregates(rules: CalculationRules) throws {
        let roomA = makeRoom(id: 8, area: 30, wallAuto: 90)
        let roomB = makeRoom(id: 9, area: 18, wallAuto: 55)

        let wallsA = Surface(id: 801, roomId: roomA.id, type: "wall", name: "A", area: 80, perimeter: 0, isCustom: false, source: "auto", manualAdjustment: 10)
        let wallsB = Surface(id: 802, roomId: roomB.id, type: "wall", name: "B", area: 60, perimeter: 0, isCustom: false, source: "auto", manualAdjustment: -5)
        let openingsA = Opening(id: 803, roomId: roomA.id, surfaceId: wallsA.id, type: "window", name: "A1", width: 1, height: 2, count: 3, subtractFromWallArea: true)
        let openingsB = Opening(id: 804, roomId: roomB.id, surfaceId: wallsB.id, type: "door", name: "B1", width: 1, height: 2, count: 1, subtractFromWallArea: false)

        let workA = WorkCatalogItem(id: 805, name: "Walls", unit: "м²", baseRatePerUnitHour: 0.8, basePrice: 0, swedishName: "", sortOrder: 0, mediumSpeed: 1.1, complexityCoefficient: 1.05, additionalLaborHours: 1)
        let workB = WorkCatalogItem(id: 806, name: "Floor", unit: "шт", baseRatePerUnitHour: 1.2, basePrice: 0, swedishName: "", sortOrder: 0, mediumSpeed: 1.3, heightCoefficient: 1.02, additionalLaborHours: 0.5)

        let materialA = MaterialCatalogItem(id: 807, name: "Paint", unit: "l", basePrice: 120, swedishName: "", sortOrder: 0, markupPercent: 15, usagePerWorkUnit: 0.35)
        let materialB = MaterialCatalogItem(id: 808, name: "Primer", unit: "l", basePrice: 80, swedishName: "", sortOrder: 0, markupPercent: 10, usagePerWorkUnit: 0.2)

        let speed = SpeedProfile(id: 809, name: "mixed", coefficient: 0.9, daysDivider: 7, sortOrder: 0)

        let result = calculate(rooms: [roomA, roomB],
                               surfacesByRoom: [roomA.id: [wallsA], roomB.id: [wallsB]],
                               openingsByRoom: [roomA.id: [openingsA], roomB.id: [openingsB]],
                               selectedWorks: [roomA.id: [workA], roomB.id: [workB]],
                               selectedMaterials: [roomA.id: [materialA], roomB.id: [materialB]],
                               speed: speed,
                               pricingMode: .hourly,
                               laborRate: 550,
                               overhead: 1.08,
                               rules: rules)

        try assertTrue(result.rows.count == 4, "J.mixed scenario returns work+material rows across rooms")

        let sumHours = result.rows.reduce(0) { $0 + $1.hours }
        let sumDays = result.rows.reduce(0) { $0 + $1.days }
        let sumLabor = result.rows.reduce(0) { $0 + $1.laborCost }
        let sumMaterials = result.rows.reduce(0) { $0 + $1.materialCost }

        try assertApprox(result.totalHours, sumHours, "H.totalHours aggregate")
        try assertApprox(result.totalDays, sumDays, "H.totalDays aggregate")
        try assertApprox(result.totalLabor, sumLabor, "H.totalLabor aggregate")
        try assertApprox(result.totalMaterials, sumMaterials, "H.totalMaterials aggregate")

        let expectedTransport = (result.totalLabor + result.totalMaterials) * rules.transportPercent
        let expectedEquipment = result.totalLabor * rules.equipmentPercent
        let expectedWaste = result.totalMaterials * rules.wastePercent
        let subtotal = result.totalLabor + result.totalMaterials + expectedTransport + expectedEquipment + expectedWaste
        let expectedMargin = subtotal * rules.marginPercent
        let expectedMoms = (subtotal + expectedMargin) * rules.momsPercent
        let expectedGrandTotal = subtotal + expectedMargin + expectedMoms

        try assertApprox(result.transportCost, expectedTransport, "H.transportCost aggregate")
        try assertApprox(result.equipmentCost, expectedEquipment, "H.equipmentCost aggregate")
        try assertApprox(result.wasteCost, expectedWaste, "H.wasteCost aggregate")
        try assertApprox(result.margin, expectedMargin, "H.margin aggregate")
        try assertApprox(result.moms, expectedMoms, "H.moms aggregate")
        try assertApprox(result.grandTotal, expectedGrandTotal, "H.grandTotal aggregate")
    }

    static func main() {
        var failures: [String] = []
        let rules = CalculationRules.default

        let scenarios: [(String, () throws -> Void)] = [
            ("A.baseline work", { try verifyBaselineWorkScenario(rules: rules) }),
            ("B.openings subtraction", { try verifyOpeningsSubtractionAndFloor(rules: rules) }),
            ("C.non-square-unit", { try verifyNonSquareUnitUsesRoomArea(rules: rules) }),
            ("D+E.speed/base/days guards + coefficients", { try verifySpeedAndBaseRateGuardsWithCoefficients(rules: rules) }),
            ("D.minWorkMediumSpeed guard", { try verifyMinWorkMediumSpeedGuard(rules: rules) }),
            ("F.pricing modes", { try verifyPricingModes(rules: rules) }),
            ("G.material usage guard", { try verifyMaterialUsageGuard(rules: rules) }),
            ("G.material quantity guard", { try verifyMaterialQuantityGuard(rules: rules) }),
            ("I.inactive filtering", { try verifyInactiveFiltering(rules: rules) }),
            ("H+J.aggregates + mixed scenario", { try verifyMixedScenarioAndAggregates(rules: rules) })
        ]

        for (name, scenario) in scenarios {
            do {
                print("--- Running \(name) ---")
                try scenario()
            } catch let error as VerificationFailure {
                let message = "[FAIL] \(name): \(error.message)"
                failures.append(message)
                print(message)
            } catch {
                let message = "[FAIL] \(name): \(error)"
                failures.append(message)
                print(message)
            }
        }

        if failures.isEmpty {
            print("RESULT: PASS")
        } else {
            print("RESULT: FAIL (\(failures.count) scenarios failed)")
            Foundation.exit(1)
        }
    }
}
