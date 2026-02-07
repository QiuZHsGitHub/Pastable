import SwiftUI

/// 更多菜单弹窗视图
struct MoreMenuView: View {
  @Environment(\.dismiss) private var dismiss
  
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
        
        Divider()
          .padding(.vertical, 4)
      }
      
      // 设置
      if #available(macOS 14.0, *) {
        SettingsLink {
          MenuItemContent(title: "menu.settings", icon: "gearshape", shortcut: "⌘,")
        }
        .buttonStyle(MenuLinkStyle())
        .simultaneousGesture(TapGesture().onEnded {
          // 确保应用激活，并在稍微延迟后关闭菜单，给 SettingsLink 响应时间
          NSApp.activate(ignoringOtherApps: true)
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            dismiss()
          }
        })
      } else {
        menuItem(title: "menu.settings", icon: "gearshape", shortcut: "⌘,") {
          onSettings()
          dismiss()
        }
      }
      
      // 关于
      menuItem(title: "menu.about", icon: "info.circle") {
        onAbout()
        dismiss()
      }
      
      Divider()
        .padding(.vertical, 4)
      
      // 退出（最后一项）
      menuItem(title: "menu.quit", icon: "power", shortcut: "⌘Q") {
        onQuit()
      }
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 4)
    .frame(width: 200)
    .background(VisualEffectView(material: .menu))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color(hex: "#FFFFFF").opacity(0.1), lineWidth: 1)
    )
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
  
  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 14))
        .foregroundColor(Color(hex: "#FFFFFF").opacity(0.8))
        .frame(width: 20)
      
      Text(title)
        .font(.system(size: 13))
        .foregroundColor(Color(hex: "#FFFFFF"))
      
      Spacer()
      
      if let shortcut = shortcut {
        Text(shortcut)
          .font(.system(size: 12))
          .foregroundColor(Color(hex: "#FFFFFF").opacity(0.5))
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .contentShape(Rectangle())
  }
}

/// 自定义 ButtonStyle 用于处理 SettingsLink 的样式和 Hover 状态
private struct MenuLinkStyle: ButtonStyle {
  @State private var isHovered = false
  
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background(isHovered ? Color(hex: "#FFFFFF").opacity(0.1) : Color.clear)
      .cornerRadius(4)
      .onHover { hovering in
        isHovered = hovering
      }
  }
}

/// 带 hover 高亮效果的菜单项按钮
private struct MenuItemButton: View {
  let title: LocalizedStringKey
  let icon: String
  var shortcut: String? = nil
  let action: () -> Void
  
  @State private var isHovered = false
  
  var body: some View {
    Button(action: action) {
      MenuItemContent(title: title, icon: icon, shortcut: shortcut)
    }
    .buttonStyle(.plain)
    .background(isHovered ? Color(hex: "#FFFFFF").opacity(0.1) : Color.clear)
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
