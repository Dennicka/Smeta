import Foundation
import SQLite3

extension AppRepository {
    func seedStage2Defaults() throws {
        if try documentSeries().isEmpty {
            let defaults: [(DocumentType, String)] = [(.offert, "OFF"), (.avtal, "AVT"), (.faktura, "FAK"), (.kreditfaktura, "KRF"), (.ata, "ATA"), (.paminnelse, "PAM")]
            for (type, prefix) in defaults {
                _ = try insertDocumentSeries(DocumentSeries(id: 0, documentType: type.rawValue, prefix: prefix, nextNumber: 1, active: true))
            }
        }
        if try taxProfiles().isEmpty {
            _ = try insertTaxProfile(TaxProfile(id: 0, name: "B2C Moms 25%", customerType: CustomerType.b2c.rawValue, taxMode: TaxMode.normal.rawValue, vatRate: 0.25, rotPercent: 0.3, active: true))
            _ = try insertTaxProfile(TaxProfile(id: 0, name: "B2B Moms 25%", customerType: CustomerType.b2b.rawValue, taxMode: TaxMode.normal.rawValue, vatRate: 0.25, rotPercent: 0, active: true))
            _ = try insertTaxProfile(TaxProfile(id: 0, name: "B2B Reverse Charge", customerType: CustomerType.b2b.rawValue, taxMode: TaxMode.reverseCharge.rawValue, vatRate: 0, rotPercent: 0, active: true))
        }
    }

    func insertDocumentSeries(_ row: DocumentSeries) throws -> Int64 {
        try db.withStatement("INSERT INTO document_series (document_type,prefix,next_number,active) VALUES (?,?,?,?)") { s in
            bind2(s, 1, row.documentType); bind2(s, 2, row.prefix); sqlite3_bind_int(s, 3, Int32(row.nextNumber)); sqlite3_bind_int(s, 4, row.active ? 1 : 0); try step2(s)
        }
        return db.lastInsertedRowID()
    }

    func documentSeries() throws -> [DocumentSeries] {
        try fetch2("SELECT id,document_type,prefix,next_number,active FROM document_series ORDER BY document_type") { s in
            DocumentSeries(id: sqlite3_column_int64(s, 0), documentType: text2(s, 1), prefix: text2(s, 2), nextNumber: Int(sqlite3_column_int(s, 3)), active: sqlite3_column_int(s, 4) == 1)
        }
    }

    func updateDocumentSeries(_ row: DocumentSeries) throws {
        try db.withStatement("UPDATE document_series SET prefix=?,next_number=?,active=? WHERE id=?") { s in
            bind2(s, 1, row.prefix); sqlite3_bind_int(s, 2, Int32(row.nextNumber)); sqlite3_bind_int(s, 3, row.active ? 1 : 0); sqlite3_bind_int64(s, 4, row.id); try step2(s)
        }
    }

    func insertTaxProfile(_ row: TaxProfile) throws -> Int64 {
        try db.withStatement("INSERT INTO tax_profiles (name,customer_type,tax_mode,vat_rate,rot_percent,active) VALUES (?,?,?,?,?,?)") { s in
            bind2(s, 1, row.name); bind2(s, 2, row.customerType); bind2(s, 3, row.taxMode); sqlite3_bind_double(s, 4, row.vatRate); sqlite3_bind_double(s, 5, row.rotPercent); sqlite3_bind_int(s, 6, row.active ? 1 : 0); try step2(s)
        }
        return db.lastInsertedRowID()
    }

    func taxProfiles() throws -> [TaxProfile] {
        try fetch2("SELECT id,name,customer_type,tax_mode,vat_rate,rot_percent,active FROM tax_profiles ORDER BY id") { s in
            TaxProfile(id: sqlite3_column_int64(s, 0), name: text2(s, 1), customerType: text2(s, 2), taxMode: text2(s, 3), vatRate: sqlite3_column_double(s, 4), rotPercent: sqlite3_column_double(s, 5), active: sqlite3_column_int(s, 6) == 1)
        }
    }

