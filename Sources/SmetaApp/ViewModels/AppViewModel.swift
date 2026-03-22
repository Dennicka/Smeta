import Foundation
import SmetaCore
#if canImport(AppKit)
import AppKit
#endif

protocol OffertPDFGenerating {
    func generateOffertSwedish(
        template: DocumentTemplate,
        company: Company,
        client: Client,
        project: Project,
        result: CalculationResult,
        saveURL: URL
    ) throws
}

extension PDFDocumentService: OffertPDFGenerating {}

protocol OffertDestinationProviding {
    func chooseDestination(defaultFileName: String) throws -> URL?
}

protocol BusinessDocumentPDFGenerating {
    func generateBusinessDocumentPDF(title: String, body: String, saveURL: URL) throws
}

extension PDFDocumentService: BusinessDocumentPDFGenerating {}

protocol BusinessDocumentDestinationProviding {
    func chooseDestination(defaultFileName: String) throws -> URL?
}

struct OffertContourFailureInjection {
    var persistentWriteFailure: (() throws -> Void)?
    var beforePromoteFailure: (() throws -> Void)?
}

struct BusinessDocumentExportFailureInjection {
    var persistentWriteFailure: (() throws -> Void)?
    var beforePromoteFailure: (() throws -> Void)?
}

private struct DefaultOffertDestinationProvider: OffertDestinationProviding {
    func chooseDestination(defaultFileName: String) throws -> URL? {
        #if canImport(AppKit)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultFileName
        panel.allowedFileTypes = ["pdf"]
        guard panel.runModal() == .OK else {
            return nil
        }
        return panel.url
        #else
        throw NSError(domain: "OffertGeneration", code: 1, userInfo: [NSLocalizedDescriptionKey: "Генерация Offert доступна только на AppKit-платформах"])
        #endif
    }
}

private struct DefaultBusinessDocumentDestinationProvider: BusinessDocumentDestinationProviding {
    func chooseDestination(defaultFileName: String) throws -> URL? {
        #if canImport(AppKit)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultFileName
        panel.allowedFileTypes = ["pdf"]
        guard panel.runModal() == .OK else {
            return nil
        }
        return panel.url
        #else
        throw NSError(domain: "DocumentExport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Экспорт PDF доступен только на AppKit-платформах"])
        #endif
    }
}

#if !canImport(SwiftUI)
protocol ObservableObject {}

@propertyWrapper
struct Published<Value> {
    var wrappedValue: Value
    init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
}
#endif

@MainActor
final class AppViewModel: ObservableObject {
    enum BootstrapStatus: Equatable {
        case idle
        case success
        case failed(String)
    }

    @Published var clients: [Client] = []
    @Published var properties: [PropertyObject] = []
    @Published var projects: [Project] = []
    @Published var rooms: [Room] = []
    @Published var works: [WorkCatalogItem] = []
    @Published var materials: [MaterialCatalogItem] = []
    @Published var speedProfiles: [SpeedProfile] = []
    @Published var surfacesByRoom: [Int64: [Surface]] = [:]
    @Published var openingsByRoom: [Int64: [Opening]] = [:]
    @Published var pricingMode: PricingMode = .fixed
    @Published var templates: [DocumentTemplate] = []
    @Published var generatedDocuments: [GeneratedDocument] = []
    @Published var businessDocuments: [BusinessDocument] = []
    @Published var paymentsByDocumentId: [Int64: [DocumentPaymentEntry]] = [:]
    @Published var documentSeries: [DocumentSeries] = []
    @Published var taxProfiles: [TaxProfile] = []
    @Published var suppliers: [Supplier] = []
    @Published var receivableBuckets: [ReceivableBucket] = []
    @Published var selectedProjectProfitability: ProjectProfitability?
    @Published var projectNotes: [ProjectNote] = []
    @Published var selectedProject: Project?
    @Published var searchText: String = ""
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published var bootstrapStatus: BootstrapStatus = .idle

    @Published var selectedWorksByRoom: [Int64: [WorkCatalogItem]] = [:]
    @Published var selectedMaterialsByRoom: [Int64: [MaterialCatalogItem]] = [:]

    @Published var laborRatePerHour: Double = 600
    @Published var overheadCoefficient: Double = 1.15
    @Published var calculationRules: CalculationRules = .default
    @Published var selectedSpeedId: Int64 = 0
    @Published var calculationResult: CalculationResult?
    @Published var calculationInvocationCount: Int = 0

