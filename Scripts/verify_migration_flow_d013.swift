import Foundation
import SQLite3

@discardableResult
func assertCheck(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
    if condition() {
        print("[PASS] \(message)")
        return true
    }
    print("[FAIL] \(message)")
    return false
}

func fetchText(_ db: SQLiteDatabase, _ sql: String) throws -> String? {
    let statement = try db.prepare(sql)
    defer { sqlite3_finalize(statement) }
    guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
    guard let raw = sqlite3_column_text(statement, 0) else { return nil }
    return String(cString: raw)
}

func fetchInt(_ db: SQLiteDatabase, _ sql: String) throws -> Int {
    let statement = try db.prepare(sql)
    defer { sqlite3_finalize(statement) }
    guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
    return Int(sqlite3_column_int(statement, 0))
}

func columnExists(_ db: SQLiteDatabase, table: String, column: String) throws -> Bool {
    let statement = try db.prepare("PRAGMA table_info('\(table.replacingOccurrences(of: "'", with: "''"))');")
    defer { sqlite3_finalize(statement) }
    while sqlite3_step(statement) == SQLITE_ROW {
        guard let nameRaw = sqlite3_column_text(statement, 1) else { continue }
        if String(cString: nameRaw) == column {
            return true
        }
    }
    return false
}

func removeDatabaseArtifacts(at dbURL: URL) {
    let fm = FileManager.default
    let urls = [
        dbURL,
        URL(fileURLWithPath: dbURL.path + "-wal"),
        URL(fileURLWithPath: dbURL.path + "-shm")
    ]
    for url in urls where fm.fileExists(atPath: url.path) {
        try? fm.removeItem(at: url)
    }
}

func databaseURL(for filename: String) throws -> URL {
    let appSupport = try FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil,
                                                 create: true)
    let folder = appSupport.appendingPathComponent("Smeta", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder.appendingPathComponent(filename)
}

func buildLegacyFixture(_ db: SQLiteDatabase) throws {
    try db.execute("""
    CREATE TABLE IF NOT EXISTS clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        address TEXT
    );
    CREATE TABLE IF NOT EXISTS properties (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        address TEXT,
        FOREIGN KEY(client_id) REFERENCES clients(id)
    );
    CREATE TABLE IF NOT EXISTS speed_profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        coefficient REAL NOT NULL,
        days_divider REAL NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE IF NOT EXISTS projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id INTEGER NOT NULL,
        property_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        speed_profile_id INTEGER NOT NULL,
        created_at REAL NOT NULL,
        FOREIGN KEY(client_id) REFERENCES clients(id),
        FOREIGN KEY(property_id) REFERENCES properties(id),
        FOREIGN KEY(speed_profile_id) REFERENCES speed_profiles(id)
    );
    CREATE TABLE IF NOT EXISTS calculation_rules (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        transport_percent REAL NOT NULL DEFAULT 0.02,
        equipment_percent REAL NOT NULL DEFAULT 0.03,
        waste_percent REAL NOT NULL DEFAULT 0.04,
        margin_percent REAL NOT NULL DEFAULT 0.12,
        moms_percent REAL NOT NULL DEFAULT 0.25
    );
    """)

    try db.execute("""
    INSERT INTO clients(id, name, email, phone, address) VALUES (1, 'Legacy Client', 'legacy@example.com', '100', 'Legacy street');
    INSERT INTO properties(id, client_id, name, address) VALUES (1, 1, 'Legacy Property', 'Old address');
    INSERT INTO speed_profiles(id, name, coefficient, days_divider, sort_order) VALUES (1, 'Standard', 1.0, 8.0, 0);
    INSERT INTO projects(id, client_id, property_id, name, speed_profile_id, created_at) VALUES (1, 1, 1, 'Legacy Project', 1, 1234567890);
    INSERT INTO calculation_rules(id, transport_percent, equipment_percent, waste_percent, margin_percent, moms_percent)
    VALUES (1, 0.02, 0.03, 0.04, 0.12, 0.25);
    """)
}

