import Foundation

protocol PersistableEntity: Identifiable {
    var id: Int64 { get set }
}

struct Company: PersistableEntity {
    var id: Int64
    var name: String
    var orgNumber: String
    var email: String
    var phone: String
}

struct Client: PersistableEntity {
    var id: Int64
    var name: String
    var email: String
    var phone: String
    var address: String
}

struct PropertyObject: PersistableEntity {
    var id: Int64
    var clientId: Int64
    var name: String
    var address: String
    var objectType: String = ""
    var notes: String = ""
    var photoPath: String = ""
    var totalArea: Double = 0
    var accessLevel: String = ""
    var internalComment: String = ""
}

struct Project: PersistableEntity {
    var id: Int64
    var clientId: Int64
    var propertyId: Int64
    var name: String
    var speedProfileId: Int64
    var createdAt: Date
    var pricingMode: String = PricingMode.fixed.rawValue
    var isDraft: Bool = true
}

struct Room: PersistableEntity {
    var id: Int64
    var projectId: Int64
    var name: String
    var area: Double
    var height: Double
    var roomType: String = ""
    var length: Double = 0
    var width: Double = 0
    var ceilingArea: Double = 0
    var wallAreaAuto: Double = 0
    var wallAreaManualAdjustment: Double = 0
    var surfaceCondition: String = "standard"
    var notes: String = ""
    var photoPath: String = ""
    var roomTemplateId: Int64? = nil

    var floorArea: Double { area }
    var wallAreaTotal: Double { max(0, wallAreaAuto + wallAreaManualAdjustment) }
}

struct Surface: PersistableEntity {
    var id: Int64
    var roomId: Int64
    var type: String
    var name: String
    var area: Double
    var perimeter: Double
    var isCustom: Bool
    var source: String
    var manualAdjustment: Double

    var effectiveArea: Double { max(0, area + manualAdjustment) }
}

struct Opening: PersistableEntity {
    var id: Int64
    var roomId: Int64
    var surfaceId: Int64?
    var type: String
    var name: String
    var width: Double
    var height: Double
    var count: Int
    var subtractFromWallArea: Bool

    var area: Double { width * height * Double(count) }
    var slopeArea: Double { 2 * (width + height) * 0.15 * Double(count) }
}

struct TrimElement: PersistableEntity {
    var id: Int64
    var roomId: Int64
    var type: String
    var length: Double
    var quantity: Int
    var notes: String
}

struct RoomTemplate: PersistableEntity {
    var id: Int64
    var name: String
    var roomType: String
    var defaultLength: Double
    var defaultWidth: Double
    var defaultHeight: Double
    var notes: String
}

struct WorkCategory: PersistableEntity {
    var id: Int64
    var name: String
    var sortOrder: Int
}

struct WorkSubcategory: PersistableEntity {
    var id: Int64
    var categoryId: Int64
    var name: String
    var sortOrder: Int
}

struct MaterialCategory: PersistableEntity {
    var id: Int64
    var name: String
    var sortOrder: Int
}

struct MaterialUsageNorm: PersistableEntity {
    var id: Int64
    var workItemId: Int64
    var materialItemId: Int64
    var usagePerUnit: Double
    var notes: String
}

struct WorkSpeedRule: PersistableEntity {
    var id: Int64
    var workItemId: Int64
    var surfaceType: String
    var slow: Double
    var medium: Double
    var fast: Double
}

struct ComplexityRule: PersistableEntity {
    var id: Int64
    var name: String
    var coefficient: Double
    var enabledByDefault: Bool
    var appliesToSurfaceType: String
}

struct SurfaceConditionProfile: PersistableEntity {
    var id: Int64
    var name: String
    var coefficient: Double
    var notes: String
}

enum PricingMode: String, CaseIterable, Identifiable {
    case fixed = "fixed_price"
    case estimated = "estimated_price"
    case hourly = "hourly_price"
    case byVolume = "volume_price"
    case combined = "combined_price"

    var id: String { rawValue }
}

struct EstimateVersion: PersistableEntity {
    var id: Int64
    var estimateId: Int64
    var versionName: String
    var createdAt: Date
    var changedSummary: String
}

struct EstimateAdjustment: PersistableEntity {
    var id: Int64
    var estimateVersionId: Int64
    var title: String
    var value: Double
    var type: String
}

struct Supplier: PersistableEntity {
    var id: Int64
    var name: String
    var contact: String
    var phone: String
    var email: String
}

struct SupplierArticle: PersistableEntity {
    var id: Int64
    var supplierId: Int64
    var materialItemId: Int64
    var sku: String
    var purchasePrice: Double
    var isPrimary: Bool
}

struct EquipmentCostRule: PersistableEntity {
    var id: Int64
    var name: String
    var costPerHour: Double
    var appliesToWorkCategoryId: Int64?
}

struct TransportCostRule: PersistableEntity {
    var id: Int64
    var name: String
    var fixedCost: Double
    var costPerKm: Double
}

struct WasteDisposalRule: PersistableEntity {
    var id: Int64
    var name: String
    var costPerCubicMeter: Double
}

