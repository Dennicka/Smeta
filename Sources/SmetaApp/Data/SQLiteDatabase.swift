import Foundation
import SQLite3

enum DatabaseError: Error {
    case openFailed
    case prepareFailed(String)
    case executeFailed(String)
}

final class SQLiteDatabase {
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

        """)

        try? execute("ALTER TABLE projects ADD COLUMN workflow_status TEXT NOT NULL DEFAULT 'draft';")

        try? execute("ALTER TABLE projects ADD COLUMN pricing_mode TEXT NOT NULL DEFAULT 'fixed_price';")
        try? execute("ALTER TABLE projects ADD COLUMN is_draft INTEGER NOT NULL DEFAULT 1;")
        try? execute("ALTER TABLE properties ADD COLUMN object_type TEXT NOT NULL DEFAULT '';")
        try? execute("ALTER TABLE properties ADD COLUMN notes TEXT NOT NULL DEFAULT '';")
        try? execute("ALTER TABLE properties ADD COLUMN photo_path TEXT NOT NULL DEFAULT '';")
        try? execute("ALTER TABLE properties ADD COLUMN total_area REAL NOT NULL DEFAULT 0;")
        try? execute("ALTER TABLE properties ADD COLUMN access_level TEXT NOT NULL DEFAULT '';")
        try? execute("ALTER TABLE properties ADD COLUMN internal_comment TEXT NOT NULL DEFAULT '';")
        try? execute("ALTER TABLE rooms ADD COLUMN room_type TEXT NOT NULL DEFAULT '';")
        try? execute("ALTER TABLE rooms ADD COLUMN length REAL NOT NULL DEFAULT 0;")
        try? execute("ALTER TABLE rooms ADD COLUMN width REAL NOT NULL DEFAULT 0;")
        try? execute("ALTER TABLE rooms ADD COLUMN ceiling_area REAL NOT NULL DEFAULT 0;")
        try? execute("ALTER TABLE rooms ADD COLUMN wall_area_auto REAL NOT NULL DEFAULT 0;")
        try? execute("ALTER TABLE rooms ADD COLUMN wall_area_manual_adjustment REAL NOT NULL DEFAULT 0;")
        try? execute("ALTER TABLE rooms ADD COLUMN surface_condition TEXT NOT NULL DEFAULT 'standard';")
        try? execute("ALTER TABLE rooms ADD COLUMN notes TEXT NOT NULL DEFAULT '';")
        try? execute("ALTER TABLE rooms ADD COLUMN photo_path TEXT NOT NULL DEFAULT '';")
        try? execute("ALTER TABLE rooms ADD COLUMN room_template_id INTEGER;")
        try? execute("ALTER TABLE work_catalog ADD COLUMN category_id INTEGER;")
        try? execute("ALTER TABLE work_catalog ADD COLUMN subcategory_id INTEGER;")
        try? execute("ALTER TABLE work_catalog ADD COLUMN description TEXT NOT NULL DEFAULT '';")
        try? execute("ALTER TABLE work_catalog ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1;")
        try? execute("ALTER TABLE work_catalog ADD COLUMN include_standard_offer INTEGER NOT NULL DEFAULT 1;")
        try? execute("ALTER TABLE work_catalog ADD COLUMN rot_eligible INTEGER NOT NULL DEFAULT 1;")
        try? execute("ALTER TABLE work_catalog ADD COLUMN applicability TEXT NOT NULL DEFAULT 'b2c,b2b';")
        try? execute("ALTER TABLE work_catalog ADD COLUMN base_purchase_price REAL NOT NULL DEFAULT 0;")
        try? execute("ALTER TABLE work_catalog ADD COLUMN hourly_price REAL NOT NULL DEFAULT 0;")
        try? execute("ALTER TABLE work_catalog ADD COLUMN slow_speed REAL NOT NULL DEFAULT 0;")
        try? execute("ALTER TABLE work_catalog ADD COLUMN medium_speed REAL NOT NULL DEFAULT 0;")
        try? execute("ALTER TABLE work_catalog ADD COLUMN fast_speed REAL NOT NULL DEFAULT 0;")
        try? execute("ALTER TABLE work_catalog ADD COLUMN complexity_coefficient REAL NOT NULL DEFAULT 1;")
        try? execute("ALTER TABLE work_catalog ADD COLUMN height_coefficient REAL NOT NULL DEFAULT 1;")
        try? execute("ALTER TABLE work_catalog ADD COLUMN condition_coefficient REAL NOT NULL DEFAULT 1;")
        try? execute("ALTER TABLE work_catalog ADD COLUMN urgency_coefficient REAL NOT NULL DEFAULT 1;")
        try? execute("ALTER TABLE work_catalog ADD COLUMN accessibility_coefficient REAL NOT NULL DEFAULT 1;")
        try? execute("ALTER TABLE work_catalog ADD COLUMN additional_labor_hours REAL NOT NULL DEFAULT 0;")
        try? execute("ALTER TABLE work_catalog ADD COLUMN additional_material_usage REAL NOT NULL DEFAULT 0;")
        try? execute("ALTER TABLE material_catalog ADD COLUMN category_id INTEGER;")
        try? execute("ALTER TABLE material_catalog ADD COLUMN purchase_price REAL NOT NULL DEFAULT 0;")
        try? execute("ALTER TABLE material_catalog ADD COLUMN markup_percent REAL NOT NULL DEFAULT 0;")
        try? execute("ALTER TABLE material_catalog ADD COLUMN supplier_id INTEGER;")
        try? execute("ALTER TABLE material_catalog ADD COLUMN sku TEXT NOT NULL DEFAULT '';")
        try? execute("ALTER TABLE material_catalog ADD COLUMN usage_per_work_unit REAL NOT NULL DEFAULT 0;")
        try? execute("ALTER TABLE material_catalog ADD COLUMN package_size REAL NOT NULL DEFAULT 1;")
        try? execute("ALTER TABLE material_catalog ADD COLUMN stock REAL NOT NULL DEFAULT 0;")
        try? execute("ALTER TABLE material_catalog ADD COLUMN comment TEXT NOT NULL DEFAULT '';")
        try? execute("ALTER TABLE material_catalog ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1;")
    }

    func copyDatabase(to destination: URL) throws {
        try FileManager.default.copyItem(at: dbPath, to: destination)
    }

    func restoreDatabase(from source: URL) throws {
        sqlite3_close(db)
        if FileManager.default.fileExists(atPath: dbPath.path) {
            try FileManager.default.removeItem(at: dbPath)
        }
        try FileManager.default.copyItem(at: source, to: dbPath)
        if sqlite3_open(dbPath.path, &db) != SQLITE_OK {
            throw DatabaseError.openFailed
        }
    }
}
