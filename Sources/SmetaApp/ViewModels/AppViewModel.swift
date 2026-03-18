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
    @Published var surfacesByRoom: [Int64: [Surface]] = [:]
    @Published var openingsByRoom: [Int64: [Opening]] = [:]
    @Published var pricingMode: PricingMode = .fixed
    @Published var templates: [DocumentTemplate] = []
    @Published var generatedDocuments: [GeneratedDocument] = []
    @Published var businessDocuments: [BusinessDocument] = []
    @Published var documentSeries: [DocumentSeries] = []
    @Published var taxProfiles: [TaxProfile] = []
    @Published var selectedProject: Project?
    @Published var searchText: String = ""
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    @Published var selectedWorksByRoom: [Int64: [WorkCatalogItem]] = [:]
    @Published var selectedMaterialsByRoom: [Int64: [MaterialCatalogItem]] = [:]

    @Published var laborRatePerHour: Double = 600
    @Published var overheadCoefficient: Double = 1.15
    @Published var selectedSpeedId: Int64 = 0
    @Published var calculationResult: CalculationResult?

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
        surfacesByRoom = Dictionary(uniqueKeysWithValues: try rooms.map { ($0.id, try repository.surfaces(roomId: $0.id)) })
        openingsByRoom = Dictionary(uniqueKeysWithValues: try rooms.map { ($0.id, try repository.openings(roomId: $0.id)) })
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
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { errorMessage = "Имя клиента обязательно"; return }
        do {
            _ = try repository.insertClient(Client(id: 0, name: trimmed, email: email, phone: phone, address: address))
            infoMessage = "Клиент сохранён"
            try reloadAll()
        } catch {
            errorMessage = "Не удалось сохранить клиента: \(error.localizedDescription)"
        }
    }

    func addProperty(clientId: Int64, name: String, address: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { errorMessage = "Название объекта обязательно"; return }
        do {
            _ = try repository.insertProperty(PropertyObject(id: 0, clientId: clientId, name: trimmed, address: address))
            infoMessage = "Объект сохранён"
            try reloadAll()
        } catch {
            errorMessage = "Не удалось сохранить объект: \(error.localizedDescription)"
        }
    }

    func addProject(clientId: Int64, propertyId: Int64, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { errorMessage = "Название проекта обязательно"; return }
        do {
            let speed = selectedSpeedId == 0 ? (speedProfiles.first?.id ?? 1) : selectedSpeedId
            _ = try repository.insertProject(Project(id: 0, clientId: clientId, propertyId: propertyId, name: trimmed, speedProfileId: speed, createdAt: Date()))
            infoMessage = "Проект создан"
            try reloadAll()
        } catch {
            errorMessage = "Не удалось создать проект: \(error.localizedDescription)"
        }
    }

    func addRoom(projectId: Int64, name: String, area: Double, height: Double, length: Double = 0, width: Double = 0, manualWallAdjustment: Double = 0, roomType: String = "") {
        let floorArea = area > 0 ? area : (length > 0 && width > 0 ? length * width : 0)
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { errorMessage = "Название помещения обязательно"; return }
        guard floorArea > 0, height > 0 else { errorMessage = "Площадь и высота должны быть больше нуля"; return }
        let wallAuto = length > 0 && width > 0 ? (2 * (length + width) * height) : floorArea * 2.8
        let room = Room(id: 0, projectId: projectId, name: name, area: floorArea, height: height, roomType: roomType, length: length, width: width, ceilingArea: floorArea, wallAreaAuto: wallAuto, wallAreaManualAdjustment: manualWallAdjustment)
        do {
            let roomId = try repository.insertRoom(room)
            try repository.replaceSurfaces(roomId: roomId, surfaces: [
                Surface(id: 0, roomId: roomId, type: "wall", name: "Стены", area: wallAuto, perimeter: length > 0 && width > 0 ? 2 * (length + width) : 0, isCustom: false, source: "auto", manualAdjustment: manualWallAdjustment),
                Surface(id: 0, roomId: roomId, type: "ceiling", name: "Потолок", area: floorArea, perimeter: 0, isCustom: false, source: "auto", manualAdjustment: 0),
                Surface(id: 0, roomId: roomId, type: "floor", name: "Пол", area: floorArea, perimeter: 0, isCustom: false, source: "auto", manualAdjustment: 0),
                Surface(id: 0, roomId: roomId, type: "plinth", name: "Плинтус", area: 0, perimeter: length > 0 && width > 0 ? 2 * (length + width) : 0, isCustom: false, source: "auto", manualAdjustment: 0)
            ])
            try reloadAll()
        } catch { errorMessage = "Не удалось сохранить помещение: \(error.localizedDescription)" }
    }

    func duplicateRoom(_ room: Room) {
        addRoom(projectId: room.projectId, name: room.name + " (копия)", area: room.area, height: room.height, length: room.length, width: room.width, manualWallAdjustment: room.wallAreaManualAdjustment, roomType: room.roomType)
    }

    func addOpening(roomId: Int64, type: String, name: String, width: Double, height: Double, count: Int, subtract: Bool) {
        do { try repository.addOpening(Opening(id: 0, roomId: roomId, surfaceId: nil, type: type, name: name, width: width, height: height, count: count, subtractFromWallArea: subtract)); try reloadAll() } catch { print(error) }
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
            let vatRate = taxMode == .reverseCharge ? 0 : 0.25
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

    func finalizeDocument(_ doc: BusinessDocument) {
        guard !doc.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { errorMessage = "Нельзя финализировать документ без заголовка"; return }
        do {
            let json = """{"title":"\(doc.title)","total":\(doc.totalAmount),"vat":\(doc.vatAmount),"rotReduction":\(doc.rotReduction)}"""
            try repository.finalizeDocument(documentId: doc.id, templateId: templates.first?.id, snapshotJSON: json)
            infoMessage = "Документ финализирован"
            try reloadAll()
        } catch {
            errorMessage = "Не удалось финализировать документ: \(error.localizedDescription)"
        }
    }

    func addPayment(documentId: Int64, amount: Double, method: String, reference: String) {
        do {
            try repository.registerPayment(documentId: documentId, amount: amount, method: method, reference: reference)
            infoMessage = "Оплата добавлена"
            try reloadAll()
        } catch {
            errorMessage = "Не удалось добавить оплату: \(error.localizedDescription)"
        }
    }

    func backupDatabase() {
        do {
            try backupService.backupViaDialog()
            infoMessage = "Backup успешно создан"
        } catch {
            errorMessage = "Backup завершился ошибкой: \(error.localizedDescription)"
        }
    }

    func restoreDatabase() {
        do {
            try backupService.restoreViaDialog()
            infoMessage = "База восстановлена"
            try reloadAll()
        } catch {
            errorMessage = "Restore завершился ошибкой: \(error.localizedDescription)"
        }
    }

    func dataLocationPath() -> String {
        backupService.dataLocation().path
    }
}

private extension AppRepository {
    func fetchWithClientProperties() throws -> [PropertyObject] {
        try properties(for: nil)
    }
}
