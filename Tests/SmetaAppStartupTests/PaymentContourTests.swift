import XCTest
import SQLite3
@testable import SmetaApp

@MainActor
final class PaymentContourTests: XCTestCase {
    func testPartialPaymentSuccessUpdatesPaidAmountBalanceAndStatus() throws {
        let (repo, dbPath, projectId) = try makeRepository(tag: "partial-success")
        defer { cleanupSQLiteArtifacts(at: dbPath) }
        let invoiceId = try createInvoice(repository: repo, projectId: projectId, status: DocumentStatus.finalized.rawValue, totalAmount: 1_000)

        try repo.registerPayment(documentId: invoiceId, amount: 300, method: "Bankgiro", reference: "P1")

        let updated = try XCTUnwrap(repo.businessDocument(documentId: invoiceId))
        XCTAssertEqual(updated.paidAmount, 300, accuracy: 0.0001)
        XCTAssertEqual(updated.balanceDue, 700, accuracy: 0.0001)
        XCTAssertEqual(updated.status, DocumentStatus.partiallyPaid.rawValue)

        let payments = try repo.documentPayments(documentId: invoiceId)
        XCTAssertEqual(payments.count, 1)
        XCTAssertEqual(payments.first?.amount, 300, accuracy: 0.0001)
    }

    func testFinalPaymentClosesInvoice() throws {
        let (repo, dbPath, projectId) = try makeRepository(tag: "final-close")
        defer { cleanupSQLiteArtifacts(at: dbPath) }
        let invoiceId = try createInvoice(repository: repo, projectId: projectId, status: DocumentStatus.finalized.rawValue, totalAmount: 1_000)

        try repo.registerPayment(documentId: invoiceId, amount: 400, method: "Bankgiro", reference: "P1")
        try repo.registerPayment(documentId: invoiceId, amount: 600, method: "Bankgiro", reference: "P2")

        let updated = try XCTUnwrap(repo.businessDocument(documentId: invoiceId))
        XCTAssertEqual(updated.paidAmount, 1_000, accuracy: 0.0001)
        XCTAssertEqual(updated.balanceDue, 0, accuracy: 0.0001)
        XCTAssertEqual(updated.status, DocumentStatus.paid.rawValue)
        XCTAssertEqual(try repo.documentPayments(documentId: invoiceId).count, 2)
    }

    func testOverpaymentRejectedWithoutStateMutation() throws {
        let (repo, dbPath, projectId) = try makeRepository(tag: "overpay")
        defer { cleanupSQLiteArtifacts(at: dbPath) }
        let invoiceId = try createInvoice(repository: repo, projectId: projectId, status: DocumentStatus.finalized.rawValue, totalAmount: 500)
        let before = try XCTUnwrap(repo.businessDocument(documentId: invoiceId))

        XCTAssertThrowsError(try repo.registerPayment(documentId: invoiceId, amount: 700, method: "Bankgiro", reference: "bad"))
        let after = try XCTUnwrap(repo.businessDocument(documentId: invoiceId))

        XCTAssertEqual(after.paidAmount, before.paidAmount, accuracy: 0.0001)
        XCTAssertEqual(after.balanceDue, before.balanceDue, accuracy: 0.0001)
        XCTAssertEqual(after.status, before.status)
        XCTAssertTrue(try repo.documentPayments(documentId: invoiceId).isEmpty)
        XCTAssertEqual(try tableRowCount(repository: repo, tableName: "payments"), 0)
        XCTAssertEqual(try tableRowCount(repository: repo, tableName: "payment_allocations"), 0)
    }

    func testInvalidAmountsRejectedWithoutPartialWrites() throws {
        let (repo, dbPath, projectId) = try makeRepository(tag: "invalid-amounts")
        defer { cleanupSQLiteArtifacts(at: dbPath) }
        let invoiceId = try createInvoice(repository: repo, projectId: projectId, status: DocumentStatus.finalized.rawValue, totalAmount: 500)
        let before = try XCTUnwrap(repo.businessDocument(documentId: invoiceId))

        XCTAssertThrowsError(try repo.registerPayment(documentId: invoiceId, amount: 0, method: "Bankgiro", reference: "zero"))
        XCTAssertThrowsError(try repo.registerPayment(documentId: invoiceId, amount: -10, method: "Bankgiro", reference: "negative"))

        let after = try XCTUnwrap(repo.businessDocument(documentId: invoiceId))
        XCTAssertEqual(after.paidAmount, before.paidAmount, accuracy: 0.0001)
        XCTAssertEqual(after.balanceDue, before.balanceDue, accuracy: 0.0001)
        XCTAssertEqual(after.status, before.status)
        XCTAssertEqual(try tableRowCount(repository: repo, tableName: "payments"), 0)
        XCTAssertEqual(try tableRowCount(repository: repo, tableName: "payment_allocations"), 0)
    }

