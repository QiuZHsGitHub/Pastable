import SwiftUI
import SwiftData

struct HeaderView: View {
  let categories: [String]
  @Binding var selectedCategory: String
  @Binding var searchText: String
  var hasHistory: Bool
  var onClearHistory: (() -> Void)?

  /// 搜索框固定宽度。Figma 让搜索框占满分类右侧的剩余空间，但在宽屏面板上
  /// 会拉成一条很长的输入条，这里收成紧凑的搜索框宽度。
  private let searchBarWidth: CGFloat = 400

  var body: some View {
    HStack(alignment: .center, spacing: 24) {
      // Category Filter
      CategoryFilter(categories: categories, selectedCategory: $selectedCategory)
      
      // Between the filters and the search box: clicking this blank space just
      // releases the search field's keyboard focus.
      Color.clear
        .contentShape(Rectangle())
        .onTapGesture {
          AppState.shared.searchFocusRequest = .blur
        }
      
      // Search Bar & Buttons
      SearchBar(
        text: $searchText,
        hasHistory: hasHistory,
        onClearHistory: onClearHistory
      )
      .frame(width: searchBarWidth)
    }
    .padding(.top, 16)
    .padding(.horizontal, 24)
    // Global shortcut to focus search (Cmd+Shift+F)
    // We attach it here to the container
    .background(
      Button("") {
        AppState.shared.searchFocusRequest = .focus
      }
      .keyboardShortcut("f", modifiers: [.command, .shift])
      .hidden()
    )
  }
}

#Preview("头部视图") {
  HeaderView(
    categories: ["All", "Text"],
    selectedCategory: .constant("All"),
    searchText: .constant(""),
    hasHistory: true,
    onClearHistory: {}
  )
  .background(Color.pastableBackground)
}
