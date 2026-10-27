import SwiftUI
import SwiftData

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \HistoryItem.lastCopiedAt, order: .reverse) private var items: [HistoryItem]
  @ObservedObject var appState = AppState.shared
  @Environment(\.colorScheme) private var colorScheme

  private var theme: AppTheme { AppTheme.theme(for: colorScheme) }

  private let categories = ["All", "Text", "Code", "Links", "Others"]
  @State private var keyMonitor: Any?
  @State private var showClearConfirmation = false

  var body: some View {
    VStack(spacing: 0) {
      // 1. Header (Category + Search)
      HeaderView(
        categories: categories,
        selectedCategory: $appState.selectedCategory,
        searchText: $appState.searchText,
        hasHistory: !items.isEmpty,
        onClearHistory: { showClearConfirmation = true }
      )

      // 2. Card List / empty state
      if appState.displayItems.isEmpty {
        EmptyStateView(hasHistory: !items.isEmpty, searchText: appState.searchText)
      } else {
        CardList(
          items: appState.displayItems,
          selectedItemId: $appState.selectedItemID,
          onPaste: { item in
            performPaste(item: item)
          },
          onDelete: { item in
            delete(item: item)
          }
        )
      }
    }
    .background(
      LinearGradient(
        stops: [
          .init(color: theme.panelTop, location: 0),
          .init(color: theme.panelMid, location: 0.16),
          .init(color: theme.panelBottom, location: 1)
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    )
    .clipShape(TopRoundedRectangle(radius: 24))
    .overlay(
      TopRoundedRectangle(radius: 24)
        .stroke(theme.panelBorder, lineWidth: 1)
    )
    .edgesIgnoringSafeArea(.all)
    .onChange(of: items) { _, newValue in
      appState.updateItems(newValue)
    }
    .onChange(of: appState.searchText) { _, _ in
      appState.resetSelection()
    }
    .onAppear {
      appState.updateItems(items)
      installKeyboardMonitor()
    }
    .onDisappear {
      if let keyMonitor {
        NSEvent.removeMonitor(keyMonitor)
        self.keyMonitor = nil
      }
    }
    .confirmationDialog(
      "clear_history.title",
      isPresented: $showClearConfirmation,
      titleVisibility: .visible
    ) {
      Button("clear_history.confirm", role: .destructive) {
        clearHistory()
      }
      Button("common.cancel", role: .cancel) {}
    } message: {
      Text("clear_history.message")
    }
  }

  // MARK: - Actions

  private func performPaste(item: HistoryItem) {
    let delegate = appState.appDelegate
    appState.selectedItemID = item.persistentModelID

    // 1. Close the panel and give focus back to the app the user came from.
    // Without this, Cmd+V can be delivered to Pastable instead of the target app.
    delegate?.closePanel()
    let target = delegate?.restorePreviousApplication()

    // 2. Move the item to the front of the history.
    item.lastCopiedAt = Date()
    item.numberOfCopies += 1
    do {
      try modelContext.save()
    } catch {
      AppLogger.Storage.error("Failed to save paste timestamp", error: error)
    }

    // 3. Copy, then fire Cmd+V as soon as the pasteboard write is observable
    // and the target app has keyboard focus (with a timeout fallback instead
    // of the old fixed 120ms delay).
    Clipboard.shared.copy(item)
    Task { @MainActor in
      await Clipboard.shared.paste(whenReadyFor: target)
    }
  }

  private func delete(item: HistoryItem) {
    modelContext.delete(item)
    do {
      try modelContext.save()
    } catch {
      AppLogger.Storage.error("Failed to delete item", error: error)
    }
    if appState.selectedItemID == item.persistentModelID {
      appState.resetSelection()
    }
  }

  private func clearHistory() {
    Storage.shared.clearAll()
    appState.resetSelection()
  }

  // MARK: - Keyboard

  private func installKeyboardMonitor() {
    guard keyMonitor == nil else { return }

    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      let consumed = MainActor.assumeIsolated {
        handleKeyDown(event) == nil
      }
      return consumed ? nil : event
    }
  }

  private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
    guard appState.isPanelVisible else { return event }

    let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

    switch event.keyCode {
    case 53: // Escape
      appState.appDelegate?.closePanel(restorePrevious: true)
      return nil

    case 36, 76: // Return / keypad Enter
      guard !flags.contains(.command), !flags.contains(.option) else { return event }
      if let item = appState.item(with: appState.selectedItemID) ?? appState.displayItems.first {
        performPaste(item: item)
        return nil
      }
      return event

    case 51 where flags.contains(.command): // Cmd + Delete
      if let item = appState.item(with: appState.hoveredItemID)
        ?? appState.item(with: appState.selectedItemID) {
        delete(item: item)
        return nil
      }
      return event

    case 123, 124: // Left / Right
      // Arrow keys carry the .function flag on macOS; ignore that and keypad
      // flags when checking whether this is an unmodified navigation key.
      let navigationFlags = flags.subtracting([.function, .numericPad, .capsLock])
      guard appState.searchText.isEmpty, navigationFlags.isEmpty else { return event }
      appState.moveSelection(by: event.keyCode == 123 ? -1 : 1)
      return nil

    default:
      break
    }

    // Fn + 1…9 (laptops) or Cmd + 1…9 quick paste. Arrow keys and the numeric
    // keypad also set modifier flags on macOS, so only explicitly reject the
    // modifiers that would change the meaning of the shortcut.
    let disallowedFlags: NSEvent.ModifierFlags = [.option, .control]
    if flags.intersection(disallowedFlags).isEmpty,
       flags.contains(.command) || flags.contains(.function),
       let index = Self.digitIndex(for: event) {
      let displayItems = appState.displayItems
      if displayItems.indices.contains(index) {
        performPaste(item: displayItems[index])
        return nil
      }
    }

    return event
  }

  /// ANSI number row and the F1…F9 keys produced by Fn+number on laptops.
  private static func digitIndex(for event: NSEvent) -> Int? {
    let numberKeys: [UInt16: Int] = [
      18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9
    ]
    if let index = numberKeys[event.keyCode] {
      return index - 1
    }

    let functionKeys: [UInt16: Int] = [
      122: 1, 120: 2, 99: 3, 118: 4, 96: 5, 97: 6, 98: 7, 100: 8, 101: 9
    ]
    if let index = functionKeys[event.keyCode] {
      return index - 1
    }

    if let character = event.charactersIgnoringModifiers,
       let number = Int(character), number >= 1, number <= 9 {
      return number - 1
    }

    return nil
  }
}

// Custom Shape for top rounded corners
struct TopRoundedRectangle: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Start bottom left
        path.move(to: CGPoint(x: 0, y: h))
        // Line up to top left start
        path.addLine(to: CGPoint(x: 0, y: radius))
        // Arc top left
        path.addArc(center: CGPoint(x: radius, y: radius), radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        // Line to top right start
        path.addLine(to: CGPoint(x: w - radius, y: 0))
        // Arc top right
        path.addArc(center: CGPoint(x: w - radius, y: radius), radius: radius, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        // Line down to bottom right
        path.addLine(to: CGPoint(x: w, y: h))
        // Close path
        path.closeSubpath()

        return path
    }
}

#Preview("主视图") {
  ContentView()
    .modelContainer(for: HistoryItem.self, inMemory: true)
}