struct DefaultProjectPreset: PersistableEntity {
    var id: Int64
    var name: String
    var pricingMode: String
    var speedProfileId: Int64
    var notes: String
}

struct CalculationSnapshot: PersistableEntity {
    var id: Int64
    var projectId: Int64
    var estimateVersionId: Int64?
    var documentId: Int64?
    var snapshotJSON: String
    var createdAt: Date
}

struct WorkCatalogItem: PersistableEntity {
    var id: Int64
    var name: String
    var unit: String
    var baseRatePerUnitHour: Double
    var basePrice: Double
    var swedishName: String
    var sortOrder: Int
    var categoryId: Int64? = nil
    var subcategoryId: Int64? = nil
    var description: String = ""
    var isActive: Bool = true
    var includeInStandardOffer: Bool = true
    var rotEligible: Bool = true
    var applicability: String = "b2c,b2b"
    var basePurchasePrice: Double = 0
    var hourlyPrice: Double = 0
    var slowSpeed: Double = 0
    var mediumSpeed: Double = 0
    var fastSpeed: Double = 0
    var complexityCoefficient: Double = 1
    var heightCoefficient: Double = 1
    var conditionCoefficient: Double = 1
    var urgencyCoefficient: Double = 1
    var accessibilityCoefficient: Double = 1
    var additionalLaborHours: Double = 0
    var additionalMaterialUsage: Double = 0
}

struct MaterialCatalogItem: PersistableEntity {
    var id: Int64
    var name: String
    var unit: String
    var basePrice: Double
    var swedishName: String
    var sortOrder: Int
    var categoryId: Int64? = nil
    var purchasePrice: Double = 0
    var markupPercent: Double = 0
    var supplierId: Int64? = nil
    var sku: String = ""
    var usagePerWorkUnit: Double = 0
    var packageSize: Double = 1
    var stock: Double = 0
    var comment: String = ""
    var isActive: Bool = true
}

struct SpeedProfile: PersistableEntity {
    var id: Int64
    var name: String
    var coefficient: Double
    var daysDivider: Double
    var sortOrder: Int
}

struct Estimate: PersistableEntity {
    var id: Int64
    var projectId: Int64
    var speedProfileId: Int64
    var laborRatePerHour: Double
    var overheadCoefficient: Double
    var createdAt: Date
}

struct EstimateLine: PersistableEntity {
    var id: Int64
    var estimateId: Int64
    var roomId: Int64
    var workItemId: Int64?
    var materialItemId: Int64?
    var quantity: Double
    var unitPrice: Double
    var coefficient: Double
    var type: String
}

// Stage 1/2 entities below unchanged
struct DocumentTemplate: PersistableEntity { var id: Int64; var name: String; var language: String; var headerText: String; var footerText: String; var sortOrder: Int }
struct GeneratedDocument: PersistableEntity { var id: Int64; var estimateId: Int64; var templateId: Int64; var title: String; var path: String; var generatedAt: Date }

enum ProjectWorkflowStatus: String, CaseIterable { case draft, calculation, offertSent, offertApproved, avtalReady, workInProgress, readyForInvoice, invoiced, partiallyPaid, paid, credit, cancelled }
enum DocumentType: String, CaseIterable { case offert, avtal, faktura, kreditfaktura, ata, paminnelse }
enum DocumentStatus: String, CaseIterable { case draft, generated, finalized, sent, paid, cancelled, credited }
enum CustomerType: String, CaseIterable { case b2c, b2b }
enum TaxMode: String, CaseIterable { case normal, reverseCharge }

struct BusinessDocument: PersistableEntity {
    var id: Int64; var projectId: Int64; var type: String; var status: String; var number: String; var title: String; var issueDate: Date; var dueDate: Date?; var customerType: String; var taxMode: String; var currency: String; var subtotalLabor: Double; var subtotalMaterial: Double; var subtotalOther: Double; var vatRate: Double; var vatAmount: Double; var rotEligibleLabor: Double; var rotReduction: Double; var totalAmount: Double; var paidAmount: Double; var balanceDue: Double; var relatedDocumentId: Int64?; var notes: String
}

struct BusinessDocumentLine: PersistableEntity { var id: Int64; var documentId: Int64; var lineType: String; var description: String; var quantity: Double; var unit: String; var unitPrice: Double; var vatRate: Double; var isRotEligible: Bool; var total: Double }
struct DocumentSeries: PersistableEntity { var id: Int64; var documentType: String; var prefix: String; var nextNumber: Int; var active: Bool }
struct TaxProfile: PersistableEntity { var id: Int64; var name: String; var customerType: String; var taxMode: String; var vatRate: Double; var rotPercent: Double; var active: Bool }
struct ProjectStatusHistory: PersistableEntity { var id: Int64; var projectId: Int64; var status: String; var changedAt: Date; var note: String }
struct DocumentSnapshot: PersistableEntity { var id: Int64; var documentId: Int64; var templateId: Int64?; var snapshotJSON: String; var createdAt: Date }
struct Payment: PersistableEntity { var id: Int64; var amount: Double; var paidAt: Date; var method: String; var reference: String }
struct PaymentAllocation: PersistableEntity { var id: Int64; var paymentId: Int64; var documentId: Int64; var amount: Double }

