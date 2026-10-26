import SwiftUI
import SwiftData

struct CardList: View {
  var items: [HistoryItem] = HistoryItem.examples
  @Binding var selectedItemId: PersistentIdentifier?
  @ObservedObject var appState = AppState.shared
  let onPaste: (HistoryItem) -> Void
  let onDelete: (HistoryItem) -> Void

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: 16) {
          ForEach(items) { item in
            cardView(for: item)
              .id(item.persistentModelID)
          }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .id("ScrollToTopAnchor")
      }
      .scrollIndicators(.automatic)
      .frame(height: 273)
      .simultaneousGesture(
        TapGesture().onEnded {
          AppState.shared.searchFocusRequest = .blur
        }
      )
      .onChange(of: appState.shouldScrollToTop) { _, shouldScroll in
        guard shouldScroll else { return }
        proxy.scrollTo("ScrollToTopAnchor", anchor: .leading)
        appState.shouldScrollToTop = false
      }
      .onChange(of: selectedItemId) { _, newValue in
        guard let newValue else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
          proxy.scrollTo(newValue, anchor: .center)
        }
      }
      .onAppear {
        // If a new item was added while the panel was hidden, snap to the front
        // without animating.
        if appState.shouldScrollToTop {
          proxy.scrollTo("ScrollToTopAnchor", anchor: .leading)
          appState.shouldScrollToTop = false
        }
      }
    }
  }

  // MARK: - Private Views

  @ViewBuilder
  private func cardView(for item: HistoryItem) -> some View {
    Button(action: {
      selectedItemId = item.persistentModelID
      onPaste(item)
    }) {
      CardCell(
        item: item,
        isSelected: selectedItemId == item.persistentModelID,
        onCopy: nil
      )
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      if hovering {
        appState.hoveredItemID = item.persistentModelID
      } else if appState.hoveredItemID == item.persistentModelID {
        appState.hoveredItemID = nil
      }
    }
    .help(cardTitle(for: item))
  }

  private func cardTitle(for item: HistoryItem) -> String {
    if item.isFile, let fileURL = item.fileURLs.first {
      return fileURL.lastPathComponent.removingPercentEncoding ?? fileURL.lastPathComponent
    }
    return item.title.isEmpty ? item.previewableText : item.title
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
