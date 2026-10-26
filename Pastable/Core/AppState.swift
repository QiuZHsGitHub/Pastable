import SwiftUI
import SwiftData
import Combine

@MainActor
final class AppState: ObservableObject {
  static let shared = AppState()

  @Published var isPanelVisible: Bool = false
  @Published var searchText: String = ""
  @Published var filteredItems: [HistoryItem] = []
  @Published var settingsTab: SettingsTab = .general
  @Published var shouldScrollToTop: Bool = false
  @Published var searchFocusRequest: SearchFocusRequest = .none
  @Published var selectedCategory: String = "All"
  @Published var selectedItemID: PersistentIdentifier?
  @Published var hoveredItemID: PersistentIdentifier?

  enum SearchFocusRequest: Equatable {
    case none
    case focus
    case blur
  }

  enum SettingsTab: Hashable {
    case general
    case storage
    case shortcuts
    case about
  }

  weak var appDelegate: AppDelegate?

  private var allItems: [HistoryItem] = []
  private var cancellables = Set<AnyCancellable>()

  @AppStorage(Preferences.Key.searchMode)
  private var searchMode: SearchService.SearchMode = .fuzzy

  init() {
    $searchText
      .removeDuplicates()
      .debounce(for: .milliseconds(120), scheduler: RunLoop.main)
      .sink { [weak self] text in
        self?.performSearch(query: text)
      }
      .store(in: &cancellables)

    // Search mode and other preferences are written through @AppStorage in the
    // Settings window. Observe the defaults so the open panel updates live.
    NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
      .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
      .sink { [weak self] _ in
        guard let self else { return }
        self.performSearch(query: self.searchText)
      }
      .store(in: &cancellables)
  }

  func updateItems(_ items: [HistoryItem]) {
    // SwiftData can occasionally return duplicate instances with the same
    // persistentModelID. De-duplicate defensively to avoid duplicate cards.
    var unique: [PersistentIdentifier: HistoryItem] = [:]
    for item in items {
      if let existing = unique[item.persistentModelID] {
        if item.lastCopiedAt > existing.lastCopiedAt {
          unique[item.persistentModelID] = item
        }
      } else {
        unique[item.persistentModelID] = item
      }
    }

    let deduped = Array(unique.values).sorted { $0.lastCopiedAt > $1.lastCopiedAt }
    // Hide empty clipboard strings immediately, even before the next launch
    // maintenance removes them from the store.
    let visible = deduped.filter { !$0.isEffectivelyEmpty }
    self.allItems = visible

    if let selectedItemID, !visible.contains(where: { $0.persistentModelID == selectedItemID }) {
      self.selectedItemID = nil
    }
    if let hoveredItemID, !visible.contains(where: { $0.persistentModelID == hoveredItemID }) {
      self.hoveredItemID = nil
    }

    performSearch(query: searchText)
  }

  // MARK: - Filtering

  var displayItems: [HistoryItem] {
    let filtered = searchText.isEmpty ? allItems : filteredItems

    switch selectedCategory {
    case "Text":
      return filtered.filter { !$0.isCode && !$0.isLink && !$0.isImage && !$0.isFile }
    case "Code":
      return filtered.filter { $0.isCode }
    case "Links":
      return filtered.filter { $0.isLink }
    case "Others":
      return filtered.filter { $0.isImage || $0.isFile }
    default:
      return filtered
    }
  }

  func performSearch(query: String) {
    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      filteredItems = allItems
    } else {
      filteredItems = SearchService.shared.search(query: query, items: allItems, mode: searchMode)
    }
  }

  func refreshSearch() {
    performSearch(query: searchText)
  }

  // MARK: - Selection

  var selectedIndex: Int? {
    guard let selectedItemID else { return nil }
    return displayItems.firstIndex { $0.persistentModelID == selectedItemID }
  }

  func moveSelection(by delta: Int) {
    let items = displayItems
    guard !items.isEmpty else {
      selectedItemID = nil
      return
    }

    let current: Int
    if let selectedIndex {
      current = selectedIndex
    } else {
      current = delta >= 0 ? -1 : items.count
    }

    let next = min(max(current + delta, 0), items.count - 1)
    selectedItemID = items[next].persistentModelID
    hoveredItemID = nil
  }

  func selectFirstIfNeeded() {
    if selectedItemID == nil {
      selectedItemID = displayItems.first?.persistentModelID
    }
  }

  func resetSelection() {
    selectedItemID = nil
    hoveredItemID = nil
  }

  func item(with id: PersistentIdentifier?) -> HistoryItem? {
    guard let id else { return nil }
    return displayItems.first { $0.persistentModelID == id }
  }
}
