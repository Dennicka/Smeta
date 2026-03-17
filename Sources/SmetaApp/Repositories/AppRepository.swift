import Foundation
import SQLite3

final class AppRepository {
    private let db: SQLiteDatabase

    init(db: SQLiteDatabase) { self.db = db }

    func seedIfNeeded() throws {
        if try !clients().isEmpty { return }
        _ = try insertCompany(Company(id: 0, name: "NordBygg AB", orgNumber: "556000-1234", email: "info@nordbygg.se", phone: "+46 8 555 00 00"))

        let c1 = try insertClient(Client(id: 0, name: "Anna Svensson", email: "anna@client.se", phone: "+46 70 111 22 33", address: "Stockholm"))
        let c2 = try insertClient(Client(id: 0, name: "Lars Holm", email: "lars@client.se", phone: "+46 70 444 55 66", address: "Uppsala"))

        let p1 = try insertProperty(PropertyObject(id: 0, clientId: c1, name: "Lägenhet Södermalm", address: "Götgatan 21"))
        _ = try insertProperty(PropertyObject(id: 0, clientId: c2, name: "Villa Solna", address: "Hagavägen 9"))

        let slow = try insertSpeedProfile(SpeedProfile(id: 0, name: "Стандарт", coefficient: 1.0, daysDivider: 7.0, sortOrder: 0))
        _ = try insertSpeedProfile(SpeedProfile(id: 0, name: "Быстро", coefficient: 1.2, daysDivider: 9.0, sortOrder: 1))
        _ = try insertSpeedProfile(SpeedProfile(id: 0, name: "Экспресс", coefficient: 1.45, daysDivider: 11.0, sortOrder: 2))

        _ = try insertWorkItem(WorkCatalogItem(id: 0, name: "Покраска стен", unit: "м²", baseRatePerUnitHour: 0.22, basePrice: 220, swedishName: "Målning av väggar", sortOrder: 0))
        _ = try insertWorkItem(WorkCatalogItem(id: 0, name: "Шпаклевка", unit: "м²", baseRatePerUnitHour: 0.30, basePrice: 260, swedishName: "Spackling", sortOrder: 1))

        _ = try insertMaterialItem(MaterialCatalogItem(id: 0, name: "Краска белая", unit: "л", basePrice: 65, swedishName: "Vit färg", sortOrder: 0))
        _ = try insertMaterialItem(MaterialCatalogItem(id: 0, name: "Грунтовка", unit: "л", basePrice: 48, swedishName: "Primer", sortOrder: 1))

        _ = try insertTemplate(DocumentTemplate(id: 0, name: "Offert Standard", language: "sv", headerText: "OFFERT", footerText: "Tack för förtroendet!", sortOrder: 0))

        let projectId = try insertProject(Project(id: 0, clientId: c1, propertyId: p1, name: "Ремонт кухни", speedProfileId: slow, createdAt: Date()))
        _ = try insertRoom(Room(id: 0, projectId: projectId, name: "Кухня", area: 14, height: 2.7))
        _ = try insertRoom(Room(id: 0, projectId: projectId, name: "Коридор", area: 8, height: 2.6))
    }

    func companies() throws -> [Company] { try fetch("SELECT id,name,org_number,email,phone FROM companies") { stmt in
        Company(id: sqlite3_column_int64(stmt, 0), name: text(stmt,1), orgNumber: text(stmt,2), email: text(stmt,3), phone: text(stmt,4))
    }}

    func insertCompany(_ c: Company) throws -> Int64 {
        try db.withStatement("INSERT INTO companies (name,org_number,email,phone) VALUES (?,?,?,?)") { s in
            bind(s,1,c.name); bind(s,2,c.orgNumber); bind(s,3,c.email); bind(s,4,c.phone); try step(s)
        }
        return db.lastInsertedRowID()
    }

    func clients() throws -> [Client] { try fetch("SELECT id,name,email,phone,address FROM clients ORDER BY id DESC") { stmt in
        Client(id: sqlite3_column_int64(stmt,0), name: text(stmt,1), email: text(stmt,2), phone: text(stmt,3), address: text(stmt,4))
    }}
    func insertClient(_ c: Client) throws -> Int64 {
        try db.withStatement("INSERT INTO clients (name,email,phone,address) VALUES (?,?,?,?)") { s in
            bind(s,1,c.name); bind(s,2,c.email); bind(s,3,c.phone); bind(s,4,c.address); try step(s)
        }
        return db.lastInsertedRowID()
    }

    func properties(for clientId: Int64? = nil) throws -> [PropertyObject] {
        let sql = clientId == nil ? "SELECT id,client_id,name,address FROM properties ORDER BY id DESC" : "SELECT id,client_id,name,address FROM properties WHERE client_id=? ORDER BY id DESC"
        return try fetchWithBind(sql, bindValue: clientId) { s in
            PropertyObject(id: sqlite3_column_int64(s,0), clientId: sqlite3_column_int64(s,1), name: text(s,2), address: text(s,3))
        }
    }

