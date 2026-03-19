import Foundation
import SQLite3

final class AppRepository {
    let db: SQLiteDatabase

    static let demoResetCleanedTables = [
        "payment_allocations",
        "payments",
        "document_snapshots",
        "business_document_lines",
        "business_documents",
        "generated_documents",
        "estimate_adjustments",
        "estimate_versions",
        "estimate_lines",
        "estimates",
        "calculation_snapshots",
        "trim_elements",
        "openings",
        "surfaces",
        "rooms",
        "project_notes",
        "project_tags",
        "project_lifecycle_history",
        "project_status_history",
        "projects",
        "properties",
        "clients",
        "purchase_list_items",
        "purchase_lists",
        "supplier_price_history",
        "supplier_articles",
        "suppliers",
        "default_project_presets",
        "material_usage_norms",
        "work_speed_rules",
        "work_subcategories",
        "work_categories",
        "material_categories",
        "export_logs",
        "companies",
        "speed_profiles",
        "work_catalog",
        "material_catalog",
        "document_templates",
        "document_series",
        "tax_profiles"
    ]

    static let demoResetPreservedTables = [
        "calculation_rules",
        "schema_migrations"
    ]

    init(db: SQLiteDatabase) { self.db = db }

    func performLaunchBootstrapWrites(
        failureInjection: (() throws -> Void)? = nil
    ) throws {
        try db.execute("BEGIN IMMEDIATE TRANSACTION;")
        var committed = false
        defer {
            if !committed {
                try? db.execute("ROLLBACK;")
            }
        }

        try seedIfNeeded()
        try failureInjection?()
        try seedStage2Defaults()

        try db.execute("COMMIT;")
        committed = true
    }

    func resetDemoData() throws {
        try db.execute("BEGIN IMMEDIATE TRANSACTION;")
        var committed = false
        defer {
            if !committed {
                try? db.execute("ROLLBACK;")
            }
        }

        for table in Self.demoResetCleanedTables {
            try db.execute("DELETE FROM \(table);")
        }
        let sequenceFilter = Self.demoResetCleanedTables.map { "'\($0)'" }.joined(separator: ",")
        try db.execute("DELETE FROM sqlite_sequence WHERE name IN (\(sequenceFilter));")

        try seedIfNeeded()
        try seedStage2Defaults()

        var hasForeignKeyViolations = false
        try db.withStatement("PRAGMA foreign_key_check;") { stmt in
            hasForeignKeyViolations = sqlite3_step(stmt) == SQLITE_ROW
        }
        if hasForeignKeyViolations {
            throw DatabaseError.executeFailed("resetDemoData produced foreign key violations")
        }

        try db.execute("COMMIT;")
        committed = true
    }

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

    func client(id: Int64) throws -> Client? {
        try fetchWithBind("SELECT id,name,email,phone,address FROM clients WHERE id=?", bindValue: id) { stmt in
            Client(id: sqlite3_column_int64(stmt,0), name: text(stmt,1), email: text(stmt,2), phone: text(stmt,3), address: text(stmt,4))
        }.first
    }

    func insertClient(_ c: Client) throws -> Int64 {
        try db.withStatement("INSERT INTO clients (name,email,phone,address) VALUES (?,?,?,?)") { s in
            bind(s,1,c.name); bind(s,2,c.email); bind(s,3,c.phone); bind(s,4,c.address); try step(s)
        }
        return db.lastInsertedRowID()
    }

