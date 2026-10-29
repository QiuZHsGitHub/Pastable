import SwiftUI
import SwiftData
import Combine

@MainActor
final class AppState: ObservableObject {
  static let shared = AppState()

  @Published var isPanelVisible: Bool = false
  @Published var searchText: String = "" {
    didSet { recomputeDisplayItems() }
  }
  @Published var filteredItems: [HistoryItem] = []
  /// Folded tokens of the active search (see `SearchService.tokens(for:)`).
  /// Updated together with the debounced search result so cards can show why
  /// they matched without re-tokenizing per render.
  @Published private(set) var searchTokens: [String] = []
  @Published var settingsTab: SettingsTab = .general
  @Published var shouldScrollToTop: Bool = false
  @Published var searchFocusRequest: SearchFocusRequest = .none
  @Published var selectedCategory: String = "All" {
    didSet { recomputeDisplayItems() }
  }
  @Published var selectedItemID: PersistentIdentifier?
  /// Deliberately NOT `@Published`: hover is pure input state for the Cmd+Delete
  /// shortcut and is only read from event handlers, never from `body`. Cards
  /// slide under a stationary cursor while scrolling, and each crossing used to
  /// publish here — invalidating ContentView/CardList and re-rendering every
  /// visible card mid-scroll. Nothing renders from this value, so publishing
  /// bought nothing but jank.
  var hoveredItemID: PersistentIdentifier?
  /// Filtered + category-sorted view of the history. Recomputed on data or
  /// search changes only (not per render), because the category filter runs
  /// type classification over every record.
  @Published private(set) var displayItems: [HistoryItem] = []

  /// How many filtered items the shelf materializes at once. The visible band
  /// is only a handful of cards; capping the window keeps SwiftUI diffing and
  /// `ForEach` bookkeeping bounded even if the history grows to the
  /// "unlimited" sizes clipboard managers like Paste allow. The window grows
  /// as the user scrolls or arrow-keys toward its end.
  static let displayWindowBatchSize = 120

  @Published private(set) var displayLimit = AppState.displayWindowBatchSize

  /// Full (uncapped) size of the current filtered + category result.
  private var availableCount = 0

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

  /// SwiftUI `openSettings` action captured from the panel's hosted hierarchy.
  /// The Settings scene only opens reliably through this action (the AppKit
  /// `showSettingsWindow:` trick silently no-ops in this app).
  var openSettingsAction: (() -> Void)?

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
    scheduleSearchWarmUp()
  }

  // MARK: - Filtering

  private func recomputeDisplayItems() {
    let filtered = searchText.isEmpty ? allItems : filteredItems

    let result: [HistoryItem]
    switch selectedCategory {
    case "Text":
      result = filtered.filter { !$0.isCode && !$0.isLink && !$0.isImage && !$0.isFile }
    case "Code":
      result = filtered.filter { $0.isCode }
    case "Links":
      result = filtered.filter { $0.isLink }
    case "Others":
      result = filtered.filter { $0.isImage || $0.isFile }
    default:
      result = filtered
    }

    availableCount = result.count
    displayItems = result.count > displayLimit
      ? Array(result.prefix(displayLimit))
      : result
  }

  /// Grow the lazily loaded display window by one batch. No-op while every
  /// result is already visible.
  func expandDisplayWindow() {
    guard availableCount > displayItems.count else { return }
    displayLimit += Self.displayWindowBatchSize
    recomputeDisplayItems()
  }

  /// Called from `CardList` when a card near the end of the loaded window
  /// appears, so scrolling into older history stays seamless.
  func expandDisplayWindowIfNeeded(around id: PersistentIdentifier) {
    guard availableCount > displayItems.count,
          let index = displayItems.firstIndex(where: { $0.persistentModelID == id }),
          index >= displayItems.count - 12 else { return }
    expandDisplayWindow()
  }

  func performSearch(query: String) {
    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      filteredItems = allItems
      searchTokens = []
    } else {
      searchTokens = SearchService.tokens(for: query)
      filteredItems = SearchService.shared.search(query: query, items: allItems, mode: searchMode)
    }
    recomputeDisplayItems()
  }

  func refreshSearch() {
    performSearch(query: searchText)
  }

  // MARK: - Search index warm-up

  private var searchWarmUpTask: Task<Void, Never>?

  /// Idle-time pass that builds each record's folded search strings in small
  /// chunks (see `HistoryItem.warmUpSearchIndex`). Without it, the first
  /// keystroke after launch folds every pending record in one go and the panel
  /// hitches. Debounced by cancelling the previous pass, so bursts of
  /// clipboard activity restart the walk instead of stacking (walking an
  /// already-warm record is nearly free).
  private func scheduleSearchWarmUp() {
    searchWarmUpTask?.cancel()
    searchWarmUpTask = Task { [weak self] in
      // Let launch / data-change rendering finish first.
      try? await Task.sleep(nanoseconds: 400_000_000)
      guard let self, !Task.isCancelled else { return }

      var processed = 0
      for item in self.allItems {
        if Task.isCancelled { return }
        item.warmUpSearchIndex()
        // Also pre-compute the render-path classification (link/code detection,
        // file URLs) so a card's first body pass while scrolling is a handful of
        // cache reads instead of regex / NSDataDetector scans on the main thread.
        item.warmUpDisplayCaches()
        processed += 1
        if processed % 5 == 0 {
          // Yield and pause briefly so a large history never monopolizes the
          // main actor while the panel is open. Small batches: classification
          // heuristics on multi-thousand-character clips are millisecond-scale
          // each, and a 20-item burst could drop frames while scrolling.
          await Task.yield()
          try? await Task.sleep(nanoseconds: 2_000_000)
        }
      }
    }
  }

  // MARK: - Selection

  var selectedIndex: Int? {
    guard let selectedItemID else { return nil }
    return displayItems.firstIndex { $0.persistentModelID == selectedItemID }
  }

  func moveSelection(by delta: Int) {
    // Let keyboard navigation walk past the end of the lazily loaded window.
    if delta > 0, let selectedIndex, selectedIndex >= displayItems.count - 1 {
      expandDisplayWindow()
    }

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
