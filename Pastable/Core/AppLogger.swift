import Foundation
import os.log

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
        return Logger(subsystem: "com.example.pastable", category: category.rawValue)
    }
    
    /// Log a debug message
    /// - Parameters:
    ///   - category: The log category
    ///   - message: The message to log
    ///   - privacy: Privacy level for the message
    static func debug(_ category: Category, _ message: String, privacy: OSLogPrivacy = .private) {
        logger(for: category).debug("\(message, privacy: privacy)")
    }
    
    /// Log an info message
    /// - Parameters:
    ///   - category: The log category
    ///   - message: The message to log
    ///   - privacy: Privacy level for the message
    static func info(_ category: Category, _ message: String, privacy: OSLogPrivacy = .private) {
        logger(for: category).info("\(message, privacy: privacy)")
    }
    
    /// Log a notice message
    /// - Parameters:
    ///   - category: The log category
    ///   - message: The message to log
    ///   - privacy: Privacy level for the message
    static func notice(_ category: Category, _ message: String, privacy: OSLogPrivacy = .private) {
        logger(for: category).notice("\(message, privacy: privacy)")
    }
    
    /// Log an error message
    /// - Parameters:
    ///   - category: The log category
    ///   - message: The message to log
    ///   - error: Optional error to include
    ///   - privacy: Privacy level for the message
    static func error(_ category: Category, _ message: String, error: Error? = nil, privacy: OSLogPrivacy = .private) {
        var logMessage = message
        if let error = error {
            logMessage += " - \(error.localizedDescription)"
        }
        logger(for: category).error("\(logMessage, privacy: privacy)")
    }
    
    /// Log a fault message
    /// - Parameters:
    ///   - category: The log category
    ///   - message: The message to log
    ///   - error: Optional error to include
    ///   - privacy: Privacy level for the message
    static func fault(_ category: Category, _ message: String, error: Error? = nil, privacy: OSLogPrivacy = .private) {
        var logMessage = message
        if let error = error {
            logMessage += " - \(error.localizedDescription)"
        }
        logger(for: category).fault("\(logMessage, privacy: privacy)")
    }
}

// Convenience extensions for common log operations
extension AppLogger {
    /// Clipboard-specific logging
    enum Clipboard {
        static func debug(_ message: String, privacy: OSLogPrivacy = .private) {
            AppLogger.debug(.clipboard, message, privacy: privacy)
        }
        
        static func info(_ message: String, privacy: OSLogPrivacy = .private) {
            AppLogger.info(.clipboard, message, privacy: privacy)
        }
        
        static func notice(_ message: String, privacy: OSLogPrivacy = .private) {
            AppLogger.notice(.clipboard, message, privacy: privacy)
        }
        
        static func error(_ message: String, error: Error? = nil, privacy: OSLogPrivacy = .private) {
            AppLogger.error(.clipboard, message, error: error, privacy: privacy)
        }
    }
    
    /// Storage-specific logging
    enum Storage {
        static func debug(_ message: String, privacy: OSLogPrivacy = .private) {
            AppLogger.debug(.storage, message, privacy: privacy)
        }
        
        static func info(_ message: String, privacy: OSLogPrivacy = .private) {
            AppLogger.info(.storage, message, privacy: privacy)
        }
        
        static func error(_ message: String, error: Error? = nil, privacy: OSLogPrivacy = .private) {
            AppLogger.error(.storage, message, error: error, privacy: privacy)
        }
    }
    
    /// Search-specific logging
    enum Search {
        static func debug(_ message: String, privacy: OSLogPrivacy = .private) {
            AppLogger.debug(.search, message, privacy: privacy)
        }
        
        static func info(_ message: String, privacy: OSLogPrivacy = .private) {
            AppLogger.info(.search, message, privacy: privacy)
        }
        
        static func notice(_ message: String, privacy: OSLogPrivacy = .private) {
            AppLogger.notice(.search, message, privacy: privacy)
        }
    }
}
