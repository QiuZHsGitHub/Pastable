import SwiftUI

struct CategoryFilter: View {
  let categories: [String]
  @Binding var selectedCategory: String

  @State private var hoveredCategory: String?
  @Environment(\.colorScheme) private var colorScheme

  private var theme: AppTheme { AppTheme.theme(for: colorScheme) }

  var body: some View {
    HStack(alignment: .center, spacing: 8) {
      ForEach(categories, id: \.self) { category in
        categoryButton(for: category)
      }

      Spacer()
    }
    .animation(.easeOut(duration: 0.15), value: selectedCategory)
  }

  // MARK: - Private Views

  @ViewBuilder
  private func categoryButton(for category: String) -> some View {
    let isSelected = selectedCategory == category
    let isHovered = hoveredCategory == category
    let title = NSLocalizedString("category.\(category.lowercased())", comment: category)

    Button(action: {
      selectedCategory = category
    }) {
      HStack(spacing: 6) {
        Circle()
          .fill(isSelected ? Color.pastableOrange : color(for: category))
          .frame(width: 5, height: 5)

        Text(title)
          .font(.system(size: 13.5, weight: isSelected ? .semibold : .regular))
          .foregroundColor(
            isSelected
              ? theme.tabTextSelected
              : (isHovered ? theme.textPrimary : theme.tabText)
          )
          .lineLimit(1)
      }
      .padding(.horizontal, 13)
      .frame(height: 32)
      .background(
        RoundedRectangle(cornerRadius: 9)
          .fill(
            isSelected
              ? theme.tabSelectedBackground
              : (isHovered ? theme.tabHoverBackground : theme.tabBackground)
          )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 9)
          .strokeBorder(
            isSelected ? Color.pastableOrange : theme.tabBorder,
            lineWidth: 1
          )
      )
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      hoveredCategory = hovering ? category : nil
    }
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private func color(for category: String) -> Color {
    switch category {
    case "All": return Color(hex: "#9CA3AF")    // Gray-400
    case "Text": return Color(hex: "#10B981")   // Emerald-500
    case "Code": return Color(hex: "#3B82F6")   // Blue-500
    case "Links": return Color(hex: "#A855F7")  // Purple-500
    case "Others": return Color(hex: "#EC4899") // Pink-500
    default: return .gray
    }
  }
}

#Preview("分类筛选") {
  CategoryFilter(
    categories: ["All", "Text", "Code", "Links", "Others"],
    selectedCategory: .constant("All")
  )
  .frame(width: 800)
  .padding()
  .background(Color.pastableBackground)
}
