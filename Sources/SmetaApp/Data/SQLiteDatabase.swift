import Foundation
import SQLite3

enum DatabaseError: Error {
    case openFailed
    case prepareFailed(String)
    case executeFailed(String)
}

final class SQLiteDatabase {
    struct MigrationRecord: Equatable {
        let version: Int
        let id: String
        let appliedAt: Double
    }

    private struct MigrationStep {
        let version: Int
        let id: String
        let apply: (SQLiteDatabase) throws -> Void
    }

    private var db: OpaquePointer?
    let dbPath: URL

    init(filename: String = "smeta.sqlite") throws {
        let appSupport = try FileManager.default.url(for: .applicationSupportDirectory,
                                                     in: .userDomainMask,
                                                     appropriateFor: nil,
                                                     create: true)
        let folder = appSupport.appendingPathComponent("Smeta", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        dbPath = folder.appendingPathComponent(filename)

        if sqlite3_open(dbPath.path, &db) != SQLITE_OK {
            throw DatabaseError.openFailed
        }
        try configureConnection()
    }

    deinit { sqlite3_close(db) }

    func execute(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &errorMessage) != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown"
            sqlite3_free(errorMessage)
            throw DatabaseError.executeFailed(message)
        }
    }

    func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        guard let statement else { throw DatabaseError.prepareFailed("Statement nil") }
        return statement
    }

    func lastInsertedRowID() -> Int64 { sqlite3_last_insert_rowid(db) }

    func withStatement(_ sql: String, _ body: (OpaquePointer) throws -> Void) throws {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try body(statement)
    }

    func initializeSchema() throws {
        try ensureMigrationHistoryTable()
        let appliedVersions = try fetchAppliedMigrationVersions()

        for migration in Self.orderedMigrations {
            guard !appliedVersions.contains(migration.version) else { continue }
            try execute("BEGIN IMMEDIATE TRANSACTION;")
            do {
                try migration.apply(self)
                try recordMigration(version: migration.version, id: migration.id)
                try execute("COMMIT;")
            } catch {
                try? execute("ROLLBACK;")
                throw error
            }
        }
    }

    func currentSchemaVersion() throws -> Int {
        let sql = "SELECT COALESCE(MAX(version), 0) FROM schema_migrations;"
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw DatabaseError.executeFailed("Unable to read schema version")
        }
        return Int(sqlite3_column_int(statement, 0))
    }

    func migrationHistory() throws -> [MigrationRecord] {
        let statement = try prepare("SELECT version, id, applied_at FROM schema_migrations ORDER BY version ASC;")
        defer { sqlite3_finalize(statement) }

        var result: [MigrationRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let version = Int(sqlite3_column_int(statement, 0))
            let id = String(cString: sqlite3_column_text(statement, 1))
            let appliedAt = sqlite3_column_double(statement, 2)
            result.append(MigrationRecord(version: version, id: id, appliedAt: appliedAt))
        }
        return result
    }

    private func applyBaseSchemaMigration() throws {
        try execute("""
        CREATE TABLE IF NOT EXISTS companies (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            org_number TEXT,
            email TEXT,
            phone TEXT
        );
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
        CREATE TABLE IF NOT EXISTS rooms (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            area REAL NOT NULL,
            height REAL NOT NULL,
            FOREIGN KEY(project_id) REFERENCES projects(id)
        );
        CREATE TABLE IF NOT EXISTS work_catalog (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            unit TEXT NOT NULL,
            base_rate_hour REAL NOT NULL,
            base_price REAL NOT NULL,
            swedish_name TEXT NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS material_catalog (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            unit TEXT NOT NULL,
            base_price REAL NOT NULL,
            swedish_name TEXT NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS estimates (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id INTEGER NOT NULL,
            speed_profile_id INTEGER NOT NULL,
            labor_rate_hour REAL NOT NULL,
            overhead_coefficient REAL NOT NULL,
            created_at REAL NOT NULL,
            FOREIGN KEY(project_id) REFERENCES projects(id),
            FOREIGN KEY(speed_profile_id) REFERENCES speed_profiles(id)
        );
        CREATE TABLE IF NOT EXISTS estimate_lines (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            estimate_id INTEGER NOT NULL,
            room_id INTEGER NOT NULL,
            work_item_id INTEGER,
            material_item_id INTEGER,
            quantity REAL NOT NULL,
            unit_price REAL NOT NULL,
            coefficient REAL NOT NULL,
            type TEXT NOT NULL,
            FOREIGN KEY(estimate_id) REFERENCES estimates(id),
            FOREIGN KEY(room_id) REFERENCES rooms(id)
        );
        CREATE TABLE IF NOT EXISTS document_templates (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            language TEXT NOT NULL,
            header_text TEXT NOT NULL,
            footer_text TEXT NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS generated_documents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            estimate_id INTEGER NOT NULL,
            template_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            path TEXT NOT NULL,
            generated_at REAL NOT NULL,
            FOREIGN KEY(estimate_id) REFERENCES estimates(id),
            FOREIGN KEY(template_id) REFERENCES document_templates(id)
        );

        CREATE TABLE IF NOT EXISTS project_status_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id INTEGER NOT NULL,
            status TEXT NOT NULL,
            changed_at REAL NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            FOREIGN KEY(project_id) REFERENCES projects(id)
        );
        CREATE TABLE IF NOT EXISTS document_series (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            document_type TEXT NOT NULL UNIQUE,
            prefix TEXT NOT NULL,
            next_number INTEGER NOT NULL,
            active INTEGER NOT NULL DEFAULT 1
        );
        CREATE TABLE IF NOT EXISTS tax_profiles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            customer_type TEXT NOT NULL,
            tax_mode TEXT NOT NULL,
            vat_rate REAL NOT NULL,
            rot_percent REAL NOT NULL,
            active INTEGER NOT NULL DEFAULT 1
        );
        CREATE TABLE IF NOT EXISTS business_documents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id INTEGER NOT NULL,
            type TEXT NOT NULL,
            status TEXT NOT NULL,
            number TEXT NOT NULL DEFAULT '',
            title TEXT NOT NULL,
            issue_date REAL NOT NULL,
            due_date REAL,
            customer_type TEXT NOT NULL,
            tax_mode TEXT NOT NULL,
            currency TEXT NOT NULL DEFAULT 'SEK',
            subtotal_labor REAL NOT NULL,
            subtotal_material REAL NOT NULL,
            subtotal_other REAL NOT NULL,
            vat_rate REAL NOT NULL,
            vat_amount REAL NOT NULL,
            rot_eligible_labor REAL NOT NULL,
            rot_reduction REAL NOT NULL,
            total_amount REAL NOT NULL,
            paid_amount REAL NOT NULL DEFAULT 0,
            balance_due REAL NOT NULL,
            related_document_id INTEGER,
            notes TEXT NOT NULL DEFAULT '',
            FOREIGN KEY(project_id) REFERENCES projects(id),
            FOREIGN KEY(related_document_id) REFERENCES business_documents(id)
        );
        CREATE TABLE IF NOT EXISTS business_document_lines (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            document_id INTEGER NOT NULL,
            line_type TEXT NOT NULL,
            description TEXT NOT NULL,
            quantity REAL NOT NULL,
            unit TEXT NOT NULL,
            unit_price REAL NOT NULL,
            vat_rate REAL NOT NULL,
            is_rot_eligible INTEGER NOT NULL DEFAULT 0,
            total REAL NOT NULL,
            FOREIGN KEY(document_id) REFERENCES business_documents(id)
        );
        CREATE TABLE IF NOT EXISTS document_snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            document_id INTEGER NOT NULL,
            template_id INTEGER,
            snapshot_json TEXT NOT NULL,
            created_at REAL NOT NULL,
            FOREIGN KEY(document_id) REFERENCES business_documents(id),
            FOREIGN KEY(template_id) REFERENCES document_templates(id)
        );
        CREATE TABLE IF NOT EXISTS payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            paid_at REAL NOT NULL,
            method TEXT NOT NULL,
            reference TEXT NOT NULL DEFAULT ''
        );
        CREATE TABLE IF NOT EXISTS payment_allocations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            payment_id INTEGER NOT NULL,
            document_id INTEGER NOT NULL,
            amount REAL NOT NULL,
            FOREIGN KEY(payment_id) REFERENCES payments(id),
            FOREIGN KEY(document_id) REFERENCES business_documents(id)
        );

        CREATE TABLE IF NOT EXISTS room_templates (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            room_type TEXT NOT NULL,
            default_length REAL NOT NULL DEFAULT 0,
            default_width REAL NOT NULL DEFAULT 0,
            default_height REAL NOT NULL DEFAULT 2.7,
            notes TEXT NOT NULL DEFAULT ''
        );
        CREATE TABLE IF NOT EXISTS surfaces (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            room_id INTEGER NOT NULL,
            type TEXT NOT NULL,
            name TEXT NOT NULL,
            area REAL NOT NULL DEFAULT 0,
            perimeter REAL NOT NULL DEFAULT 0,
            is_custom INTEGER NOT NULL DEFAULT 0,
            source TEXT NOT NULL DEFAULT 'auto',
            manual_adjustment REAL NOT NULL DEFAULT 0,
            FOREIGN KEY(room_id) REFERENCES rooms(id)
        );
        CREATE TABLE IF NOT EXISTS openings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            room_id INTEGER NOT NULL,
            surface_id INTEGER,
            type TEXT NOT NULL,
            name TEXT NOT NULL,
            width REAL NOT NULL,
            height REAL NOT NULL,
            count INTEGER NOT NULL DEFAULT 1,
            subtract_from_wall_area INTEGER NOT NULL DEFAULT 1,
            FOREIGN KEY(room_id) REFERENCES rooms(id),
            FOREIGN KEY(surface_id) REFERENCES surfaces(id)
        );
        CREATE TABLE IF NOT EXISTS trim_elements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            room_id INTEGER NOT NULL,
            type TEXT NOT NULL,
            length REAL NOT NULL,
            quantity INTEGER NOT NULL DEFAULT 1,
            notes TEXT NOT NULL DEFAULT '',
            FOREIGN KEY(room_id) REFERENCES rooms(id)
        );
        CREATE TABLE IF NOT EXISTS work_categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS work_subcategories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(category_id) REFERENCES work_categories(id)
        );
        CREATE TABLE IF NOT EXISTS material_categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS material_usage_norms (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            work_item_id INTEGER NOT NULL,
            material_item_id INTEGER NOT NULL,
            usage_per_unit REAL NOT NULL DEFAULT 0,
            notes TEXT NOT NULL DEFAULT '',
            FOREIGN KEY(work_item_id) REFERENCES work_catalog(id),
            FOREIGN KEY(material_item_id) REFERENCES material_catalog(id)
        );
        CREATE TABLE IF NOT EXISTS work_speed_rules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            work_item_id INTEGER NOT NULL,
            surface_type TEXT NOT NULL DEFAULT 'wall',
            slow REAL NOT NULL DEFAULT 0,
            medium REAL NOT NULL DEFAULT 0,
            fast REAL NOT NULL DEFAULT 0,
            FOREIGN KEY(work_item_id) REFERENCES work_catalog(id)
        );
        CREATE TABLE IF NOT EXISTS complexity_rules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            coefficient REAL NOT NULL,
            enabled_by_default INTEGER NOT NULL DEFAULT 0,
            applies_to_surface_type TEXT NOT NULL DEFAULT 'any'
        );
        CREATE TABLE IF NOT EXISTS surface_condition_profiles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            coefficient REAL NOT NULL,
            notes TEXT NOT NULL DEFAULT ''
        );
        CREATE TABLE IF NOT EXISTS estimate_versions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            estimate_id INTEGER NOT NULL,
            version_name TEXT NOT NULL,
            created_at REAL NOT NULL,
            changed_summary TEXT NOT NULL DEFAULT '',
            FOREIGN KEY(estimate_id) REFERENCES estimates(id)
        );
        CREATE TABLE IF NOT EXISTS estimate_adjustments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            estimate_version_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            value REAL NOT NULL,
            type TEXT NOT NULL,
            FOREIGN KEY(estimate_version_id) REFERENCES estimate_versions(id)
        );
        CREATE TABLE IF NOT EXISTS suppliers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            contact TEXT NOT NULL DEFAULT '',
            phone TEXT NOT NULL DEFAULT '',
            email TEXT NOT NULL DEFAULT ''
        );
        CREATE TABLE IF NOT EXISTS supplier_articles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            supplier_id INTEGER NOT NULL,
            material_item_id INTEGER NOT NULL,
            sku TEXT NOT NULL,
            purchase_price REAL NOT NULL DEFAULT 0,
            is_primary INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(supplier_id) REFERENCES suppliers(id),
            FOREIGN KEY(material_item_id) REFERENCES material_catalog(id)
        );
        CREATE TABLE IF NOT EXISTS equipment_cost_rules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            cost_per_hour REAL NOT NULL,
            applies_to_work_category_id INTEGER
        );
        CREATE TABLE IF NOT EXISTS transport_cost_rules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            fixed_cost REAL NOT NULL,
            cost_per_km REAL NOT NULL
        );
        CREATE TABLE IF NOT EXISTS waste_disposal_rules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            cost_per_cubic_meter REAL NOT NULL
        );
        CREATE TABLE IF NOT EXISTS default_project_presets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            pricing_mode TEXT NOT NULL,
            speed_profile_id INTEGER NOT NULL,
            notes TEXT NOT NULL DEFAULT '',
            FOREIGN KEY(speed_profile_id) REFERENCES speed_profiles(id)
        );
        CREATE TABLE IF NOT EXISTS calculation_snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id INTEGER NOT NULL,
            estimate_version_id INTEGER,
            document_id INTEGER,
            snapshot_json TEXT NOT NULL,
            created_at REAL NOT NULL,
            FOREIGN KEY(project_id) REFERENCES projects(id)
        );
        CREATE TABLE IF NOT EXISTS calculation_rules (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            transport_percent REAL NOT NULL DEFAULT 0.02,
            equipment_percent REAL NOT NULL DEFAULT 0.03,
            waste_percent REAL NOT NULL DEFAULT 0.04,
            margin_percent REAL NOT NULL DEFAULT 0.12,
            moms_percent REAL NOT NULL DEFAULT 0.25,
            min_speed_rate REAL NOT NULL DEFAULT 0.01,
            min_work_medium_speed REAL NOT NULL DEFAULT 0.1,
            min_work_base_rate_per_unit_hour REAL NOT NULL DEFAULT 0.01,
            min_speed_days_divider REAL NOT NULL DEFAULT 0.1,
            min_material_usage_per_work_unit REAL NOT NULL DEFAULT 0.2,
            min_material_quantity REAL NOT NULL DEFAULT 0.01
        );

        """)

        try execute("""
        INSERT OR IGNORE INTO calculation_rules (
            id,
            transport_percent,
            equipment_percent,
            waste_percent,
            margin_percent,
            moms_percent
        ) VALUES (1, 0.02, 0.03, 0.04, 0.12, 0.25);
        """)
    }

    private func applyLegacyUpgradeBridgeMigration() throws {
        try addColumnIfMissing(table: "projects", column: "workflow_status", definition: "TEXT NOT NULL DEFAULT 'draft'")
        try addColumnIfMissing(table: "projects", column: "pricing_mode", definition: "TEXT NOT NULL DEFAULT 'fixed_price'")
        try addColumnIfMissing(table: "projects", column: "is_draft", definition: "INTEGER NOT NULL DEFAULT 1")
        try addColumnIfMissing(table: "projects", column: "lifecycle_status", definition: "TEXT NOT NULL DEFAULT 'active'")
        try addColumnIfMissing(table: "projects", column: "archived_at", definition: "REAL")

        try addColumnIfMissing(table: "properties", column: "object_type", definition: "TEXT NOT NULL DEFAULT ''")
        try addColumnIfMissing(table: "properties", column: "notes", definition: "TEXT NOT NULL DEFAULT ''")
        try addColumnIfMissing(table: "properties", column: "photo_path", definition: "TEXT NOT NULL DEFAULT ''")
        try addColumnIfMissing(table: "properties", column: "total_area", definition: "REAL NOT NULL DEFAULT 0")
        try addColumnIfMissing(table: "properties", column: "access_level", definition: "TEXT NOT NULL DEFAULT ''")
        try addColumnIfMissing(table: "properties", column: "internal_comment", definition: "TEXT NOT NULL DEFAULT ''")

        try addColumnIfMissing(table: "rooms", column: "room_type", definition: "TEXT NOT NULL DEFAULT ''")
        try addColumnIfMissing(table: "rooms", column: "length", definition: "REAL NOT NULL DEFAULT 0")
        try addColumnIfMissing(table: "rooms", column: "width", definition: "REAL NOT NULL DEFAULT 0")
        try addColumnIfMissing(table: "rooms", column: "ceiling_area", definition: "REAL NOT NULL DEFAULT 0")
        try addColumnIfMissing(table: "rooms", column: "wall_area_auto", definition: "REAL NOT NULL DEFAULT 0")
        try addColumnIfMissing(table: "rooms", column: "wall_area_manual_adjustment", definition: "REAL NOT NULL DEFAULT 0")
        try addColumnIfMissing(table: "rooms", column: "surface_condition", definition: "TEXT NOT NULL DEFAULT 'standard'")
        try addColumnIfMissing(table: "rooms", column: "notes", definition: "TEXT NOT NULL DEFAULT ''")
        try addColumnIfMissing(table: "rooms", column: "photo_path", definition: "TEXT NOT NULL DEFAULT ''")
        try addColumnIfMissing(table: "rooms", column: "room_template_id", definition: "INTEGER")

        try addColumnIfMissing(table: "work_catalog", column: "category_id", definition: "INTEGER")
        try addColumnIfMissing(table: "work_catalog", column: "subcategory_id", definition: "INTEGER")
        try addColumnIfMissing(table: "work_catalog", column: "description", definition: "TEXT NOT NULL DEFAULT ''")
        try addColumnIfMissing(table: "work_catalog", column: "is_active", definition: "INTEGER NOT NULL DEFAULT 1")
        try addColumnIfMissing(table: "work_catalog", column: "include_standard_offer", definition: "INTEGER NOT NULL DEFAULT 1")
        try addColumnIfMissing(table: "work_catalog", column: "rot_eligible", definition: "INTEGER NOT NULL DEFAULT 1")
        try addColumnIfMissing(table: "work_catalog", column: "applicability", definition: "TEXT NOT NULL DEFAULT 'b2c,b2b'")
        try addColumnIfMissing(table: "work_catalog", column: "base_purchase_price", definition: "REAL NOT NULL DEFAULT 0")
        try addColumnIfMissing(table: "work_catalog", column: "hourly_price", definition: "REAL NOT NULL DEFAULT 0")
        try addColumnIfMissing(table: "work_catalog", column: "slow_speed", definition: "REAL NOT NULL DEFAULT 0")
        try addColumnIfMissing(table: "work_catalog", column: "medium_speed", definition: "REAL NOT NULL DEFAULT 0")
        try addColumnIfMissing(table: "work_catalog", column: "fast_speed", definition: "REAL NOT NULL DEFAULT 0")
        try addColumnIfMissing(table: "work_catalog", column: "complexity_coefficient", definition: "REAL NOT NULL DEFAULT 1")
        try addColumnIfMissing(table: "work_catalog", column: "height_coefficient", definition: "REAL NOT NULL DEFAULT 1")
        try addColumnIfMissing(table: "work_catalog", column: "condition_coefficient", definition: "REAL NOT NULL DEFAULT 1")
        try addColumnIfMissing(table: "work_catalog", column: "urgency_coefficient", definition: "REAL NOT NULL DEFAULT 1")
        try addColumnIfMissing(table: "work_catalog", column: "accessibility_coefficient", definition: "REAL NOT NULL DEFAULT 1")
        try addColumnIfMissing(table: "work_catalog", column: "additional_labor_hours", definition: "REAL NOT NULL DEFAULT 0")
        try addColumnIfMissing(table: "work_catalog", column: "additional_material_usage", definition: "REAL NOT NULL DEFAULT 0")

        try addColumnIfMissing(table: "material_catalog", column: "category_id", definition: "INTEGER")
        try addColumnIfMissing(table: "material_catalog", column: "purchase_price", definition: "REAL NOT NULL DEFAULT 0")
        try addColumnIfMissing(table: "material_catalog", column: "markup_percent", definition: "REAL NOT NULL DEFAULT 0")
        try addColumnIfMissing(table: "material_catalog", column: "supplier_id", definition: "INTEGER")
        try addColumnIfMissing(table: "material_catalog", column: "sku", definition: "TEXT NOT NULL DEFAULT ''")
        try addColumnIfMissing(table: "material_catalog", column: "usage_per_work_unit", definition: "REAL NOT NULL DEFAULT 0")
        try addColumnIfMissing(table: "material_catalog", column: "package_size", definition: "REAL NOT NULL DEFAULT 1")
        try addColumnIfMissing(table: "material_catalog", column: "stock", definition: "REAL NOT NULL DEFAULT 0")
        try addColumnIfMissing(table: "material_catalog", column: "comment", definition: "TEXT NOT NULL DEFAULT ''")
        try addColumnIfMissing(table: "material_catalog", column: "is_active", definition: "INTEGER NOT NULL DEFAULT 1")

        try addColumnIfMissing(table: "calculation_rules", column: "min_speed_rate", definition: "REAL NOT NULL DEFAULT 0.01")
        try addColumnIfMissing(table: "calculation_rules", column: "min_work_medium_speed", definition: "REAL NOT NULL DEFAULT 0.1")
        try addColumnIfMissing(table: "calculation_rules", column: "min_work_base_rate_per_unit_hour", definition: "REAL NOT NULL DEFAULT 0.01")
        try addColumnIfMissing(table: "calculation_rules", column: "min_speed_days_divider", definition: "REAL NOT NULL DEFAULT 0.1")
        try addColumnIfMissing(table: "calculation_rules", column: "min_material_usage_per_work_unit", definition: "REAL NOT NULL DEFAULT 0.2")
        try addColumnIfMissing(table: "calculation_rules", column: "min_material_quantity", definition: "REAL NOT NULL DEFAULT 0.01")

        try addColumnIfMissing(table: "business_documents", column: "reminder_status", definition: "TEXT NOT NULL DEFAULT 'none'")
        try addColumnIfMissing(table: "business_documents", column: "internal_flag", definition: "TEXT NOT NULL DEFAULT ''")

        try execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_business_documents_number_unique ON business_documents(number) WHERE number <> '';")
        try execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_document_series_type_unique ON document_series(document_type);")
        try execute("CREATE INDEX IF NOT EXISTS idx_payment_allocations_document ON payment_allocations(document_id);")
        try execute("CREATE INDEX IF NOT EXISTS idx_projects_updated_lookup ON projects(id, created_at);")

        try execute("""
        INSERT OR IGNORE INTO calculation_rules (
            id,
            transport_percent,
            equipment_percent,
            waste_percent,
            margin_percent,
            moms_percent,
            min_speed_rate,
            min_work_medium_speed,
            min_work_base_rate_per_unit_hour,
            min_speed_days_divider,
            min_material_usage_per_work_unit,
            min_material_quantity
        ) VALUES (1, 0.02, 0.03, 0.04, 0.12, 0.25, 0.01, 0.1, 0.01, 0.1, 0.2, 0.01);
        """)
    }

    private func applyStage5OpsTailTablesMigration() throws {
        try execute("""
        CREATE TABLE IF NOT EXISTS supplier_contacts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            supplier_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT '',
            email TEXT NOT NULL DEFAULT '',
            phone TEXT NOT NULL DEFAULT '',
            is_primary INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(supplier_id) REFERENCES suppliers(id)
        );
        CREATE TABLE IF NOT EXISTS supplier_price_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            supplier_article_id INTEGER NOT NULL,
            purchase_price REAL NOT NULL,
            changed_at REAL NOT NULL,
            source TEXT NOT NULL DEFAULT 'manual',
            FOREIGN KEY(supplier_article_id) REFERENCES supplier_articles(id)
        );
        CREATE TABLE IF NOT EXISTS material_price_profiles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            material_item_id INTEGER NOT NULL UNIQUE,
            preferred_supplier_id INTEGER,
            preferred_article_id INTEGER,
            target_markup_percent REAL NOT NULL DEFAULT 0,
            updated_at REAL NOT NULL,
            FOREIGN KEY(material_item_id) REFERENCES material_catalog(id)
        );
        CREATE TABLE IF NOT EXISTS purchase_lists (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'draft',
            created_at REAL NOT NULL,
            exported_at REAL,
            note TEXT NOT NULL DEFAULT '',
            FOREIGN KEY(project_id) REFERENCES projects(id)
        );
        CREATE TABLE IF NOT EXISTS purchase_list_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            purchase_list_id INTEGER NOT NULL,
            material_item_id INTEGER NOT NULL,
            supplier_id INTEGER,
            article_id INTEGER,
            quantity REAL NOT NULL DEFAULT 0,
            unit TEXT NOT NULL DEFAULT '',
            planned_price REAL NOT NULL DEFAULT 0,
            purchased_quantity REAL NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'pending',
            FOREIGN KEY(purchase_list_id) REFERENCES purchase_lists(id),
            FOREIGN KEY(material_item_id) REFERENCES material_catalog(id)
        );
        CREATE TABLE IF NOT EXISTS project_lifecycle_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id INTEGER NOT NULL,
            lifecycle_status TEXT NOT NULL,
            changed_at REAL NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            FOREIGN KEY(project_id) REFERENCES projects(id)
        );
        CREATE TABLE IF NOT EXISTS project_tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id INTEGER NOT NULL,
            tag TEXT NOT NULL,
            FOREIGN KEY(project_id) REFERENCES projects(id)
        );
        CREATE TABLE IF NOT EXISTS project_notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id INTEGER NOT NULL,
            note_type TEXT NOT NULL,
            text TEXT NOT NULL,
            pinned INTEGER NOT NULL DEFAULT 0,
            updated_at REAL NOT NULL,
            FOREIGN KEY(project_id) REFERENCES projects(id)
        );
        CREATE TABLE IF NOT EXISTS export_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            kind TEXT NOT NULL,
            scope TEXT NOT NULL,
            path TEXT NOT NULL,
            created_at REAL NOT NULL
        );
        """)
    }

    private func addColumnIfMissing(table: String, column: String, definition: String) throws {
        guard try tableExists(table) else { return }
        guard !(try columnExists(table: table, column: column)) else { return }
        try execute("ALTER TABLE \(table) ADD COLUMN \(column) \(definition);")
    }

    private func tableExists(_ table: String) throws -> Bool {
        let statement = try prepare("SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1;")
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, table, -1, SQLITE_TRANSIENT)
        return sqlite3_step(statement) == SQLITE_ROW
    }

    private func columnExists(table: String, column: String) throws -> Bool {
        let escapedTable = table.replacingOccurrences(of: "'", with: "''")
        let statement = try prepare("PRAGMA table_info('\(escapedTable)');")
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let namePtr = sqlite3_column_text(statement, 1) else { continue }
            if String(cString: namePtr) == column {
                return true
            }
        }
        return false
    }

    private func ensureMigrationHistoryTable() throws {
        try execute("""
        CREATE TABLE IF NOT EXISTS schema_migrations (
            version INTEGER PRIMARY KEY,
            id TEXT NOT NULL UNIQUE,
            applied_at REAL NOT NULL
        );
        """)
    }

    private func fetchAppliedMigrationVersions() throws -> Set<Int> {
        let statement = try prepare("SELECT version FROM schema_migrations;")
        defer { sqlite3_finalize(statement) }

        var versions: Set<Int> = []
        while sqlite3_step(statement) == SQLITE_ROW {
            versions.insert(Int(sqlite3_column_int(statement, 0)))
        }
        return versions
    }

    private func recordMigration(version: Int, id: String) throws {
        try withStatement("INSERT INTO schema_migrations(version, id, applied_at) VALUES (?, ?, ?);") { statement in
            sqlite3_bind_int(statement, 1, Int32(version))
            sqlite3_bind_text(statement, 2, id, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(statement, 3, Date().timeIntervalSince1970)
            if sqlite3_step(statement) != SQLITE_DONE {
                throw DatabaseError.executeFailed(String(cString: sqlite3_errmsg(db)))
            }
        }
    }

    private static let orderedMigrations: [MigrationStep] = [
        MigrationStep(version: 1, id: "001_base_schema") { database in
            try database.applyBaseSchemaMigration()
        },
        MigrationStep(version: 2, id: "002_legacy_upgrade_bridge") { database in
            try database.applyLegacyUpgradeBridgeMigration()
        },
        MigrationStep(version: 3, id: "003_stage5_ops_tail_tables") { database in
            try database.applyStage5OpsTailTablesMigration()
        }
    ]

    func copyDatabase(to destination: URL) throws {
        try FileManager.default.copyItem(at: dbPath, to: destination)
    }

    func restoreDatabase(from source: URL) throws {
        try validateBackup(at: source)
        sqlite3_close(db)
        if FileManager.default.fileExists(atPath: dbPath.path) {
            try FileManager.default.removeItem(at: dbPath)
        }
        try FileManager.default.copyItem(at: source, to: dbPath)
        if sqlite3_open(dbPath.path, &db) != SQLITE_OK {
            throw DatabaseError.openFailed
        }
        try configureConnection()
    }

    func dataFolder() -> URL {
        dbPath.deletingLastPathComponent()
    }

    func validateBackup(at source: URL) throws {
        var backupDB: OpaquePointer?
        guard sqlite3_open_v2(source.path, &backupDB, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let backupDB else {
            throw DatabaseError.executeFailed("Не удалось открыть backup-файл")
        }
        defer { sqlite3_close(backupDB) }

        let requiredTables = ["companies", "clients", "projects", "business_documents", "document_series", "payments"]
        for table in requiredTables {
            let sql = "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(backupDB, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
                throw DatabaseError.executeFailed("Не удалось проверить структуру backup")
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, table, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) != SQLITE_ROW {
                throw DatabaseError.executeFailed("Backup несовместим: отсутствует таблица \(table)")
            }
        }
    }

    private func configureConnection() throws {
        try execute("PRAGMA foreign_keys = ON;")
        try execute("PRAGMA journal_mode = WAL;")
        try execute("PRAGMA synchronous = NORMAL;")
        try execute("PRAGMA busy_timeout = 5000;")
    }
}
