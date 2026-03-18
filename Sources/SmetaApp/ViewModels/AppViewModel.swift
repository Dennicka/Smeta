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
    @Published var businessDocuments: [BusinessDocument] = []
    @Published var documentSeries: [DocumentSeries] = []
    @Published var taxProfiles: [TaxProfile] = []
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
            try repository.seedStage2Defaults()
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
        businessDocuments = try repository.businessDocuments()
        documentSeries = try repository.documentSeries()
        taxProfiles = try repository.taxProfiles()
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



    func createDraftDocument(type: DocumentType, projectId: Int64, title: String, customerType: CustomerType, taxMode: TaxMode, lines: [BusinessDocumentLine], rotPercent: Double = 0) {
        do {
            let labor = lines.filter { $0.lineType == "labor" }.reduce(0) { $0 + $1.total }
            let material = lines.filter { $0.lineType == "material" }.reduce(0) { $0 + $1.total }
            let other = lines.filter { $0.lineType == "other" }.reduce(0) { $0 + $1.total }
            let vatRate = taxMode == .reverseCharge ? 0 : 0.25
            let rotEligible = lines.filter { $0.isRotEligible }.reduce(0) { $0 + $1.total }
            let rotReduction = rotEligible * rotPercent
            let subtotal = labor + material + other
            let vatAmount = subtotal * vatRate
            let total = subtotal + vatAmount - rotReduction
            let doc = BusinessDocument(id: 0, projectId: projectId, type: type.rawValue, status: DocumentStatus.draft.rawValue, number: "", title: title, issueDate: Date(), dueDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()), customerType: customerType.rawValue, taxMode: taxMode.rawValue, currency: "SEK", subtotalLabor: labor, subtotalMaterial: material, subtotalOther: other, vatRate: vatRate, vatAmount: vatAmount, rotEligibleLabor: rotEligible, rotReduction: rotReduction, totalAmount: total, paidAmount: 0, balanceDue: total, relatedDocumentId: nil, notes: "")
            _ = try repository.createBusinessDocument(doc, lines: lines)
            try repository.updateProjectStatus(projectId: projectId, status: .calculation)
            try reloadAll()
        } catch { print(error) }
    }

    func finalizeDocument(_ doc: BusinessDocument) {
        do {
            let json = """{"title":"\(doc.title)","total":\(doc.totalAmount),"vat":\(doc.vatAmount),"rotReduction":\(doc.rotReduction)}"""
            try repository.finalizeDocument(documentId: doc.id, templateId: templates.first?.id, snapshotJSON: json)
            try reloadAll()
        } catch { print(error) }
    }

    func addPayment(documentId: Int64, amount: Double, method: String, reference: String) {
        do { try repository.registerPayment(documentId: documentId, amount: amount, method: method, reference: reference); try reloadAll() } catch { print(error) }
    }

    func backupDatabase() { do { try backupService.backupViaDialog() } catch { print(error) } }
    func restoreDatabase() { do { try backupService.restoreViaDialog(); try reloadAll() } catch { print(error) } }
}

private extension AppRepository {
    func fetchWithClientProperties() throws -> [PropertyObject] {
        try properties(for: nil)
    }
}
