import Foundation
import SQLite3

struct ExpectedObject {
    let name: String
    let type: String // table/index
}

let expectedObjects: [ExpectedObject] = [
    // tables
    .init(name: "schema_migrations", type: "table"),
    .init(name: "companies", type: "table"),
    .init(name: "clients", type: "table"),
    .init(name: "properties", type: "table"),
    .init(name: "speed_profiles", type: "table"),
    .init(name: "projects", type: "table"),
    .init(name: "rooms", type: "table"),
    .init(name: "work_catalog", type: "table"),
    .init(name: "material_catalog", type: "table"),
    .init(name: "estimates", type: "table"),
    .init(name: "estimate_lines", type: "table"),
    .init(name: "document_templates", type: "table"),
    .init(name: "generated_documents", type: "table"),
    .init(name: "project_status_history", type: "table"),
    .init(name: "document_series", type: "table"),
    .init(name: "tax_profiles", type: "table"),
    .init(name: "business_documents", type: "table"),
    .init(name: "business_document_lines", type: "table"),
    .init(name: "document_snapshots", type: "table"),
    .init(name: "payments", type: "table"),
    .init(name: "payment_allocations", type: "table"),
    .init(name: "room_templates", type: "table"),
    .init(name: "surfaces", type: "table"),
    .init(name: "openings", type: "table"),
    .init(name: "trim_elements", type: "table"),
    .init(name: "work_categories", type: "table"),
    .init(name: "work_subcategories", type: "table"),
    .init(name: "material_categories", type: "table"),
    .init(name: "material_usage_norms", type: "table"),
    .init(name: "work_speed_rules", type: "table"),
    .init(name: "complexity_rules", type: "table"),
    .init(name: "surface_condition_profiles", type: "table"),
    .init(name: "estimate_versions", type: "table"),
    .init(name: "estimate_adjustments", type: "table"),
    .init(name: "suppliers", type: "table"),
    .init(name: "supplier_articles", type: "table"),
    .init(name: "equipment_cost_rules", type: "table"),
    .init(name: "transport_cost_rules", type: "table"),
    .init(name: "waste_disposal_rules", type: "table"),
    .init(name: "default_project_presets", type: "table"),
    .init(name: "calculation_snapshots", type: "table"),
    .init(name: "calculation_rules", type: "table"),
    .init(name: "supplier_contacts", type: "table"),
    .init(name: "supplier_price_history", type: "table"),
    .init(name: "material_price_profiles", type: "table"),
    .init(name: "purchase_lists", type: "table"),
    .init(name: "purchase_list_items", type: "table"),
    .init(name: "project_lifecycle_history", type: "table"),
    .init(name: "project_tags", type: "table"),
    .init(name: "project_notes", type: "table"),
    .init(name: "export_logs", type: "table"),

    // critical indexes
    .init(name: "idx_business_documents_number_unique", type: "index"),
    .init(name: "idx_document_series_type_lookup", type: "index"),
    .init(name: "idx_document_series_active_unique", type: "index"),
    .init(name: "idx_payment_allocations_document", type: "index"),
    .init(name: "idx_projects_updated_lookup", type: "index")
]

func objectExists(_ db: SQLiteDatabase, type: String, name: String) throws -> Bool {
    let statement = try db.prepare("SELECT 1 FROM sqlite_master WHERE type=? AND name=? LIMIT 1;")
    defer { sqlite3_finalize(statement) }
    sqlite3_bind_text(statement, 1, type, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(statement, 2, name, -1, SQLITE_TRANSIENT)
    return sqlite3_step(statement) == SQLITE_ROW
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

func databaseURL(for filename: String) throws -> URL {
    let appSupport = try FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil,
                                                 create: true)
    let folder = appSupport.appendingPathComponent("Smeta", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder.appendingPathComponent(filename)
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
struct VerifySchemaParityD013B {
    static func main() {
        let runID = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let scenarioAFile = "d013b_schema_a_\(runID).sqlite"
        let scenarioBFile = "d013b_schema_b_\(runID).sqlite"

        var scenarioAResults: [String: Bool] = [:]
        var scenarioBResults: [String: Bool] = [:]
        var failed = false

        do {
            // Scenario A
            removeDatabaseArtifacts(at: try databaseURL(for: scenarioAFile))
            let dbA = try SQLiteDatabase(filename: scenarioAFile)
            try dbA.initializeSchema()

            let versionA = try dbA.currentSchemaVersion()
            print("[INFO] Scenario A schema version: \(versionA)")

            // Scenario B
            removeDatabaseArtifacts(at: try databaseURL(for: scenarioBFile))
            let dbB = try SQLiteDatabase(filename: scenarioBFile)
            try buildLegacyFixture(dbB)
            try dbB.initializeSchema()

            let versionB = try dbB.currentSchemaVersion()
            print("[INFO] Scenario B schema version: \(versionB)")

            let legacyProjectName = try fetchText(dbB, "SELECT name FROM projects WHERE id=1;")
            let legacyWorkflowStatus = try fetchText(dbB, "SELECT workflow_status FROM projects WHERE id=1;")
            print("[INFO] Scenario B legacy project name: \(legacyProjectName ?? "nil")")
            print("[INFO] Scenario B workflow_status after migration: \(legacyWorkflowStatus ?? "nil")")

            print("| object name | type | expected | actual in Scenario A | actual in Scenario B |")
            print("|---|---|---|---|---|")

            for object in expectedObjects {
                let existsA = try objectExists(dbA, type: object.type, name: object.name)
                let existsB = try objectExists(dbB, type: object.type, name: object.name)
                scenarioAResults["\(object.type):\(object.name)"] = existsA
                scenarioBResults["\(object.type):\(object.name)"] = existsB
                print("| \(object.name) | \(object.type) | yes | \(existsA ? "yes" : "no") | \(existsB ? "yes" : "no") |")
            }

            let parityA = scenarioAResults.values.allSatisfy { $0 }
            let parityB = scenarioBResults.values.allSatisfy { $0 }
            let migrationRowsA = try fetchInt(dbA, "SELECT COUNT(*) FROM schema_migrations;")
            let migrationRowsB = try fetchInt(dbB, "SELECT COUNT(*) FROM schema_migrations;")
            let dataPreserved = (legacyProjectName == "Legacy Project") && (legacyWorkflowStatus == "draft")

            print("[INFO] Scenario A migration rows: \(migrationRowsA)")
            print("[INFO] Scenario B migration rows: \(migrationRowsB)")
            print("[INFO] Scenario B legacy data preserved: \(dataPreserved ? "yes" : "no")")

            print("[VERDICT] fresh schema parity = \(parityA ? "PASS" : "FAIL")")
            print("[VERDICT] legacy upgrade parity = \(parityB && dataPreserved ? "PASS" : "FAIL")")

            if !parityA || !parityB || !dataPreserved || versionA != 5 || versionB != 5 || migrationRowsA != 5 || migrationRowsB != 5 {
                failed = true
            }
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
