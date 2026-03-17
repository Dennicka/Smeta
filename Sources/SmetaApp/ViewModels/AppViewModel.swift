import Foundation
import AppKit

@MainActor
final class AppViewModel: ObservableObject {
    @Published var clients: [Client] = []
    @Published var properties: [PropertyObject] = []
    @Published var projects: [Project] = []
    @Published var rooms: [Room] = []
    @Published var works: [WorkCatalogItem] = []
    @Published var materials: [MaterialCatalogItem] = []
    @Published var speedProfiles: [SpeedProfile] = []
    @Published var templates: [DocumentTemplate] = []
    @Published var generatedDocuments: [GeneratedDocument] = []
    @Published var selectedProject: Project?
    @Published var searchText: String = ""

    @Published var selectedWorksByRoom: [Int64: [WorkCatalogItem]] = [:]
    @Published var selectedMaterialsByRoom: [Int64: [MaterialCatalogItem]] = [:]

    @Published var laborRatePerHour: Double = 600
    @Published var overheadCoefficient: Double = 1.15
    @Published var selectedSpeedId: Int64 = 0
    @Published var calculationResult: CalculationResult?

    private let repository: AppRepository
    private let calculator = EstimateCalculator()
    private let pdfService = PDFDocumentService()
    private let backupService: BackupService

    init(repository: AppRepository, backupService: BackupService) {
        self.repository = repository
        self.backupService = backupService
    }

    func bootstrap() {
        do {
            try repository.seedIfNeeded()
            try reloadAll()
            selectedProject = projects.first
            selectedSpeedId = speedProfiles.first?.id ?? 0
        } catch {
            print("Bootstrap error: \(error)")
        }
    }

    func reloadAll() throws {
        clients = try repository.clients()
        properties = try repository.fetchWithClientProperties()
        projects = try repository.projects()
        rooms = try repository.rooms()
        works = try repository.workItems()
        materials = try repository.materialItems()
        speedProfiles = try repository.speedProfiles()
        templates = try repository.templates()
        generatedDocuments = try repository.generatedDocuments()
    }

    func addClient(name: String, email: String, phone: String, address: String) {
        do { _ = try repository.insertClient(Client(id: 0, name: name, email: email, phone: phone, address: address)); try reloadAll() } catch { print(error) }
    }

    func addProperty(clientId: Int64, name: String, address: String) {
        do { _ = try repository.insertProperty(PropertyObject(id: 0, clientId: clientId, name: name, address: address)); try reloadAll() } catch { print(error) }
    }

    func addProject(clientId: Int64, propertyId: Int64, name: String) {
        do {
            let speed = selectedSpeedId == 0 ? (speedProfiles.first?.id ?? 1) : selectedSpeedId
            _ = try repository.insertProject(Project(id: 0, clientId: clientId, propertyId: propertyId, name: name, speedProfileId: speed, createdAt: Date()))
            try reloadAll()
        } catch { print(error) }
    }

    func addRoom(projectId: Int64, name: String, area: Double, height: Double) {
        do { _ = try repository.insertRoom(Room(id: 0, projectId: projectId, name: name, area: area, height: height)); try reloadAll() } catch { print(error) }
    }

    func addWork(_ item: WorkCatalogItem) { do { _ = try repository.insertWorkItem(item); try reloadAll() } catch { print(error) } }
    func updateWork(_ item: WorkCatalogItem) { do { try repository.updateWorkItem(item); try reloadAll() } catch { print(error) } }
    func addMaterial(_ item: MaterialCatalogItem) { do { _ = try repository.insertMaterialItem(item); try reloadAll() } catch { print(error) } }
    func updateMaterial(_ item: MaterialCatalogItem) { do { try repository.updateMaterialItem(item); try reloadAll() } catch { print(error) } }
    func addSpeed(_ item: SpeedProfile) { do { _ = try repository.insertSpeedProfile(item); try reloadAll() } catch { print(error) } }
    func updateSpeed(_ item: SpeedProfile) { do { try repository.updateSpeedProfile(item); try reloadAll() } catch { print(error) } }
    func addTemplate(_ item: DocumentTemplate) { do { _ = try repository.insertTemplate(item); try reloadAll() } catch { print(error) } }
    func updateTemplate(_ item: DocumentTemplate) { do { try repository.updateTemplate(item); try reloadAll() } catch { print(error) } }

    func calculate() {
        guard let project = selectedProject else { return }
        let projectRooms = rooms.filter { $0.projectId == project.id }
        guard let speed = speedProfiles.first(where: { $0.id == selectedSpeedId }) ?? speedProfiles.first else { return }
        calculationResult = calculator.calculate(rooms: projectRooms,
                                                 selectedWorks: selectedWorksByRoom,
                                                 selectedMaterials: selectedMaterialsByRoom,
                                                 speed: speed,
                                                 laborRate: laborRatePerHour,
                                                 overhead: overheadCoefficient)
    }

    func saveEstimateAndGenerateDocument() {
        guard let project = selectedProject,
              let speed = speedProfiles.first(where: { $0.id == selectedSpeedId }) ?? speedProfiles.first,
              let calc = calculationResult,
              let template = templates.first,
              let company = try? repository.companies().first,
              let client = clients.first(where: { $0.id == project.clientId })
        else { return }

        do {
            let estimateId = try repository.insertEstimate(Estimate(id: 0, projectId: project.id, speedProfileId: speed.id, laborRatePerHour: laborRatePerHour, overheadCoefficient: overheadCoefficient, createdAt: Date()))

            for row in calc.rows {
                if let room = rooms.first(where: { $0.name == row.roomName }) {
                    let work = works.first(where: { $0.name == row.itemName })
                    let material = materials.first(where: { $0.name == row.itemName })
                    try repository.insertEstimateLine(EstimateLine(id: 0, estimateId: estimateId, roomId: room.id, workItemId: work?.id, materialItemId: material?.id, quantity: row.quantity, unitPrice: row.total, coefficient: row.coefficient, type: work == nil ? "material" : "work"))
                }
            }

            let panel = NSSavePanel()
            panel.nameFieldStringValue = "Offert-\(project.name).pdf"
            panel.allowedFileTypes = ["pdf"]
            if panel.runModal() == .OK, let url = panel.url {
                try pdfService.generateOffertSwedish(template: template, company: company, client: client, project: project, result: calc, saveURL: url)
                try repository.insertGeneratedDocument(GeneratedDocument(id: 0, estimateId: estimateId, templateId: template.id, title: "Offert \(project.name)", path: url.path, generatedAt: Date()))
                try reloadAll()
            }
        } catch { print(error) }
    }

    func backupDatabase() { do { try backupService.backupViaDialog() } catch { print(error) } }
    func restoreDatabase() { do { try backupService.restoreViaDialog(); try reloadAll() } catch { print(error) } }
}

private extension AppRepository {
    func fetchWithClientProperties() throws -> [PropertyObject] {
        try properties(for: nil)
    }
}