struct ImmutableDocumentSnapshot: Codable {
    var schemaVersion: Int
    var snapshotCreatedAt: Date
    var document: DocumentMetaSnapshot
    var company: CompanyDisplaySnapshot
    var client: ClientDisplaySnapshot
    var project: ProjectSnapshotContext
    var financials: DocumentFinancialSnapshot
    var lines: [DocumentLineSnapshot]
    var references: DocumentReferenceSnapshot
    var notes: String
}

struct DocumentMetaSnapshot: Codable {
    var documentId: Int64
    var templateId: Int64?
    var type: String
    var number: String
    var title: String
    var statusAtSnapshotTime: String
    var issueDate: Date
    var dueDate: Date?
    var currency: String
}

struct CompanyDisplaySnapshot: Codable {
    var name: String
    var orgNumber: String
    var email: String
    var phone: String
}

struct ClientDisplaySnapshot: Codable {
    var name: String
    var email: String
    var phone: String
    var address: String
}

struct ProjectSnapshotContext: Codable {
    var projectId: Int64
    var projectName: String
    var propertyObjectName: String?
    var objectAddress: String?
}

struct DocumentFinancialSnapshot: Codable {
    var customerType: String
    var taxMode: String
    var subtotalLabor: Double
    var subtotalMaterial: Double
    var subtotalOther: Double
    var vatRate: Double
    var vatAmount: Double
    var rotEligibleLabor: Double
    var rotReduction: Double
    var totalAmount: Double
    var paidAmount: Double
    var balanceDue: Double
}

struct DocumentLineSnapshot: Codable {
    var lineType: String
    var description: String
    var quantity: Double
    var unit: String
    var unitPrice: Double
    var vatRate: Double
    var isRotEligible: Bool
    var total: Double
}

struct DocumentReferenceSnapshot: Codable {
    var relatedDocumentId: Int64?
    var relatedDocumentNumber: String?
    var sourceEstimateId: Int64?
    var sourceProjectId: Int64?
    var sourceProjectName: String?
}

struct LegacyDocumentSnapshot: Codable {
    var title: String
    var total: Double
    var vat: Double
    var rotReduction: Double
}

struct SupplierContact: PersistableEntity {
    var id: Int64
    var supplierId: Int64
    var name: String
    var role: String
    var email: String
    var phone: String
    var isPrimary: Bool
}

struct SupplierPriceHistory: PersistableEntity {
    var id: Int64
    var supplierArticleId: Int64
    var purchasePrice: Double
    var changedAt: Date
    var source: String
}

struct PurchaseList: PersistableEntity {
    var id: Int64
    var projectId: Int64
    var status: String
    var createdAt: Date
    var exportedAt: Date?
    var note: String
}

struct PurchaseListItem: PersistableEntity {
    var id: Int64
    var purchaseListId: Int64
    var materialItemId: Int64
    var supplierId: Int64?
    var articleId: Int64?
    var quantity: Double
    var unit: String
    var plannedPrice: Double
    var purchasedQuantity: Double
    var status: String
}

struct MaterialPriceProfile: PersistableEntity {
    var id: Int64
    var materialItemId: Int64
    var preferredSupplierId: Int64?
    var preferredArticleId: Int64?
    var targetMarkupPercent: Double
    var updatedAt: Date
}

struct ProjectLifecycleEntry: PersistableEntity {
    var id: Int64
    var projectId: Int64
    var lifecycleStatus: String
    var changedAt: Date
    var note: String
}

struct ProjectTag: PersistableEntity {
    var id: Int64
    var projectId: Int64
    var tag: String
}

struct ProjectNote: PersistableEntity {
    var id: Int64
    var projectId: Int64
    var noteType: String
    var text: String
    var pinned: Bool
    var updatedAt: Date
}

struct ExportLog: PersistableEntity {
    var id: Int64
    var kind: String
    var scope: String
    var path: String
    var createdAt: Date
}

struct ImportIssue: Identifiable {
    var id: UUID = UUID()
    var row: Int
    var field: String
    var message: String
}

struct ImportPreview<Row> {
    var rows: [Row]
    var issues: [ImportIssue]
    var createCount: Int
    var updateCount: Int
    var skippedCount: Int = 0
    var invalidCount: Int = 0
}

enum ClientImportAction {
    case create(Client)
    case update(Client)
    case skip(reason: String)
    case invalid(issue: ImportIssue)
}

struct ClientImportReport {
    var actions: [ClientImportAction]
    var created: Int
    var updated: Int
    var skipped: Int
    var invalid: Int
    var issues: [ImportIssue]
}

struct ProjectProfitability {
    var projectId: Int64
    var plannedLaborRevenue: Double
    var plannedMaterialRevenue: Double
    var plannedCost: Double
    var plannedGrossMargin: Double
    var actualInvoicedAmount: Double
    var paidAmount: Double
    var outstandingAmount: Double
    var expectedROTClaimAmount: Double
    var creditedAmount: Double
}

struct ReceivableBucket {
    var title: String
    var documents: [BusinessDocument]
    var totalOutstanding: Double
}