    var filteredBusinessDocuments: [BusinessDocument] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return businessDocuments }
        return businessDocuments.filter { doc in
            doc.title.lowercased().contains(query) ||
            doc.number.lowercased().contains(query) ||
            doc.type.lowercased().contains(query) ||
            doc.status.lowercased().contains(query)
        }
    }

    private let repository: AppRepository
    private let calculator = EstimateCalculator()
    private let businessDocumentPDFGenerator: BusinessDocumentPDFGenerating
    private let offertPDFGenerator: OffertPDFGenerating
    private let backupService: BackupService
    private let stage5Service = Stage5Service()
    private let documentDraftBuilder = DocumentDraftBuilder()
    private let documentSnapshotBuilder = DocumentSnapshotBuilder()
    private let documentExportPipeline = DocumentExportPipeline()
    private let pdfFileState = PDFFileStateOrchestrator()
    private let exportArtifacts = ExportArtifactCoordinator()
    private let offertDestinationProvider: OffertDestinationProviding
    private let offertFailureInjection: OffertContourFailureInjection?
    private let businessDocumentDestinationProvider: BusinessDocumentDestinationProviding
    private let businessDocumentExportFailureInjection: BusinessDocumentExportFailureInjection?

    init(
        repository: AppRepository,
        backupService: BackupService,
        offertPDFGenerator: OffertPDFGenerating = PDFDocumentService(),
        offertDestinationProvider: OffertDestinationProviding = DefaultOffertDestinationProvider(),
        offertFailureInjection: OffertContourFailureInjection? = nil,
        businessDocumentPDFGenerator: BusinessDocumentPDFGenerating = PDFDocumentService(),
        businessDocumentDestinationProvider: BusinessDocumentDestinationProviding = DefaultBusinessDocumentDestinationProvider(),
        businessDocumentExportFailureInjection: BusinessDocumentExportFailureInjection? = nil
    ) {
        self.repository = repository
        self.backupService = backupService
        self.offertPDFGenerator = offertPDFGenerator
        self.offertDestinationProvider = offertDestinationProvider
        self.offertFailureInjection = offertFailureInjection
        self.businessDocumentPDFGenerator = businessDocumentPDFGenerator
        self.businessDocumentDestinationProvider = businessDocumentDestinationProvider
        self.businessDocumentExportFailureInjection = businessDocumentExportFailureInjection
    }

    func bootstrap() {
        do {
            try performBootstrap()
            bootstrapStatus = .success
            errorMessage = nil
        } catch {
            bootstrapStatus = .failed(error.localizedDescription)
            present(error: error, prefix: "Ошибка инициализации")
        }
    }

    func performBootstrap() throws {
        try repository.performLaunchBootstrapWrites()
        try reloadAll()
    }

    func ensureUISmokeBootstrapDataIfNeeded() throws {
        guard SmokeRuntimeConfig.isUISmokeEnabled else { return }
        if projects.count < 2 {
            guard let clientId = clients.first?.id else {
                throw NSError(domain: "Smeta.RuntimeProbe", code: 9101, userInfo: [NSLocalizedDescriptionKey: "No client available for UI smoke"])
            }
            guard let propertyId = properties.first(where: { $0.clientId == clientId })?.id ?? properties.first?.id else {
                throw NSError(domain: "Smeta.RuntimeProbe", code: 9102, userInfo: [NSLocalizedDescriptionKey: "No property available for UI smoke"])
            }
            addProject(clientId: clientId, propertyId: propertyId, name: "UI Smoke Secondary Project")
            if let errorMessage {
                throw NSError(domain: "Smeta.RuntimeProbe", code: 9103, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
        }

        try ensureUISmokeCalculationContour()
    }

    private func ensureUISmokeCalculationContour() throws {
        guard let firstWork = works.first(where: \.isActive) ?? works.first else {
            throw NSError(domain: "Smeta.RuntimeProbe", code: 9104, userInfo: [NSLocalizedDescriptionKey: "No work catalog item available for UI smoke"])
        }
        guard let firstMaterial = materials.first(where: \.isActive) ?? materials.first else {
            throw NSError(domain: "Smeta.RuntimeProbe", code: 9105, userInfo: [NSLocalizedDescriptionKey: "No material catalog item available for UI smoke"])
        }

        var changed = false
        let smokeProjects = Array(projects.prefix(2))
        for project in smokeProjects {
            var room = rooms.first(where: { $0.projectId == project.id })
            if room == nil {
                let createdRoomId = try repository.createRoomWithAutoSurfaces(
                    Room(id: 0, projectId: project.id, name: "UI Smoke Room", area: 12, height: 2.6)
                )
                room = Room(id: createdRoomId, projectId: project.id, name: "UI Smoke Room", area: 12, height: 2.6)
                changed = true
            }

            guard let roomId = room?.id else {
                continue
            }

            if selectedWorksByRoom[roomId, default: []].isEmpty {
                try repository.replaceRoomWorkAssignments(roomId: roomId, workIds: [firstWork.id])
                changed = true
            }
            if selectedMaterialsByRoom[roomId, default: []].isEmpty {
                try repository.replaceRoomMaterialAssignments(roomId: roomId, materialIds: [firstMaterial.id])
                changed = true
            }
        }

        if changed {
            try reloadAll()
        }
    }

    private func present(error: Error, prefix: String) {
        errorMessage = "\(prefix): \(error.localizedDescription)"
    }

    func reloadAll() throws {
        let snapshot = StateSnapshot.capture(from: self)
        let selectedProjectId = selectedProject?.id
        do {
            clients = try repository.clients()
            properties = try repository.fetchWithClientProperties()
            projects = try repository.projects()
            rooms = try repository.rooms()
            surfacesByRoom = Dictionary(uniqueKeysWithValues: try rooms.map { ($0.id, try repository.surfaces(roomId: $0.id)) })
            openingsByRoom = Dictionary(uniqueKeysWithValues: try rooms.map { ($0.id, try repository.openings(roomId: $0.id)) })
            works = try repository.workItems()
            materials = try repository.materialItems()
            selectedWorksByRoom = [:]
            selectedMaterialsByRoom = [:]
            let workAssignments = try repository.roomWorkAssignments()
            let materialAssignments = try repository.roomMaterialAssignments()
            selectedWorksByRoom = Dictionary(uniqueKeysWithValues: workAssignments.map { roomId, workIds in
                (roomId, works.filter { workIds.contains($0.id) })
            })
            selectedMaterialsByRoom = Dictionary(uniqueKeysWithValues: materialAssignments.map { roomId, materialIds in
                (roomId, materials.filter { materialIds.contains($0.id) })
            })
            speedProfiles = try repository.speedProfiles()
            templates = try repository.templates()
            generatedDocuments = try repository.generatedDocuments()
            businessDocuments = try repository.businessDocuments()
            paymentsByDocumentId = Dictionary(uniqueKeysWithValues: try businessDocuments.map { document in
                (document.id, try repository.documentPayments(documentId: document.id))
            })
            documentSeries = try repository.documentSeries()
            taxProfiles = try repository.taxProfiles()
            calculationRules = try repository.calculationRules()
            suppliers = (try? repository.suppliers()) ?? []
            receivableBuckets = stage5Service.receivablesBuckets((try? repository.receivablesDocuments()) ?? [])
            selectedProject = selectedProjectId.flatMap { id in
                projects.first(where: { $0.id == id })
            } ?? projects.first
            try synchronizeSelectedSpeedWithSelectedProject(persistFallbackToProject: true, context: "reload")
            if let project = selectedProject {
                refreshProjectProfitability(projectId: project.id, showMissingEstimateError: false)
                projectNotes = (try? repository.projectNotes(projectId: project.id)) ?? []
            } else {
                projectNotes = []
            }
        } catch {
            snapshot.restore(to: self)
            throw error
        }
    }

    private struct StateSnapshot {
        let clients: [Client]
        let properties: [PropertyObject]
        let projects: [Project]
        let rooms: [Room]
        let works: [WorkCatalogItem]
        let materials: [MaterialCatalogItem]
        let speedProfiles: [SpeedProfile]
        let surfacesByRoom: [Int64: [Surface]]
        let openingsByRoom: [Int64: [Opening]]
        let templates: [DocumentTemplate]
        let generatedDocuments: [GeneratedDocument]
        let businessDocuments: [BusinessDocument]
        let paymentsByDocumentId: [Int64: [DocumentPaymentEntry]]
        let documentSeries: [DocumentSeries]
        let taxProfiles: [TaxProfile]
        let suppliers: [Supplier]
        let receivableBuckets: [ReceivableBucket]
        let selectedProjectProfitability: ProjectProfitability?
        let projectNotes: [ProjectNote]
        let selectedWorksByRoom: [Int64: [WorkCatalogItem]]
        let selectedMaterialsByRoom: [Int64: [MaterialCatalogItem]]
        let selectedProject: Project?
        let selectedSpeedId: Int64
        let calculationRules: CalculationRules

        @MainActor
        static func capture(from vm: AppViewModel) -> StateSnapshot {
            StateSnapshot(clients: vm.clients,
                          properties: vm.properties,
                          projects: vm.projects,
                          rooms: vm.rooms,
                          works: vm.works,
                          materials: vm.materials,
                          speedProfiles: vm.speedProfiles,
                          surfacesByRoom: vm.surfacesByRoom,
                          openingsByRoom: vm.openingsByRoom,
                          templates: vm.templates,
                          generatedDocuments: vm.generatedDocuments,
                          businessDocuments: vm.businessDocuments,
                          paymentsByDocumentId: vm.paymentsByDocumentId,
                          documentSeries: vm.documentSeries,
                          taxProfiles: vm.taxProfiles,
                          suppliers: vm.suppliers,
                          receivableBuckets: vm.receivableBuckets,
                          selectedProjectProfitability: vm.selectedProjectProfitability,
                          projectNotes: vm.projectNotes,
                          selectedWorksByRoom: vm.selectedWorksByRoom,
                          selectedMaterialsByRoom: vm.selectedMaterialsByRoom,
                          selectedProject: vm.selectedProject,
                          selectedSpeedId: vm.selectedSpeedId,
                          calculationRules: vm.calculationRules)
        }

        @MainActor
        func restore(to vm: AppViewModel) {
            vm.clients = clients
            vm.properties = properties
            vm.projects = projects
            vm.rooms = rooms
            vm.works = works
            vm.materials = materials
            vm.speedProfiles = speedProfiles
            vm.surfacesByRoom = surfacesByRoom
            vm.openingsByRoom = openingsByRoom
            vm.templates = templates
            vm.generatedDocuments = generatedDocuments
            vm.businessDocuments = businessDocuments
            vm.paymentsByDocumentId = paymentsByDocumentId
            vm.documentSeries = documentSeries
            vm.taxProfiles = taxProfiles
            vm.suppliers = suppliers
            vm.receivableBuckets = receivableBuckets
            vm.selectedProjectProfitability = selectedProjectProfitability
            vm.projectNotes = projectNotes
            vm.selectedWorksByRoom = selectedWorksByRoom
            vm.selectedMaterialsByRoom = selectedMaterialsByRoom
            vm.selectedProject = selectedProject
            vm.selectedSpeedId = selectedSpeedId
            vm.calculationRules = calculationRules
        }
    }

    @discardableResult
    func addClient(name: String, email: String, phone: String, address: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { errorMessage = "Имя клиента обязательно"; return false }
        do {
            _ = try repository.insertClient(Client(id: 0, name: trimmed, email: email, phone: phone, address: address))
            infoMessage = "Клиент сохранён"
            try reloadAll()
            return true
        } catch {
            errorMessage = "Не удалось сохранить клиента: \(error.localizedDescription)"
            return false
        }
    }
    @discardableResult
    func updateClient(_ client: Client) -> Bool {
        let trimmedName = client.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Имя клиента обязательно"
            return false
        }
        do {
            var updatedClient = client
            updatedClient.name = trimmedName
            try repository.updateClient(updatedClient)
            infoMessage = "Клиент обновлён"
            try reloadAll()
            return true
        } catch {
            present(error: error, prefix: "Не удалось обновить клиента")
            return false
        }
    }
    func deleteClient(_ client: Client) {
        do {
            try repository.deleteClient(id: client.id)
            if selectedProject?.clientId == client.id {
                selectedProject = nil
            }
            infoMessage = "Клиент удалён"
            try reloadAll()
        } catch {
            present(error: error, prefix: "Не удалось удалить клиента (проверьте зависимости)")
        }
    }

    @discardableResult
    func addProperty(clientId: Int64, name: String, address: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { errorMessage = "Название объекта обязательно"; return false }
        do {
            _ = try repository.insertProperty(PropertyObject(id: 0, clientId: clientId, name: trimmed, address: address))
            infoMessage = "Объект сохранён"
            try reloadAll()
            return true
        } catch {
            errorMessage = "Не удалось сохранить объект: \(error.localizedDescription)"
            return false
        }
    }
    @discardableResult
    func updateProperty(_ property: PropertyObject) -> Bool {
        let trimmedName = property.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Название объекта обязательно"
            return false
        }
        do {
            var updatedProperty = property
            updatedProperty.name = trimmedName
            try repository.updateProperty(updatedProperty)
            infoMessage = "Объект обновлён"
            try reloadAll()
            return true
        } catch {
            present(error: error, prefix: "Не удалось обновить объект")
            return false
        }
    }
    func deleteProperty(_ property: PropertyObject) {
        do {
            try repository.deleteProperty(id: property.id)
            infoMessage = "Объект удалён"
            try reloadAll()
        } catch {
            present(error: error, prefix: "Не удалось удалить объект (проверьте зависимости)")
        }
    }

    @discardableResult
    func addProject(clientId: Int64, propertyId: Int64, name: String) -> Bool {
        let defaultSpeed = speedProfiles.first?.id ?? resolvedSpeedIdForNewProject()
        return addProject(clientId: clientId, propertyId: propertyId, speedProfileId: defaultSpeed, pricingMode: PricingMode.fixed.rawValue, isDraft: true, name: name)
    }

    @discardableResult
    func addProject(clientId: Int64, propertyId: Int64, speedProfileId: Int64, pricingMode: String, isDraft: Bool, name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { errorMessage = "Название проекта обязательно"; return false }
        do {
            let normalizedPricingMode = try validatedPricingMode(pricingMode)
            try validateProjectReferences(clientId: clientId, propertyId: propertyId, speedProfileId: speedProfileId)
            let projectId = try repository.insertProject(
                Project(
                    id: 0,
                    clientId: clientId,
                    propertyId: propertyId,
                    name: trimmed,
                    speedProfileId: speedProfileId,
                    createdAt: Date(),
                    pricingMode: normalizedPricingMode,
                    isDraft: isDraft
                )
            )
            infoMessage = "Проект создан"
            try reloadAll()
            if let inserted = projects.first(where: { $0.id == projectId }) {
                try selectProject(inserted)
            }
            return true
        } catch {
            errorMessage = "Не удалось создать проект: \(error.localizedDescription)"
            return false
        }
    }
    @discardableResult
    func updateProject(_ project: Project) -> Bool {
        let trimmedName = project.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Название проекта обязательно"
            return false
        }
        do {
            let normalizedPricingMode = try validatedPricingMode(project.pricingMode)
            try validateProjectReferences(clientId: project.clientId, propertyId: project.propertyId, speedProfileId: project.speedProfileId)
            var updatedProject = project
            updatedProject.name = trimmedName
            updatedProject.pricingMode = normalizedPricingMode
            try repository.updateProject(updatedProject)
            infoMessage = "Проект обновлён"
            try reloadAll()
            return true
        } catch {
            present(error: error, prefix: "Не удалось обновить проект")
            return false
        }
    }
    func deleteProject(_ project: Project) {
        do {
            try repository.deleteProject(id: project.id)
            if selectedProject?.id == project.id {
                selectedProject = nil
            }
            infoMessage = "Проект удалён"
            try reloadAll()
        } catch {
            present(error: error, prefix: "Не удалось удалить проект (проверьте зависимости)")
        }
    }

    func selectProject(_ project: Project) throws {
        selectedProject = project
        try synchronizeSelectedSpeedWithSelectedProject(persistFallbackToProject: true, context: "project-selection")
    }

    func setSelectedSpeedProfile(_ speedProfileId: Int64) {
        guard speedProfiles.contains(where: { $0.id == speedProfileId }) else {
            errorMessage = "Выбранный профиль скорости недоступен"
            return
        }
        guard var project = selectedProject else {
            selectedSpeedId = speedProfileId
            return
        }
        do {
            try repository.updateProjectSpeedProfile(projectId: project.id, speedProfileId: speedProfileId)
            project.speedProfileId = speedProfileId
            selectedProject = project
            selectedSpeedId = speedProfileId
            if let projectIndex = projects.firstIndex(where: { $0.id == project.id }) {
                projects[projectIndex].speedProfileId = speedProfileId
            }
            try reloadAll()
        } catch {
            present(error: error, prefix: "Не удалось обновить профиль скорости проекта")
        }
    }

    func addRoom(projectId: Int64, name: String, area: Double, height: Double, length: Double = 0, width: Double = 0, manualWallAdjustment: Double = 0, roomType: String = "") {
        let geometry = deriveRoomGeometry(area: area, length: length, width: width, height: height, manualWallAdjustment: manualWallAdjustment)
        let floorArea = geometry.floorArea
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { errorMessage = "Название помещения обязательно"; return }
        guard floorArea > 0, height > 0 else { errorMessage = "Площадь и высота должны быть больше нуля"; return }
        let room = Room(id: 0, projectId: projectId, name: name, area: floorArea, height: height, roomType: roomType, length: length, width: width, ceilingArea: geometry.ceilingArea, wallAreaAuto: geometry.wallAreaAuto, wallAreaManualAdjustment: manualWallAdjustment)
        do {
            _ = try repository.createRoomWithAutoSurfaces(room)
            try reloadAll()
        } catch { errorMessage = "Не удалось сохранить помещение: \(error.localizedDescription)" }
    }

    func duplicateRoom(_ room: Room) {
        addRoom(projectId: room.projectId, name: room.name + " (копия)", area: room.area, height: room.height, length: room.length, width: room.width, manualWallAdjustment: room.wallAreaManualAdjustment, roomType: room.roomType)
    }
    @discardableResult
    func updateRoom(_ room: Room) -> Bool {
        do {
            guard !room.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                errorMessage = "Название помещения обязательно"
                return false
            }
            guard room.height > 0 else {
                errorMessage = "Высота помещения должна быть больше нуля"
                return false
            }
            let geometry = deriveRoomGeometry(area: room.area, length: room.length, width: room.width, height: room.height, manualWallAdjustment: room.wallAreaManualAdjustment)
            guard geometry.floorArea > 0 else {
                errorMessage = "Площадь помещения должна быть больше нуля"
                return false
            }
            if let roomTemplateId = room.roomTemplateId, try !repository.roomTemplateExists(id: roomTemplateId) {
                errorMessage = "Указан несуществующий RoomTemplate ID: \(roomTemplateId)"
                return false
            }
            let updated = Room(id: room.id, projectId: room.projectId, name: room.name, area: geometry.floorArea, height: room.height, roomType: room.roomType, length: room.length, width: room.width, ceilingArea: geometry.ceilingArea, wallAreaAuto: geometry.wallAreaAuto, wallAreaManualAdjustment: room.wallAreaManualAdjustment, surfaceCondition: room.surfaceCondition, notes: room.notes, photoPath: room.photoPath, roomTemplateId: room.roomTemplateId)
            try repository.updateRoomWithAutoSurfaces(updated)
            infoMessage = "Помещение обновлено"
            try reloadAll()
            return true
        } catch {
            present(error: error, prefix: "Не удалось обновить помещение")
            return false
        }
    }
    func deleteRoom(_ room: Room) {
        do {
            try repository.deleteRoom(id: room.id)
            selectedWorksByRoom[room.id] = nil
            selectedMaterialsByRoom[room.id] = nil
            infoMessage = "Помещение удалено"
            try reloadAll()
        } catch {
            present(error: error, prefix: "Не удалось удалить помещение")
        }
    }

    func addOpening(roomId: Int64, type: String, name: String, width: Double, height: Double, count: Int, subtract: Bool) {
        do { try repository.addOpening(Opening(id: 0, roomId: roomId, surfaceId: nil, type: type, name: name, width: width, height: height, count: count, subtractFromWallArea: subtract)); try reloadAll() } catch { present(error: error, prefix: "Не удалось добавить проём") }
    }
    func deleteOpening(_ opening: Opening) {
        do {
            try repository.deleteOpening(id: opening.id)
            infoMessage = "Проём удалён"
            try reloadAll()
        } catch {
            present(error: error, prefix: "Не удалось удалить проём")
        }
    }

    @discardableResult
    func addWork(_ item: WorkCatalogItem) -> Bool {
        do {
            try validateWorkRequiredFields(item)
            try validateWorkReferences(item)
            _ = try repository.insertWorkItem(item)
            try reloadAll()
            return true
        } catch {
            present(error: error, prefix: "Не удалось добавить работу")
            return false
        }
    }
    @discardableResult
    func updateWork(_ item: WorkCatalogItem) -> Bool {
        do {
            try validateWorkRequiredFields(item)
            try validateWorkReferences(item)
            try repository.updateWorkItem(item)
            try reloadAll()
            return true
        } catch {
            present(error: error, prefix: "Не удалось обновить работу")
            return false
        }
    }
    func deleteWork(_ item: WorkCatalogItem) { do { try repository.deleteWorkItem(id: item.id); try reloadAll() } catch { present(error: error, prefix: "Не удалось удалить работу") } }
    @discardableResult
    func addMaterial(_ item: MaterialCatalogItem) -> Bool {
        do {
            try validateMaterialRequiredFields(item)
            try validateMaterialReferences(item)
            _ = try repository.insertMaterialItem(item)
            try reloadAll()
            return true
        } catch {
            present(error: error, prefix: "Не удалось добавить материал")
            return false
        }
    }
    @discardableResult
    func updateMaterial(_ item: MaterialCatalogItem) -> Bool {
        do {
            try validateMaterialRequiredFields(item)
            try validateMaterialReferences(item)
            try repository.updateMaterialItem(item)
            try reloadAll()
            return true
        } catch {
            present(error: error, prefix: "Не удалось обновить материал")
            return false
        }
    }
    func deleteMaterial(_ item: MaterialCatalogItem) { do { try repository.deleteMaterialItem(id: item.id); try reloadAll() } catch { present(error: error, prefix: "Не удалось удалить материал") } }
    @discardableResult
    func addSpeed(_ item: SpeedProfile) -> Bool {
        let trimmedName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Название профиля скорости обязательно"
            return false
        }
        do {
            var speed = item
            speed.name = trimmedName
            _ = try repository.insertSpeedProfile(speed)
            try reloadAll()
            return true
        } catch {
            present(error: error, prefix: "Не удалось добавить профиль скорости")
            return false
        }
    }
    @discardableResult
    func updateSpeed(_ item: SpeedProfile) -> Bool {
        let trimmedName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Название профиля скорости обязательно"
            return false
        }
        do {
            var updatedSpeed = item
            updatedSpeed.name = trimmedName
            try repository.updateSpeedProfile(updatedSpeed)
            try reloadAll()
            return true
        } catch {
            present(error: error, prefix: "Не удалось обновить профиль скорости")
            return false
        }
    }
    func deleteSpeed(_ item: SpeedProfile) { do { try repository.deleteSpeedProfile(id: item.id); try reloadAll() } catch { present(error: error, prefix: "Не удалось удалить профиль скорости") } }
    @discardableResult
    func addTemplate(_ item: DocumentTemplate) -> Bool {
        let trimmedName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Название шаблона обязательно"
            return false
        }
        do {
            var template = item
            template.name = trimmedName
            _ = try repository.insertTemplate(template)
            try reloadAll()
            return true
        } catch {
            present(error: error, prefix: "Не удалось добавить шаблон")
            return false
        }
    }
    @discardableResult
    func updateTemplate(_ item: DocumentTemplate) -> Bool {
        let trimmedName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Название шаблона обязательно"
            return false
        }
        do {
            var updatedTemplate = item
            updatedTemplate.name = trimmedName
            try repository.updateTemplate(updatedTemplate)
            try reloadAll()
            return true
        } catch {
            present(error: error, prefix: "Не удалось обновить шаблон")
            return false
        }
    }
    func deleteTemplate(_ item: DocumentTemplate) { do { try repository.deleteTemplate(id: item.id); try reloadAll() } catch { present(error: error, prefix: "Не удалось удалить шаблон") } }

    func toggleWorkSelection(roomId: Int64, work: WorkCatalogItem) {
        let current = selectedWorksByRoom[roomId, default: []]
        var next = current
        if let index = next.firstIndex(where: { $0.id == work.id }) {
            next.remove(at: index)
        } else {
            next.append(work)
        }
        do {
            try repository.replaceRoomWorkAssignments(roomId: roomId, workIds: next.map(\.id))
            selectedWorksByRoom[roomId] = next
        } catch {
            selectedWorksByRoom[roomId] = current
            present(error: error, prefix: "Не удалось сохранить назначения работ")
        }
    }
    func toggleMaterialSelection(roomId: Int64, material: MaterialCatalogItem) {
        let current = selectedMaterialsByRoom[roomId, default: []]
        var next = current
        if let index = next.firstIndex(where: { $0.id == material.id }) {
            next.remove(at: index)
        } else {
            next.append(material)
        }
        do {
            try repository.replaceRoomMaterialAssignments(roomId: roomId, materialIds: next.map(\.id))
            selectedMaterialsByRoom[roomId] = next
        } catch {
            selectedMaterialsByRoom[roomId] = current
            present(error: error, prefix: "Не удалось сохранить назначения материалов")
        }
    }

    private func deriveRoomGeometry(area: Double, length: Double, width: Double, height: Double, manualWallAdjustment: Double) -> (floorArea: Double, ceilingArea: Double, wallAreaAuto: Double, wallAreaTotal: Double) {
        let floorArea = (length > 0 && width > 0) ? (length * width) : area
        let wallAreaAuto = (length > 0 && width > 0) ? (2 * (length + width) * height) : (max(0, floorArea) * 2.8)
        let wallAreaTotal = max(0, wallAreaAuto + manualWallAdjustment)
        return (max(0, floorArea), max(0, floorArea), max(0, wallAreaAuto), wallAreaTotal)
    }

    private func validatedPricingMode(_ rawValue: String) throws -> String {
        guard PricingMode(rawValue: rawValue) != nil else {
            throw NSError(domain: "AppViewModel.Validation", code: 102, userInfo: [NSLocalizedDescriptionKey: "Некорректный pricingMode: \(rawValue)"])
        }
        return rawValue
    }

    private func validateProjectReferences(clientId: Int64, propertyId: Int64, speedProfileId: Int64) throws {
        guard try repository.client(id: clientId) != nil else {
            throw NSError(domain: "AppViewModel.Validation", code: 100, userInfo: [NSLocalizedDescriptionKey: "Клиент с id=\(clientId) не найден"])
        }
        guard try repository.propertyBelongsToClient(propertyId: propertyId, clientId: clientId) else {
            throw NSError(domain: "AppViewModel.Validation", code: 101, userInfo: [NSLocalizedDescriptionKey: "Объект id=\(propertyId) не принадлежит клиенту id=\(clientId)"])
        }
        guard try repository.speedProfileExists(id: speedProfileId) else {
            throw NSError(domain: "AppViewModel.Validation", code: 103, userInfo: [NSLocalizedDescriptionKey: "Профиль скорости id=\(speedProfileId) не найден"])
        }
    }

    private func validateWorkReferences(_ item: WorkCatalogItem) throws {
        if let categoryId = item.categoryId, try !repository.workCategoryExists(id: categoryId) {
            throw NSError(domain: "AppViewModel.Validation", code: 201, userInfo: [NSLocalizedDescriptionKey: "Category ID \(categoryId) не существует"])
        }
        if item.subcategoryId != nil, item.categoryId == nil {
            throw NSError(domain: "AppViewModel.Validation", code: 203, userInfo: [NSLocalizedDescriptionKey: "Subcategory ID можно указать только вместе с Category ID"])
        }
        if let subcategoryId = item.subcategoryId, try !repository.workSubcategoryExists(id: subcategoryId, categoryId: item.categoryId) {
            throw NSError(domain: "AppViewModel.Validation", code: 202, userInfo: [NSLocalizedDescriptionKey: "Subcategory ID \(subcategoryId) не существует или не соответствует выбранной категории"])
        }
    }

    private func validateWorkRequiredFields(_ item: WorkCatalogItem) throws {
        guard !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "AppViewModel.Validation", code: 210, userInfo: [NSLocalizedDescriptionKey: "Название работы обязательно"])
        }
        guard !item.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "AppViewModel.Validation", code: 211, userInfo: [NSLocalizedDescriptionKey: "Единица измерения работы обязательна"])
        }
    }

    private func validateMaterialReferences(_ item: MaterialCatalogItem) throws {
        if let categoryId = item.categoryId, try !repository.materialCategoryExists(id: categoryId) {
            throw NSError(domain: "AppViewModel.Validation", code: 301, userInfo: [NSLocalizedDescriptionKey: "Category ID \(categoryId) не существует"])
        }
        if let supplierId = item.supplierId, try !repository.supplierExists(id: supplierId) {
            throw NSError(domain: "AppViewModel.Validation", code: 302, userInfo: [NSLocalizedDescriptionKey: "Supplier ID \(supplierId) не существует"])
        }
    }

    private func validateMaterialRequiredFields(_ item: MaterialCatalogItem) throws {
        guard !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "AppViewModel.Validation", code: 310, userInfo: [NSLocalizedDescriptionKey: "Название материала обязательно"])
        }
        guard !item.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "AppViewModel.Validation", code: 311, userInfo: [NSLocalizedDescriptionKey: "Единица измерения материала обязательна"])
        }
    }

    func calculate() {
        calculationInvocationCount += 1
        guard let project = selectedProject else {
            errorMessage = "Выберите проект перед расчётом"
            return
        }
        let speed: SpeedProfile
        do {
            speed = try synchronizedSpeedProfileForSelectedProject(context: "calculation")
        } catch {
            present(error: error, prefix: "Не найден профиль скорости для расчёта")
            return
        }
        let projectRooms = rooms.filter { $0.projectId == project.id }
        let openings = Dictionary(uniqueKeysWithValues: projectRooms.map { ($0.id, openingsByRoom[$0.id, default: []]) })
        let surfaces = Dictionary(uniqueKeysWithValues: projectRooms.map { ($0.id, surfacesByRoom[$0.id, default: []]) })
        calculationResult = calculator.calculate(rooms: projectRooms,
                                                 surfacesByRoom: surfaces,
                                                 openingsByRoom: openings,
                                                 selectedWorks: selectedWorksByRoom,
                                                 selectedMaterials: selectedMaterialsByRoom,
                                                 speed: speed,
                                                 pricingMode: pricingMode,
                                                 laborRate: laborRatePerHour,
                                                 overhead: overheadCoefficient,
                                                 rules: calculationRules)
    }

    func saveEstimateAndGenerateDocument() {
        do {
            guard let project = selectedProject else {
                errorMessage = "Выберите проект перед генерацией Offert"
                return
            }
            let speed = try synchronizedSpeedProfileForSelectedProject(context: "offert")
            guard let calc = calculationResult else {
                errorMessage = "Сначала выполните расчёт, затем генерируйте Offert"
                return
            }
            guard let template = templates.first else {
                errorMessage = "Не найден шаблон документа для Offert"
                return
            }
            guard let company = try repository.companies().first else {
                errorMessage = "Не заполнены реквизиты компании для Offert"
                return
            }
            guard let client = clients.first(where: { $0.id == project.clientId }) else {
                errorMessage = "Не найден клиент проекта для Offert"
                return
            }
            let validRoomIds = Set(rooms.filter { $0.projectId == project.id }.map(\.id))

            guard let finalURL = try offertDestinationProvider.chooseDestination(defaultFileName: "Offert-\(project.name).pdf") else {
                infoMessage = "Генерация Offert отменена пользователем"
                return
            }

            let tempURL = pdfFileState.temporaryPDFURL(near: finalURL, prefix: "offert-pending")
            var didMoveToFinal = false
            var backupURL: URL?
            do {
                try offertPDFGenerator.generateOffertSwedish(template: template, company: company, client: client, project: project, result: calc, saveURL: tempURL)
                let estimateLineDrafts = try calc.rows.map { row in
                    try EstimateLineIdentityValidator.makeEstimateLineDraft(
                        row: row,
                        validRoomIds: validRoomIds
                    )
                }
                _ = try repository.performOffertGenerationWrites(
                    payload: AppRepository.OffertGenerationWritePayload(
                        estimate: Estimate(id: 0, projectId: project.id, speedProfileId: speed.id, laborRatePerHour: laborRatePerHour, overheadCoefficient: overheadCoefficient, createdAt: Date()),
                        estimateLineDrafts: estimateLineDrafts,
                        generatedDocumentTemplateId: template.id,
                        generatedDocumentTitle: "Offert \(project.name)",
                        generatedDocumentPath: finalURL.path,
                        generatedAt: Date()
                    ),
                    beforeCommit: {
                        backupURL = try self.pdfFileState.backupExistingFileIfNeeded(at: finalURL)
                        try self.offertFailureInjection?.beforePromoteFailure?()
                        try self.pdfFileState.promotePreparedPDF(from: tempURL, to: finalURL)
                        didMoveToFinal = true
                    },
                    failureInjection: self.offertFailureInjection?.persistentWriteFailure
                )
            } catch {
                var recoveryFailures: [String] = []
                if didMoveToFinal || backupURL != nil {
                    do {
                        try pdfFileState.recoverAfterFailedCommit(finalURL: finalURL, backupURL: backupURL, didPromote: didMoveToFinal)
                    } catch {
                        recoveryFailures.append(error.localizedDescription)
                    }
                }
                do {
                    try pdfFileState.removeTemporaryFileIfPresent(at: tempURL)
                } catch {
                    recoveryFailures.append("не удалось удалить временный PDF: \(error.localizedDescription)")
                }
                if !recoveryFailures.isEmpty {
                    throw NSError(domain: "PDFRecovery", code: 1, userInfo: [NSLocalizedDescriptionKey: "Ошибка операции и неполное восстановление: \(recoveryFailures.joined(separator: " | "))"])
                }
                throw error
            }

            try pdfFileState.removeTemporaryFileIfPresent(at: tempURL)
            var backupCleanupWarning: String?
            if let backupURL {
                do {
                    try pdfFileState.cleanupBackupAfterCommit(backupURL: backupURL)
                } catch {
                    backupCleanupWarning = "Offert сохранён, но cleanup backup не завершился: \(error.localizedDescription)"
                }
            }
            var refreshWarning: String?
            do {
                try reloadAll()
            } catch {
                refreshWarning = "Offert сохранён, но обновление экрана не выполнено: \(error.localizedDescription)"
            }
            if let backupCleanupWarning, let refreshWarning {
                infoMessage = "\(backupCleanupWarning) | \(refreshWarning)"
            } else if let backupCleanupWarning {
                infoMessage = backupCleanupWarning
            } else if let refreshWarning {
                infoMessage = refreshWarning
            } else {
                infoMessage = "Offert сохранён"
            }
        } catch { present(error: error, prefix: "Ошибка генерации Offert") }
    }

    private func resolvedSpeedIdForNewProject() -> Int64 {
        if let selectedProject,
           speedProfiles.contains(where: { $0.id == selectedProject.speedProfileId }) {
            return selectedProject.speedProfileId
        }
        if speedProfiles.contains(where: { $0.id == selectedSpeedId }) {
            return selectedSpeedId
        }
        return speedProfiles.first?.id ?? 1
    }

    private func synchronizedSpeedProfileForSelectedProject(context: String) throws -> SpeedProfile {
        try synchronizeSelectedSpeedWithSelectedProject(persistFallbackToProject: true, context: context)
        guard let speed = speedProfiles.first(where: { $0.id == selectedSpeedId }) else {
            throw ProjectSpeedSyncError.noAvailableSpeedProfiles
        }
        return speed
    }

    func resolveSyncedSpeedProfileIdForEstimatePath() throws -> Int64 {
        try synchronizedSpeedProfileForSelectedProject(context: "estimate-save-probe").id
    }

    private func synchronizeSelectedSpeedWithSelectedProject(persistFallbackToProject: Bool, context: String) throws {
        guard let project = selectedProject else {
            selectedSpeedId = speedProfiles.first?.id ?? 0
            return
        }
        let decision = try ProjectSpeedSyncResolver.resolve(
            projectSpeedProfileId: project.speedProfileId,
            availableSpeedProfileIds: speedProfiles.map(\.id)
        )
        selectedSpeedId = decision.activeSpeedProfileId
        guard decision.didUseFallback else { return }
        if persistFallbackToProject {
            try repository.updateProjectSpeedProfile(projectId: project.id, speedProfileId: decision.activeSpeedProfileId)
            if let selected = selectedProject {
                selectedProject = Project(
                    id: selected.id,
                    clientId: selected.clientId,
                    propertyId: selected.propertyId,
                    name: selected.name,
                    speedProfileId: decision.activeSpeedProfileId,
                    createdAt: selected.createdAt,
                    pricingMode: selected.pricingMode,
                    isDraft: selected.isDraft
                )
            }
            if let projectIndex = projects.firstIndex(where: { $0.id == project.id }) {
                projects[projectIndex].speedProfileId = decision.activeSpeedProfileId
            }
        }
        if let missingSpeedId = decision.missingProjectSpeedProfileId {
            errorMessage = "Профиль скорости id \(missingSpeedId) отсутствует для проекта \"\(project.name)\"; применён fallback id \(decision.activeSpeedProfileId) (\(context))"
        }
    }



    func createDraftDocument(type: DocumentType, projectId: Int64, title: String, customerType: CustomerType, taxMode: TaxMode, lines: [BusinessDocumentLine], rotPercent: Double = 0) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { errorMessage = "Название документа обязательно"; return }
        guard !lines.isEmpty else { errorMessage = "Документ должен содержать минимум одну строку"; return }
        guard lines.allSatisfy({ $0.quantity > 0 && $0.unitPrice >= 0 && !$0.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            errorMessage = "Проверьте строки документа: описание, количество и цены"
            return
        }
        if taxMode == .reverseCharge && customerType != .b2b {
            errorMessage = "Reverse charge допустим только для B2B"
            return
        }
        if rotPercent > 0 && customerType != .b2c {
            errorMessage = "ROT возможен только для B2C"
            return
        }

        do {
            let labor = lines.filter { $0.lineType == "labor" }.reduce(0) { $0 + $1.total }
            let material = lines.filter { $0.lineType == "material" }.reduce(0) { $0 + $1.total }
            let other = lines.filter { $0.lineType == "other" }.reduce(0) { $0 + $1.total }
            guard let taxProfile = taxProfiles.first(where: { $0.active && $0.customerType == customerType.rawValue && $0.taxMode == taxMode.rawValue }) else {
                errorMessage = "Не найден активный налоговый профиль для \(customerType.rawValue)/\(taxMode.rawValue)"
                return
            }
            let vatRate = taxProfile.vatRate
            let rotEligible = lines.filter { $0.isRotEligible }.reduce(0) { $0 + $1.total }
            let rotReduction = rotEligible * rotPercent
            let subtotal = labor + material + other
            let vatAmount = subtotal * vatRate
            let total = subtotal + vatAmount - rotReduction
            guard total >= 0 else { errorMessage = "Итоговая сумма не может быть отрицательной"; return }

            let doc = BusinessDocument(id: 0, projectId: projectId, type: type.rawValue, status: DocumentStatus.draft.rawValue, number: "", title: trimmedTitle, issueDate: Date(), dueDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()), customerType: customerType.rawValue, taxMode: taxMode.rawValue, currency: "SEK", subtotalLabor: labor, subtotalMaterial: material, subtotalOther: other, vatRate: vatRate, vatAmount: vatAmount, rotEligibleLabor: rotEligible, rotReduction: rotReduction, totalAmount: total, paidAmount: 0, balanceDue: total, relatedDocumentId: nil, notes: "")
            _ = try repository.createBusinessDocument(doc, lines: lines)
            try repository.updateProjectStatus(projectId: projectId, status: .calculation)
            infoMessage = "Черновик документа создан"
            try reloadAll()
        } catch {
            errorMessage = "Не удалось создать документ: \(error.localizedDescription)"
        }
    }

    func createOffertDraftFromSelectedProject(title: String, useRot: Bool) {
        guard let project = selectedProject else {
            errorMessage = "Выберите проект для создания Offert"
            return
        }
        do {
            let context = try loadDocumentBuildContext(projectId: project.id)
            switch documentDraftBuilder.buildOffert(context: context, title: title, useRot: useRot) {
            case .success(let payload):
                try persistDraftDocument(payload: payload)
                infoMessage = "Черновик Offert создан из данных проекта"
                try reloadAll()
            case .incomplete(let reason):
                errorMessage = reason
            }
        } catch {
            errorMessage = "Не удалось создать Offert: \(error.localizedDescription)"
        }
    }

    func createFakturaDraftFromSelectedProject(reverseCharge: Bool) {
        guard let project = selectedProject else {
            errorMessage = "Выберите проект для создания Faktura"
            return
        }
        do {
            let context = try loadDocumentBuildContext(projectId: project.id)
            let title = "Faktura \(project.name)"
            switch documentDraftBuilder.buildFaktura(context: context, title: title, reverseCharge: reverseCharge) {
            case .success(let payload):
                try persistDraftDocument(payload: payload)
                infoMessage = "Черновик Faktura создан из данных проекта"
                try reloadAll()
            case .incomplete(let reason):
                errorMessage = reason
            }
        } catch {
            errorMessage = "Не удалось создать Faktura: \(error.localizedDescription)"
        }
    }

    func createAvtalDraftFromSelectedProject() {
        guard let project = selectedProject else {
            errorMessage = "Выберите проект для создания Avtal"
            return
        }
        do {
            let context = try loadDocumentBuildContext(projectId: project.id)
            switch documentDraftBuilder.buildAvtal(context: context, title: "Avtal \(project.name)") {
            case .success(let payload):
                try persistDraftDocument(payload: payload)
                infoMessage = "Черновик Avtal создан из финализированной Offert"
                try reloadAll()
            case .incomplete(let reason):
                errorMessage = reason
            }
        } catch {
            errorMessage = "Не удалось создать Avtal: \(error.localizedDescription)"
        }
    }

    func createKreditfakturaDraftFromSelectedProject() {
        guard let project = selectedProject else {
            errorMessage = "Выберите проект для создания Kreditfaktura"
            return
        }
        do {
            let context = try loadDocumentBuildContext(projectId: project.id)
            switch documentDraftBuilder.buildKreditfaktura(context: context, title: "Kreditfaktura \(project.name)") {
            case .success(let payload):
                try persistDraftDocument(payload: payload)
                infoMessage = "Черновик Kreditfaktura создан из финализированной Faktura"
                try reloadAll()
            case .incomplete(let reason):
                errorMessage = reason
            }
        } catch {
            errorMessage = "Не удалось создать Kreditfaktura: \(error.localizedDescription)"
        }
    }

    func createAtaDraftFromSelectedProject() {
        guard let project = selectedProject else {
            errorMessage = "Выберите проект для создания ÄTA"
            return
        }
        do {
            let context = try loadDocumentBuildContext(projectId: project.id)
            switch documentDraftBuilder.buildAta(context: context, title: "ÄTA \(project.name)") {
            case .success(let payload):
                try persistDraftDocument(payload: payload)
                infoMessage = "Черновик ÄTA создан из данных проекта"
                try reloadAll()
            case .incomplete(let reason):
                errorMessage = reason
            }
        } catch {
            errorMessage = "Не удалось создать ÄTA: \(error.localizedDescription)"
        }
    }

    func createPaminnelseDraftFromSelectedProject() {
        guard let project = selectedProject else {
            errorMessage = "Выберите проект для создания Påminnelse"
            return
        }
        do {
            let context = try loadDocumentBuildContext(projectId: project.id)
            switch documentDraftBuilder.buildPaminnelse(context: context, title: "Påminnelse \(project.name)") {
            case .success(let payload):
                try persistDraftDocument(payload: payload)
                infoMessage = "Черновик Påminnelse создан из данных задолженности"
                try reloadAll()
            case .incomplete(let reason):
                errorMessage = reason
            }
        } catch {
            errorMessage = "Не удалось создать Påminnelse: \(error.localizedDescription)"
        }
    }

    private func loadDocumentBuildContext(projectId: Int64) throws -> DocumentBuildContext {
        let company = try repository.companies().first
        let project: Project?
        if let cachedProject = projects.first(where: { $0.id == projectId }) {
            project = cachedProject
        } else {
            project = try repository.projects().first(where: { $0.id == projectId })
        }
        let client = project.flatMap { project in
            clients.first(where: { $0.id == project.clientId }) ?? (try? repository.clients().first(where: { $0.id == project.clientId }))
        }
        let estimate = try repository.estimates(projectId: projectId).first
        let estimateLines: [EstimateLine]
        if let estimate {
            estimateLines = try repository.estimateLines(estimateId: estimate.id)
        } else {
            estimateLines = []
        }
        let projectDocuments = try repository.businessDocuments().filter { $0.projectId == projectId }
        let projectDocumentLines = try Dictionary(uniqueKeysWithValues: projectDocuments.map { doc in
            (doc.id, try repository.businessDocumentLines(documentId: doc.id))
        })
        let worksById = Dictionary(uniqueKeysWithValues: works.map { ($0.id, $0) })
        let materialsById = Dictionary(uniqueKeysWithValues: materials.map { ($0.id, $0) })
        return DocumentBuildContext(
            company: company,
            client: client,
            project: project,
            estimate: estimate,
            estimateLines: estimateLines,
            workItemsById: worksById,
            materialItemsById: materialsById,
            businessDocuments: projectDocuments,
            businessDocumentLinesByDocumentId: projectDocumentLines,
            taxProfiles: taxProfiles
        )
    }

    private func persistDraftDocument(payload: DocumentDraftPayload) throws {
        let doc = BusinessDocument(
            id: 0,
            projectId: payload.projectId,
            type: payload.type.rawValue,
            status: DocumentStatus.draft.rawValue,
            number: "",
            title: payload.title,
            issueDate: payload.issueDate,
            dueDate: payload.dueDate,
            customerType: payload.customerType.rawValue,
            taxMode: payload.taxMode.rawValue,
            currency: payload.currency,
            subtotalLabor: payload.subtotalLabor,
            subtotalMaterial: payload.subtotalMaterial,
            subtotalOther: payload.subtotalOther,
            vatRate: payload.vatRate,
            vatAmount: payload.vatAmount,
            rotEligibleLabor: payload.rotEligibleLabor,
            rotReduction: payload.rotReduction,
            totalAmount: payload.totalAmount,
            paidAmount: 0,
            balanceDue: payload.totalAmount,
            relatedDocumentId: payload.relatedDocumentId,
            notes: payload.notes
        )
        _ = try repository.createBusinessDocument(doc, lines: payload.lines)
        try repository.updateProjectStatus(projectId: payload.projectId, status: .calculation)
    }

    func finalizeDocument(_ doc: BusinessDocument) {
        guard !doc.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { errorMessage = "Нельзя финализировать документ без заголовка"; return }
        guard doc.status == DocumentStatus.draft.rawValue else {
            infoMessage = "Документ уже финализирован"
            return
        }
        do {
            let templateId = templates.first?.id
            let sourceEstimateId = try repository.estimates(projectId: doc.projectId).first?.id
            try repository.finalizeDocumentWithSnapshot(documentId: doc.id, templateId: templateId) { finalizedDoc, finalizedLines in
                let relatedDocumentNumber: String?
                if let relatedId = finalizedDoc.relatedDocumentId {
                    relatedDocumentNumber = try repository.businessDocument(documentId: relatedId)?.number
                } else {
                    relatedDocumentNumber = nil
                }
                let project = projectForSnapshot(projectId: finalizedDoc.projectId)
                let context = DocumentSnapshotBuildContext(
                    company: companiesSnapshotValue(),
                    client: clients.first(where: { $0.id == project?.clientId }),
                    project: project,
                    property: propertyForSnapshot(project: project),
                    sourceEstimateId: sourceEstimateId,
                    relatedDocumentNumber: relatedDocumentNumber
                )
                let snapshot = documentSnapshotBuilder.buildImmutableSnapshot(
                    document: finalizedDoc,
                    lines: finalizedLines,
                    context: context,
                    templateId: templateId
                )
                return try documentSnapshotBuilder.serialize(snapshot: snapshot)
            }
            infoMessage = "Документ финализирован"
            try reloadAll()
        } catch {
            errorMessage = "Не удалось финализировать документ: \(error.localizedDescription)"
        }
    }

    func exportDocumentPDF(_ doc: BusinessDocument) {
        let supportedTypes: Set<String> = [
            DocumentType.avtal.rawValue,
            DocumentType.faktura.rawValue,
            DocumentType.kreditfaktura.rawValue,
            DocumentType.ata.rawValue,
            DocumentType.paminnelse.rawValue
        ]
        guard supportedTypes.contains(doc.type) else {
            errorMessage = "Export поддержан только для Avtal/Faktura/Kreditfaktura/ÄTA/Påminnelse"
            return
        }

        do {
            let lines = try repository.businessDocumentLines(documentId: doc.id)
            let snapshots = try repository.documentSnapshots(documentId: doc.id)
            let payload = try documentExportPipeline.buildPayload(document: doc, lines: lines, snapshots: snapshots)

            let identifier = doc.number.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "DRAFT-\(doc.id)" : doc.number
            let defaultFileName = "\(doc.type)-\(identifier).pdf"
            guard let finalURL = try businessDocumentDestinationProvider.chooseDestination(defaultFileName: defaultFileName) else {
                infoMessage = "Экспорт PDF отменён пользователем"
                return
            }

            let tempURL = pdfFileState.temporaryPDFURL(near: finalURL, prefix: "business-document-pending")
            var didMoveToFinal = false
            var backupURL: URL?
            do {
                try businessDocumentPDFGenerator.generateBusinessDocumentPDF(title: payload.title, body: payload.body, saveURL: tempURL)
                try repository.performBusinessDocumentPDFExportWrites(
                    payload: AppRepository.BusinessDocumentPDFExportWritePayload(
                        exportKind: "business_document_pdf",
                        exportScope: "document_\(doc.id)_\(doc.type)_\(payload.source.rawValue)",
                        finalPath: finalURL.path
                    ),
                    beforeCommit: {
                        backupURL = try self.pdfFileState.backupExistingFileIfNeeded(at: finalURL)
                        try self.businessDocumentExportFailureInjection?.beforePromoteFailure?()
                        try self.pdfFileState.promotePreparedPDF(from: tempURL, to: finalURL)
                        didMoveToFinal = true
                    },
                    failureInjection: self.businessDocumentExportFailureInjection?.persistentWriteFailure
                )
            } catch {
                var recoveryFailures: [String] = []
                if didMoveToFinal || backupURL != nil {
                    do {
                        try pdfFileState.recoverAfterFailedCommit(finalURL: finalURL, backupURL: backupURL, didPromote: didMoveToFinal)
                    } catch {
                        recoveryFailures.append(error.localizedDescription)
                    }
                }
                do {
                    try pdfFileState.removeTemporaryFileIfPresent(at: tempURL)
                } catch {
                    recoveryFailures.append("не удалось удалить временный PDF: \(error.localizedDescription)")
                }
                if !recoveryFailures.isEmpty {
                    throw NSError(domain: "PDFRecovery", code: 2, userInfo: [NSLocalizedDescriptionKey: "Ошибка операции и неполное восстановление: \(recoveryFailures.joined(separator: " | "))"])
                }
                throw error
            }

            try pdfFileState.removeTemporaryFileIfPresent(at: tempURL)
            var backupCleanupWarning: String?
            if let backupURL {
                do {
                    try pdfFileState.cleanupBackupAfterCommit(backupURL: backupURL)
                } catch {
                    backupCleanupWarning = "PDF экспортирован, но cleanup backup не завершился: \(error.localizedDescription)"
                }
            }
            var refreshWarning: String?
            do {
                try reloadAll()
            } catch {
                refreshWarning = "PDF экспортирован, но обновление экрана не выполнено: \(error.localizedDescription)"
            }
            if let backupCleanupWarning, let refreshWarning {
                infoMessage = "\(backupCleanupWarning) | \(refreshWarning)"
            } else if let backupCleanupWarning {
                infoMessage = backupCleanupWarning
            } else if let refreshWarning {
                infoMessage = refreshWarning
            } else {
                infoMessage = "PDF экспортирован (\(payload.source.rawValue))"
            }
        } catch {
            errorMessage = "Не удалось экспортировать PDF: \(error.localizedDescription)"
        }
    }

    private func companiesSnapshotValue() -> Company? {
        if let company = try? repository.companies().first {
            return company
        }
        return nil
    }

    private func projectForSnapshot(projectId: Int64) -> Project? {
        projects.first(where: { $0.id == projectId }) ?? (try? repository.projects().first(where: { $0.id == projectId }))
    }

    private func propertyForSnapshot(project: Project?) -> PropertyObject? {
        guard let project else { return nil }
        return properties.first(where: { $0.id == project.propertyId }) ?? (try? repository.properties().first(where: { $0.id == project.propertyId }))
    }

    @discardableResult
    func addPayment(documentId: Int64, amount: Double, method: String, reference: String) -> Bool {
        do {
            try repository.registerPayment(documentId: documentId, amount: amount, method: method, reference: reference)
            infoMessage = "Оплата добавлена"
            try reloadAll()
            return true
        } catch {
            errorMessage = "Не удалось добавить оплату: \(error.localizedDescription)"
            return false
        }
    }

    func backupDatabase() {
        do {
            try backupService.backupViaDialog()
            infoMessage = "Backup успешно создан"
        } catch {
            if let backupError = error as? BackupServiceError {
                infoMessage = backupError.localizedDescription
            } else {
                errorMessage = "Backup завершился ошибкой: \(error.localizedDescription)"
            }
        }
    }

    func restoreDatabase() {
        do {
            try backupService.restoreViaDialog()
            infoMessage = "База восстановлена"
            try reloadAll()
        } catch {
            if let backupError = error as? BackupServiceError {
                infoMessage = backupError.localizedDescription
            } else {
                errorMessage = "Restore завершился ошибкой: \(error.localizedDescription)"
            }
        }
    }

    func dataLocationPath() -> String {
        backupService.dataLocation().path
    }

    func importClientsFromCSV(raw: String) {
        let rows = stage5Service.parseCSV(raw)
        let report = stage5Service.buildClientImportReport(rows: rows, existing: clients)
        do {
            for action in report.actions {
                switch action {
                case .create(let client):
                    _ = try repository.insertClient(client)
                case .update(let client):
                    try repository.updateClient(client)
                case .skip, .invalid:
                    continue
                }
            }
            if report.invalid > 0 {
                let details = report.issues.prefix(3).map { "строка \($0.row): \($0.message)" }.joined(separator: "; ")
                errorMessage = "Импорт завершён с invalid: \(report.invalid). \(details)"
            } else {
                errorMessage = nil
            }
            infoMessage = "Импортировано: created \(report.created), updated \(report.updated), skipped \(report.skipped), invalid \(report.invalid)"
            try reloadAll()
        } catch {
            errorMessage = "Импорт клиентов завершился ошибкой: \(error.localizedDescription)"
        }
    }

    func refreshProjectProfitability(projectId: Int64, showMissingEstimateError: Bool = true) {
        do {
            guard let estimate = try repository.estimates(projectId: projectId).first else {
                if showMissingEstimateError {
                    errorMessage = "Нет сметы для расчёта прибыльности проекта"
                }
                selectedProjectProfitability = nil
                return
            }
            let lines = try repository.estimateLines(estimateId: estimate.id)
            let docs = businessDocuments.filter { $0.projectId == projectId }
            selectedProjectProfitability = stage5Service.profitability(projectId: projectId, estimateLines: lines, materials: materials, documents: docs)
        } catch {
            errorMessage = "Не удалось рассчитать прибыльность: \(error.localizedDescription)"
        }
    }

    func archiveProject(_ projectId: Int64) {
        do {
            try repository.setProjectLifecycle(projectId: projectId, status: "archived", note: "manual archive")
            try reloadAll()
        } catch { errorMessage = "Archive error: \(error.localizedDescription)" }
    }

    func restoreProjectFromArchive(_ projectId: Int64) {
        do {
            try repository.setProjectLifecycle(projectId: projectId, status: "active", note: "manual restore")
            try reloadAll()
        } catch { errorMessage = "Restore error: \(error.localizedDescription)" }
    }

    func addInternalNote(projectId: Int64, type: String, text: String, pinned: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Текст заметки не может быть пустым"
            return
        }
        do {
            try repository.addProjectNote(projectId: projectId, type: type, text: trimmed, pinned: pinned)
            projectNotes = try repository.projectNotes(projectId: projectId)
        } catch { errorMessage = "Note save error: \(error.localizedDescription)" }
    }

    func exportProjectBundle(projectId: Int64) {
        #if canImport(AppKit)
        do {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            panel.prompt = "Выбрать"
            guard panel.runModal() == .OK, let folder = panel.url else {
                infoMessage = "Export bundle отменён пользователем"
                return
            }
            let projectDocs = businessDocuments.filter { $0.projectId == projectId }
            let lines = projectDocs.map { "\($0.number),\($0.type),\($0.totalAmount),\($0.paidAmount),\($0.balanceDue)" }.joined(separator: "\n")
            let csv = "number,type,total,paid,outstanding\n" + lines
            let timestamp = Int(Date().timeIntervalSince1970)
            let exportFolderName = "smeta-project-\(projectId)-\(timestamp)"
            let stagingFolder = try exportArtifacts.prepareProjectBundleStagingFolder(
                dataFolder: repository.db.dataFolder(),
                projectId: projectId,
                timestamp: timestamp
            )
            let csvPath = stagingFolder.appendingPathComponent("invoice_register.csv")
            guard let csvData = csv.data(using: .utf8) else {
                errorMessage = "Не удалось закодировать invoice_register.csv в UTF-8"
                return
            }
            try csvData.write(to: csvPath)
            let manifest = stage5Service.buildExportManifest(appVersion: "stage5", schemaVersion: "5", files: ["invoice_register.csv"])
            guard let manifestData = manifest.data(using: .utf8) else {
                errorMessage = "Не удалось закодировать manifest.json в UTF-8"
                return
            }
            try manifestData.write(to: stagingFolder.appendingPathComponent("manifest.json"))
            let exportFolder = folder.appendingPathComponent(exportFolderName, isDirectory: true)
            try FileManager.default.moveItem(at: stagingFolder, to: exportFolder)
            try repository.logExport(kind: "project_bundle", scope: "project_\(projectId)", path: exportFolder.path)
            NSWorkspace.shared.open(exportFolder)
            infoMessage = "Export bundle создан"
        } catch { errorMessage = "Export error: \(error.localizedDescription)" }
        #else
        errorMessage = "Export bundle доступен только на AppKit-платформах"
        #endif
    }

    func resetDemoData() {
        do {
            try repository.resetDemoData()
            try reloadAll()
            infoMessage = "Demo data reset выполнен"
        } catch { errorMessage = "Reset error: \(error.localizedDescription)" }
    }

    func clearTempExports() {
        let report = exportArtifacts.cleanupManagedArtifacts(dataFolder: repository.db.dataFolder())
        if report.isNoOp {
            infoMessage = "Временных export artifacts не найдено"
            return
        }
        if report.failures.isEmpty {
            infoMessage = "Очистка export artifacts завершена: удалено \(report.deletedCount)"
            return
        }
        let details = report.failures.map { "\($0.path): \($0.reason)" }.joined(separator: " | ")
        if report.deletedCount > 0 {
            errorMessage = "Очистка export artifacts частично выполнена: удалено \(report.deletedCount), ошибок \(report.failures.count). \(details)"
        } else {
            errorMessage = "Очистка export artifacts не выполнена: \(details)"
        }
    }

}

private extension AppRepository {
    func fetchWithClientProperties() throws -> [PropertyObject] {
        try properties(for: nil)
    }
}
