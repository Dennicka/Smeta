import XCTest
@testable import SmetaApp

final class EstimateCalculatorOracleTests: XCTestCase {
    private let calculator = EstimateCalculator()

    func testSingleRoomSingleWorkAndMaterialHappyPathUsesExactOracleValues() {
        let room = Room(id: 1, projectId: 1, name: "Room A", area: 10, height: 2.7, wallAreaAuto: 18)
        let surfacesByRoom: [Int64: [Surface]] = [
            room.id: [Surface(id: 10, roomId: room.id, type: "wall", name: "Wall", area: 20, perimeter: 0, isCustom: false, source: "auto", manualAdjustment: 0)]
        ]
        let openingsByRoom: [Int64: [Opening]] = [
            room.id: [Opening(id: 20, roomId: room.id, surfaceId: nil, type: "window", name: "Window", width: 1, height: 1, count: 2, subtractFromWallArea: true)]
        ]

        let work = WorkCatalogItem(
            id: 101,
            name: "Painting",
            unit: "м²",
            baseRatePerUnitHour: 0.5,
            basePrice: 0,
            swedishName: "",
            sortOrder: 0,
            mediumSpeed: 3,
            complexityCoefficient: 1,
            heightCoefficient: 1,
            conditionCoefficient: 1,
            urgencyCoefficient: 1,
            accessibilityCoefficient: 1,
            additionalLaborHours: 2
        )

        let material = MaterialCatalogItem(
            id: 201,
            name: "Paint",
            unit: "l",
            basePrice: 50,
            swedishName: "",
            sortOrder: 0,
            markupPercent: 10,
            usagePerWorkUnit: 0.4
        )

        let speed = SpeedProfile(id: 1, name: "Medium", coefficient: 1.5, daysDivider: 9, sortOrder: 0)
        let rules = CalculationRules(
            id: 1,
            transportPercent: 0.10,
            equipmentPercent: 0.20,
            wastePercent: 0.05,
            marginPercent: 0.10,
            momsPercent: 0.25,
            minSpeedRate: 0.01,
            minWorkMediumSpeed: 0.1,
            minWorkBaseRatePerUnitHour: 0.01,
            minSpeedDaysDivider: 0.1,
            minMaterialUsagePerWorkUnit: 0.01,
            minMaterialQuantity: 0.01
        )

        let result = calculator.calculate(
            rooms: [room],
            surfacesByRoom: surfacesByRoom,
            openingsByRoom: openingsByRoom,
            selectedWorks: [room.id: [work]],
            selectedMaterials: [room.id: [material]],
            speed: speed,
            pricingMode: .fixed,
            laborRate: 100,
            overhead: 1.25,
            rules: rules
        )

        XCTAssertEqual(result.rows.count, 2)

        let workRow = tryUnwrap(result.rows.first(where: { $0.workItemId == work.id }))
        XCTAssertEqual(workRow.quantity, 18, accuracy: 0.0001)
        XCTAssertEqual(workRow.speedCoefficient, 4.5, accuracy: 0.0001)
        XCTAssertEqual(workRow.normHours, 9, accuracy: 0.0001)
        XCTAssertEqual(workRow.hours, 4.5, accuracy: 0.0001)
        XCTAssertEqual(workRow.days, 0.5, accuracy: 0.0001)
        XCTAssertEqual(workRow.laborCost, 450, accuracy: 0.0001)
        XCTAssertEqual(workRow.materialCost, 0, accuracy: 0.0001)

        let materialRow = tryUnwrap(result.rows.first(where: { $0.materialItemId == material.id }))
        XCTAssertEqual(materialRow.quantity, 4, accuracy: 0.0001)
        XCTAssertEqual(materialRow.materialCost, 220, accuracy: 0.0001)
        XCTAssertEqual(materialRow.total, 220, accuracy: 0.0001)

        XCTAssertEqual(result.totalHours, 4.5, accuracy: 0.0001)
        XCTAssertEqual(result.totalDays, 0.5, accuracy: 0.0001)
        XCTAssertEqual(result.totalLabor, 450, accuracy: 0.0001)
        XCTAssertEqual(result.totalMaterials, 220, accuracy: 0.0001)
        XCTAssertEqual(result.transportCost, 67, accuracy: 0.0001)
        XCTAssertEqual(result.equipmentCost, 90, accuracy: 0.0001)
        XCTAssertEqual(result.wasteCost, 11, accuracy: 0.0001)
        XCTAssertEqual(result.margin, 83.8, accuracy: 0.0001)
        XCTAssertEqual(result.moms, 230.45, accuracy: 0.0001)
        XCTAssertEqual(result.grandTotal, 1152.25, accuracy: 0.0001)
    }

