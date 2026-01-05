//
//  Logger.swift
//  anyfleet
//
//  Unified logging utility using OSLog
//

import Foundation
import OSLog

/// Centralized logging utility for the anyfleet app
enum AppLogger {
    /// Main app logger
    private static let logger = Logger(subsystem: "com.anyfleet.app", category: "App")
    
    /// Charter-related logging
    static let charter = Logger(subsystem: "com.anyfleet.app", category: "Charter")
    
    /// Database-related logging
    static let database = Logger(subsystem: "com.anyfleet.app", category: "Database")
    
    /// Repository-related logging
    static let repository = Logger(subsystem: "com.anyfleet.app", category: "Repository")
    
    /// Store-related logging
    static let store = Logger(subsystem: "com.anyfleet.app", category: "Store")
    
    /// View-related logging
    static let view = Logger(subsystem: "com.anyfleet.app", category: "View")
    
    /// Auth-related logging
    static let auth = Logger(subsystem: "com.anyfleet.app", category: "Auth")

    /// API-related logging
    static let api = Logger(subsystem: "com.anyfleet.app", category: "API")
}

// MARK: - Convenience Extensions

extension Logger {
    /// Log a debug message
    nonisolated func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let formattedMessage = "\(fileName):\(line) \(function) - \(message)"
        self.log(level: .debug, "\(formattedMessage)")
    }
    
    /// Log an info message
    nonisolated func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let formattedMessage = "\(fileName):\(line) \(function) - \(message)"
        self.log(level: .info, "\(formattedMessage)")
    }
    
    /// Log a warning message
    nonisolated func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let formattedMessage = "\(fileName):\(line) \(function) - \(message)"
        self.log(level: .default, "\(formattedMessage)")
    }
    
    /// Log an error message
    nonisolated func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let formattedMessage: String
        if let error = error {
            formattedMessage = "\(fileName):\(line) \(function) - \(message): \(error.localizedDescription)"
        } else {
            formattedMessage = "\(fileName):\(line) \(function) - \(message)"
        }
        self.log(level: .error, "\(formattedMessage)")
    }
    
    /// Log the start of an operation
    nonisolated func startOperation(_ operation: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let formattedMessage = "▶️ START: \(operation) - \(fileName):\(line) \(function)"
        self.log(level: .debug, "\(formattedMessage)")
    }
    
    /// Log the completion of an operation
    nonisolated func completeOperation(_ operation: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let formattedMessage = "✅ COMPLETE: \(operation) - \(fileName):\(line) \(function)"
        self.log(level: .debug, "\(formattedMessage)")
    }
    
    /// Log the failure of an operation
    nonisolated func failOperation(_ operation: String, error: Error, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let formattedMessage = "❌ FAIL: \(operation) - \(fileName):\(line) \(function) - Error: \(error.localizedDescription)"
        self.log(level: .error, "\(formattedMessage)")
    }
}
