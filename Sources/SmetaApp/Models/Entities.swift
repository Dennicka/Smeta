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
}

struct Project: PersistableEntity {
    var id: Int64
    var clientId: Int64
    var propertyId: Int64
    var name: String
    var speedProfileId: Int64
    var createdAt: Date
}

struct Room: PersistableEntity {
    var id: Int64
    var projectId: Int64
    var name: String
    var area: Double
    var height: Double
}

struct WorkCatalogItem: PersistableEntity {
    var id: Int64
    var name: String
    var unit: String
    var baseRatePerUnitHour: Double
    var basePrice: Double
    var swedishName: String
    var sortOrder: Int
}

struct MaterialCatalogItem: PersistableEntity {
    var id: Int64
    var name: String
    var unit: String
    var basePrice: Double
    var swedishName: String
    var sortOrder: Int
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

struct DocumentTemplate: PersistableEntity {
    var id: Int64
    var name: String
    var language: String
    var headerText: String
    var footerText: String
    var sortOrder: Int
}

struct GeneratedDocument: PersistableEntity {
    var id: Int64
    var estimateId: Int64
    var templateId: Int64
    var title: String
    var path: String
    var generatedAt: Date
}

enum ProjectWorkflowStatus: String, CaseIterable {
    case draft, calculation, offertSent, offertApproved, avtalReady, workInProgress, readyForInvoice, invoiced, partiallyPaid, paid, credit, cancelled
}

enum DocumentType: String, CaseIterable {
    case offert, avtal, faktura, kreditfaktura, ata, paminnelse
}

enum DocumentStatus: String, CaseIterable {
    case draft, generated, finalized, sent, paid, cancelled, credited
}

enum CustomerType: String, CaseIterable {
    case b2c, b2b
}

enum TaxMode: String, CaseIterable {
    case normal, reverseCharge
}

struct BusinessDocument: PersistableEntity {
    var id: Int64
    var projectId: Int64
    var type: String
    var status: String
    var number: String
    var title: String
    var issueDate: Date
    var dueDate: Date?
    var customerType: String
    var taxMode: String
    var currency: String
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
    var relatedDocumentId: Int64?
    var notes: String
}

struct BusinessDocumentLine: PersistableEntity {
    var id: Int64
    var documentId: Int64
    var lineType: String
    var description: String
    var quantity: Double
    var unit: String
    var unitPrice: Double
    var vatRate: Double
    var isRotEligible: Bool
    var total: Double
}

struct DocumentSeries: PersistableEntity {
    var id: Int64
    var documentType: String
    var prefix: String
    var nextNumber: Int
    var active: Bool
}

struct TaxProfile: PersistableEntity {
    var id: Int64
    var name: String
    var customerType: String
    var taxMode: String
    var vatRate: Double
    var rotPercent: Double
    var active: Bool
}

struct ProjectStatusHistory: PersistableEntity {
    var id: Int64
    var projectId: Int64
    var status: String
    var changedAt: Date
    var note: String
}

struct DocumentSnapshot: PersistableEntity {
    var id: Int64
    var documentId: Int64
    var templateId: Int64?
    var snapshotJSON: String
    var createdAt: Date
}

struct Payment: PersistableEntity {
    var id: Int64
    var amount: Double
    var paidAt: Date
    var method: String
    var reference: String
}

struct PaymentAllocation: PersistableEntity {
    var id: Int64
    var paymentId: Int64
    var documentId: Int64
    var amount: Double
}
