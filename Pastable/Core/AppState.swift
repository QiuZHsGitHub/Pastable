import SwiftUI
import SwiftData
import Combine

@MainActor
class AppState: ObservableObject {
  static let shared = AppState()

  @Published var isPanelVisible: Bool = false
  @Published var searchText: String = ""
  @Published var filteredItems: [HistoryItem] = []
  @Published var settingsTab: SettingsTab = .general
  @Published var shouldScrollToTop: Bool = false // Signal to scroll list to top on new content
  @Published var searchFocusRequest: SearchFocusRequest = .none // Signal to focus/blur global search bar

  enum SearchFocusRequest {
    case none
    case focus
    case blur
  }
  
  let themeManager = ThemeManager.shared
  
  enum SettingsTab: Hashable {
    case general
    case storage
    case shortcuts
    case about
  }
  
  weak var appDelegate: AppDelegate?
  
  private var allItems: [HistoryItem] = []
  private let throttler = Throttler(minimumDelay: 0.2)
  private var cancellables = Set<AnyCancellable>()
  
  init() {
    // Listen to search text changes
    $searchText
      .dropFirst()
      .sink { [weak self] text in
        self?.throttler.throttle {
          Task { @MainActor [weak self] in
            self?.performSearch(query: text)
          }
        }
      }
      .store(in: &cancellables)
  }
  
  func updateItems(_ items: [HistoryItem]) {
    // SwiftData can occasionally return duplicate instances with the same persistentModelID.
    // De-duplicate defensively to avoid rendering duplicate cards.
    var unique: [PersistentIdentifier: HistoryItem] = [:]
    for item in items {
      if let existing = unique[item.persistentModelID] {
        // Keep the newer one if timestamps differ
        if item.firstCopiedAt > existing.firstCopiedAt {
          unique[item.persistentModelID] = item
        }
      } else {
        unique[item.persistentModelID] = item
      }
    }
    let deduped = Array(unique.values).sorted { $0.firstCopiedAt > $1.firstCopiedAt }
    self.allItems = deduped
    #if DEBUG
    let ids = items.map { "\($0.persistentModelID)" }
    let uniqueIds = Set(ids)
    let sample = ids.prefix(5).joined(separator: ", ")
    print("[AppState][updateItems] \(ISO8601DateFormatter().string(from: Date())) count=\(items.count) unique=\(uniqueIds.count) sample=\(sample)")
    print("[AppState][updateItems] dedupedCount=\(deduped.count)")
    #endif
    // Re-run search if text is present, otherwise show all
    performSearch(query: searchText)
  }

  // MARK: - Filter Logic state
  @Published var selectedCategory: String = "All"
  @AppStorage("searchMode") var searchMode: SearchService.SearchMode = .fuzzy
  
  var displayItems: [HistoryItem] {
    let filtered: [HistoryItem]
    
    // 1. Search Filter
    if !searchText.isEmpty {
      filtered = filteredItems
    } else {
      filtered = allItems
    }
    
    // 2. Category Filter
    switch selectedCategory {
    case "Text":
      return filtered.filter { !$0.isCode && !$0.isLink && !$0.isImage && !$0.isFile }
    case "Code":
      return filtered.filter { $0.isCode }
    case "Links":
      return filtered.filter { $0.isLink }
    case "Others":
      return filtered.filter { $0.isImage || $0.isFile }
    default: // "All"
      return filtered
    }
  }

  private func performSearch(query: String) {
    if query.isEmpty {
      filteredItems = allItems
    } else {
      filteredItems = SearchService.shared.search(query: query, items: allItems, mode: searchMode)
    }
  }
}