    func testDraftInvoiceRejectedWithoutPartialWrites() throws {
        let (repo, dbPath, projectId) = try makeRepository(tag: "draft-reject")
        defer { cleanupSQLiteArtifacts(at: dbPath) }
        let draftInvoiceId = try createInvoice(repository: repo, projectId: projectId, status: DocumentStatus.draft.rawValue, totalAmount: 300)
        let before = try XCTUnwrap(repo.businessDocument(documentId: draftInvoiceId))

        XCTAssertThrowsError(try repo.registerPayment(documentId: draftInvoiceId, amount: 50, method: "Bankgiro", reference: "draft"))

        let after = try XCTUnwrap(repo.businessDocument(documentId: draftInvoiceId))
        XCTAssertEqual(after.paidAmount, before.paidAmount, accuracy: 0.0001)
        XCTAssertEqual(after.balanceDue, before.balanceDue, accuracy: 0.0001)
        XCTAssertEqual(after.status, before.status)
        XCTAssertEqual(try tableRowCount(repository: repo, tableName: "payments"), 0)
        XCTAssertEqual(try tableRowCount(repository: repo, tableName: "payment_allocations"), 0)
    }

    func testPersistenceAfterReloadAndNewViewModelRetainsPaymentsState() throws {
        let (repo, dbPath, projectId) = try makeRepository(tag: "reload")
        defer { cleanupSQLiteArtifacts(at: dbPath) }
        let invoiceId = try createInvoice(repository: repo, projectId: projectId, status: DocumentStatus.finalized.rawValue, totalAmount: 900)

        let vm = AppViewModel(repository: repo, backupService: BackupService(db: repo.db))
        try vm.reloadAll()
        vm.addPayment(documentId: invoiceId, amount: 400, method: "Bankgiro", reference: "via-vm")
        XCTAssertNil(vm.errorMessage)

        let reloadedVM = AppViewModel(repository: repo, backupService: BackupService(db: repo.db))
        try reloadedVM.reloadAll()
        let reloadedDoc = try XCTUnwrap(reloadedVM.businessDocuments.first(where: { $0.id == invoiceId }))

        XCTAssertEqual(reloadedDoc.paidAmount, 400, accuracy: 0.0001)
        XCTAssertEqual(reloadedDoc.balanceDue, 500, accuracy: 0.0001)
        XCTAssertEqual(reloadedDoc.status, DocumentStatus.partiallyPaid.rawValue)
        XCTAssertEqual(reloadedVM.paymentsByDocumentId[invoiceId]?.count, 1)

        try reloadedVM.reloadAll()
        let afterSecondReload = try XCTUnwrap(reloadedVM.businessDocuments.first(where: { $0.id == invoiceId }))
        XCTAssertEqual(afterSecondReload.paidAmount, 400, accuracy: 0.0001)
        XCTAssertEqual(afterSecondReload.balanceDue, 500, accuracy: 0.0001)
        XCTAssertEqual(afterSecondReload.status, DocumentStatus.partiallyPaid.rawValue)
        XCTAssertEqual(reloadedVM.paymentsByDocumentId[invoiceId]?.count, 1)
    }

    func testOutstandingAndReminderCompatibilityUsesRemainingBalanceAfterPartialPayment() throws {
        let (repo, dbPath, projectId) = try makeRepository(tag: "reminder-outstanding")
        defer { cleanupSQLiteArtifacts(at: dbPath) }
        let invoiceId = try createInvoice(repository: repo, projectId: projectId, status: DocumentStatus.finalized.rawValue, totalAmount: 1_200)
        try repo.registerPayment(documentId: invoiceId, amount: 200, method: "Bankgiro", reference: "P1")

        let receivable = try XCTUnwrap(repo.receivablesDocuments().first(where: { $0.id == invoiceId }))
        XCTAssertEqual(receivable.balanceDue, 1_000, accuracy: 0.0001)

        let vm = AppViewModel(repository: repo, backupService: BackupService(db: repo.db))
        try vm.reloadAll()
        vm.selectedProject = vm.projects.first(where: { $0.id == projectId })
        vm.createPaminnelseDraftFromSelectedProject()
        XCTAssertNil(vm.errorMessage)

        let reminder = try XCTUnwrap(vm.businessDocuments.first(where: { $0.type == DocumentType.paminnelse.rawValue }))
        XCTAssertEqual(reminder.totalAmount, 1_000, accuracy: 0.0001)
        XCTAssertEqual(reminder.relatedDocumentId, invoiceId)
    }

    func testRejectsPaymentForNonFakturaDocument() throws {
        let (repo, dbPath, projectId) = try makeRepository(tag: "non-faktura")
        defer { cleanupSQLiteArtifacts(at: dbPath) }
        let avtalId = try createDocument(repository: repo, projectId: projectId, type: .avtal, status: DocumentStatus.finalized.rawValue, totalAmount: 500)

        XCTAssertThrowsError(try repo.registerPayment(documentId: avtalId, amount: 100, method: "BG", reference: "NF"))
        XCTAssertEqual(try tableRowCount(repository: repo, tableName: "payments"), 0)
        XCTAssertEqual(try tableRowCount(repository: repo, tableName: "payment_allocations"), 0)
    }

