import Foundation

private func assertOrFail(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("ASSERT FAILED: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct VerifyEstimateLineIdentity {
    static func main() {
        let roomA = Room(id: 101, projectId: 1, name: "Кухня", area: 10, height: 2.7, roomType: "")
        let roomB = Room(id: 202, projectId: 1, name: "Кухня", area: 20, height: 2.7, roomType: "")

        let workA = WorkCatalogItem(id: 501, name: "Шпаклевка", unit: "м²", baseRatePerUnitHour: 1, basePrice: 0, swedishName: "", sortOrder: 0, categoryId: nil, subcategoryId: nil, description: "", isActive: true, includeInStandardOffer: true, rotEligible: true, applicability: "", basePurchasePrice: 0, hourlyPrice: 0, slowSpeed: 1, mediumSpeed: 1, fastSpeed: 1, complexityCoefficient: 1, heightCoefficient: 1, conditionCoefficient: 1, urgencyCoefficient: 1, accessibilityCoefficient: 1, additionalLaborHours: 0, additionalMaterialUsage: 0)
        let workB = WorkCatalogItem(id: 502, name: "Шпаклевка", unit: "м²", baseRatePerUnitHour: 1, basePrice: 0, swedishName: "", sortOrder: 0, categoryId: nil, subcategoryId: nil, description: "", isActive: true, includeInStandardOffer: true, rotEligible: true, applicability: "", basePurchasePrice: 0, hourlyPrice: 0, slowSpeed: 1, mediumSpeed: 1, fastSpeed: 1, complexityCoefficient: 1, heightCoefficient: 1, conditionCoefficient: 1, urgencyCoefficient: 1, accessibilityCoefficient: 1, additionalLaborHours: 0, additionalMaterialUsage: 0)

        let result = EstimateCalculator().calculate(
            rooms: [roomA, roomB],
            surfacesByRoom: [:],
            openingsByRoom: [:],
            selectedWorks: [roomA.id: [workA], roomB.id: [workB]],
            selectedMaterials: [:],
            speed: SpeedProfile(id: 1, name: "Средняя", coefficient: 1, daysDivider: 8, sortOrder: 1),
            pricingMode: .fixed,
            laborRate: 100,
            overhead: 1,
            rules: CalculationRules.default
        )
        assertOrFail(result.rows.count == 2, "Ожидалось 2 строки расчёта")

        let oldMapped = result.rows.map { row -> (Int64, Int64?) in
            let roomId = [roomA, roomB].first(where: { $0.name == row.roomName })!.id
            let workId = [workA, workB].first(where: { $0.name == row.itemName })?.id
            return (roomId, workId)
        }
        print("OLD_NAME_BASED_MAPPING=\(oldMapped)")
        assertOrFail(oldMapped[0] == (101, 501), "Старая маппинг логика: первая строка")
        assertOrFail(oldMapped[1] == (101, 501), "Старая маппинг логика должна спутать дубли имени")

        let validRoomIds: Set<Int64> = [roomA.id, roomB.id]
        let estimateLines = result.rows.map { row in
            try! EstimateLineIdentityValidator.makeEstimateLine(estimateId: 9001, row: row, validRoomIds: validRoomIds)
        }
        print("NEW_ID_BASED_LINES=\(estimateLines.map { ($0.roomId, $0.workItemId, $0.materialItemId) })")
        assertOrFail(estimateLines[0].roomId == 101 && estimateLines[0].workItemId == 501, "Первая строка должна сохранить исходные id")
        assertOrFail(estimateLines[1].roomId == 202 && estimateLines[1].workItemId == 502, "Вторая строка должна сохранить исходные id при дублях имени")

        let invalidBothNil = CalculationRow(roomId: 101, workItemId: nil, materialItemId: nil, roomName: "Кухня", itemName: "broken-nil", quantity: 1, speedCoefficient: 1, normHours: 0, coefficient: 1, hours: 0, days: 0, laborCost: 0, materialCost: 0, total: 0, formula: "")
        do {
            _ = try EstimateLineIdentityValidator.makeEstimateLine(estimateId: 1, row: invalidBothNil, validRoomIds: validRoomIds)
            assertOrFail(false, "Ожидалась ошибка для обоих nil")
        } catch {
            print("INVALID_BOTH_NIL_REJECTED=\(error.localizedDescription)")
        }

        let invalidBothSet = CalculationRow(roomId: 101, workItemId: 777, materialItemId: 888, roomName: "Кухня", itemName: "broken-both", quantity: 1, speedCoefficient: 1, normHours: 0, coefficient: 1, hours: 0, days: 0, laborCost: 0, materialCost: 0, total: 0, formula: "")
        do {
            _ = try EstimateLineIdentityValidator.makeEstimateLine(estimateId: 1, row: invalidBothSet, validRoomIds: validRoomIds)
            assertOrFail(false, "Ожидалась ошибка для одновременно work+material")
        } catch {
            print("INVALID_BOTH_SET_REJECTED=\(error.localizedDescription)")
        }

        let invalidRoom = CalculationRow(roomId: 9999, workItemId: 777, materialItemId: nil, roomName: "Кухня", itemName: "broken-room", quantity: 1, speedCoefficient: 1, normHours: 0, coefficient: 1, hours: 0, days: 0, laborCost: 0, materialCost: 0, total: 0, formula: "")
        do {
            _ = try EstimateLineIdentityValidator.makeEstimateLine(estimateId: 1, row: invalidRoom, validRoomIds: validRoomIds)
            assertOrFail(false, "Ожидалась ошибка для roomId вне расчёта")
        } catch {
            print("INVALID_ROOM_REJECTED=\(error.localizedDescription)")
        }

        print("VERIFY_ESTIMATE_LINE_IDENTITY_OK")
    }
}
