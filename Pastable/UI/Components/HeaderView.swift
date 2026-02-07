import SwiftUI
import SwiftData

struct HeaderView: View {
  let categories: [String]
  @Binding var selectedCategory: String
  @Binding var searchText: String
  var hasHistory: Bool
  var onClearHistory: (() -> Void)?
  
  var body: some View {
    HStack(alignment: .center, spacing: 24) {
      // Category Filter
      CategoryFilter(categories: categories, selectedCategory: $selectedCategory)
      
        Spacer()
      
      // Search Bar & Buttons
      SearchBar(
        text: $searchText,
        hasHistory: hasHistory,
        onClearHistory: onClearHistory
      )
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