    func insertProperty(_ p: PropertyObject) throws -> Int64 {
        try db.withStatement("INSERT INTO properties (client_id,name,address) VALUES (?,?,?)") { s in
            sqlite3_bind_int64(s,1,p.clientId); bind(s,2,p.name); bind(s,3,p.address); try step(s)
        }
        return db.lastInsertedRowID()
    }

    func speedProfiles() throws -> [SpeedProfile] { try fetch("SELECT id,name,coefficient,days_divider,sort_order FROM speed_profiles ORDER BY sort_order,id") { s in
        SpeedProfile(id: sqlite3_column_int64(s,0), name: text(s,1), coefficient: sqlite3_column_double(s,2), daysDivider: sqlite3_column_double(s,3), sortOrder: Int(sqlite3_column_int(s,4)))
    }}
    func insertSpeedProfile(_ profile: SpeedProfile) throws -> Int64 {
        try db.withStatement("INSERT INTO speed_profiles (name,coefficient,days_divider,sort_order) VALUES (?,?,?,?)") { s in
            bind(s,1,profile.name); sqlite3_bind_double(s,2,profile.coefficient); sqlite3_bind_double(s,3,profile.daysDivider); sqlite3_bind_int(s,4,Int32(profile.sortOrder)); try step(s)
        }
        return db.lastInsertedRowID()
    }
    func updateSpeedProfile(_ profile: SpeedProfile) throws {
        try db.withStatement("UPDATE speed_profiles SET name=?,coefficient=?,days_divider=?,sort_order=? WHERE id=?") { s in
            bind(s,1,profile.name); sqlite3_bind_double(s,2,profile.coefficient); sqlite3_bind_double(s,3,profile.daysDivider); sqlite3_bind_int(s,4,Int32(profile.sortOrder)); sqlite3_bind_int64(s,5,profile.id); try step(s)
        }
    }

    func projects() throws -> [Project] { try fetch("SELECT id,client_id,property_id,name,speed_profile_id,created_at FROM projects ORDER BY id DESC") { s in
        Project(id: sqlite3_column_int64(s,0), clientId: sqlite3_column_int64(s,1), propertyId: sqlite3_column_int64(s,2), name: text(s,3), speedProfileId: sqlite3_column_int64(s,4), createdAt: Date(timeIntervalSince1970: sqlite3_column_double(s,5)))
    }}
    func insertProject(_ p: Project) throws -> Int64 {
        try db.withStatement("INSERT INTO projects (client_id,property_id,name,speed_profile_id,created_at) VALUES (?,?,?,?,?)") { s in
            sqlite3_bind_int64(s,1,p.clientId); sqlite3_bind_int64(s,2,p.propertyId); bind(s,3,p.name); sqlite3_bind_int64(s,4,p.speedProfileId); sqlite3_bind_double(s,5,p.createdAt.timeIntervalSince1970); try step(s)
        }
        return db.lastInsertedRowID()
    }

    func rooms(projectId: Int64? = nil) throws -> [Room] {
        let sql = projectId == nil ? "SELECT id,project_id,name,area,height FROM rooms ORDER BY id DESC" : "SELECT id,project_id,name,area,height FROM rooms WHERE project_id=? ORDER BY id DESC"
        return try fetchWithBind(sql, bindValue: projectId) { s in
            Room(id: sqlite3_column_int64(s,0), projectId: sqlite3_column_int64(s,1), name: text(s,2), area: sqlite3_column_double(s,3), height: sqlite3_column_double(s,4))
        }
    }
    func insertRoom(_ room: Room) throws -> Int64 {
        try db.withStatement("INSERT INTO rooms (project_id,name,area,height) VALUES (?,?,?,?)") { s in
            sqlite3_bind_int64(s,1,room.projectId); bind(s,2,room.name); sqlite3_bind_double(s,3,room.area); sqlite3_bind_double(s,4,room.height); try step(s)
        }
        return db.lastInsertedRowID()
    }

