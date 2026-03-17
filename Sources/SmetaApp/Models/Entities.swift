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
