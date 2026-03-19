import XCTest
@testable import SmetaCore

final class ProjectSpeedSyncResolverTests: XCTestCase {
    func testResolveUsesProjectSpeedWhenPresent() throws {
        let decision = try ProjectSpeedSyncResolver.resolve(
            projectSpeedProfileId: 20,
            availableSpeedProfileIds: [10, 20, 30]
        )

        XCTAssertEqual(decision.activeSpeedProfileId, 20)
        XCTAssertFalse(decision.didUseFallback)
        XCTAssertNil(decision.missingProjectSpeedProfileId)
    }

    func testResolveFallsBackWhenProjectSpeedMissing() throws {
        let decision = try ProjectSpeedSyncResolver.resolve(
            projectSpeedProfileId: 99,
            availableSpeedProfileIds: [10, 20]
        )

        XCTAssertEqual(decision.activeSpeedProfileId, 10)
        XCTAssertTrue(decision.didUseFallback)
        XCTAssertEqual(decision.missingProjectSpeedProfileId, 99)
    }

    func testResolveFailsWhenNoProfilesAvailable() {
        XCTAssertThrowsError(
            try ProjectSpeedSyncResolver.resolve(projectSpeedProfileId: 99, availableSpeedProfileIds: [])
        ) { error in
            XCTAssertEqual(error as? ProjectSpeedSyncError, .noAvailableSpeedProfiles)
        }
    }
}
