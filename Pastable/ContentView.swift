import SwiftUI
import SwiftData

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \HistoryItem.firstCopiedAt, order: .reverse) private var items: [HistoryItem]
  @ObservedObject var appState = AppState.shared
  
  private let categories = ["All", "Code", "Links", "Others"]
  @State private var selectedItemId: PersistentIdentifier? = nil

  var body: some View {
    VStack(spacing: 0) {
      // 1. Header (Category + Search)
      HeaderView(
        categories: categories,
        selectedCategory: $appState.selectedCategory,
        searchText: $appState.searchText,
        hasHistory: !items.isEmpty,
        onClearHistory: {
          for item in items {
            modelContext.delete(item)
          }
        }
      )

      // 2. Card List
      CardList(
        items: appState.displayItems,
        selectedItemId: $selectedItemId,
        onPaste: { item in
          performPaste(item: item)
        },
        onDelete: { item in
          modelContext.delete(item)
        }
      )
    }
    .background(VisualEffectView(material: .menu))
    .clipShape(TopRoundedRectangle(radius: 24))
    .edgesIgnoringSafeArea(.all)
    .onChange(of: items) { oldValue, newValue in
      appState.updateItems(newValue)
    }
    .onAppear {
      appState.updateItems(items)
      setupKeyboardMonitor()
    }
    .preferredColorScheme(.dark)
  }
  
  private func performPaste(item: HistoryItem) {
    // 1. Close panel
    AppState.shared.appDelegate?.closePanel()
    
    // 2. Move item to top (update timestamp)
    item.firstCopiedAt = Date()
    
    // 3. Copy item to clipboard
    Clipboard.shared.copy(item)
    
    // 3. Trigger paste action
    Clipboard.shared.paste()
  }
  
  private func setupKeyboardMonitor() {
    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      // Check for Fn functionality (or F1-F9 keys directly if mapped)
      // Fn + Number typically emits F-keys (F1 = 122, F2 = 120...) or Number chars if Fn lock is on?
      // User asked specifically for "Fn + 1 to 9".
      // We will check for the presence of the .function modifier flag AND the number keys.
      // However, usually Fn + Number keys are NOT standard key events unless mapped.
      // Assuming user might mean F1..F9 keys which are often Fn+Number on laptops.
        
      // Option A: Check for F1..F9 keys (keycode 122, 120, 99, 118, 96, 97, 98, 100, 101)
      // Option B: Check for .function modifier + Number keycodes (18...25)
        
      if event.modifierFlags.contains(.function) {
        if let char = event.charactersIgnoringModifiers, let num = Int(char), num >= 1 && num <= 9 {
             let index = num - 1
             let items = AppState.shared.displayItems
             if index < items.count {
                 performPaste(item: items[index])
                 return nil // Consume event
             }
        }
      }
      return event
    }
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
