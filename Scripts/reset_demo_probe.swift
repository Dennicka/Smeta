import Foundation
import SQLite3

private let trackedTables = [
    "companies",
    "clients",
    "properties",
    "projects",
    "rooms",
    "estimates",
    "estimate_lines",
    "business_documents",
    "business_document_lines",
    "work_catalog",
    "material_catalog",
    "speed_profiles",
    "document_templates",
    "document_series",
    "tax_profiles",
    "suppliers",
    "supplier_articles"
]

private func tableCount(_ db: SQLiteDatabase, table: String) throws -> Int {
    var value = 0
    try db.withStatement("SELECT COUNT(*) FROM \(table);") { stmt in
        guard sqlite3_step(stmt) == SQLITE_ROW else { return }
        value = Int(sqlite3_column_int(stmt, 0))
    }
    return value
}

private func snapshot(_ db: SQLiteDatabase, tables: [String]) throws -> [String: Int] {
    var result: [String: Int] = [:]
    for table in tables {
        result[table] = try tableCount(db, table: table)
    }
    return result
}

private func printSnapshot(_ title: String, snapshot: [String: Int], tables: [String]) {
    print(title)
    for table in tables {
        print("  \(table)=\(snapshot[table, default: -1])")
    }
}

private func foreignKeyCheck(_ db: SQLiteDatabase) throws -> Int {
    var violations = 0
    try db.withStatement("PRAGMA foreign_key_check;") { stmt in
        while sqlite3_step(stmt) == SQLITE_ROW {
            violations += 1
        }
    }
    return violations
}

@main
struct ResetDemoProbe {
    static func main() throws {
        let filename = "smeta-reset-verification-\(UUID().uuidString).sqlite"
        let db = try SQLiteDatabase(filename: filename)
        defer {
            try? FileManager.default.removeItem(at: db.dbPath)
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: db.dbPath.path + "-wal"))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: db.dbPath.path + "-shm"))
        }

        try db.initializeSchema()
        let repository = AppRepository(db: db)

        print("CLEANED_TABLES=\(AppRepository.demoResetCleanedTables.joined(separator: ","))")
        print("PRESERVED_TABLES=\(AppRepository.demoResetPreservedTables.joined(separator: ","))")

        var snapshots: [[String: Int]] = []
        var fkViolations: [Int] = []

        for run in 1...3 {
            try repository.resetDemoData()
            let snap = try snapshot(db, tables: trackedTables)
            let fk = try foreignKeyCheck(db)
            snapshots.append(snap)
            fkViolations.append(fk)
            printSnapshot("RESET \(run)", snapshot: snap, tables: trackedTables)
            print("FOREIGN_KEY_CHECK \(run)=\(fk)")
        }

        let preservedSnapshot = try snapshot(db, tables: AppRepository.demoResetPreservedTables)
        printSnapshot("PRESERVED_AFTER_RESET3", snapshot: preservedSnapshot, tables: AppRepository.demoResetPreservedTables)

        guard snapshots.count == 3, snapshots[0] == snapshots[1], snapshots[1] == snapshots[2] else {
            fatalError("reset is not idempotent: snapshots differ")
        }
        guard fkViolations.allSatisfy({ $0 == 0 }) else {
            fatalError("foreign_key_check contains violations")
        }

        print("IDEMPOTENT=OK")
    }
}
