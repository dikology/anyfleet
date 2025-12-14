//
//  AppDatabase.swift
//  anyfleet
//
//  GRDB database configuration and access for offline-first storage
//

import Foundation
import GRDB

/// The main database manager that handles all SQLite operations via GRDB.
/// Provides offline-first storage for charters and user data.
final class AppDatabase: Sendable {
    /// The database writer (DatabaseQueue for main app, DatabaseQueue for tests)
    let dbWriter: any DatabaseWriter 
    
    // Note: nonisolated(unsafe) is required here despite compiler warning
    // because static properties are inferred as main actor-isolated in Swift 6,
    // and we need to access lock from nonisolated shared property
    private nonisolated(unsafe) static let lock = NSLock()
    private nonisolated(unsafe) static var _shared: AppDatabase?
    
    nonisolated static var shared: AppDatabase {
        if let existing = _shared { return existing }
        
        lock.lock()
        defer { lock.unlock() }
        
        if let existing = _shared { return existing }
        let new = makeShared()
        _shared = new
        return new
    }
    
    // MARK: - Initialization
    
    /// Creates a database with the given writer
    nonisolated init(_ dbWriter: any DatabaseWriter) throws {
        AppLogger.database.debug("Initializing AppDatabase")
        self.dbWriter = dbWriter
        AppLogger.database.debug("Running database migrations")
        try migrator.migrate(dbWriter)
        AppLogger.database.info("AppDatabase initialized and migrations completed")
    }
    
    // MARK: - Database Migrator
    
    /// The database migrator that handles schema evolution
    nonisolated private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        #if DEBUG
        // Speed up development by nuking the database when migrations change
        migrator.eraseDatabaseOnSchemaChange = true
        #endif
        
        migrator.registerMigration("v1.0.0_createInitialSchema") { db in
            AppLogger.database.debug("Running migration: v1.0.0_createInitialSchema")
            // MARK: Charters Table
            try db.create(table: "charters") { t in
                t.primaryKey("id", .text).notNull()
                t.column("name", .text).notNull()
                t.column("boatName", .text)
                t.column("location", .text)
                t.column("startDate", .datetime).notNull()
                t.column("endDate", .datetime).notNull()
                t.column("checkInChecklistID", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("syncStatus", .text).notNull().defaults(to: "pending")
            }
            
            try db.create(index: "idx_charters_startDate", on: "charters", columns: ["startDate"])
            AppLogger.database.info("Migration v1.0.0_createInitialSchema completed successfully")
        }
        
        return migrator
    }
    
    // MARK: - Factory Methods
    
    /// Creates the shared database instance
    nonisolated private static func makeShared() -> AppDatabase {
        do {
            let fileManager = FileManager.default
            let appSupportURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            
            let directoryURL = appSupportURL.appendingPathComponent("Database", isDirectory: true)
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            
            let databaseURL = directoryURL.appendingPathComponent("anyfleet.sqlite")
            
            AppLogger.database.info("Database path: \(databaseURL.path)")
            
            // Configure the database
            let config = Configuration()
            
            #if DEBUG
            // Enable verbose logging in debug builds
            // config.prepareDatabase { db in
            //     db.trace { print("SQL: \($0)") }
            // }
            #endif
            
            AppLogger.database.debug("Creating DatabaseQueue")
            let dbQueue = try DatabaseQueue(path: databaseURL.path, configuration: config)
            AppLogger.database.info("DatabaseQueue created successfully")
            return try AppDatabase(dbQueue)
            
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }
    
    /// Creates an in-memory database for testing
    nonisolated static func makeEmpty() throws -> AppDatabase {
        let dbQueue = try DatabaseQueue(configuration: Configuration())
        return try AppDatabase(dbQueue)
    }
}

// MARK: - Database Access

extension AppDatabase {
    /// Provides read access to the database
    func reader() -> any DatabaseReader {
        dbWriter
    }
}