    func testMultipleWorksAndMaterialsInOneRoomAreSummedWithoutLoss() {
        let room = Room(id: 2, projectId: 1, name: "Room B", area: 12, height: 2.7, wallAreaAuto: 30)
        let rules = CalculationRules.default
        let speed = SpeedProfile(id: 1, name: "Base", coefficient: 1, daysDivider: 8, sortOrder: 0)

        let workA = WorkCatalogItem(id: 1, name: "Wall Work", unit: "м²", baseRatePerUnitHour: 0.2, basePrice: 0, swedishName: "", sortOrder: 0, mediumSpeed: 2)
        let workB = WorkCatalogItem(id: 2, name: "Room Work", unit: "шт", baseRatePerUnitHour: 0.5, basePrice: 0, swedishName: "", sortOrder: 1, mediumSpeed: 1, additionalLaborHours: 1)
        let materialA = MaterialCatalogItem(id: 11, name: "Material A", unit: "kg", basePrice: 20, swedishName: "", sortOrder: 0, markupPercent: 0, usagePerWorkUnit: 0.5)
        let materialB = MaterialCatalogItem(id: 12, name: "Material B", unit: "kg", basePrice: 10, swedishName: "", sortOrder: 1, markupPercent: 50, usagePerWorkUnit: 0.2)

        let result = calculator.calculate(
            rooms: [room],
            surfacesByRoom: [:],
            openingsByRoom: [:],
            selectedWorks: [room.id: [workA, workB]],
            selectedMaterials: [room.id: [materialA, materialB]],
            speed: speed,
            pricingMode: .fixed,
            laborRate: 100,
            overhead: 1,
            rules: rules
        )

        XCTAssertEqual(result.rows.count, 4)
        XCTAssertEqual(Set(result.rows.compactMap(\.workItemId)).count, 2)
        XCTAssertEqual(Set(result.rows.compactMap(\.materialItemId)).count, 2)

        // Work A: quantity 30 -> norm 6 -> speed 2 -> hours 3 -> labor 300
        // Work B: quantity 12 -> norm 6 -> speed 1 -> hours 7 (incl +1) -> labor 700
        XCTAssertEqual(result.totalLabor, 1000, accuracy: 0.0001)
        // Material A: 12*0.5*20 = 120
        // Material B: 12*0.2*(10+50%) = 36
        XCTAssertEqual(result.totalMaterials, 156, accuracy: 0.0001)

        let sumRowsLabor = result.rows.reduce(0) { $0 + $1.laborCost }
        let sumRowsMaterials = result.rows.reduce(0) { $0 + $1.materialCost }
        XCTAssertEqual(result.totalLabor, sumRowsLabor, accuracy: 0.0001)
        XCTAssertEqual(result.totalMaterials, sumRowsMaterials, accuracy: 0.0001)
    }