    func workItems() throws -> [WorkCatalogItem] { try fetch("SELECT id,name,unit,base_rate_hour,base_price,swedish_name,sort_order FROM work_catalog ORDER BY sort_order,id") { s in
        WorkCatalogItem(id: sqlite3_column_int64(s,0), name: text(s,1), unit: text(s,2), baseRatePerUnitHour: sqlite3_column_double(s,3), basePrice: sqlite3_column_double(s,4), swedishName: text(s,5), sortOrder: Int(sqlite3_column_int(s,6)))
    }}
    func insertWorkItem(_ item: WorkCatalogItem) throws -> Int64 {
        try db.withStatement("INSERT INTO work_catalog (name,unit,base_rate_hour,base_price,swedish_name,sort_order) VALUES (?,?,?,?,?,?)") { s in
            bind(s,1,item.name); bind(s,2,item.unit); sqlite3_bind_double(s,3,item.baseRatePerUnitHour); sqlite3_bind_double(s,4,item.basePrice); bind(s,5,item.swedishName); sqlite3_bind_int(s,6,Int32(item.sortOrder)); try step(s)
        }
        return db.lastInsertedRowID()
    }
    func updateWorkItem(_ item: WorkCatalogItem) throws {
        try db.withStatement("UPDATE work_catalog SET name=?,unit=?,base_rate_hour=?,base_price=?,swedish_name=?,sort_order=? WHERE id=?") { s in
            bind(s,1,item.name); bind(s,2,item.unit); sqlite3_bind_double(s,3,item.baseRatePerUnitHour); sqlite3_bind_double(s,4,item.basePrice); bind(s,5,item.swedishName); sqlite3_bind_int(s,6,Int32(item.sortOrder)); sqlite3_bind_int64(s,7,item.id); try step(s)
        }
    }

    func materialItems() throws -> [MaterialCatalogItem] { try fetch("SELECT id,name,unit,base_price,swedish_name,sort_order FROM material_catalog ORDER BY sort_order,id") { s in
        MaterialCatalogItem(id: sqlite3_column_int64(s,0), name: text(s,1), unit: text(s,2), basePrice: sqlite3_column_double(s,3), swedishName: text(s,4), sortOrder: Int(sqlite3_column_int(s,5)))
    }}
    func insertMaterialItem(_ item: MaterialCatalogItem) throws -> Int64 {
        try db.withStatement("INSERT INTO material_catalog (name,unit,base_price,swedish_name,sort_order) VALUES (?,?,?,?,?)") { s in
            bind(s,1,item.name); bind(s,2,item.unit); sqlite3_bind_double(s,3,item.basePrice); bind(s,4,item.swedishName); sqlite3_bind_int(s,5,Int32(item.sortOrder)); try step(s)
        }
        return db.lastInsertedRowID()
    }
    func updateMaterialItem(_ item: MaterialCatalogItem) throws {
        try db.withStatement("UPDATE material_catalog SET name=?,unit=?,base_price=?,swedish_name=?,sort_order=? WHERE id=?") { s in
            bind(s,1,item.name); bind(s,2,item.unit); sqlite3_bind_double(s,3,item.basePrice); bind(s,4,item.swedishName); sqlite3_bind_int(s,5,Int32(item.sortOrder)); sqlite3_bind_int64(s,6,item.id); try step(s)
        }
    }

    func templates() throws -> [DocumentTemplate] { try fetch("SELECT id,name,language,header_text,footer_text,sort_order FROM document_templates ORDER BY sort_order,id") { s in
        DocumentTemplate(id: sqlite3_column_int64(s,0), name: text(s,1), language: text(s,2), headerText: text(s,3), footerText: text(s,4), sortOrder: Int(sqlite3_column_int(s,5)))
    }}
    func insertTemplate(_ t: DocumentTemplate) throws -> Int64 {
        try db.withStatement("INSERT INTO document_templates (name,language,header_text,footer_text,sort_order) VALUES (?,?,?,?,?)") { s in
            bind(s,1,t.name); bind(s,2,t.language); bind(s,3,t.headerText); bind(s,4,t.footerText); sqlite3_bind_int(s,5,Int32(t.sortOrder)); try step(s)
        }
        return db.lastInsertedRowID()
    }
    func updateTemplate(_ t: DocumentTemplate) throws {
        try db.withStatement("UPDATE document_templates SET name=?,language=?,header_text=?,footer_text=?,sort_order=? WHERE id=?") { s in
            bind(s,1,t.name); bind(s,2,t.language); bind(s,3,t.headerText); bind(s,4,t.footerText); sqlite3_bind_int(s,5,Int32(t.sortOrder)); sqlite3_bind_int64(s,6,t.id); try step(s)
        }
    }