@main
struct VerifyMigrationFlowD013 {
    static func main() {
        let runID = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let dbFileA = "d013_scenarioA_\(runID).sqlite"
        let dbFileB = "d013_scenarioB_\(runID).sqlite"

        var failed = false

        do {
            // Scenario A: empty DB -> latest schema.
            removeDatabaseArtifacts(at: try databaseURL(for: dbFileA))
            let dbAFresh = try SQLiteDatabase(filename: dbFileA)
            try dbAFresh.initializeSchema()
            let versionA = try dbAFresh.currentSchemaVersion()
            failed = !assertCheck(versionA == 3, "Scenario A: schema version is 3") || failed
            let hasWorkflow = try columnExists(dbAFresh, table: "projects", column: "workflow_status")
            failed = !assertCheck(hasWorkflow, "Scenario A: projects.workflow_status exists") || failed
            let historyA = try dbAFresh.migrationHistory()
            print("[INFO] Scenario A migration history: \(historyA.map { "\($0.version):\($0.id)" }.joined(separator: ", "))")
            failed = !assertCheck(historyA.map(\.id) == ["001_base_schema", "002_legacy_upgrade_bridge", "003_stage5_ops_tail_tables"], "Scenario A: ordered migration ids recorded") || failed

            // Simple smoke write/read on latest schema.
            try dbAFresh.execute("""
            INSERT INTO clients(name, email, phone, address) VALUES ('A', 'a@example.com', '', '');
            INSERT INTO properties(client_id, name, address) VALUES (1, 'P', '');
            INSERT INTO speed_profiles(name, coefficient, days_divider, sort_order) VALUES ('N', 1.0, 8.0, 0);
            INSERT INTO projects(client_id, property_id, name, speed_profile_id, created_at) VALUES (1, 1, 'Smoke Project', 1, 1);
            """)
            let smokeProjectName = try fetchText(dbAFresh, "SELECT name FROM projects WHERE id=1;")
            failed = !assertCheck(smokeProjectName == "Smoke Project", "Scenario A: smoke read/write PASS") || failed

            // Scenario B: legacy fixture -> migration up -> schema/data checks.
            removeDatabaseArtifacts(at: try databaseURL(for: dbFileB))
            let dbBLegacy = try SQLiteDatabase(filename: dbFileB)
            try buildLegacyFixture(dbBLegacy)

            let hasWorkflowBefore = try columnExists(dbBLegacy, table: "projects", column: "workflow_status")
            failed = !assertCheck(hasWorkflowBefore == false, "Scenario B: legacy fixture starts without projects.workflow_status") || failed

            try dbBLegacy.initializeSchema()
            let versionB = try dbBLegacy.currentSchemaVersion()
            failed = !assertCheck(versionB == 3, "Scenario B: migrated schema version is 3") || failed

            let workflowStatus = try fetchText(dbBLegacy, "SELECT workflow_status FROM projects WHERE id=1;")
            let pricingMode = try fetchText(dbBLegacy, "SELECT pricing_mode FROM projects WHERE id=1;")
            let projectName = try fetchText(dbBLegacy, "SELECT name FROM projects WHERE id=1;")
            failed = !assertCheck(projectName == "Legacy Project", "Scenario B: legacy project data preserved") || failed
            failed = !assertCheck(workflowStatus == "draft", "Scenario B: new required workflow_status default populated") || failed
            failed = !assertCheck(pricingMode == "fixed_price", "Scenario B: new required pricing_mode default populated") || failed

            // Scenario C: rerun on current schema is safe no-op.
            let historyBefore = try dbBLegacy.migrationHistory()
            try dbBLegacy.initializeSchema()
            let historyAfter = try dbBLegacy.migrationHistory()
            failed = !assertCheck(historyBefore == historyAfter, "Scenario C: second runner pass keeps migration history unchanged") || failed
            let migrationRows = try fetchInt(dbBLegacy, "SELECT COUNT(*) FROM schema_migrations;")
            failed = !assertCheck(migrationRows == 3, "Scenario C: no duplicate migration rows") || failed

            print("[INFO] Scenario B migration history: \(historyAfter.map { "\($0.version):\($0.id)" }.joined(separator: ", "))")
        } catch {
            failed = true
            print("[ERROR] \(error)")
        }

        if failed {
            print("RESULT: FAIL")
            exit(1)
        }

        print("RESULT: PASS")
    }
}
