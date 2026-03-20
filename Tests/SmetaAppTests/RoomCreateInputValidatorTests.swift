import XCTest
@testable import SmetaCore

final class RoomCreateInputValidatorTests: XCTestCase {
    func testValidAreaWithGarbageInDimensionsFails() {
        let result = RoomCreateInputValidator.validate(
            area: "20",
            length: "",
            width: "abc",
            height: "2.7",
            wallAdjustment: "0"
        )

        XCTAssertEqual(failureMessage(result), "Ширина должна быть числом")
    }

    func testValidDimensionsWithGarbageInAreaFails() {
        let result = RoomCreateInputValidator.validate(
            area: "abc",
            length: "4",
            width: "3",
            height: "2.7",
            wallAdjustment: "0"
        )

        XCTAssertEqual(failureMessage(result), "Площадь пола должна быть числом")
    }

    func testAreaOnlySucceeds() {
        let result = RoomCreateInputValidator.validate(
            area: "20",
            length: "",
            width: "",
            height: "2.7",
            wallAdjustment: "0.5"
        )

        XCTAssertEqual(successInput(result), .init(area: 20, length: 0, width: 0, height: 2.7, manualWallAdjustment: 0.5))
    }

    func testDimensionsOnlySucceeds() {
        let result = RoomCreateInputValidator.validate(
            area: "",
            length: "4",
            width: "3",
            height: "2.7",
            wallAdjustment: "0"
        )

        XCTAssertEqual(successInput(result), .init(area: 0, length: 4, width: 3, height: 2.7, manualWallAdjustment: 0))
    }

    func testOnlyLengthWithoutWidthFails() {
        let result = RoomCreateInputValidator.validate(
            area: "",
            length: "4",
            width: "",
            height: "2.7",
            wallAdjustment: "0"
        )

        XCTAssertEqual(failureMessage(result), "Для расчёта по габаритам заполните и длину, и ширину")
    }

    func testCommaDecimalHeightAndAdjustmentAreAccepted() {
        let result = RoomCreateInputValidator.validate(
            area: "20",
            length: "",
            width: "",
            height: "2,7",
            wallAdjustment: "0,5"
        )

        XCTAssertEqual(successInput(result), .init(area: 20, length: 0, width: 0, height: 2.7, manualWallAdjustment: 0.5))
    }

    func testCommaDecimalDimensionsAreAccepted() {
        let result = RoomCreateInputValidator.validate(
            area: "",
            length: "4,2",
            width: "3,1",
            height: "2,7",
            wallAdjustment: "0"
        )

        XCTAssertEqual(successInput(result), .init(area: 0, length: 4.2, width: 3.1, height: 2.7, manualWallAdjustment: 0))
    }

    func testHeightLessOrEqualZeroFails() {
        let result = RoomCreateInputValidator.validate(
            area: "20",
            length: "",
            width: "",
            height: "0",
            wallAdjustment: "0"
        )

        XCTAssertEqual(failureMessage(result), "Высота должна быть больше нуля")
    }

    private func successInput(_ result: Result<RoomCreateInputValidator.Input, RoomCreateInputValidator.ValidationError>) -> RoomCreateInputValidator.Input? {
        switch result {
        case .success(let input):
            return input
        case .failure(let error):
            XCTFail("Expected success, got failure: \(error.messageText)")
            return nil
        }
    }

    private func failureMessage(_ result: Result<RoomCreateInputValidator.Input, RoomCreateInputValidator.ValidationError>) -> String? {
        switch result {
        case .success(let input):
            XCTFail("Expected failure, got success: \(input)")
            return nil
        case .failure(let error):
            return error.messageText
        }
    }
}
