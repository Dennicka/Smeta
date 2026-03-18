import Foundation

struct VerifyClientCSVImportD011 {
    private let service = Stage5Service()

    @discardableResult
    private func check(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
        if condition() {
            print("[PASS] \(message)")
            return true
        }
        print("[FAIL] \(message)")
        return false
    }

    func run() -> Int32 {
        let existing = [
            Client(id: 1, name: "Anna Legacy", email: "anna@client.se", phone: "111", address: "Old A"),
            Client(id: 2, name: "Ext Legacy", email: "", phone: "222", address: "Old B")
        ]

        var failures = 0

        let createRows = service.parseCSV("""
name,email,phone,address
Bertil New,bertil@client.se,333,New Street 1
""")
        let createReport = service.buildClientImportReport(rows: createRows, existing: existing)
        if !check(createReport.created == 1 && createReport.updated == 0 && createReport.skipped == 0 && createReport.invalid == 0, "create scenario classified as create") { failures += 1 }

        let updateRows = service.parseCSV("""
name,email,phone,address
Anna Updated,anna@client.se,999,Updated Street
""")
        let updateReport = service.buildClientImportReport(rows: updateRows, existing: existing)
        let updateClient = updateReport.actions.compactMap { action -> Client? in
            if case .update(let client) = action { return client }
            return nil
        }.first
        if !check(updateReport.created == 0 && updateReport.updated == 1 && updateReport.skipped == 0 && updateReport.invalid == 0, "update scenario classified as update") { failures += 1 }
        if !check(updateClient?.id == 1, "update uses stable email match to existing id") { failures += 1 }
        if !check(!(updateClient?.name.contains("(updated)") ?? true), "update payload does not append '(updated)'") { failures += 1 }

        let skipRows = service.parseCSV("""
name,email,phone,address,externalId
Ghost External,,444,No Match,9999
""")
        let skipReport = service.buildClientImportReport(rows: skipRows, existing: existing)
        if !check(skipReport.created == 0 && skipReport.updated == 0 && skipReport.skipped == 1 && skipReport.invalid == 0, "skip scenario classified as skip when externalId is unknown") { failures += 1 }

        let invalidRows = service.parseCSV("""
name,email,phone,address
No Key,,555,Nowhere
""")
        let invalidReport = service.buildClientImportReport(rows: invalidRows, existing: existing)
        if !check(invalidReport.created == 0 && invalidReport.updated == 0 && invalidReport.skipped == 0 && invalidReport.invalid == 1, "invalid scenario classified as invalid without stable key") { failures += 1 }

        print("RESULT: \(failures == 0 ? "PASS" : "FAIL")")
        return failures == 0 ? 0 : 1
    }
}

@main
struct VerifyClientCSVImportD011Main {
    static func main() {
        Foundation.exit(VerifyClientCSVImportD011().run())
    }
}