    func updateProjectStatus(projectId: Int64, status: ProjectWorkflowStatus, note: String = "") throws {
        try db.withStatement("UPDATE projects SET workflow_status=? WHERE id=?") { s in
            bind2(s, 1, status.rawValue); sqlite3_bind_int64(s, 2, projectId); try step2(s)
        }
        try db.withStatement("INSERT INTO project_status_history (project_id,status,changed_at,note) VALUES (?,?,?,?)") { s in
            sqlite3_bind_int64(s, 1, projectId); bind2(s, 2, status.rawValue); sqlite3_bind_double(s, 3, Date().timeIntervalSince1970); bind2(s, 4, note); try step2(s)
        }
    }

    func createBusinessDocument(_ doc: BusinessDocument, lines: [BusinessDocumentLine]) throws -> Int64 {
        try db.withStatement("INSERT INTO business_documents (project_id,type,status,number,title,issue_date,due_date,customer_type,tax_mode,currency,subtotal_labor,subtotal_material,subtotal_other,vat_rate,vat_amount,rot_eligible_labor,rot_reduction,total_amount,paid_amount,balance_due,related_document_id,notes) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)") { s in
            sqlite3_bind_int64(s, 1, doc.projectId); bind2(s, 2, doc.type); bind2(s, 3, doc.status); bind2(s, 4, doc.number); bind2(s, 5, doc.title)
            sqlite3_bind_double(s, 6, doc.issueDate.timeIntervalSince1970)
            if let due = doc.dueDate { sqlite3_bind_double(s, 7, due.timeIntervalSince1970) } else { sqlite3_bind_null(s, 7) }
            bind2(s, 8, doc.customerType); bind2(s, 9, doc.taxMode); bind2(s, 10, doc.currency)
            sqlite3_bind_double(s, 11, doc.subtotalLabor); sqlite3_bind_double(s, 12, doc.subtotalMaterial); sqlite3_bind_double(s, 13, doc.subtotalOther)
            sqlite3_bind_double(s, 14, doc.vatRate); sqlite3_bind_double(s, 15, doc.vatAmount); sqlite3_bind_double(s, 16, doc.rotEligibleLabor); sqlite3_bind_double(s, 17, doc.rotReduction)
            sqlite3_bind_double(s, 18, doc.totalAmount); sqlite3_bind_double(s, 19, doc.paidAmount); sqlite3_bind_double(s, 20, doc.balanceDue)
            if let rel = doc.relatedDocumentId { sqlite3_bind_int64(s, 21, rel) } else { sqlite3_bind_null(s, 21) }
            bind2(s, 22, doc.notes); try step2(s)
        }
        let id = db.lastInsertedRowID()
        for line in lines {
            try db.withStatement("INSERT INTO business_document_lines (document_id,line_type,description,quantity,unit,unit_price,vat_rate,is_rot_eligible,total) VALUES (?,?,?,?,?,?,?,?,?)") { s in
                sqlite3_bind_int64(s, 1, id); bind2(s, 2, line.lineType); bind2(s, 3, line.description); sqlite3_bind_double(s, 4, line.quantity); bind2(s, 5, line.unit)
                sqlite3_bind_double(s, 6, line.unitPrice); sqlite3_bind_double(s, 7, line.vatRate); sqlite3_bind_int(s, 8, line.isRotEligible ? 1 : 0); sqlite3_bind_double(s, 9, line.total); try step2(s)
            }
        }
        return id
    }

