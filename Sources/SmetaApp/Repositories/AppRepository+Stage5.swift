import Foundation
import SQLite3

extension AppRepository {
    func suppliers() throws -> [Supplier] {
        try fetch5("SELECT id,name,contact,phone,email FROM suppliers ORDER BY name") { s in
            Supplier(id: sqlite3_column_int64(s, 0), name: text5(s, 1), contact: text5(s, 2), phone: text5(s, 3), email: text5(s, 4))
        }
    }

    func upsertSupplier(_ row: Supplier) throws -> Int64 {
        var existing: Int64?
        try db.withStatement("SELECT id FROM suppliers WHERE lower(name)=lower(?) LIMIT 1") { s in
            bind5(s, 1, row.name)
            if sqlite3_step(s) == SQLITE_ROW { existing = sqlite3_column_int64(s, 0) }
        }
        if let existing {
            try db.withStatement("UPDATE suppliers SET contact=?,phone=?,email=? WHERE id=?") { s in
                bind5(s, 1, row.contact); bind5(s, 2, row.phone); bind5(s, 3, row.email); sqlite3_bind_int64(s, 4, existing); try step5(s)
            }
            return existing
        }
        try db.withStatement("INSERT INTO suppliers (name,contact,phone,email) VALUES (?,?,?,?)") { s in
            bind5(s, 1, row.name); bind5(s, 2, row.contact); bind5(s, 3, row.phone); bind5(s, 4, row.email); try step5(s)
        }
        return db.lastInsertedRowID()
    }

    func upsertSupplierArticle(supplierId: Int64, materialName: String, sku: String, purchasePrice: Double, isPrimary: Bool) throws {
        var materialId: Int64?
        try db.withStatement("SELECT id FROM material_catalog WHERE lower(name)=lower(?) LIMIT 1") { s in
            bind5(s, 1, materialName)
            if sqlite3_step(s) == SQLITE_ROW { materialId = sqlite3_column_int64(s, 0) }
        }
        guard let materialId else { throw DatabaseError.executeFailed("Material not found: \(materialName)") }

        var articleId: Int64?
        try db.withStatement("SELECT id FROM supplier_articles WHERE supplier_id=? AND material_item_id=? AND sku=? LIMIT 1") { s in
            sqlite3_bind_int64(s, 1, supplierId); sqlite3_bind_int64(s, 2, materialId); bind5(s, 3, sku)
            if sqlite3_step(s) == SQLITE_ROW { articleId = sqlite3_column_int64(s, 0) }
        }

        if let articleId {
            try db.withStatement("UPDATE supplier_articles SET purchase_price=?,is_primary=? WHERE id=?") { s in
                sqlite3_bind_double(s, 1, purchasePrice); sqlite3_bind_int(s, 2, isPrimary ? 1 : 0); sqlite3_bind_int64(s, 3, articleId); try step5(s)
            }
            try recordPriceHistory(articleId: articleId, purchasePrice: purchasePrice, source: "import-update")
        } else {
            try db.withStatement("INSERT INTO supplier_articles (supplier_id,material_item_id,sku,purchase_price,is_primary) VALUES (?,?,?,?,?)") { s in
                sqlite3_bind_int64(s, 1, supplierId); sqlite3_bind_int64(s, 2, materialId); bind5(s, 3, sku); sqlite3_bind_double(s, 4, purchasePrice); sqlite3_bind_int(s, 5, isPrimary ? 1 : 0); try step5(s)
            }
            let newId = db.lastInsertedRowID()
            try recordPriceHistory(articleId: newId, purchasePrice: purchasePrice, source: "import-create")
        }

        try db.withStatement("UPDATE material_catalog SET purchase_price=?, supplier_id=?, sku=? WHERE id=?") { s in
            sqlite3_bind_double(s, 1, purchasePrice); sqlite3_bind_int64(s, 2, supplierId); bind5(s, 3, sku); sqlite3_bind_int64(s, 4, materialId); try step5(s)
        }
    }

    func recordPriceHistory(articleId: Int64, purchasePrice: Double, source: String) throws {
        try db.withStatement("INSERT INTO supplier_price_history (supplier_article_id,purchase_price,changed_at,source) VALUES (?,?,?,?)") { s in
            sqlite3_bind_int64(s, 1, articleId); sqlite3_bind_double(s, 2, purchasePrice); sqlite3_bind_double(s, 3, Date().timeIntervalSince1970); bind5(s, 4, source); try step5(s)
        }
    }

    func bulkUpdateMaterialPrices(percent: Double, appliesToSellingPrice: Bool) throws -> Int {
        let factor = 1 + percent / 100
        let sql = appliesToSellingPrice
            ? "UPDATE material_catalog SET base_price = ROUND(base_price * ?, 2)"
            : "UPDATE material_catalog SET purchase_price = ROUND(purchase_price * ?, 2)"
        try db.withStatement(sql) { s in sqlite3_bind_double(s, 1, factor); try step5(s) }
        return try materialItems().count
    }

    func replacePreferredSupplier(materialId: Int64, supplierId: Int64?) throws {
        try db.withStatement("UPDATE material_catalog SET supplier_id=? WHERE id=?") { s in
            if let supplierId { sqlite3_bind_int64(s, 1, supplierId) } else { sqlite3_bind_null(s, 1) }
            sqlite3_bind_int64(s, 2, materialId)
            try step5(s)
        }
    }

