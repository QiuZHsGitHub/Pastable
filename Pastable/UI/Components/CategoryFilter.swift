import SwiftUI

struct CategoryFilter: View {
  let categories: [String]
  @Binding var selectedCategory: String
  @ObservedObject var themeManager = ThemeManager.shared
  
  var body: some View {
    HStack(alignment: .bottom, spacing: 8) {
      ForEach(categories, id: \.self) { category in
        categoryButton(for: category)
      }
      
      Spacer()
    }
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedCategory)
  }
  
  // MARK: - Private Views
  
  @ViewBuilder
  private func categoryButton(for category: String) -> some View {
    let isSelected = selectedCategory == category
    let borderColor = color(for: category)
    
    // Use NSLocalizedString for dynamic keys to ensure immediate lookup
    let title = NSLocalizedString("category.\(category.lowercased())", comment: category)
    
    Button(action: {
      selectedCategory = category
    }) {
      Text(title)
        .font(.system(size: 14))
        .foregroundColor(isSelected ? .white : .white.opacity(0.6))
        .padding(.horizontal, 16)
        .padding(.vertical, isSelected ? 10 : 7)
        .background(
          isSelected
            ? AnyView(Color.pastableOrange) // Use Orange Theme selection
            : AnyView(Color.white.opacity(0.05))
        )
        .clipShape(
          UnevenRoundedRectangle(
            topLeadingRadius: 8,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 8
          )
        )
        .overlay(alignment: .bottom) {
          Rectangle()
            .fill(borderColor)
            .frame(height: 3)
        }
    }
    .buttonStyle(.plain)
  }
  
  private func color(for category: String) -> Color {
    // Fixed colors as requested
    switch category {
    case "All": return Color(hex: "#9CA3AF")    // Gray-400
    case "Code": return Color(hex: "#3B82F6")   // Blue-500
    case "Links": return Color(hex: "#A855F7")  // Purple-500
    case "Others": return Color(hex: "#EC4899") // Pink-500
    default: return .gray
    }
  }
}

#Preview("分类筛选") {
  CategoryFilter(
    categories: ["All", "Code", "Links", "Others"],
    selectedCategory: .constant("All")
  )
  .frame(width: 800)
  .padding()
  .background(Color.pastableBackground)
}