    func performDocumentFinalizationWrites(
        documentId: Int64,
        templateId: Int64?,
        snapshotBuilder: (BusinessDocument, [BusinessDocumentLine]) throws -> String,
        failureInjection: (() throws -> Void)? = nil
    ) throws {
        try db.execute("BEGIN IMMEDIATE TRANSACTION")
        var committed = false
        defer {
            if !committed {
                try? db.execute("ROLLBACK")
            }
        }

        guard let currentDocument = try businessDocument(documentId: documentId) else {
            throw DatabaseError.executeFailed("Документ не найден")
        }

        if currentDocument.status == DocumentStatus.finalized.rawValue {
            try db.execute("COMMIT")
            committed = true
            return
        }

        guard currentDocument.status == DocumentStatus.draft.rawValue else {
            throw DatabaseError.executeFailed("Финализация доступна только для draft-документа")
        }

        let activeSeries = try requireActiveSeries(for: currentDocument.type)
        let assignedNumber = "\(activeSeries.prefix)-\(String(format: "%06d", activeSeries.nextNumber))"

        try db.withStatement("UPDATE business_documents SET status='finalized', number=? WHERE id=? AND status='draft'") { s in
            bind2(s, 1, assignedNumber)
            sqlite3_bind_int64(s, 2, documentId)
            try step2(s)
        }

        try db.withStatement("UPDATE document_series SET next_number=? WHERE id=?") { s in
            sqlite3_bind_int(s, 1, Int32(activeSeries.nextNumber + 1))
            sqlite3_bind_int64(s, 2, activeSeries.id)
            try step2(s)
        }

        try failureInjection?()

        guard let finalizedDocument = try businessDocument(documentId: documentId),
              finalizedDocument.status == DocumentStatus.finalized.rawValue,
              !finalizedDocument.number.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              finalizedDocument.number == assignedNumber else {
            throw DatabaseError.executeFailed("Не удалось подтвердить финальное состояние документа")
        }

        let finalizedLines = try businessDocumentLines(documentId: documentId)
        let snapshotJSON = try snapshotBuilder(finalizedDocument, finalizedLines)
        guard !snapshotJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DatabaseError.executeFailed("Пустой snapshot документа")
        }

        try db.withStatement("INSERT INTO document_snapshots (document_id,template_id,snapshot_json,created_at) VALUES (?,?,?,?)") { s in
            sqlite3_bind_int64(s, 1, documentId)
            if let templateId { sqlite3_bind_int64(s, 2, templateId) } else { sqlite3_bind_null(s, 2) }
            bind2(s, 3, snapshotJSON)
            sqlite3_bind_double(s, 4, Date().timeIntervalSince1970)
            try step2(s)
        }