    func testMultipleRoomsAreAggregatedAtProjectLevel() {
        let room1 = Room(id: 10, projectId: 1, name: "R1", area: 10, height: 2.6, wallAreaAuto: 20)
        let room2 = Room(id: 20, projectId: 1, name: "R2", area: 5, height: 2.6, wallAreaAuto: 8)

        let work1 = WorkCatalogItem(id: 1, name: "W1", unit: "м²", baseRatePerUnitHour: 0.5, basePrice: 0, swedishName: "", sortOrder: 0, mediumSpeed: 2)
        let work2 = WorkCatalogItem(id: 2, name: "W2", unit: "шт", baseRatePerUnitHour: 1, basePrice: 0, swedishName: "", sortOrder: 0, mediumSpeed: 1)
        let mat1 = MaterialCatalogItem(id: 11, name: "M1", unit: "u", basePrice: 10, swedishName: "", sortOrder: 0, usagePerWorkUnit: 0.5)
        let mat2 = MaterialCatalogItem(id: 22, name: "M2", unit: "u", basePrice: 20, swedishName: "", sortOrder: 0, usagePerWorkUnit: 1)

        let rules = CalculationRules.default
        let speed = SpeedProfile(id: 1, name: "S", coefficient: 1, daysDivider: 8, sortOrder: 0)

        let result = calculator.calculate(
            rooms: [room1, room2],
            surfacesByRoom: [:],
            openingsByRoom: [:],
            selectedWorks: [room1.id: [work1], room2.id: [work2]],
            selectedMaterials: [room1.id: [mat1], room2.id: [mat2]],
            speed: speed,
            pricingMode: .fixed,
            laborRate: 100,
            overhead: 1,
            rules: rules
        )

        XCTAssertEqual(result.rows.count, 4)
        // Room1 work: 20*0.5/2 = 5 h => 500
        // Room2 work: 5*1/1 = 5 h => 500
        XCTAssertEqual(result.totalLabor, 1000, accuracy: 0.0001)
        // Room1 mat: 10*0.5*10 = 50
        // Room2 mat: 5*1*20 = 100
        XCTAssertEqual(result.totalMaterials, 150, accuracy: 0.0001)
    }

    func testSpeedProfileCoefficientPredictablyChangesWorkHours() {
        let room = Room(id: 1, projectId: 1, name: "Speed", area: 10, height: 2.7, wallAreaAuto: 20)
        let work = WorkCatalogItem(id: 1, name: "Work", unit: "м²", baseRatePerUnitHour: 0.4, basePrice: 0, swedishName: "", sortOrder: 0, mediumSpeed: 2)

        let slow = SpeedProfile(id: 1, name: "Slow", coefficient: 1, daysDivider: 8, sortOrder: 0)
        let fast = SpeedProfile(id: 2, name: "Fast", coefficient: 2, daysDivider: 8, sortOrder: 1)

        let baseResult = calculator.calculate(
            rooms: [room],
            surfacesByRoom: [:],
            openingsByRoom: [:],
            selectedWorks: [room.id: [work]],
            selectedMaterials: [:],
            speed: slow,
            pricingMode: .fixed,
            laborRate: 100,
            overhead: 1,
            rules: .default
        )

        let fasterResult = calculator.calculate(
            rooms: [room],
            surfacesByRoom: [:],
            openingsByRoom: [:],
            selectedWorks: [room.id: [work]],
            selectedMaterials: [:],
            speed: fast,
            pricingMode: .fixed,
            laborRate: 100,
            overhead: 1,
            rules: .default
        )

        XCTAssertEqual(baseResult.totalHours, 4, accuracy: 0.0001)
        XCTAssertEqual(fasterResult.totalHours, 2, accuracy: 0.0001)
        XCTAssertEqual(fasterResult.totalHours, baseResult.totalHours / 2, accuracy: 0.0001)
        XCTAssertEqual(fasterResult.totalLabor, baseResult.totalLabor / 2, accuracy: 0.0001)
    }

