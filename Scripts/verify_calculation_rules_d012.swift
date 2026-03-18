import Foundation

@main
struct VerifyCalculationRulesD012 {
    private static func check(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
        if condition() {
            print("[PASS] \(message)")
            return true
        }
        print("[FAIL] \(message)")
        return false
    }

    private static func scenarioResult(rules: CalculationRules) -> CalculationResult {
        let calculator = EstimateCalculator()
        let room = Room(id: 1, projectId: 1, name: "Room 1", area: 10, height: 2.7)
        let surface = Surface(id: 1, roomId: 1, type: "wall", name: "Walls", area: 40, perimeter: 0, isCustom: false, source: "auto", manualAdjustment: 0)
        let work = WorkCatalogItem(
            id: 1,
            name: "Paint walls",
            unit: "м²",
            baseRatePerUnitHour: 0,
            basePrice: 0,
            swedishName: "Målning",
            sortOrder: 0,
            mediumSpeed: 0.05,
            additionalLaborHours: 0
        )
        let material = MaterialCatalogItem(id: 1, name: "Paint", unit: "l", basePrice: 100, swedishName: "Färg", sortOrder: 0, markupPercent: 0, usagePerWorkUnit: 0, isActive: true)
        let speed = SpeedProfile(id: 1, name: "Standard", coefficient: 0.01, daysDivider: 0, sortOrder: 0)

        return calculator.calculate(
            rooms: [room],
            surfacesByRoom: [room.id: [surface]],
            openingsByRoom: [:],
            selectedWorks: [room.id: [work]],
            selectedMaterials: [room.id: [material]],
            speed: speed,
            pricingMode: .fixed,
            laborRate: 100,
            overhead: 1,
            rules: rules
        )
    }

    static func main() {
        let baseline = scenarioResult(rules: .default)

        var failures = 0

        var tunedTransport = CalculationRules.default
        tunedTransport.transportPercent = 0.10
        let tunedTransportResult = scenarioResult(rules: tunedTransport)
        if !check(abs(tunedTransportResult.transportCost - baseline.transportCost) > 0.001, "transportPercent affects transportCost") { failures += 1 }

        var tunedEquipment = CalculationRules.default
        tunedEquipment.equipmentPercent = 0.20
        let tunedEquipmentResult = scenarioResult(rules: tunedEquipment)
        if !check(abs(tunedEquipmentResult.equipmentCost - baseline.equipmentCost) > 0.001, "equipmentPercent affects equipmentCost") { failures += 1 }

        var tunedWaste = CalculationRules.default
        tunedWaste.wastePercent = 0.30
        let tunedWasteResult = scenarioResult(rules: tunedWaste)
        if !check(abs(tunedWasteResult.wasteCost - baseline.wasteCost) > 0.001, "wastePercent affects wasteCost") { failures += 1 }

        var tunedMargin = CalculationRules.default
        tunedMargin.marginPercent = 0.40
        let tunedMarginResult = scenarioResult(rules: tunedMargin)
        if !check(abs(tunedMarginResult.margin - baseline.margin) > 0.001, "marginPercent affects margin") { failures += 1 }

        var tunedMoms = CalculationRules.default
        tunedMoms.momsPercent = 0.10
        let tunedMomsResult = scenarioResult(rules: tunedMoms)
        if !check(abs(tunedMomsResult.moms - baseline.moms) > 0.001, "momsPercent affects moms") { failures += 1 }

        var tunedMinSpeedRate = CalculationRules.default
        tunedMinSpeedRate.minSpeedRate = 0.5
        let tunedMinSpeedRateResult = scenarioResult(rules: tunedMinSpeedRate)
        if !check(abs(tunedMinSpeedRateResult.totalLabor - baseline.totalLabor) > 0.001, "minSpeedRate affects labor in low-speed scenario") { failures += 1 }

        var tunedMinWorkMediumSpeed = CalculationRules.default
        tunedMinWorkMediumSpeed.minWorkMediumSpeed = 5.0
        let tunedMinWorkMediumSpeedResult = scenarioResult(rules: tunedMinWorkMediumSpeed)
        if !check(abs(tunedMinWorkMediumSpeedResult.totalLabor - baseline.totalLabor) > 0.001, "minWorkMediumSpeed affects labor when configured threshold exceeds work.mediumSpeed") { failures += 1 }

        var tunedMinWorkBaseRate = CalculationRules.default
        tunedMinWorkBaseRate.minWorkBaseRatePerUnitHour = 0.5
        let tunedMinWorkBaseRateResult = scenarioResult(rules: tunedMinWorkBaseRate)
        if !check(abs(tunedMinWorkBaseRateResult.totalLabor - baseline.totalLabor) > 0.001, "minWorkBaseRatePerUnitHour affects labor when baseRatePerUnitHour is zero") { failures += 1 }

        var tunedMinDaysDivider = CalculationRules.default
        tunedMinDaysDivider.minSpeedDaysDivider = 1.0
        let tunedMinDaysDividerResult = scenarioResult(rules: tunedMinDaysDivider)
        if !check(abs(tunedMinDaysDividerResult.totalDays - baseline.totalDays) > 0.001, "minSpeedDaysDivider affects day estimate") { failures += 1 }

        var tunedMinMaterialUsage = CalculationRules.default
        tunedMinMaterialUsage.minMaterialUsagePerWorkUnit = 0.5
        let tunedMinMaterialUsageResult = scenarioResult(rules: tunedMinMaterialUsage)
        if !check(abs(tunedMinMaterialUsageResult.totalMaterials - baseline.totalMaterials) > 0.001, "minMaterialUsagePerWorkUnit affects material cost when usagePerWorkUnit is zero") { failures += 1 }

        var tunedMinMaterialQuantity = CalculationRules.default
        tunedMinMaterialQuantity.minMaterialQuantity = 10.0
        let tunedMinMaterialQuantityResult = scenarioResult(rules: tunedMinMaterialQuantity)
        if !check(abs(tunedMinMaterialQuantityResult.totalMaterials - baseline.totalMaterials) > 0.001, "minMaterialQuantity affects material cost floor") { failures += 1 }

        if !check(abs(tunedTransportResult.grandTotal - baseline.grandTotal) > 0.001, "grand total changes after rule tuning") { failures += 1 }

        print(String(format: "BASELINE_TOTAL=%.4f", baseline.grandTotal))
        print(String(format: "BASELINE_LABOR=%.4f", baseline.totalLabor))
        print(String(format: "BASELINE_MATERIALS=%.4f", baseline.totalMaterials))

        if failures == 0 {
            print("RESULT: PASS")
        } else {
            print("RESULT: FAIL (\(failures) checks failed)")
            Foundation.exit(1)
        }
    }
}
