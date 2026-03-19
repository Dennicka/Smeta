import Foundation
import SmetaCore
#if canImport(AppKit)
import AppKit
#endif

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
    private let stage5Service = Stage5Service()
    private let documentDraftBuilder = DocumentDraftBuilder()
    private let documentSnapshotBuilder = DocumentSnapshotBuilder()
    private let documentExportPipeline = DocumentExportPipeline()
    private let pdfFileState = PDFFileStateOrchestrator()
    private let exportArtifacts = ExportArtifactCoordinator()

    init(repository: AppRepository, backupService: BackupService) {
        self.repository = repository
        self.backupService = backupService
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
        if projects.count >= 2 { return }
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
            speedProfiles = try repository.speedProfiles()
            templates = try repository.templates()
            generatedDocuments = try repository.generatedDocuments()
            businessDocuments = try repository.businessDocuments()
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
        let documentSeries: [DocumentSeries]
        let taxProfiles: [TaxProfile]
        let suppliers: [Supplier]
        let receivableBuckets: [ReceivableBucket]
        let selectedProjectProfitability: ProjectProfitability?
        let projectNotes: [ProjectNote]
        let selectedProject: Project?
        let selectedSpeedId: Int64
        let calculationRules: CalculationRules

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
                          documentSeries: vm.documentSeries,
                          taxProfiles: vm.taxProfiles,
                          suppliers: vm.suppliers,
                          receivableBuckets: vm.receivableBuckets,
                          selectedProjectProfitability: vm.selectedProjectProfitability,
                          projectNotes: vm.projectNotes,
                          selectedProject: vm.selectedProject,
                          selectedSpeedId: vm.selectedSpeedId,
                          calculationRules: vm.calculationRules)
        }

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
            vm.documentSeries = documentSeries
            vm.taxProfiles = taxProfiles
            vm.suppliers = suppliers
            vm.receivableBuckets = receivableBuckets
            vm.selectedProjectProfitability = selectedProjectProfitability
            vm.projectNotes = projectNotes
            vm.selectedProject = selectedProject
            vm.selectedSpeedId = selectedSpeedId
            vm.calculationRules = calculationRules
        }
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
            let speed = resolvedSpeedIdForNewProject()
            let projectId = try repository.insertProject(Project(id: 0, clientId: clientId, propertyId: propertyId, name: trimmed, speedProfileId: speed, createdAt: Date()))
            infoMessage = "Проект создан"
            try reloadAll()
            if let inserted = projects.first(where: { $0.id == projectId }) {
                try selectProject(inserted)
            }
        } catch {
            errorMessage = "Не удалось создать проект: \(error.localizedDescription)"
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
        do { try repository.addOpening(Opening(id: 0, roomId: roomId, surfaceId: nil, type: type, name: name, width: width, height: height, count: count, subtractFromWallArea: subtract)); try reloadAll() } catch { present(error: error, prefix: "Не удалось добавить проём") }
    }

    func addWork(_ item: WorkCatalogItem) { do { _ = try repository.insertWorkItem(item); try reloadAll() } catch { present(error: error, prefix: "Не удалось добавить работу") } }
    func updateWork(_ item: WorkCatalogItem) { do { try repository.updateWorkItem(item); try reloadAll() } catch { present(error: error, prefix: "Не удалось обновить работу") } }
    func addMaterial(_ item: MaterialCatalogItem) { do { _ = try repository.insertMaterialItem(item); try reloadAll() } catch { present(error: error, prefix: "Не удалось добавить материал") } }
    func updateMaterial(_ item: MaterialCatalogItem) { do { try repository.updateMaterialItem(item); try reloadAll() } catch { present(error: error, prefix: "Не удалось обновить материал") } }
    func addSpeed(_ item: SpeedProfile) { do { _ = try repository.insertSpeedProfile(item); try reloadAll() } catch { present(error: error, prefix: "Не удалось добавить профиль скорости") } }
    func updateSpeed(_ item: SpeedProfile) { do { try repository.updateSpeedProfile(item); try reloadAll() } catch { present(error: error, prefix: "Не удалось обновить профиль скорости") } }
    func addTemplate(_ item: DocumentTemplate) { do { _ = try repository.insertTemplate(item); try reloadAll() } catch { present(error: error, prefix: "Не удалось добавить шаблон") } }
    func updateTemplate(_ item: DocumentTemplate) { do { try repository.updateTemplate(item); try reloadAll() } catch { present(error: error, prefix: "Не удалось обновить шаблон") } }

    func calculate() {
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

            #if canImport(AppKit)
            let panel = NSSavePanel()
            panel.nameFieldStringValue = "Offert-\(project.name).pdf"
            panel.allowedFileTypes = ["pdf"]
            guard panel.runModal() == .OK, let finalURL = panel.url else {
                infoMessage = "Генерация Offert отменена пользователем"
                return
            }
            #else
            throw NSError(domain: "OffertGeneration", code: 1, userInfo: [NSLocalizedDescriptionKey: "Генерация Offert доступна только на AppKit-платформах"])
            #endif

            let tempURL = pdfFileState.temporaryPDFURL(near: finalURL, prefix: "offert-pending")
            var didMoveToFinal = false
            var backupURL: URL?
            var committed = false
            var beganTransaction = false
            do {
                try pdfService.generateOffertSwedish(template: template, company: company, client: client, project: project, result: calc, saveURL: tempURL)
                try repository.db.execute("BEGIN IMMEDIATE TRANSACTION")
                beganTransaction = true

                let estimateId = try repository.insertEstimate(Estimate(id: 0, projectId: project.id, speedProfileId: speed.id, laborRatePerHour: laborRatePerHour, overheadCoefficient: overheadCoefficient, createdAt: Date()))
                for row in calc.rows {
                    let estimateLine = try EstimateLineIdentityValidator.makeEstimateLine(
                        estimateId: estimateId,
                        row: row,
                        validRoomIds: validRoomIds
                    )
                    try repository.insertEstimateLine(estimateLine)
                }
                try repository.insertGeneratedDocument(GeneratedDocument(id: 0, estimateId: estimateId, templateId: template.id, title: "Offert \(project.name)", path: finalURL.path, generatedAt: Date()))
                backupURL = try pdfFileState.backupExistingFileIfNeeded(at: finalURL)
                try pdfFileState.promotePreparedPDF(from: tempURL, to: finalURL)
                didMoveToFinal = true
                try repository.db.execute("COMMIT")
                committed = true
            } catch {
                var recoveryFailures: [String] = []
                if beganTransaction && !committed {
                    do {
                        try repository.db.execute("ROLLBACK")
                    } catch {
                        recoveryFailures.append("rollback БД не выполнен: \(error.localizedDescription)")
                    }
                }
                if beganTransaction {
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

            #if canImport(AppKit)
            let panel = NSSavePanel()
            let identifier = doc.number.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "DRAFT-\(doc.id)" : doc.number
            panel.nameFieldStringValue = "\(doc.type)-\(identifier).pdf"
            panel.allowedFileTypes = ["pdf"]
            guard panel.runModal() == .OK, let finalURL = panel.url else {
                infoMessage = "Экспорт PDF отменён пользователем"
                return
            }
            #else
            throw NSError(domain: "DocumentExport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Экспорт PDF доступен только на AppKit-платформах"])
            #endif

            let tempURL = pdfFileState.temporaryPDFURL(near: finalURL, prefix: "business-document-pending")
            var didMoveToFinal = false
            var backupURL: URL?
            var committed = false
            var beganTransaction = false
            do {
                try pdfService.generateBusinessDocumentPDF(title: payload.title, body: payload.body, saveURL: tempURL)
                try repository.db.execute("BEGIN IMMEDIATE TRANSACTION")
                beganTransaction = true

                try repository.logExport(kind: "business_document_pdf", scope: "document_\(doc.id)_\(doc.type)_\(payload.source.rawValue)", path: finalURL.path)
                backupURL = try pdfFileState.backupExistingFileIfNeeded(at: finalURL)
                try pdfFileState.promotePreparedPDF(from: tempURL, to: finalURL)
                didMoveToFinal = true
                try repository.db.execute("COMMIT")
                committed = true
            } catch {
                var recoveryFailures: [String] = []
                if beganTransaction && !committed {
                    do {
                        try repository.db.execute("ROLLBACK")
                    } catch {
                        recoveryFailures.append("rollback БД не выполнен: \(error.localizedDescription)")
                    }
                }
                if beganTransaction {
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
