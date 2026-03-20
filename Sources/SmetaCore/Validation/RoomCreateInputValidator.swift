import Foundation

public struct RoomCreateInputValidator {
    public enum ValidationError: Error, Equatable {
        case message(String)

        public var messageText: String {
            switch self {
            case .message(let text):
                return text
            }
        }
    }
    public struct Input: Equatable {
        public let area: Double
        public let length: Double
        public let width: Double
        public let height: Double
        public let manualWallAdjustment: Double

        public init(area: Double, length: Double, width: Double, height: Double, manualWallAdjustment: Double) {
            self.area = area
            self.length = length
            self.width = width
            self.height = height
            self.manualWallAdjustment = manualWallAdjustment
        }
    }

    private enum ParseResult {
        case empty
        case value(Double)
        case invalid
    }

    public static func parseUserDouble(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let withoutSpaces = trimmed.replacingOccurrences(of: " ", with: "")
        if let direct = Double(withoutSpaces) {
            return direct
        }

        let commaNormalized = withoutSpaces.replacingOccurrences(of: ",", with: ".")
        if let normalized = Double(commaNormalized) {
            return normalized
        }

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.numberStyle = .decimal
        if let number = formatter.number(from: withoutSpaces) {
            return number.doubleValue
        }

        formatter.locale = Locale(identifier: "en_US_POSIX")
        if let number = formatter.number(from: withoutSpaces) {
            return number.doubleValue
        }

        return nil
    }

    public static func validate(
        area: String,
        length: String,
        width: String,
        height: String,
        wallAdjustment: String
    ) -> Result<Input, ValidationError> {
        guard let parsedHeight = parseRequiredDouble(height) else {
            return .failure(.message("Высота должна быть числом"))
        }
        guard parsedHeight > 0 else {
            return .failure(.message("Высота должна быть больше нуля"))
        }

        guard let parsedAdjustment = parseRequiredDouble(wallAdjustment) else {
            return .failure(.message("Корр. стен должно быть числом"))
        }

        let parsedArea = parseOptionalDouble(area)
        let parsedLength = parseOptionalDouble(length)
        let parsedWidth = parseOptionalDouble(width)

        if case .invalid = parsedArea {
            return .failure(.message("Площадь пола должна быть числом"))
        }
        if case .invalid = parsedLength {
            return .failure(.message("Длина должна быть числом"))
        }
        if case .invalid = parsedWidth {
            return .failure(.message("Ширина должна быть числом"))
        }

        let areaValue = value(from: parsedArea)
        let lengthValue = value(from: parsedLength)
        let widthValue = value(from: parsedWidth)

        if let areaValue, areaValue <= 0 {
            return .failure(.message("Площадь пола должна быть больше нуля"))
        }
        if let lengthValue, lengthValue <= 0 {
            return .failure(.message("Длина должна быть больше нуля"))
        }
        if let widthValue, widthValue <= 0 {
            return .failure(.message("Ширина должна быть больше нуля"))
        }

        let hasArea = areaValue != nil
        let hasLength = lengthValue != nil
        let hasWidth = widthValue != nil

        if hasArea && (hasLength || hasWidth) {
            return .failure(.message("Укажите либо площадь пола, либо длину и ширину"))
        }

        if hasLength != hasWidth {
            return .failure(.message("Для расчёта по габаритам заполните и длину, и ширину"))
        }

        if let areaValue {
            return .success(Input(area: areaValue, length: 0, width: 0, height: parsedHeight, manualWallAdjustment: parsedAdjustment))
        }

        if let lengthValue, let widthValue {
            return .success(Input(area: 0, length: lengthValue, width: widthValue, height: parsedHeight, manualWallAdjustment: parsedAdjustment))
        }

        return .failure(.message("Укажите либо площадь пола, либо длину и ширину"))
    }

    private static func parseRequiredDouble(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return parseUserDouble(trimmed)
    }

    private static func parseOptionalDouble(_ raw: String) -> ParseResult {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .empty
        }
        guard let parsed = parseUserDouble(trimmed) else {
            return .invalid
        }
        return .value(parsed)
    }

    private static func value(from parsed: ParseResult) -> Double? {
        if case let .value(value) = parsed {
            return value
        }
        return nil
    }
}
