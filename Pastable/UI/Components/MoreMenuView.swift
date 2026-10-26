import SwiftUI

/// 更多菜单弹窗视图
struct MoreMenuView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme

  private var theme: AppTheme { AppTheme.theme(for: colorScheme) }

  var onClearHistory: (() -> Void)?
  var onSettings: () -> Void
  var onAbout: () -> Void
  var onQuit: () -> Void
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // 清除历史（可选）
      if let onClearHistory = onClearHistory {
        menuItem(title: "menu.clear_history", icon: "trash", shortcut: "⌥⌘⌫") {
          onClearHistory()
          dismiss()
        }
        
        themeSeparator
      }
      
      // 设置
      menuItem(title: "menu.settings", icon: "gearshape", shortcut: "⌘,") {
        onSettings()
        dismiss()
      }

      // 关于
      menuItem(title: "menu.about", icon: "info.circle") {
        onAbout()
        dismiss()
      }
      
      themeSeparator
      
      // 退出（最后一项）
      menuItem(title: "menu.quit", icon: "power", shortcut: "⌘Q") {
        onQuit()
      }
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 4)
    .frame(width: 200)
    .background(theme.menuBackground)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(theme.menuBorder, lineWidth: 1)
    )
    .shadow(color: Color.black.opacity(theme.isDark ? 0.36 : 0.14), radius: 18, y: 8)
  }

  private var themeSeparator: some View {
    Rectangle()
      .fill(theme.menuSeparator)
      .frame(height: 1)
      .padding(.vertical, 4)
  }
  
  // MARK: - Private Views
  
  @ViewBuilder
  private func menuItem(title: LocalizedStringKey, icon: String, shortcut: String? = nil, action: @escaping () -> Void) -> some View {
    MenuItemButton(title: title, icon: icon, shortcut: shortcut, action: action)
  }
}

/// 菜单项内容视图
private struct MenuItemContent: View {
  let title: LocalizedStringKey
  let icon: String
  var shortcut: String? = nil
  @Environment(\.colorScheme) private var colorScheme

  private var theme: AppTheme { AppTheme.theme(for: colorScheme) }

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 14))
        .foregroundColor(theme.menuIcon)
        .frame(width: 20)
      
      Text(title)
        .font(.system(size: 13))
        .foregroundColor(theme.menuText)
      
      Spacer()
      
      if let shortcut = shortcut {
        Text(shortcut)
          .font(.system(size: 12))
          .foregroundColor(theme.menuShortcut)
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .contentShape(Rectangle())
  }
}

/// 带 hover 高亮效果的菜单项按钮
private struct MenuItemButton: View {
  let title: LocalizedStringKey
  let icon: String
  var shortcut: String? = nil
  let action: () -> Void
  @Environment(\.colorScheme) private var colorScheme
  @State private var isHovered = false

  private var theme: AppTheme { AppTheme.theme(for: colorScheme) }
  
  var body: some View {
    Button(action: action) {
      MenuItemContent(title: title, icon: icon, shortcut: shortcut)
    }
    .buttonStyle(.plain)
    .background(isHovered ? theme.menuHover : Color.clear)
    .cornerRadius(4)
    .onHover { hovering in
      isHovered = hovering
    }
  }
}

#Preview("更多菜单") {
  MoreMenuView(
    onClearHistory: { print("清除历史") },
    onSettings: { print("设置") },
    onAbout: { print("关于") },
    onQuit: { print("退出") }
  )
  .padding()
  .background(Color.black)
}
