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
    
    // Note: nonisolated is used here because static properties are inferred as main actor-isolated in Swift 6,
    // and we need to access lock from nonisolated shared property. NSLock is Sendable, so unsafe is not needed.
    private nonisolated static let lock = NSLock()
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
        
        migrator.registerMigration("v1.1.0_createLibrarySchema") { db in
            AppLogger.database.debug("Running migration: v1.1.0_createLibrarySchema")
            
            // MARK: Library Content Metadata Table
            try db.create(table: "library_content") { t in
                t.primaryKey("id", .text).notNull()
                t.column("title", .text).notNull()
                t.column("description", .text)
                t.column("type", .text).notNull() // checklist, practice_guide, flashcard_deck
                t.column("visibility", .text).notNull().defaults(to: "private")
                t.column("creatorID", .text).notNull()
                t.column("forkedFromID", .text)
                t.column("forkCount", .integer).notNull().defaults(to: 0)
                t.column("ratingAverage", .double)
                t.column("ratingCount", .integer).notNull().defaults(to: 0)
                t.column("tags", .text).notNull().defaults(to: "[]") // JSON array
                t.column("language", .text).notNull().defaults(to: "en")
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("syncStatus", .text).notNull().defaults(to: "pending")
            }
            
            // MARK: Checklists Table (full content)
            try db.create(table: "checklists") { t in
                t.primaryKey("id", .text).notNull()
                t.column("title", .text).notNull()
                t.column("description", .text)
                t.column("checklistType", .text).notNull().defaults(to: "general")
                t.column("tags", .text).notNull().defaults(to: "[]") // JSON array
                t.column("content", .text).notNull().defaults(to: "[]") // JSON of sections/items
                t.column("creatorID", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("syncStatus", .text).notNull().defaults(to: "pending")
            }
            
            // Create indexes
            try db.create(index: "idx_library_content_creator", on: "library_content", columns: ["creatorID"])
            try db.create(index: "idx_library_content_type", on: "library_content", columns: ["type"])
            try db.create(index: "idx_library_content_updated", on: "library_content", columns: ["updatedAt"])
            try db.create(index: "idx_checklists_creator", on: "checklists", columns: ["creatorID"])
            try db.create(index: "idx_checklists_updated", on: "checklists", columns: ["updatedAt"])
            
            AppLogger.database.info("Migration v1.1.0_createLibrarySchema completed successfully")
        }
        
        migrator.registerMigration("v1.2.0_createChecklistExecutionSchema") { db in
            AppLogger.database.debug("Running migration: v1.2.0_createChecklistExecutionSchema")
            
            // MARK: Checklist Execution States Table
            try db.create(table: "checklistExecutionStates") { t in
                t.primaryKey("id", .text).notNull()
                t.column("checklistID", .text).notNull()
                t.column("charterID", .text).notNull()
                t.column("itemStates", .text).notNull().defaults(to: "{}")
                t.column("progressPercentage", .real)
                t.column("createdAt", .datetime).notNull()
                t.column("lastUpdated", .datetime).notNull()
                t.column("completedAt", .datetime)
                t.column("syncStatus", .text).notNull().defaults(to: "pending")
                
                t.uniqueKey(["checklistID", "charterID"])
                
                t.foreignKey(["charterID"], references: "charters", onDelete: .cascade, onUpdate: .cascade)
            }
            
            // Create indexes
            try db.create(index: "idx_executionStates_charter",
                          on: "checklistExecutionStates", columns: ["charterID"])
            try db.create(index: "idx_executionStates_checklist",
                          on: "checklistExecutionStates", columns: ["checklistID"])
            try db.create(index: "idx_executionStates_updated",
                          on: "checklistExecutionStates", columns: ["lastUpdated"])
            
            AppLogger.database.info("Migration v1.2.0_createChecklistExecutionSchema completed successfully")
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
