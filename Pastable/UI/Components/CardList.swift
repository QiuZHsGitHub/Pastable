import SwiftUI
import SwiftData

struct CardList: View {
  var items: [HistoryItem] = HistoryItem.examples
  @Binding var selectedItemId: PersistentIdentifier?
  @ObservedObject var appState = AppState.shared
  let onPaste: (HistoryItem) -> Void
  let onDelete: (HistoryItem) -> Void
  
  @State private var hoveredItemId: PersistentIdentifier?
  
  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: 16) {
          ForEach(items) { item in
            cardView(for: item)
              .id(item.id) // Important for scrollTo
          }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)  // contentInset
        .id("ScrollToTopAnchor") // Anchor applied to the padded container
      }
      .scrollIndicators(.automatic)
      .frame(height: 273)
      .simultaneousGesture(
        TapGesture().onEnded {
          AppState.shared.searchFocusRequest = .blur
        }
      )
      .onChange(of: AppState.shared.shouldScrollToTop) { shouldScroll in
        if shouldScroll {
          proxy.scrollTo("ScrollToTopAnchor", anchor: .leading)
          DispatchQueue.main.async {
             AppState.shared.shouldScrollToTop = false
          }
        }
      }
      .onAppear {
          // If a new item was added while hidden, snap to top immediately without animation
          if AppState.shared.shouldScrollToTop {
              proxy.scrollTo("ScrollToTopAnchor", anchor: .leading)
              // Reset signal
              DispatchQueue.main.async {
                  AppState.shared.shouldScrollToTop = false
              }
          }
      }
      // Global shortcut for delete on hover (Command+Delete)
      // Hidden button trick to attach keyboard shortcut
      .background(
        Button("") {
          if let hoveredId = hoveredItemId, let item = items.first(where: { $0.id == hoveredId }) {
             onDelete(item)
          }
        }
        .keyboardShortcut(.delete, modifiers: .command)
        .hidden()
      )
    }
  }
  
  // MARK: - Private Views
  
  @ViewBuilder
  private func cardView(for item: HistoryItem) -> some View {
    Button(action: {
      onPaste(item)
    }) {
      CardCell(
        item: item,
        isSelected: selectedItemId == item.id,
        onCopy: nil // Inner action handled by parent Button
      )
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      if hovering {
        hoveredItemId = item.id
      } else if hoveredItemId == item.id {
        hoveredItemId = nil
      }
    }
  }
}

// MARK: - Preview

private struct CardListPreview: View {
  @State private var selectedId: PersistentIdentifier? = nil
  
  var body: some View {
    CardList(
      items: HistoryItem.examples,
      selectedItemId: $selectedId,
      onPaste: { _ in },
      onDelete: { _ in }
    )
    .background(Color.pastableBackground)
  }
}

#Preview("卡片列表") {
  CardListPreview()
}
