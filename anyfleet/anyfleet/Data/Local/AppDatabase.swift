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
        //AppLogger.database.debug("Initializing AppDatabase")
        self.dbWriter = dbWriter
        // AppLogger.database.debug("Running database migrations")
        try migrator.migrate(dbWriter)
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
            // AppLogger.database.debug("Running migration: v1.0.0_createInitialSchema")
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
        }
        
        migrator.registerMigration("v1.1.0_createLibrarySchema") { db in
            // AppLogger.database.debug("Running migration: v1.1.0_createLibrarySchema")
            
            // MARK: Library Content Metadata Table
            try db.create(table: "library_content") { t in
                t.primaryKey("id", .text).notNull()
                t.column("title", .text).notNull()
                t.column("description", .text)
                t.column("type", .text).notNull() // checklist, practice_guide, flashcard_deck
                t.column("visibility", .text).notNull().defaults(to: "private")
                t.column("creatorID", .text)
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
                t.column("creatorID", .text)
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
            
        }
        
        migrator.registerMigration("v1.2.0_createChecklistExecutionSchema") { db in
            // AppLogger.database.debug("Running migration: v1.2.0_createChecklistExecutionSchema")
            
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
            
        }
        
        migrator.registerMigration("v1.3.0_addPinnedColumnsToLibrary") { db in
            // AppLogger.database.debug("Running migration: v1.3.0_addPinnedColumnsToLibrary")
            
            try db.alter(table: "library_content") { t in
                t.add(column: "isPinned", .integer).notNull().defaults(to: false)
                t.add(column: "pinnedOrder", .integer)
            }
            
            try db.create(
                index: "idx_library_content_pinned",
                on: "library_content",
                columns: ["isPinned", "pinnedOrder", "updatedAt"]
            )
            
        }
        
        migrator.registerMigration("v1.4.0_createPracticeGuidesTable") { db in
            // AppLogger.database.debug("Running migration: v1.4.0_createPracticeGuidesTable")
            
            // MARK: Practice Guides Table (full content)
            try db.create(table: "practice_guides") { t in
                t.primaryKey("id", .text).notNull()
                t.column("title", .text).notNull()
                t.column("description", .text)
                t.column("markdown", .text).notNull().defaults(to: "")
                t.column("tags", .text).notNull().defaults(to: "[]") // JSON array
                t.column("creatorID", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("syncStatus", .text).notNull().defaults(to: "pending")
            }
            
            // Create indexes
            try db.create(index: "idx_practice_guides_creator", on: "practice_guides", columns: ["creatorID"])
            try db.create(index: "idx_practice_guides_updated", on: "practice_guides", columns: ["updatedAt"])
            
        }
        
        migrator.registerMigration("v1.5.0_addVisibilityFields") { db in
            // AppLogger.database.debug("Running migration: v1.5.0_addVisibilityFields")
            
            try db.alter(table: "library_content") { t in
                t.add(column: "publishedAt", .datetime)
                t.add(column: "publicID", .text)
                t.add(column: "publicMetadata", .text) // JSON for PublicMetadata
            }
            
        }

        migrator.registerMigration("v1.6.0_createSyncQueueTable") { db in
            // AppLogger.database.debug("Running migration: v1.6.0_createSyncQueueTable")
            
            try db.create(table: "sync_queue") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("contentID", .text).notNull()
                t.column("operation", .text).notNull()
                t.column("visibilityState", .text).notNull()
                t.column("payload", .text) // JSON
                t.column("createdAt", .datetime).notNull()
                t.column("retryCount", .integer).notNull().defaults(to: 0)
                t.column("lastError", .text)
                t.column("syncedAt", .datetime)

                t.foreignKey(["contentID"], references: "library_content", onDelete: .cascade)
            }

            // Partial index for pending items only
            try db.execute(sql: """
                CREATE INDEX idx_sync_queue_pending
                ON sync_queue(createdAt)
                WHERE syncedAt IS NULL
            """)

            try db.create(index: "idx_sync_queue_content", on: "sync_queue", columns: ["contentID"])
            
        }

        migrator.registerMigration("v1.7.0_addForkAttributionColumns") { db in
            // AppLogger.database.debug("Running migration: v1.7.0_addForkAttributionColumns")

            try db.alter(table: "library_content") { t in
                t.add(column: "originalAuthorUsername", .text)
                t.add(column: "originalContentPublicID", .text)
            }

        }

        migrator.registerMigration("v1.8.0_addCharterSyncAndGeoFields") { db in
            try db.alter(table: "charters") { t in
                // Sync fields
                t.add(column: "serverID", .text)
                t.add(column: "visibility", .text).notNull().defaults(to: "private")
                t.add(column: "needsSync", .boolean).notNull().defaults(to: false)
                t.add(column: "lastSyncedAt", .datetime)

                // Geo fields
                t.add(column: "latitude", .double)
                t.add(column: "longitude", .double)
                t.add(column: "locationPlaceID", .text)
            }

            try db.create(
                index: "idx_charters_visibility",
                on: "charters",
                columns: ["visibility"]
            )

        }

        migrator.registerMigration("v1.9.0_makeCreatorIDNullable") { db in
            // SQLite doesn't support ALTER COLUMN, so we recreate each affected table.
            // Disable foreign key enforcement for the duration of the recreation.
            try db.execute(sql: "PRAGMA foreign_keys = OFF")

            // --- library_content ---
            try db.execute(sql: """
                CREATE TABLE library_content_new (
                    id TEXT NOT NULL PRIMARY KEY,
                    title TEXT NOT NULL,
                    description TEXT,
                    type TEXT NOT NULL,
                    visibility TEXT NOT NULL DEFAULT 'private',
                    creatorID TEXT,
                    forkedFromID TEXT,
                    forkCount INTEGER NOT NULL DEFAULT 0,
                    ratingAverage REAL,
                    ratingCount INTEGER NOT NULL DEFAULT 0,
                    tags TEXT NOT NULL DEFAULT '[]',
                    language TEXT NOT NULL DEFAULT 'en',
                    isPinned INTEGER NOT NULL DEFAULT 0,
                    pinnedOrder INTEGER,
                    createdAt DATETIME NOT NULL,
                    updatedAt DATETIME NOT NULL,
                    syncStatus TEXT NOT NULL DEFAULT 'pending',
                    publishedAt DATETIME,
                    publicID TEXT,
                    publicMetadata TEXT,
                    originalAuthorUsername TEXT,
                    originalContentPublicID TEXT
                )
            """)
            try db.execute(sql: """
                INSERT INTO library_content_new
                SELECT
                    id, title, description, type, visibility,
                    CASE WHEN creatorID = '00000000-0000-0000-0000-000000000000' THEN NULL ELSE creatorID END,
                    forkedFromID, forkCount, ratingAverage, ratingCount, tags, language,
                    isPinned, pinnedOrder, createdAt, updatedAt, syncStatus,
                    publishedAt, publicID, publicMetadata,
                    originalAuthorUsername, originalContentPublicID
                FROM library_content
            """)
            try db.execute(sql: "DROP TABLE library_content")
            try db.execute(sql: "ALTER TABLE library_content_new RENAME TO library_content")
            try db.execute(sql: "CREATE INDEX idx_library_content_creator ON library_content (creatorID)")
            try db.execute(sql: "CREATE INDEX idx_library_content_type ON library_content (type)")
            try db.execute(sql: "CREATE INDEX idx_library_content_updated ON library_content (updatedAt)")
            try db.execute(sql: "CREATE INDEX idx_library_content_pinned ON library_content (isPinned, pinnedOrder, updatedAt)")

            // --- checklists ---
            try db.execute(sql: """
                CREATE TABLE checklists_new (
                    id TEXT NOT NULL PRIMARY KEY,
                    title TEXT NOT NULL,
                    description TEXT,
                    checklistType TEXT NOT NULL DEFAULT 'general',
                    tags TEXT NOT NULL DEFAULT '[]',
                    content TEXT NOT NULL DEFAULT '[]',
                    creatorID TEXT,
                    createdAt DATETIME NOT NULL,
                    updatedAt DATETIME NOT NULL,
                    syncStatus TEXT NOT NULL DEFAULT 'pending'
                )
            """)
            try db.execute(sql: """
                INSERT INTO checklists_new
                SELECT
                    id, title, description, checklistType, tags, content,
                    CASE WHEN creatorID = '00000000-0000-0000-0000-000000000000' THEN NULL ELSE creatorID END,
                    createdAt, updatedAt, syncStatus
                FROM checklists
            """)
            try db.execute(sql: "DROP TABLE checklists")
            try db.execute(sql: "ALTER TABLE checklists_new RENAME TO checklists")
            try db.execute(sql: "CREATE INDEX idx_checklists_creator ON checklists (creatorID)")
            try db.execute(sql: "CREATE INDEX idx_checklists_updated ON checklists (updatedAt)")

            // --- practice_guides ---
            try db.execute(sql: """
                CREATE TABLE practice_guides_new (
                    id TEXT NOT NULL PRIMARY KEY,
                    title TEXT NOT NULL,
                    description TEXT,
                    markdown TEXT NOT NULL DEFAULT '',
                    tags TEXT NOT NULL DEFAULT '[]',
                    creatorID TEXT,
                    createdAt DATETIME NOT NULL,
                    updatedAt DATETIME NOT NULL,
                    syncStatus TEXT NOT NULL DEFAULT 'pending'
                )
            """)
            try db.execute(sql: """
                INSERT INTO practice_guides_new
                SELECT
                    id, title, description, markdown, tags,
                    CASE WHEN creatorID = '00000000-0000-0000-0000-000000000000' THEN NULL ELSE creatorID END,
                    createdAt, updatedAt, syncStatus
                FROM practice_guides
            """)
            try db.execute(sql: "DROP TABLE practice_guides")
            try db.execute(sql: "ALTER TABLE practice_guides_new RENAME TO practice_guides")
            try db.execute(sql: "CREATE INDEX idx_practice_guides_creator ON practice_guides (creatorID)")
            try db.execute(sql: "CREATE INDEX idx_practice_guides_updated ON practice_guides (updatedAt)")

            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }

        migrator.registerMigration("v2.0.0_addNextRetryAtToSyncQueue") { db in
            try db.alter(table: "sync_queue") { t in
                t.add(column: "nextRetryAt", .datetime)
            }
        }

        migrator.registerMigration("v2.1.0_addOriginalAuthorUserId") { db in
            try db.alter(table: "library_content") { t in
                t.add(column: "originalAuthorUserId", .text)
            }
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
            
            
            // Configure the database
            let config = Configuration()
            
            #if DEBUG
            // Enable verbose logging in debug builds
            // config.prepareDatabase { db in
            //     db.trace { print("SQL: \($0)") }
            // }
            #endif
            
            // AppLogger.database.debug("Creating DatabaseQueue")
            let dbQueue = try DatabaseQueue(path: databaseURL.path, configuration: config)
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
