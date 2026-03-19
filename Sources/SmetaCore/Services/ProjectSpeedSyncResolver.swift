import Foundation

public struct ProjectSpeedSyncDecision: Equatable {
    public let activeSpeedProfileId: Int64
    public let didUseFallback: Bool
    public let missingProjectSpeedProfileId: Int64?

    public init(activeSpeedProfileId: Int64, didUseFallback: Bool, missingProjectSpeedProfileId: Int64?) {
        self.activeSpeedProfileId = activeSpeedProfileId
        self.didUseFallback = didUseFallback
        self.missingProjectSpeedProfileId = missingProjectSpeedProfileId
    }
}

public enum ProjectSpeedSyncError: Error, Equatable {
    case noAvailableSpeedProfiles
}

public enum ProjectSpeedSyncResolver {
    public static func resolve(projectSpeedProfileId: Int64, availableSpeedProfileIds: [Int64]) throws -> ProjectSpeedSyncDecision {
        if availableSpeedProfileIds.contains(projectSpeedProfileId) {
            return ProjectSpeedSyncDecision(activeSpeedProfileId: projectSpeedProfileId, didUseFallback: false, missingProjectSpeedProfileId: nil)
        }
        guard let fallback = availableSpeedProfileIds.first else {
            throw ProjectSpeedSyncError.noAvailableSpeedProfiles
        }
        return ProjectSpeedSyncDecision(activeSpeedProfileId: fallback, didUseFallback: true, missingProjectSpeedProfileId: projectSpeedProfileId)
    }
}