    func receivablesDocuments() throws -> [BusinessDocument] {
        try fetch5("SELECT id,project_id,type,status,number,title,issue_date,due_date,customer_type,tax_mode,currency,subtotal_labor,subtotal_material,subtotal_other,vat_rate,vat_amount,rot_eligible_labor,rot_reduction,total_amount,paid_amount,balance_due,related_document_id,notes FROM business_documents WHERE type='faktura' ORDER BY due_date") { s in
            BusinessDocument(id: sqlite3_column_int64(s, 0), projectId: sqlite3_column_int64(s, 1), type: text5(s, 2), status: text5(s, 3), number: text5(s, 4), title: text5(s, 5), issueDate: Date(timeIntervalSince1970: sqlite3_column_double(s, 6)), dueDate: sqlite3_column_type(s, 7) == SQLITE_NULL ? nil : Date(timeIntervalSince1970: sqlite3_column_double(s, 7)), customerType: text5(s, 8), taxMode: text5(s, 9), currency: text5(s, 10), subtotalLabor: sqlite3_column_double(s, 11), subtotalMaterial: sqlite3_column_double(s, 12), subtotalOther: sqlite3_column_double(s, 13), vatRate: sqlite3_column_double(s, 14), vatAmount: sqlite3_column_double(s, 15), rotEligibleLabor: sqlite3_column_double(s, 16), rotReduction: sqlite3_column_double(s, 17), totalAmount: sqlite3_column_double(s, 18), paidAmount: sqlite3_column_double(s, 19), balanceDue: sqlite3_column_double(s, 20), relatedDocumentId: sqlite3_column_type(s, 21) == SQLITE_NULL ? nil : sqlite3_column_int64(s, 21), notes: text5(s, 22))
        }
    }

    func setProjectLifecycle(projectId: Int64, status: String, note: String = "") throws {
        try db.withStatement("UPDATE projects SET lifecycle_status=?, archived_at=CASE WHEN ?='archived' THEN ? ELSE archived_at END WHERE id=?") { s in
            bind5(s, 1, status); bind5(s, 2, status); sqlite3_bind_double(s, 3, Date().timeIntervalSince1970); sqlite3_bind_int64(s, 4, projectId); try step5(s)
        }
        try db.withStatement("INSERT INTO project_lifecycle_history (project_id,lifecycle_status,changed_at,note) VALUES (?,?,?,?)") { s in
            sqlite3_bind_int64(s, 1, projectId); bind5(s, 2, status); sqlite3_bind_double(s, 3, Date().timeIntervalSince1970); bind5(s, 4, note); try step5(s)
        }
    }

    func addProjectNote(projectId: Int64, type: String, text: String, pinned: Bool) throws {
        try db.withStatement("INSERT INTO project_notes (project_id,note_type,text,pinned,updated_at) VALUES (?,?,?,?,?)") { s in
            sqlite3_bind_int64(s, 1, projectId); bind5(s, 2, type); bind5(s, 3, text); sqlite3_bind_int(s, 4, pinned ? 1 : 0); sqlite3_bind_double(s, 5, Date().timeIntervalSince1970); try step5(s)
        }
    }

    func projectNotes(projectId: Int64) throws -> [ProjectNote] {
        try fetchWithBind5("SELECT id,project_id,note_type,text,pinned,updated_at FROM project_notes WHERE project_id=? ORDER BY pinned DESC, updated_at DESC", bindValue: projectId) { s in
            ProjectNote(id: sqlite3_column_int64(s, 0), projectId: sqlite3_column_int64(s, 1), noteType: text5(s, 2), text: text5(s, 3), pinned: sqlite3_column_int(s, 4) == 1, updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(s, 5)))
        }
    }

    func logExport(kind: String, scope: String, path: String) throws {
        try db.withStatement("INSERT INTO export_logs (kind,scope,path,created_at) VALUES (?,?,?,?)") { s in
            bind5(s, 1, kind); bind5(s, 2, scope); bind5(s, 3, path); sqlite3_bind_double(s, 4, Date().timeIntervalSince1970); try step5(s)
        }
    }

    func performBusinessDocumentPDFExportWrites(
        payload: BusinessDocumentPDFExportWritePayload,
        beforeCommit: (() throws -> Void)? = nil,
        failureInjection: (() throws -> Void)? = nil
    ) throws {
        try db.execute("BEGIN IMMEDIATE TRANSACTION")
        var committed = false
        defer {
            if !committed {
                try? db.execute("ROLLBACK")
            }
        }

        try logExport(kind: payload.exportKind, scope: payload.exportScope, path: payload.finalPath)
        try failureInjection?()
        try beforeCommit?()
        try db.execute("COMMIT")
        committed = true
    }
}


private extension AppRepository {
    func fetch5<T>(_ sql: String, _ map: (OpaquePointer) -> T) throws -> [T] {
        var items: [T] = []
        try db.withStatement(sql) { s in
            while sqlite3_step(s) == SQLITE_ROW { items.append(map(s)) }
        }
        return items
    }

    func fetchWithBind5<T>(_ sql: String, bindValue: Int64, map: (OpaquePointer) -> T) throws -> [T] {
        var items: [T] = []
        try db.withStatement(sql) { s in
            sqlite3_bind_int64(s, 1, bindValue)
            while sqlite3_step(s) == SQLITE_ROW { items.append(map(s)) }
        }
        return items
    }

    func bind5(_ stmt: OpaquePointer, _ index: Int32, _ value: String) { sqlite3_bind_text(stmt, index, value, -1, SQLITE_TRANSIENT) }
    func text5(_ stmt: OpaquePointer, _ index: Int32) -> String {
        guard let c = sqlite3_column_text(stmt, index) else { return "" }
        return String(cString: c)
    }
    func step5(_ stmt: OpaquePointer) throws {
        if sqlite3_step(stmt) != SQLITE_DONE { throw DatabaseError.executeFailed("Step failed") }
    }
}