    func updateClient(_ c: Client) throws {
        try db.withStatement("UPDATE clients SET name=?,email=?,phone=?,address=? WHERE id=?") { s in
            bind(s,1,c.name); bind(s,2,c.email); bind(s,3,c.phone); bind(s,4,c.address); sqlite3_bind_int64(s,5,c.id); try step(s)
        }
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

    func calculationRules() throws -> CalculationRules {
        if let row = try fetch("SELECT id,transport_percent,equipment_percent,waste_percent,margin_percent,moms_percent,min_speed_rate,min_work_medium_speed,min_work_base_rate_per_unit_hour,min_speed_days_divider,min_material_usage_per_work_unit,min_material_quantity FROM calculation_rules WHERE id=1 LIMIT 1", { s in
            CalculationRules(id: sqlite3_column_int64(s, 0),
                             transportPercent: sqlite3_column_double(s, 1),
                             equipmentPercent: sqlite3_column_double(s, 2),
                             wastePercent: sqlite3_column_double(s, 3),
                             marginPercent: sqlite3_column_double(s, 4),
                             momsPercent: sqlite3_column_double(s, 5),
                             minSpeedRate: sqlite3_column_double(s, 6),
                             minWorkMediumSpeed: sqlite3_column_double(s, 7),
                             minWorkBaseRatePerUnitHour: sqlite3_column_double(s, 8),
                             minSpeedDaysDivider: sqlite3_column_double(s, 9),
                             minMaterialUsagePerWorkUnit: sqlite3_column_double(s, 10),
                             minMaterialQuantity: sqlite3_column_double(s, 11))
        }).first {
            return row
        }
        try upsertCalculationRules(.default)
        return .default
    }

    func upsertCalculationRules(_ rules: CalculationRules) throws {
        try db.withStatement("""
        INSERT INTO calculation_rules (id,transport_percent,equipment_percent,waste_percent,margin_percent,moms_percent,min_speed_rate,min_work_medium_speed,min_work_base_rate_per_unit_hour,min_speed_days_divider,min_material_usage_per_work_unit,min_material_quantity)
        VALUES (1,?,?,?,?,?,?,?,?,?,?,?)
        ON CONFLICT(id) DO UPDATE SET
            transport_percent=excluded.transport_percent,
            equipment_percent=excluded.equipment_percent,
            waste_percent=excluded.waste_percent,
            margin_percent=excluded.margin_percent,
            moms_percent=excluded.moms_percent,
            min_speed_rate=excluded.min_speed_rate,
            min_work_medium_speed=excluded.min_work_medium_speed,
            min_work_base_rate_per_unit_hour=excluded.min_work_base_rate_per_unit_hour,
            min_speed_days_divider=excluded.min_speed_days_divider,
            min_material_usage_per_work_unit=excluded.min_material_usage_per_work_unit,
            min_material_quantity=excluded.min_material_quantity
        """) { s in
            sqlite3_bind_double(s, 1, rules.transportPercent)
            sqlite3_bind_double(s, 2, rules.equipmentPercent)
            sqlite3_bind_double(s, 3, rules.wastePercent)
            sqlite3_bind_double(s, 4, rules.marginPercent)
            sqlite3_bind_double(s, 5, rules.momsPercent)
            sqlite3_bind_double(s, 6, rules.minSpeedRate)
            sqlite3_bind_double(s, 7, rules.minWorkMediumSpeed)
            sqlite3_bind_double(s, 8, rules.minWorkBaseRatePerUnitHour)
            sqlite3_bind_double(s, 9, rules.minSpeedDaysDivider)
            sqlite3_bind_double(s, 10, rules.minMaterialUsagePerWorkUnit)
            sqlite3_bind_double(s, 11, rules.minMaterialQuantity)
            try step(s)
        }
    }

    func projects() throws -> [Project] { try fetch("SELECT id,client_id,property_id,name,speed_profile_id,created_at,pricing_mode,is_draft FROM projects ORDER BY id DESC") { s in
        Project(id: sqlite3_column_int64(s,0), clientId: sqlite3_column_int64(s,1), propertyId: sqlite3_column_int64(s,2), name: text(s,3), speedProfileId: sqlite3_column_int64(s,4), createdAt: Date(timeIntervalSince1970: sqlite3_column_double(s,5)), pricingMode: text(s,6), isDraft: sqlite3_column_int(s,7) == 1)
    }}
    func insertProject(_ p: Project) throws -> Int64 {
        try db.withStatement("INSERT INTO projects (client_id,property_id,name,speed_profile_id,created_at,pricing_mode,is_draft) VALUES (?,?,?,?,?,?,?)") { s in
            sqlite3_bind_int64(s,1,p.clientId); sqlite3_bind_int64(s,2,p.propertyId); bind(s,3,p.name); sqlite3_bind_int64(s,4,p.speedProfileId); sqlite3_bind_double(s,5,p.createdAt.timeIntervalSince1970); bind(s,6,p.pricingMode); sqlite3_bind_int(s,7,p.isDraft ? 1 : 0); try step(s)
        }
        return db.lastInsertedRowID()
    }
    func updateProjectSpeedProfile(projectId: Int64, speedProfileId: Int64) throws {
        try db.withStatement("UPDATE projects SET speed_profile_id=? WHERE id=?") { s in
            sqlite3_bind_int64(s, 1, speedProfileId)
            sqlite3_bind_int64(s, 2, projectId)
            try step(s)
        }
    }

    func rooms(projectId: Int64? = nil) throws -> [Room] {
        let sql = projectId == nil ? "SELECT id,project_id,name,area,height,room_type,length,width,ceiling_area,wall_area_auto,wall_area_manual_adjustment,surface_condition,notes,photo_path,room_template_id FROM rooms ORDER BY id DESC" : "SELECT id,project_id,name,area,height,room_type,length,width,ceiling_area,wall_area_auto,wall_area_manual_adjustment,surface_condition,notes,photo_path,room_template_id FROM rooms WHERE project_id=? ORDER BY id DESC"
        return try fetchWithBind(sql, bindValue: projectId) { s in
            Room(id: sqlite3_column_int64(s,0), projectId: sqlite3_column_int64(s,1), name: text(s,2), area: sqlite3_column_double(s,3), height: sqlite3_column_double(s,4), roomType: text(s,5), length: sqlite3_column_double(s,6), width: sqlite3_column_double(s,7), ceilingArea: sqlite3_column_double(s,8), wallAreaAuto: sqlite3_column_double(s,9), wallAreaManualAdjustment: sqlite3_column_double(s,10), surfaceCondition: text(s,11), notes: text(s,12), photoPath: text(s,13), roomTemplateId: nullableInt64(s,14))
        }
    }
    func insertRoom(_ room: Room) throws -> Int64 {
        try db.withStatement("INSERT INTO rooms (project_id,name,area,height,room_type,length,width,ceiling_area,wall_area_auto,wall_area_manual_adjustment,surface_condition,notes,photo_path,room_template_id) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)") { s in
            sqlite3_bind_int64(s,1,room.projectId); bind(s,2,room.name); sqlite3_bind_double(s,3,room.area); sqlite3_bind_double(s,4,room.height); bind(s,5,room.roomType); sqlite3_bind_double(s,6,room.length); sqlite3_bind_double(s,7,room.width); sqlite3_bind_double(s,8,room.ceilingArea); sqlite3_bind_double(s,9,room.wallAreaAuto); sqlite3_bind_double(s,10,room.wallAreaManualAdjustment); bind(s,11,room.surfaceCondition); bind(s,12,room.notes); bind(s,13,room.photoPath); if let id = room.roomTemplateId { sqlite3_bind_int64(s,14,id) } else { sqlite3_bind_null(s,14) }; try step(s)
        }
        return db.lastInsertedRowID()
    }

    func workItems() throws -> [WorkCatalogItem] { try fetch("SELECT id,name,unit,base_rate_hour,base_price,swedish_name,sort_order,category_id,subcategory_id,description,is_active,include_standard_offer,rot_eligible,applicability,base_purchase_price,hourly_price,slow_speed,medium_speed,fast_speed,complexity_coefficient,height_coefficient,condition_coefficient,urgency_coefficient,accessibility_coefficient,additional_labor_hours,additional_material_usage FROM work_catalog ORDER BY sort_order,id") { s in
        WorkCatalogItem(id: sqlite3_column_int64(s,0), name: text(s,1), unit: text(s,2), baseRatePerUnitHour: sqlite3_column_double(s,3), basePrice: sqlite3_column_double(s,4), swedishName: text(s,5), sortOrder: Int(sqlite3_column_int(s,6)), categoryId: nullableInt64(s,7), subcategoryId: nullableInt64(s,8), description: text(s,9), isActive: sqlite3_column_int(s,10) == 1, includeInStandardOffer: sqlite3_column_int(s,11) == 1, rotEligible: sqlite3_column_int(s,12) == 1, applicability: text(s,13), basePurchasePrice: sqlite3_column_double(s,14), hourlyPrice: sqlite3_column_double(s,15), slowSpeed: sqlite3_column_double(s,16), mediumSpeed: sqlite3_column_double(s,17), fastSpeed: sqlite3_column_double(s,18), complexityCoefficient: sqlite3_column_double(s,19), heightCoefficient: sqlite3_column_double(s,20), conditionCoefficient: sqlite3_column_double(s,21), urgencyCoefficient: sqlite3_column_double(s,22), accessibilityCoefficient: sqlite3_column_double(s,23), additionalLaborHours: sqlite3_column_double(s,24), additionalMaterialUsage: sqlite3_column_double(s,25))
    }}
    func insertWorkItem(_ item: WorkCatalogItem) throws -> Int64 {
        try db.withStatement("INSERT INTO work_catalog (name,unit,base_rate_hour,base_price,swedish_name,sort_order,category_id,subcategory_id,description,is_active,include_standard_offer,rot_eligible,applicability,base_purchase_price,hourly_price,slow_speed,medium_speed,fast_speed,complexity_coefficient,height_coefficient,condition_coefficient,urgency_coefficient,accessibility_coefficient,additional_labor_hours,additional_material_usage) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)") { s in
            bind(s,1,item.name); bind(s,2,item.unit); sqlite3_bind_double(s,3,item.baseRatePerUnitHour); sqlite3_bind_double(s,4,item.basePrice); bind(s,5,item.swedishName); sqlite3_bind_int(s,6,Int32(item.sortOrder)); if let id = item.categoryId { sqlite3_bind_int64(s,7,id) } else { sqlite3_bind_null(s,7) }; if let id = item.subcategoryId { sqlite3_bind_int64(s,8,id) } else { sqlite3_bind_null(s,8) }; bind(s,9,item.description); sqlite3_bind_int(s,10,item.isActive ? 1 : 0); sqlite3_bind_int(s,11,item.includeInStandardOffer ? 1 : 0); sqlite3_bind_int(s,12,item.rotEligible ? 1 : 0); bind(s,13,item.applicability); sqlite3_bind_double(s,14,item.basePurchasePrice); sqlite3_bind_double(s,15,item.hourlyPrice); sqlite3_bind_double(s,16,item.slowSpeed); sqlite3_bind_double(s,17,item.mediumSpeed); sqlite3_bind_double(s,18,item.fastSpeed); sqlite3_bind_double(s,19,item.complexityCoefficient); sqlite3_bind_double(s,20,item.heightCoefficient); sqlite3_bind_double(s,21,item.conditionCoefficient); sqlite3_bind_double(s,22,item.urgencyCoefficient); sqlite3_bind_double(s,23,item.accessibilityCoefficient); sqlite3_bind_double(s,24,item.additionalLaborHours); sqlite3_bind_double(s,25,item.additionalMaterialUsage); try step(s)
        }
        return db.lastInsertedRowID()
    }
    func updateWorkItem(_ item: WorkCatalogItem) throws {
        try db.withStatement("UPDATE work_catalog SET name=?,unit=?,base_rate_hour=?,base_price=?,swedish_name=?,sort_order=?,category_id=?,subcategory_id=?,description=?,is_active=?,include_standard_offer=?,rot_eligible=?,applicability=?,base_purchase_price=?,hourly_price=?,slow_speed=?,medium_speed=?,fast_speed=?,complexity_coefficient=?,height_coefficient=?,condition_coefficient=?,urgency_coefficient=?,accessibility_coefficient=?,additional_labor_hours=?,additional_material_usage=? WHERE id=?") { s in
            bind(s,1,item.name); bind(s,2,item.unit); sqlite3_bind_double(s,3,item.baseRatePerUnitHour); sqlite3_bind_double(s,4,item.basePrice); bind(s,5,item.swedishName); sqlite3_bind_int(s,6,Int32(item.sortOrder)); if let id = item.categoryId { sqlite3_bind_int64(s,7,id) } else { sqlite3_bind_null(s,7) }; if let id = item.subcategoryId { sqlite3_bind_int64(s,8,id) } else { sqlite3_bind_null(s,8) }; bind(s,9,item.description); sqlite3_bind_int(s,10,item.isActive ? 1 : 0); sqlite3_bind_int(s,11,item.includeInStandardOffer ? 1 : 0); sqlite3_bind_int(s,12,item.rotEligible ? 1 : 0); bind(s,13,item.applicability); sqlite3_bind_double(s,14,item.basePurchasePrice); sqlite3_bind_double(s,15,item.hourlyPrice); sqlite3_bind_double(s,16,item.slowSpeed); sqlite3_bind_double(s,17,item.mediumSpeed); sqlite3_bind_double(s,18,item.fastSpeed); sqlite3_bind_double(s,19,item.complexityCoefficient); sqlite3_bind_double(s,20,item.heightCoefficient); sqlite3_bind_double(s,21,item.conditionCoefficient); sqlite3_bind_double(s,22,item.urgencyCoefficient); sqlite3_bind_double(s,23,item.accessibilityCoefficient); sqlite3_bind_double(s,24,item.additionalLaborHours); sqlite3_bind_double(s,25,item.additionalMaterialUsage); sqlite3_bind_int64(s,26,item.id); try step(s)
        }
    }

    func materialItems() throws -> [MaterialCatalogItem] { try fetch("SELECT id,name,unit,base_price,swedish_name,sort_order,category_id,purchase_price,markup_percent,supplier_id,sku,usage_per_work_unit,package_size,stock,comment,is_active FROM material_catalog ORDER BY sort_order,id") { s in
        MaterialCatalogItem(id: sqlite3_column_int64(s,0), name: text(s,1), unit: text(s,2), basePrice: sqlite3_column_double(s,3), swedishName: text(s,4), sortOrder: Int(sqlite3_column_int(s,5)), categoryId: nullableInt64(s,6), purchasePrice: sqlite3_column_double(s,7), markupPercent: sqlite3_column_double(s,8), supplierId: nullableInt64(s,9), sku: text(s,10), usagePerWorkUnit: sqlite3_column_double(s,11), packageSize: sqlite3_column_double(s,12), stock: sqlite3_column_double(s,13), comment: text(s,14), isActive: sqlite3_column_int(s,15) == 1)
    }}
    func insertMaterialItem(_ item: MaterialCatalogItem) throws -> Int64 {
        try db.withStatement("INSERT INTO material_catalog (name,unit,base_price,swedish_name,sort_order,category_id,purchase_price,markup_percent,supplier_id,sku,usage_per_work_unit,package_size,stock,comment,is_active) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)") { s in
            bind(s,1,item.name); bind(s,2,item.unit); sqlite3_bind_double(s,3,item.basePrice); bind(s,4,item.swedishName); sqlite3_bind_int(s,5,Int32(item.sortOrder)); if let id = item.categoryId { sqlite3_bind_int64(s,6,id) } else { sqlite3_bind_null(s,6) }; sqlite3_bind_double(s,7,item.purchasePrice); sqlite3_bind_double(s,8,item.markupPercent); if let id = item.supplierId { sqlite3_bind_int64(s,9,id) } else { sqlite3_bind_null(s,9) }; bind(s,10,item.sku); sqlite3_bind_double(s,11,item.usagePerWorkUnit); sqlite3_bind_double(s,12,item.packageSize); sqlite3_bind_double(s,13,item.stock); bind(s,14,item.comment); sqlite3_bind_int(s,15,item.isActive ? 1 : 0); try step(s)
        }
        return db.lastInsertedRowID()
    }
    func updateMaterialItem(_ item: MaterialCatalogItem) throws {
        try db.withStatement("UPDATE material_catalog SET name=?,unit=?,base_price=?,swedish_name=?,sort_order=?,category_id=?,purchase_price=?,markup_percent=?,supplier_id=?,sku=?,usage_per_work_unit=?,package_size=?,stock=?,comment=?,is_active=? WHERE id=?") { s in
            bind(s,1,item.name); bind(s,2,item.unit); sqlite3_bind_double(s,3,item.basePrice); bind(s,4,item.swedishName); sqlite3_bind_int(s,5,Int32(item.sortOrder)); if let id = item.categoryId { sqlite3_bind_int64(s,6,id) } else { sqlite3_bind_null(s,6) }; sqlite3_bind_double(s,7,item.purchasePrice); sqlite3_bind_double(s,8,item.markupPercent); if let id = item.supplierId { sqlite3_bind_int64(s,9,id) } else { sqlite3_bind_null(s,9) }; bind(s,10,item.sku); sqlite3_bind_double(s,11,item.usagePerWorkUnit); sqlite3_bind_double(s,12,item.packageSize); sqlite3_bind_double(s,13,item.stock); bind(s,14,item.comment); sqlite3_bind_int(s,15,item.isActive ? 1 : 0); sqlite3_bind_int64(s,16,item.id); try step(s)
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


    func surfaces(roomId: Int64) throws -> [Surface] {
        try fetchWithBind("SELECT id,room_id,type,name,area,perimeter,is_custom,source,manual_adjustment FROM surfaces WHERE room_id=? ORDER BY id", bindValue: roomId) { s in
            Surface(id: sqlite3_column_int64(s,0), roomId: sqlite3_column_int64(s,1), type: text(s,2), name: text(s,3), area: sqlite3_column_double(s,4), perimeter: sqlite3_column_double(s,5), isCustom: sqlite3_column_int(s,6) == 1, source: text(s,7), manualAdjustment: sqlite3_column_double(s,8))
        }
    }

    func openings(roomId: Int64) throws -> [Opening] {
        try fetchWithBind("SELECT id,room_id,surface_id,type,name,width,height,count,subtract_from_wall_area FROM openings WHERE room_id=? ORDER BY id", bindValue: roomId) { s in
            Opening(id: sqlite3_column_int64(s,0), roomId: sqlite3_column_int64(s,1), surfaceId: nullableInt64(s,2), type: text(s,3), name: text(s,4), width: sqlite3_column_double(s,5), height: sqlite3_column_double(s,6), count: Int(sqlite3_column_int(s,7)), subtractFromWallArea: sqlite3_column_int(s,8) == 1)
        }
    }

    func replaceSurfaces(roomId: Int64, surfaces: [Surface]) throws {
        try db.withStatement("DELETE FROM surfaces WHERE room_id=?") { s in sqlite3_bind_int64(s,1,roomId); try step(s) }
        for surface in surfaces {
            try db.withStatement("INSERT INTO surfaces (room_id,type,name,area,perimeter,is_custom,source,manual_adjustment) VALUES (?,?,?,?,?,?,?,?)") { s in
                sqlite3_bind_int64(s,1,roomId); bind(s,2,surface.type); bind(s,3,surface.name); sqlite3_bind_double(s,4,surface.area); sqlite3_bind_double(s,5,surface.perimeter); sqlite3_bind_int(s,6,surface.isCustom ? 1 : 0); bind(s,7,surface.source); sqlite3_bind_double(s,8,surface.manualAdjustment); try step(s)
            }
        }
    }

    func addOpening(_ opening: Opening) throws {
        try db.withStatement("INSERT INTO openings (room_id,surface_id,type,name,width,height,count,subtract_from_wall_area) VALUES (?,?,?,?,?,?,?,?)") { s in
            sqlite3_bind_int64(s,1,opening.roomId); if let sid = opening.surfaceId { sqlite3_bind_int64(s,2,sid) } else { sqlite3_bind_null(s,2) }; bind(s,3,opening.type); bind(s,4,opening.name); sqlite3_bind_double(s,5,opening.width); sqlite3_bind_double(s,6,opening.height); sqlite3_bind_int(s,7,Int32(opening.count)); sqlite3_bind_int(s,8,opening.subtractFromWallArea ? 1 : 0); try step(s)
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