    func insertEstimate(_ e: Estimate) throws -> Int64 {
        try db.withStatement("INSERT INTO estimates (project_id,speed_profile_id,labor_rate_hour,overhead_coefficient,created_at) VALUES (?,?,?,?,?)") { s in
            sqlite3_bind_int64(s,1,e.projectId); sqlite3_bind_int64(s,2,e.speedProfileId); sqlite3_bind_double(s,3,e.laborRatePerHour); sqlite3_bind_double(s,4,e.overheadCoefficient); sqlite3_bind_double(s,5,e.createdAt.timeIntervalSince1970); try step(s)
        }
        return db.lastInsertedRowID()
    }
    func estimates(projectId: Int64? = nil) throws -> [Estimate] {
        let sql = projectId == nil ? "SELECT id,project_id,speed_profile_id,labor_rate_hour,overhead_coefficient,created_at FROM estimates ORDER BY id DESC" : "SELECT id,project_id,speed_profile_id,labor_rate_hour,overhead_coefficient,created_at FROM estimates WHERE project_id=? ORDER BY id DESC"
        return try fetchWithBind(sql, bindValue: projectId) { s in
            Estimate(id: sqlite3_column_int64(s,0), projectId: sqlite3_column_int64(s,1), speedProfileId: sqlite3_column_int64(s,2), laborRatePerHour: sqlite3_column_double(s,3), overheadCoefficient: sqlite3_column_double(s,4), createdAt: Date(timeIntervalSince1970: sqlite3_column_double(s,5)))
        }
    }
    func insertEstimateLine(_ line: EstimateLine) throws {
        try db.withStatement("INSERT INTO estimate_lines (estimate_id,room_id,work_item_id,material_item_id,quantity,unit_price,coefficient,type) VALUES (?,?,?,?,?,?,?,?)") { s in
            sqlite3_bind_int64(s,1,line.estimateId); sqlite3_bind_int64(s,2,line.roomId)
            if let w = line.workItemId { sqlite3_bind_int64(s,3,w) } else { sqlite3_bind_null(s,3) }
            if let m = line.materialItemId { sqlite3_bind_int64(s,4,m) } else { sqlite3_bind_null(s,4) }
            sqlite3_bind_double(s,5,line.quantity); sqlite3_bind_double(s,6,line.unitPrice); sqlite3_bind_double(s,7,line.coefficient); bind(s,8,line.type); try step(s)
        }
    }
    func estimateLines(estimateId: Int64) throws -> [EstimateLine] {
        try fetchWithBind("SELECT id,estimate_id,room_id,work_item_id,material_item_id,quantity,unit_price,coefficient,type FROM estimate_lines WHERE estimate_id=?", bindValue: estimateId) { s in
            EstimateLine(id: sqlite3_column_int64(s,0), estimateId: sqlite3_column_int64(s,1), roomId: sqlite3_column_int64(s,2), workItemId: nullableInt64(s,3), materialItemId: nullableInt64(s,4), quantity: sqlite3_column_double(s,5), unitPrice: sqlite3_column_double(s,6), coefficient: sqlite3_column_double(s,7), type: text(s,8))
        }
    }

    func insertGeneratedDocument(_ d: GeneratedDocument) throws {
        try db.withStatement("INSERT INTO generated_documents (estimate_id,template_id,title,path,generated_at) VALUES (?,?,?,?,?)") { s in
            sqlite3_bind_int64(s,1,d.estimateId); sqlite3_bind_int64(s,2,d.templateId); bind(s,3,d.title); bind(s,4,d.path); sqlite3_bind_double(s,5,d.generatedAt.timeIntervalSince1970); try step(s)
        }
    }
    func generatedDocuments() throws -> [GeneratedDocument] {
        try fetch("SELECT id,estimate_id,template_id,title,path,generated_at FROM generated_documents ORDER BY id DESC") { s in
            GeneratedDocument(id: sqlite3_column_int64(s,0), estimateId: sqlite3_column_int64(s,1), templateId: sqlite3_column_int64(s,2), title: text(s,3), path: text(s,4), generatedAt: Date(timeIntervalSince1970: sqlite3_column_double(s,5)))
        }
    }

    private func fetch<T>(_ sql: String, _ map: (OpaquePointer) -> T) throws -> [T] {
        var items: [T] = []
        try db.withStatement(sql) { s in
            while sqlite3_step(s) == SQLITE_ROW { items.append(map(s)) }
        }
        return items
    }

    private func fetchWithBind<T>(_ sql: String, bindValue: Int64?, map: (OpaquePointer) -> T) throws -> [T] {
        var items: [T] = []
        try db.withStatement(sql) { s in
            if let bindValue { sqlite3_bind_int64(s,1,bindValue) }
            while sqlite3_step(s) == SQLITE_ROW { items.append(map(s)) }
        }
        return items
    }

    private func bind(_ stmt: OpaquePointer, _ index: Int32, _ value: String) { sqlite3_bind_text(stmt, index, value, -1, SQLITE_TRANSIENT) }
    private func text(_ stmt: OpaquePointer, _ index: Int32) -> String {
        guard let c = sqlite3_column_text(stmt, index) else { return "" }
        return String(cString: c)
    }
    private func nullableInt64(_ stmt: OpaquePointer, _ index: Int32) -> Int64? {
        sqlite3_column_type(stmt, index) == SQLITE_NULL ? nil : sqlite3_column_int64(stmt, index)
    }
    private func step(_ stmt: OpaquePointer) throws {
        if sqlite3_step(stmt) != SQLITE_DONE { throw DatabaseError.executeFailed("Step failed") }
    }
}
