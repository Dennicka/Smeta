import Foundation

enum ProbeFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message): return message
        }
    }
}

@MainActor
@main
struct VerifyProjectSpeedSyncContour {
    static func main() throws {
        let db = try SQLiteDatabase(filename: "speed-sync-probe-\(UUID().uuidString).sqlite")
        try db.initializeSchema()
        let repository = AppRepository(db: db)
        let vm = AppViewModel(repository: repository, backupService: BackupService(db: db))
        vm.bootstrap()

        guard vm.errorMessage == nil else {
            throw ProbeFailure.failed("bootstrap error: \(vm.errorMessage!)")
        }

        let speedIds = vm.speedProfiles.map(\.id)
        guard speedIds.count >= 2 else {
            throw ProbeFailure.failed("need at least two speed profiles")
        }
        let speedA = speedIds[0]
        let speedB = speedIds[1]
        guard let clientId = vm.clients.first?.id, let propertyId = vm.properties.first?.id else {
            throw ProbeFailure.failed("missing seed client/property")
        }

        let projectAId = try repository.insertProject(Project(
            id: 0,
            clientId: clientId,
            propertyId: propertyId,
            name: "Probe Project A",
            speedProfileId: speedA,
            createdAt: Date()
        ))
        let projectBId = try repository.insertProject(Project(
            id: 0,
            clientId: clientId,
            propertyId: propertyId,
            name: "Probe Project B",
            speedProfileId: speedB,
            createdAt: Date()
        ))
        try vm.reloadAll()

        guard
            let projectA = vm.projects.first(where: { $0.id == projectAId }),
            let projectB = vm.projects.first(where: { $0.id == projectBId })
        else {
            throw ProbeFailure.failed("unable to create probe projects")
        }
        guard projectA.speedProfileId != projectB.speedProfileId else {
            throw ProbeFailure.failed("invalid setup: projectA and projectB speeds must differ")
        }

        // A: Project selection sync
        try vm.selectProject(projectA)
        guard vm.selectedSpeedId == projectA.speedProfileId else {
            throw ProbeFailure.failed("A failed: selectedSpeedId does not match projectA speed")
        }
        try vm.selectProject(projectB)
        guard vm.selectedSpeedId == projectB.speedProfileId else {
            throw ProbeFailure.failed("A failed: selectedSpeedId does not match projectB speed")
        }

        // Shared setup for B
        vm.addRoom(projectId: projectA.id, name: "Room A", area: 12, height: 2.6)
        vm.addRoom(projectId: projectB.id, name: "Room B", area: 12, height: 2.6)
        guard let work = vm.works.first else {
            throw ProbeFailure.failed("missing work catalog")
        }
        guard
            let roomA = vm.rooms.first(where: { $0.projectId == projectA.id && $0.name == "Room A" }),
            let roomB = vm.rooms.first(where: { $0.projectId == projectB.id && $0.name == "Room B" })
        else {
            throw ProbeFailure.failed("unable to find created rooms")
        }

        // B: Calculation uses project speed
        try vm.selectProject(projectA)
        vm.selectedWorksByRoom = [roomA.id: [work]]
        vm.selectedMaterialsByRoom = [:]
        vm.calculate()
        guard let calcA = vm.calculationResult else { throw ProbeFailure.failed("missing calc for projectA") }

        try vm.selectProject(projectB)
        vm.selectedWorksByRoom = [roomB.id: [work]]
        vm.selectedMaterialsByRoom = [:]
        vm.calculate()
        guard let calcB = vm.calculationResult else { throw ProbeFailure.failed("missing calc for projectB") }
        guard calcA.totalHours != calcB.totalHours else {
            throw ProbeFailure.failed("B failed: calculations are equal despite different project speeds")
        }

        // C: estimate/offert-related speed resolution (without NSSavePanel)
        vm.selectedSpeedId = speedA == projectB.speedProfileId ? speedB : speedA // force stale UI value
        let estimatePathSpeed = try vm.resolveSyncedSpeedProfileIdForEstimatePath()
        guard estimatePathSpeed == projectB.speedProfileId else {
            throw ProbeFailure.failed("C failed: estimate/offert speed resolution used stale selectedSpeedId")
        }

        // D: reload keeps sync
        try vm.reloadAll()
        guard vm.selectedProject?.id == projectB.id else {
            throw ProbeFailure.failed("D failed: selected project changed after reload")
        }
        guard vm.selectedSpeedId == vm.selectedProject?.speedProfileId else {
            throw ProbeFailure.failed("D failed: selected speed out of sync after reload")
        }

        // E: missing profile fallback + persistence
        let missingProjectId = try repository.insertProject(Project(
            id: 0,
            clientId: clientId,
            propertyId: propertyId,
            name: "Probe Missing Speed",
            speedProfileId: 9_999_999,
            createdAt: Date()
        ))
        try vm.reloadAll()
        guard let missingProject = vm.projects.first(where: { $0.id == missingProjectId }) else {
            throw ProbeFailure.failed("E failed: missing-speed project absent")
        }
        try vm.selectProject(missingProject)
        guard vm.selectedSpeedId == vm.speedProfiles.first?.id else {
            throw ProbeFailure.failed("E failed: fallback speed not applied")
        }
        try vm.reloadAll()
        guard let persistedMissing = vm.projects.first(where: { $0.id == missingProjectId }) else {
            throw ProbeFailure.failed("E failed: missing project not found after reload")
        }
        guard persistedMissing.speedProfileId == vm.selectedSpeedId else {
            throw ProbeFailure.failed("E failed: fallback speed was not persisted to project")
        }

        // F: manual speed change flow
        let manualSpeed = vm.speedProfiles.last?.id ?? speedA
        vm.setSelectedSpeedProfile(manualSpeed)
        guard vm.selectedSpeedId == manualSpeed else {
            throw ProbeFailure.failed("F failed: selectedSpeedId did not update")
        }
        guard vm.selectedProject?.speedProfileId == manualSpeed else {
            throw ProbeFailure.failed("F failed: selectedProject.speedProfileId did not update")
        }
        try vm.reloadAll()
        guard vm.selectedProject?.speedProfileId == vm.selectedSpeedId else {
            throw ProbeFailure.failed("F failed: reload broke manual speed sync")
        }

        // G: new project creation defaulting rule:
        // new project inherits speed from currently selected project (if valid),
        // not from arbitrary stale selectedSpeedId.
        let baseProject = try {
            if vm.selectedProject?.id == projectA.id { return projectA }
            try vm.selectProject(projectA)
            return projectA
        }()
        let staleSpeed = (baseProject.speedProfileId == speedA) ? speedB : speedA
        vm.selectedSpeedId = staleSpeed // deliberately stale UI state
        vm.addProject(clientId: clientId, propertyId: propertyId, name: "Probe New Project Sync")
        guard let newProject = vm.selectedProject, newProject.name == "Probe New Project Sync" else {
            throw ProbeFailure.failed("G failed: new project was not selected")
        }
        guard newProject.speedProfileId == baseProject.speedProfileId else {
            throw ProbeFailure.failed("G failed: new project did not inherit selectedProject speed")
        }
        guard newProject.speedProfileId != staleSpeed else {
            throw ProbeFailure.failed("G failed: stale selectedSpeedId leaked into new project creation")
        }
        guard vm.selectedSpeedId == newProject.speedProfileId else {
            throw ProbeFailure.failed("G failed: selectedSpeedId was not synchronized to new project speed")
        }

        print("PASS: project-speed synchronization contour verified for scenarios A-G")
    }
}
