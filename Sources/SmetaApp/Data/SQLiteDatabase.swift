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
        """)
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
