import Foundation
import OSLog

/// Centralized logging system for the application
/// Provides structured logging with different levels and categories
final class AppLogger {
    
    /// Log categories
    enum Category: String {
        case app = "App"
        case clipboard = "Clipboard"
        case search = "Search"
        case storage = "Storage"
        case imageCache = "ImageCache"
        case ui = "UI"
        case performance = "Performance"
        case settings = "Settings"
    }
    
    /// Create a logger for a specific category
    /// - Parameter category: The log category
    /// - Returns: A Logger instance
    static func logger(for category: Category) -> Logger {
        return Logger(subsystem: "com.qzh.Pastable", category: category.rawValue)
    }
    
    /// Log a debug message
    /// - Parameters:
    ///   - category: The log category
    ///   - message: The message to log
    static func debug(_ category: Category, _ message: String) {
        logger(for: category).debug("\(message, privacy: .public)")
    }
    
    /// Log an info message
    /// - Parameters:
    ///   - category: The log category
    ///   - message: The message to log
    static func info(_ category: Category, _ message: String) {
        logger(for: category).info("\(message, privacy: .public)")
    }
    
    /// Log a notice message
    /// - Parameters:
    ///   - category: The log category
    ///   - message: The message to log
    static func notice(_ category: Category, _ message: String) {
        logger(for: category).notice("\(message, privacy: .public)")
    }
    
    /// Log an error message
    /// - Parameters:
    ///   - category: The log category
    ///   - message: The message to log
    ///   - error: Optional error to include
    static func error(_ category: Category, _ message: String, error: Error? = nil) {
        var logMessage = message
        if let error = error {
            logMessage += " - \(error.localizedDescription)"
        }
        logger(for: category).error("\(logMessage, privacy: .public)")
    }
    
    /// Log a fault message
    /// - Parameters:
    ///   - category: The log category
    ///   - message: The message to log
    ///   - error: Optional error to include
    static func fault(_ category: Category, _ message: String, error: Error? = nil) {
        var logMessage = message
        if let error = error {
            logMessage += " - \(error.localizedDescription)"
        }
        logger(for: category).fault("\(logMessage, privacy: .public)")
    }
}

// Convenience extensions for common log operations
extension AppLogger {
    /// Clipboard-specific logging
    enum Clipboard {
        static func debug(_ message: String) {
            AppLogger.debug(.clipboard, message)
        }
        
        static func info(_ message: String) {
            AppLogger.info(.clipboard, message)
        }
        
        static func notice(_ message: String) {
            AppLogger.notice(.clipboard, message)
        }
        
        static func error(_ message: String, error: Error? = nil) {
            AppLogger.error(.clipboard, message, error: error)
        }
    }
    
    /// Storage-specific logging
    enum Storage {
        static func debug(_ message: String) {
            AppLogger.debug(.storage, message)
        }
        
        static func info(_ message: String) {
            AppLogger.info(.storage, message)
        }
        
        static func error(_ message: String, error: Error? = nil) {
            AppLogger.error(.storage, message, error: error)
        }
    }
    
    /// Search-specific logging
    enum Search {
        static func debug(_ message: String) {
            AppLogger.debug(.search, message)
        }
        
        static func info(_ message: String) {
            AppLogger.info(.search, message)
        }
        
        static func notice(_ message: String) {
            AppLogger.notice(.search, message)
        }
    }
}

// Global AppLog namespace for compatibility with existing code
enum AppLog {
    static let app = AppLogger.logger(for: .app)
    static let clipboard = AppLogger.logger(for: .clipboard)
    static let search = AppLogger.logger(for: .search)
    static let storage = AppLogger.logger(for: .storage)
    static let ui = AppLogger.logger(for: .ui)
}