    func testOverheadCoefficientIsAppliedExactlyOnce() {
        let room = Room(id: 3, projectId: 1, name: "Overhead", area: 10, height: 2.7, wallAreaAuto: 20)
        let work = WorkCatalogItem(id: 1, name: "Work", unit: "м²", baseRatePerUnitHour: 0.4, basePrice: 0, swedishName: "", sortOrder: 0, mediumSpeed: 2)
        let speed = SpeedProfile(id: 1, name: "S", coefficient: 1, daysDivider: 8, sortOrder: 0)
        let rules = CalculationRules.default

        let overheadOne = calculator.calculate(
            rooms: [room],
            surfacesByRoom: [:],
            openingsByRoom: [:],
            selectedWorks: [room.id: [work]],
            selectedMaterials: [:],
            speed: speed,
            pricingMode: .fixed,
            laborRate: 100,
            overhead: 1.0,
            rules: rules
        )
        let overheadOnePointTwoFive = calculator.calculate(
            rooms: [room],
            surfacesByRoom: [:],
            openingsByRoom: [:],
            selectedWorks: [room.id: [work]],
            selectedMaterials: [:],
            speed: speed,
            pricingMode: .fixed,
            laborRate: 100,
            overhead: 1.25,
            rules: rules
        )

        // hours base: (20 * 0.4) / (1 * 2) = 4
        XCTAssertEqual(overheadOne.totalHours, 4, accuracy: 0.0001)
        XCTAssertEqual(overheadOnePointTwoFive.totalHours, 5, accuracy: 0.0001)
        XCTAssertEqual(overheadOnePointTwoFive.totalHours, overheadOne.totalHours * 1.25, accuracy: 0.0001)
        // If overhead were applied twice, expected multiplier would be 1.5625 and hours=6.25 (must not happen).
        XCTAssertNotEqual(overheadOnePointTwoFive.totalHours, overheadOne.totalHours * 1.25 * 1.25, accuracy: 0.0001)
    }

    func testMinimumThresholdsForWorkSpeedAndDaysDividerAreUsed() {
        let room = Room(id: 4, projectId: 1, name: "Min Rules", area: 10, height: 2.7, wallAreaAuto: 10)
        let work = WorkCatalogItem(
            id: 2,
            name: "Tiny Work",
            unit: "м²",
            baseRatePerUnitHour: 0,
            basePrice: 0,
            swedishName: "",
            sortOrder: 0,
            mediumSpeed: 0
        )
        let speed = SpeedProfile(id: 1, name: "S", coefficient: 0, daysDivider: 0, sortOrder: 0)
        let rules = CalculationRules(
            id: 1,
            transportPercent: 0,
            equipmentPercent: 0,
            wastePercent: 0,
            marginPercent: 0,
            momsPercent: 0,
            minSpeedRate: 0.5,
            minWorkMediumSpeed: 0.2,
            minWorkBaseRatePerUnitHour: 0.3,
            minSpeedDaysDivider: 4,
            minMaterialUsagePerWorkUnit: 0.2,
            minMaterialQuantity: 0.01
        )

        let result = calculator.calculate(
            rooms: [room],
            surfacesByRoom: [:],
            openingsByRoom: [:],
            selectedWorks: [room.id: [work]],
            selectedMaterials: [:],
            speed: speed,
            pricingMode: .fixed,
            laborRate: 100,
            overhead: 1,
            rules: rules
        )

        let workRow = tryUnwrap(result.rows.first)
        // quantity=10; norm=10*max(0,0.3)=3; speedRate=max(0.5, 0*max(1,0.2))=0.5
        XCTAssertEqual(workRow.normHours, 3, accuracy: 0.0001)
        XCTAssertEqual(workRow.speedCoefficient, 0.5, accuracy: 0.0001)
        XCTAssertEqual(workRow.hours, 6, accuracy: 0.0001)
        // daysDivider uses minSpeedDaysDivider=4 instead of speed.daysDivider=0
        XCTAssertEqual(workRow.days, 1.5, accuracy: 0.0001)
    }

