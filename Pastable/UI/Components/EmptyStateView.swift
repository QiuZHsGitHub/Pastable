import SwiftUI

struct EmptyStateView: View {
  let hasHistory: Bool
  let searchText: String
  @Environment(\.colorScheme) private var colorScheme

  private var theme: AppTheme { AppTheme(colorScheme) }

  var body: some View {
    VStack(spacing: 14) {
      ZStack {
        RoundedRectangle(cornerRadius: 18)
          .fill(theme.emptyTileBackground)
          .overlay(
            RoundedRectangle(cornerRadius: 18)
              .strokeBorder(theme.emptyTileBorder, lineWidth: 1)
          )
          .frame(width: 64, height: 64)

        Image(systemName: iconName)
          .font(.system(size: 24, weight: .light))
          .foregroundColor(theme.emptyIcon)
      }

      VStack(spacing: 5) {
        Text(titleKey)
          .font(.system(size: 15, weight: .medium))
          .foregroundColor(theme.emptyTitle)

        Text(subtitleKey)
          .font(.system(size: 12))
          .foregroundColor(theme.emptySubtitle)
          .multilineTextAlignment(.center)
      }

      if !hasHistory {
        HStack(spacing: 12) {
          shortcutHint("⌘⇧V", "empty.shortcut.open")
          shortcutHint("↵", "empty.shortcut.paste")
          shortcutHint("⌘1–9", "empty.shortcut.quick")
        }
        .padding(.top, 2)
      }
    }
    .frame(maxWidth: .infinity)
    .frame(height: 273)
  }

  private var iconName: String {
    if !hasHistory { return "clipboard" }
    if !searchText.isEmpty { return "magnifyingglass" }
    return "tray"
  }

  private var titleKey: LocalizedStringKey {
    if !hasHistory { return "empty.no_history" }
    if !searchText.isEmpty { return "empty.no_results" }
    return "empty.no_category"
  }

  private var subtitleKey: LocalizedStringKey {
    if !hasHistory { return "empty.hint" }
    if !searchText.isEmpty { return "empty.search_hint" }
    return "empty.category_hint"
  }

  private func shortcutHint(_ key: String, _ label: LocalizedStringKey) -> some View {
    HStack(spacing: 4) {
      Text(key)
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .foregroundColor(theme.keycapText)
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(theme.keycapBackground, in: RoundedRectangle(cornerRadius: 4))
        .overlay(
          RoundedRectangle(cornerRadius: 4)
            .strokeBorder(theme.keycapBorder, lineWidth: 1)
        )

      Text(label)
        .font(.system(size: 11))
        .foregroundColor(theme.keycapLabel)
    }
  }
}

#Preview {
  EmptyStateView(hasHistory: false, searchText: "")
    .background(Color.pastableBackground)
}