    func testRejectsPaymentForAlreadyPaidInvoice() throws {
        let (repo, dbPath, projectId) = try makeRepository(tag: "already-paid")
        defer { cleanupSQLiteArtifacts(at: dbPath) }
        let invoiceId = try createInvoice(repository: repo, projectId: projectId, status: DocumentStatus.paid.rawValue, totalAmount: 700, paidAmount: 700, balanceDue: 0)

        XCTAssertThrowsError(try repo.registerPayment(documentId: invoiceId, amount: 10, method: "BG", reference: "paid"))
        let doc = try XCTUnwrap(repo.businessDocument(documentId: invoiceId))
        XCTAssertEqual(doc.paidAmount, 700, accuracy: 0.0001)
        XCTAssertEqual(doc.balanceDue, 0, accuracy: 0.0001)
        XCTAssertEqual(doc.status, DocumentStatus.paid.rawValue)
        XCTAssertEqual(try tableRowCount(repository: repo, tableName: "payments"), 0)
        XCTAssertEqual(try tableRowCount(repository: repo, tableName: "payment_allocations"), 0)
    }

    func testDocumentStatusContainsPartiallyPaidCanonicalValue() {
        XCTAssertEqual(DocumentStatus.partiallyPaid.rawValue, "partially_paid")
        XCTAssertTrue(DocumentStatus.allCases.contains(.partiallyPaid))
    }

    private func makeRepository(tag: String) throws -> (AppRepository, URL, Int64) {
        let db = try SQLiteDatabase(filename: "payment-tests-\(tag)-\(UUID().uuidString).sqlite")
        try db.initializeSchema()
        let repository = AppRepository(db: db)

        let company = Company(id: 0, name: "Company", orgNumber: "556000-0000", email: "company@example.com", phone: "100")
        _ = try repository.insertCompany(company)
        let clientId = try repository.insertClient(Client(id: 0, name: "Client", email: "client@example.com", phone: "100", address: "Street"))
        let propertyId = try repository.insertProperty(PropertyObject(id: 0, clientId: clientId, name: "Flat", address: "Address"))
        let speedId = try repository.insertSpeedProfile(SpeedProfile(id: 0, name: "Default", coefficient: 1, daysDivider: 7, sortOrder: 0))
        let projectId = try repository.insertProject(Project(id: 0, clientId: clientId, propertyId: propertyId, name: "Project", speedProfileId: speedId, createdAt: Date()))

        return (repository, db.dbPath, projectId)
    }

    private func createInvoice(
        repository: AppRepository,
        projectId: Int64,
        status: String,
        totalAmount: Double,
        paidAmount: Double = 0,
        balanceDue: Double? = nil
    ) throws -> Int64 {
        let effectiveBalanceDue = balanceDue ?? max(totalAmount - paidAmount, 0)
        return try createDocument(
            repository: repository,
            projectId: projectId,
            type: .faktura,
            status: status,
            totalAmount: totalAmount,
            paidAmount: paidAmount,
            balanceDue: effectiveBalanceDue
        )
    }

    private func createDocument(
        repository: AppRepository,
        projectId: Int64,
        type: DocumentType,
        status: String,
        totalAmount: Double,
        paidAmount: Double = 0,
        balanceDue: Double
    ) throws -> Int64 {
        let document = BusinessDocument(
            id: 0,
            projectId: projectId,
            type: type.rawValue,
            status: status,
            number: "FAK-000001",
            title: "Invoice",
            issueDate: Date(timeIntervalSince1970: 1_710_000_000),
            dueDate: Date(timeIntervalSince1970: 1_710_000_000 + 14 * 86_400),
            customerType: CustomerType.b2c.rawValue,
            taxMode: TaxMode.normal.rawValue,
            currency: "SEK",
            subtotalLabor: totalAmount,
            subtotalMaterial: 0,
            subtotalOther: 0,
            vatRate: 0,
            vatAmount: 0,
            rotEligibleLabor: 0,
            rotReduction: 0,
            totalAmount: totalAmount,
            paidAmount: paidAmount,
            balanceDue: balanceDue,
            relatedDocumentId: nil,
            notes: "payment contour test"
        )

        return try repository.createBusinessDocument(
            document,
            lines: [BusinessDocumentLine(id: 0, documentId: 0, lineType: "labor", description: "Line", quantity: 1, unit: "h", unitPrice: totalAmount, vatRate: 0, isRotEligible: false, total: totalAmount)]
        )
    }

    private func tableRowCount(repository: AppRepository, tableName: String) throws -> Int {
        var count = 0
        try repository.db.withStatement("SELECT COUNT(1) FROM \(tableName)") { stmt in
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
        }
        return count
    }

    private func cleanupSQLiteArtifacts(at dbPath: URL) {
        let fm = FileManager.default
        try? fm.removeItem(at: dbPath)
        try? fm.removeItem(at: URL(fileURLWithPath: dbPath.path + "-wal"))
        try? fm.removeItem(at: URL(fileURLWithPath: dbPath.path + "-shm"))
    }
}