    func testMinimumThresholdsForMaterialUsageAndQuantityAreUsed() {
        let room = Room(id: 5, projectId: 1, name: "Material Min", area: 0.01, height: 2.7, wallAreaAuto: 1)
        let material = MaterialCatalogItem(
            id: 10,
            name: "Material",
            unit: "l",
            basePrice: 100,
            swedishName: "",
            sortOrder: 0,
            markupPercent: 0,
            usagePerWorkUnit: 0
        )
        let rules = CalculationRules(
            id: 1,
            transportPercent: 0,
            equipmentPercent: 0,
            wastePercent: 0,
            marginPercent: 0,
            momsPercent: 0,
            minSpeedRate: 0.01,
            minWorkMediumSpeed: 0.1,
            minWorkBaseRatePerUnitHour: 0.01,
            minSpeedDaysDivider: 0.1,
            minMaterialUsagePerWorkUnit: 0.2,
            minMaterialQuantity: 0.05
        )

        let result = calculator.calculate(
            rooms: [room],
            surfacesByRoom: [:],
            openingsByRoom: [:],
            selectedWorks: [:],
            selectedMaterials: [room.id: [material]],
            speed: SpeedProfile(id: 1, name: "S", coefficient: 1, daysDivider: 8, sortOrder: 0),
            pricingMode: .fixed,
            laborRate: 100,
            overhead: 1,
            rules: rules
        )

        let materialRow = tryUnwrap(result.rows.first)
        // raw quantity = 0.01 * max(0, 0.2) = 0.002, clamped by minMaterialQuantity to 0.05
        XCTAssertEqual(materialRow.quantity, 0.05, accuracy: 0.0001)
        XCTAssertEqual(materialRow.materialCost, 5, accuracy: 0.0001)
    }

    func testRepeatedCalculatorCallsWithSameInputAreBitwiseStableForNumericResults() {
        let room = Room(id: 6, projectId: 1, name: "Repeat", area: 8, height: 2.7, wallAreaAuto: 16)
        let work = WorkCatalogItem(id: 7, name: "Repeat Work", unit: "м²", baseRatePerUnitHour: 0.25, basePrice: 0, swedishName: "", sortOrder: 0, mediumSpeed: 2)
        let material = MaterialCatalogItem(id: 8, name: "Repeat Material", unit: "l", basePrice: 30, swedishName: "", sortOrder: 0, markupPercent: 10, usagePerWorkUnit: 0.5)
        let speed = SpeedProfile(id: 1, name: "S", coefficient: 1.2, daysDivider: 6, sortOrder: 0)
        let rules = CalculationRules.default

        let first = calculator.calculate(
            rooms: [room],
            surfacesByRoom: [:],
            openingsByRoom: [:],
            selectedWorks: [room.id: [work]],
            selectedMaterials: [room.id: [material]],
            speed: speed,
            pricingMode: .fixed,
            laborRate: 90,
            overhead: 1.1,
            rules: rules
        )
        let second = calculator.calculate(
            rooms: [room],
            surfacesByRoom: [:],
            openingsByRoom: [:],
            selectedWorks: [room.id: [work]],
            selectedMaterials: [room.id: [material]],
            speed: speed,
            pricingMode: .fixed,
            laborRate: 90,
            overhead: 1.1,
            rules: rules
        )

        XCTAssertEqual(first.totalHours, second.totalHours, accuracy: 0.0000001)
        XCTAssertEqual(first.totalDays, second.totalDays, accuracy: 0.0000001)
        XCTAssertEqual(first.totalLabor, second.totalLabor, accuracy: 0.0000001)
        XCTAssertEqual(first.totalMaterials, second.totalMaterials, accuracy: 0.0000001)
        XCTAssertEqual(first.grandTotal, second.grandTotal, accuracy: 0.0000001)
    }

    private func tryUnwrap<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) -> T {
        guard let value else {
            XCTFail("Expected non-nil value", file: file, line: line)
            fatalError("unreachable")
        }
        return value
    }
}
