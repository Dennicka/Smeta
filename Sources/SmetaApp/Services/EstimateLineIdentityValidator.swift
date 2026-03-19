import Foundation

enum EstimateLineIdentityError: Error, LocalizedError {
    case roomOutOfScope(roomId: Int64)
    case invalidWorkMaterialLink(workItemId: Int64?, materialItemId: Int64?, itemName: String)

    var errorDescription: String? {
        switch self {
        case .roomOutOfScope(let roomId):
            return "Строка расчёта содержит roomId вне текущего расчёта: \(roomId)"
        case .invalidWorkMaterialLink(let workItemId, let materialItemId, let itemName):
            return "Некорректная identity-связь строки \(itemName): workItemId=\(workItemId.map(String.init) ?? "nil"), materialItemId=\(materialItemId.map(String.init) ?? "nil"). Должен быть заполнен ровно один идентификатор."
        }
    }
}

struct EstimateLineIdentityValidator {
    static func makeEstimateLine(
        estimateId: Int64,
        row: CalculationRow,
        validRoomIds: Set<Int64>
    ) throws -> EstimateLine {
        guard validRoomIds.contains(row.roomId) else {
            throw EstimateLineIdentityError.roomOutOfScope(roomId: row.roomId)
        }

        let hasWork = row.workItemId != nil
        let hasMaterial = row.materialItemId != nil
        guard hasWork != hasMaterial else {
            throw EstimateLineIdentityError.invalidWorkMaterialLink(workItemId: row.workItemId, materialItemId: row.materialItemId, itemName: row.itemName)
        }

        return EstimateLine(
            id: 0,
            estimateId: estimateId,
            roomId: row.roomId,
            workItemId: row.workItemId,
            materialItemId: row.materialItemId,
            quantity: row.quantity,
            unitPrice: row.total,
            coefficient: row.coefficient,
            type: hasWork ? "work" : "material"
        )
    }
}