        try db.execute("COMMIT")
        committed = true
    }

    func finalizeDocumentWithSnapshot(
        documentId: Int64,
        templateId: Int64?,
        snapshotBuilder: (BusinessDocument, [BusinessDocumentLine]) throws -> String
    ) throws {
        try performDocumentFinalizationWrites(
            documentId: documentId,
            templateId: templateId,
            snapshotBuilder: snapshotBuilder
        )
    }

    func businessDocuments() throws -> [BusinessDocument] {
        try fetch2("SELECT id,project_id,type,status,number,title,issue_date,due_date,customer_type,tax_mode,currency,subtotal_labor,subtotal_material,subtotal_other,vat_rate,vat_amount,rot_eligible_labor,rot_reduction,total_amount,paid_amount,balance_due,related_document_id,notes FROM business_documents ORDER BY id DESC") { s in
            BusinessDocument(id: sqlite3_column_int64(s, 0), projectId: sqlite3_column_int64(s, 1), type: text2(s, 2), status: text2(s, 3), number: text2(s, 4), title: text2(s, 5), issueDate: Date(timeIntervalSince1970: sqlite3_column_double(s, 6)), dueDate: sqlite3_column_type(s, 7) == SQLITE_NULL ? nil : Date(timeIntervalSince1970: sqlite3_column_double(s, 7)), customerType: text2(s, 8), taxMode: text2(s, 9), currency: text2(s, 10), subtotalLabor: sqlite3_column_double(s, 11), subtotalMaterial: sqlite3_column_double(s, 12), subtotalOther: sqlite3_column_double(s, 13), vatRate: sqlite3_column_double(s, 14), vatAmount: sqlite3_column_double(s, 15), rotEligibleLabor: sqlite3_column_double(s, 16), rotReduction: sqlite3_column_double(s, 17), totalAmount: sqlite3_column_double(s, 18), paidAmount: sqlite3_column_double(s, 19), balanceDue: sqlite3_column_double(s, 20), relatedDocumentId: sqlite3_column_type(s, 21) == SQLITE_NULL ? nil : sqlite3_column_int64(s, 21), notes: text2(s, 22))
        }
    }

    func businessDocument(documentId: Int64) throws -> BusinessDocument? {
        try fetchWithBind2("SELECT id,project_id,type,status,number,title,issue_date,due_date,customer_type,tax_mode,currency,subtotal_labor,subtotal_material,subtotal_other,vat_rate,vat_amount,rot_eligible_labor,rot_reduction,total_amount,paid_amount,balance_due,related_document_id,notes FROM business_documents WHERE id=? LIMIT 1", bindValue: documentId) { s in
            BusinessDocument(id: sqlite3_column_int64(s, 0), projectId: sqlite3_column_int64(s, 1), type: text2(s, 2), status: text2(s, 3), number: text2(s, 4), title: text2(s, 5), issueDate: Date(timeIntervalSince1970: sqlite3_column_double(s, 6)), dueDate: sqlite3_column_type(s, 7) == SQLITE_NULL ? nil : Date(timeIntervalSince1970: sqlite3_column_double(s, 7)), customerType: text2(s, 8), taxMode: text2(s, 9), currency: text2(s, 10), subtotalLabor: sqlite3_column_double(s, 11), subtotalMaterial: sqlite3_column_double(s, 12), subtotalOther: sqlite3_column_double(s, 13), vatRate: sqlite3_column_double(s, 14), vatAmount: sqlite3_column_double(s, 15), rotEligibleLabor: sqlite3_column_double(s, 16), rotReduction: sqlite3_column_double(s, 17), totalAmount: sqlite3_column_double(s, 18), paidAmount: sqlite3_column_double(s, 19), balanceDue: sqlite3_column_double(s, 20), relatedDocumentId: sqlite3_column_type(s, 21) == SQLITE_NULL ? nil : sqlite3_column_int64(s, 21), notes: text2(s, 22))
        }.first
    }

    func businessDocumentLines(documentId: Int64) throws -> [BusinessDocumentLine] {
        try fetchWithBind2("SELECT id,document_id,line_type,description,quantity,unit,unit_price,vat_rate,is_rot_eligible,total FROM business_document_lines WHERE document_id=? ORDER BY id", bindValue: documentId) { s in
            BusinessDocumentLine(id: sqlite3_column_int64(s, 0), documentId: sqlite3_column_int64(s, 1), lineType: text2(s, 2), description: text2(s, 3), quantity: sqlite3_column_double(s, 4), unit: text2(s, 5), unitPrice: sqlite3_column_double(s, 6), vatRate: sqlite3_column_double(s, 7), isRotEligible: sqlite3_column_int(s, 8) == 1, total: sqlite3_column_double(s, 9))
        }
    }

    func documentSnapshots(documentId: Int64) throws -> [DocumentSnapshot] {
        try fetchWithBind2("SELECT id,document_id,template_id,snapshot_json,created_at FROM document_snapshots WHERE document_id=? ORDER BY id DESC", bindValue: documentId) { s in
            DocumentSnapshot(id: sqlite3_column_int64(s, 0), documentId: sqlite3_column_int64(s, 1), templateId: sqlite3_column_type(s, 2) == SQLITE_NULL ? nil : sqlite3_column_int64(s, 2), snapshotJSON: text2(s, 3), createdAt: Date(timeIntervalSince1970: sqlite3_column_double(s, 4)))
        }
    }

    func registerPayment(documentId: Int64, amount: Double, method: String, reference: String) throws {
        guard amount > 0 else { throw DatabaseError.executeFailed("Сумма оплаты должна быть больше нуля") }

        var balanceDue: Double = -1
        try db.withStatement("SELECT balance_due FROM business_documents WHERE id=?") { s in
            sqlite3_bind_int64(s, 1, documentId)
            if sqlite3_step(s) == SQLITE_ROW {
                balanceDue = sqlite3_column_double(s, 0)
            }
        }
        guard balanceDue >= 0 else { throw DatabaseError.executeFailed("Счёт не найден") }
        guard amount <= balanceDue else { throw DatabaseError.executeFailed("Оплата превышает остаток по счёту") }

        try db.withStatement("INSERT INTO payments (amount,paid_at,method,reference) VALUES (?,?,?,?)") { s in
            sqlite3_bind_double(s, 1, amount); sqlite3_bind_double(s, 2, Date().timeIntervalSince1970); bind2(s, 3, method); bind2(s, 4, reference); try step2(s)
        }
        let paymentId = db.lastInsertedRowID()
        try db.withStatement("INSERT INTO payment_allocations (payment_id,document_id,amount) VALUES (?,?,?)") { s in
            sqlite3_bind_int64(s, 1, paymentId); sqlite3_bind_int64(s, 2, documentId); sqlite3_bind_double(s, 3, amount); try step2(s)
        }
        try db.withStatement("UPDATE business_documents SET paid_amount=paid_amount+?, balance_due=MAX(balance_due-?,0), status=CASE WHEN balance_due-?<=0 THEN 'paid' ELSE 'sent' END WHERE id=?") { s in
            sqlite3_bind_double(s, 1, amount); sqlite3_bind_double(s, 2, amount); sqlite3_bind_double(s, 3, amount); sqlite3_bind_int64(s, 4, documentId); try step2(s)
        }
    }

    private func requireActiveSeries(for documentType: String) throws -> DocumentSeries {
        var activeSeries: DocumentSeries?
        var activeCount = 0
        try db.withStatement("SELECT id,prefix,next_number FROM document_series WHERE document_type=? AND active=1 ORDER BY id") { s in
            bind2(s, 1, documentType)
            while sqlite3_step(s) == SQLITE_ROW {
                activeCount += 1
                if activeSeries == nil {
                    activeSeries = DocumentSeries(
                        id: sqlite3_column_int64(s, 0),
                        documentType: documentType,
                        prefix: text2(s, 1),
                        nextNumber: Int(sqlite3_column_int(s, 2)),
                        active: true
                    )
                }
            }
        }

        guard let activeSeries else {
            throw DatabaseError.executeFailed("Нет активной серии для типа документа '\(documentType)'")
        }
        guard activeCount == 1 else {
            throw DatabaseError.executeFailed("Для типа документа '\(documentType)' должна быть ровно одна активная серия")
        }
        return activeSeries
    }

    private func fetch2<T>(_ sql: String, _ map: (OpaquePointer) -> T) throws -> [T] {
        var items: [T] = []
        try db.withStatement(sql) { s in
            while sqlite3_step(s) == SQLITE_ROW { items.append(map(s)) }
        }
        return items
    }

    private func fetchWithBind2<T>(_ sql: String, bindValue: Int64, map: (OpaquePointer) -> T) throws -> [T] {
        var items: [T] = []
        try db.withStatement(sql) { s in
            sqlite3_bind_int64(s, 1, bindValue)
            while sqlite3_step(s) == SQLITE_ROW { items.append(map(s)) }
        }
        return items
    }

    private func bind2(_ stmt: OpaquePointer, _ index: Int32, _ value: String) { sqlite3_bind_text(stmt, index, value, -1, SQLITE_TRANSIENT) }
    private func text2(_ stmt: OpaquePointer, _ index: Int32) -> String {
        guard let c = sqlite3_column_text(stmt, index) else { return "" }
        return String(cString: c)
    }
    private func step2(_ stmt: OpaquePointer) throws {
        if sqlite3_step(stmt) != SQLITE_DONE { throw DatabaseError.executeFailed("Step failed") }
    }
}
