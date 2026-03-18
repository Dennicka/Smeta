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

    static func main() {
        let calculator = EstimateCalculator()
        let room = Room(id: 1, projectId: 1, name: "Room 1", area: 10, height: 2.7)
        let surface = Surface(id: 1, roomId: 1, type: "wall", name: "Walls", area: 40, perimeter: 0, isCustom: false, source: "auto", manualAdjustment: 0)
        let work = WorkCatalogItem(id: 1, name: "Paint walls", unit: "м²", baseRatePerUnitHour: 1, basePrice: 0, swedishName: "Målning", sortOrder: 0)
        let material = MaterialCatalogItem(id: 1, name: "Paint", unit: "l", basePrice: 100, swedishName: "Färg", sortOrder: 0, markupPercent: 0, usagePerWorkUnit: 1, isActive: true)
        let speed = SpeedProfile(id: 1, name: "Standard", coefficient: 1, daysDivider: 8, sortOrder: 0)

        let baseline = calculator.calculate(
            rooms: [room],
            surfacesByRoom: [room.id: [surface]],
            openingsByRoom: [:],
            selectedWorks: [room.id: [work]],
            selectedMaterials: [room.id: [material]],
            speed: speed,
            pricingMode: .fixed,
            laborRate: 100,
            overhead: 1,
            rules: .default
        )

        var tunedRules = CalculationRules.default
        tunedRules.id = 1
        tunedRules.transportPercent = 0.10
        tunedRules.equipmentPercent = 0.15
        tunedRules.wastePercent = 0.20
        tunedRules.marginPercent = 0.30
        tunedRules.momsPercent = 0.10

        let tuned = calculator.calculate(
            rooms: [room],
            surfacesByRoom: [room.id: [surface]],
            openingsByRoom: [:],
            selectedWorks: [room.id: [work]],
            selectedMaterials: [room.id: [material]],
            speed: speed,
            pricingMode: .fixed,
            laborRate: 100,
            overhead: 1,
            rules: tunedRules
        )

        var failures = 0
        if !check(abs(baseline.transportCost - 100) < 0.001, "baseline transport uses default 2% rule") { failures += 1 }
        if !check(abs(baseline.equipmentCost - 120) < 0.001, "baseline equipment uses default 3% rule") { failures += 1 }
        if !check(abs(baseline.wasteCost - 40) < 0.001, "baseline waste uses default 4% rule") { failures += 1 }
        if !check(abs(baseline.margin - 631.2) < 0.001, "baseline margin uses default 12% rule") { failures += 1 }
        if !check(abs(baseline.moms - 1472.8) < 0.001, "baseline moms uses default 25% rule") { failures += 1 }
        if !check(abs(baseline.grandTotal - 7364) < 0.001, "baseline grand total is stable") { failures += 1 }

        if !check(abs(tuned.transportCost - 500) < 0.001, "tuned transport uses new 10% rule") { failures += 1 }
        if !check(abs(tuned.equipmentCost - 600) < 0.001, "tuned equipment uses new 15% rule") { failures += 1 }
        if !check(abs(tuned.wasteCost - 200) < 0.001, "tuned waste uses new 20% rule") { failures += 1 }
        if !check(abs(tuned.margin - 1890) < 0.001, "tuned margin uses new 30% rule") { failures += 1 }
        if !check(abs(tuned.moms - 819) < 0.001, "tuned moms uses new 10% rule") { failures += 1 }
        if !check(abs(tuned.grandTotal - 9009) < 0.001, "tuned grand total changed after rule update") { failures += 1 }
        if !check(abs(tuned.grandTotal - baseline.grandTotal) > 0.001, "grand total differs between default and tuned rules") { failures += 1 }

        print(String(format: "BASELINE_TOTAL=%.2f", baseline.grandTotal))
        print(String(format: "BASELINE_TRANSPORT=%.2f", baseline.transportCost))
        print(String(format: "TUNED_TOTAL=%.2f", tuned.grandTotal))
        print(String(format: "TUNED_TRANSPORT=%.2f", tuned.transportCost))

        if failures == 0 {
            print("RESULT: PASS")
        } else {
            print("RESULT: FAIL (\(failures) checks failed)")
            Foundation.exit(1)
        }
    }
}
