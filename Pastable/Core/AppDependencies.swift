import Foundation
import SwiftData

/// Dependency injection container for the application
/// Provides a centralized place to create and manage shared dependencies
@MainActor
final class AppDependencies: ObservableObject {
    
    // MARK: - Dependencies
    
    private(set) var clipboard: Clipboard
    private(set) var searchService: SearchService
    private(set) var imageCache: ImageCache
    private(set) var performanceMonitor: PerformanceMonitor
    
    /// Model context for SwiftData persistence
    @Published var modelContext: ModelContext
    
    // MARK: - Singleton
    
    static let shared = AppDependencies()
    
    // MARK: - Initialization
    
    private init() {
        // Initialize SwiftData container
        let schema = Schema([HistoryItem.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.modelContext = container.mainContext
        } catch {
            AppLogger.fault(.storage, "Failed to initialize ModelContainer", error: error)
            fatalError("Failed to initialize ModelContainer: \(error.localizedDescription)")
        }
        
        // Initialize dependencies
        self.clipboard = Clipboard()
        self.searchService = SearchService()
        self.imageCache = ImageCache.shared
        self.performanceMonitor = PerformanceMonitor()
        
        AppLogger.info(.app, "AppDependencies initialized successfully")
    }
    
    // MARK: - Lifecycle
    
    /// Clean up resources when the app is terminating
    func cleanup() {
        clipboard.stop()
        imageCache.clearAllCaches()
        AppLogger.info(.app, "AppDependencies cleaned up")
    }
    
    // MARK: - Convenience Methods
    
    /// Create a new history item with the current clipboard content
    /// - Returns: A new HistoryItem instance, or nil if clipboard is empty
    func createHistoryItemFromClipboard() -> HistoryItem? {
        let monitor = PerformanceMonitor()
        let item = monitor.measure("createHistoryItemFromClipboard") {
            clipboard.createHistoryItem()
        }
        return item
    }
    
    /// Search history items
    /// - Parameters:
    ///   - query: The search query
    ///   - items: Items to search in
    ///   - mode: Search mode (exact or fuzzy)
    /// - Returns: Filtered items matching the query
    func search(query: String, in items: [HistoryItem], mode: SearchService.SearchMode = .fuzzy) -> [HistoryItem] {
        let monitor = PerformanceMonitor()
        return monitor.measure("search") {
            searchService.search(query: query, items: items, mode: mode)
        }
    }
}
