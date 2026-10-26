import SwiftUI

struct SearchBar: View {
  @Binding var text: String
  var hasHistory: Bool = false
  var onClearHistory: (() -> Void)?
  @Environment(\.openSettings) private var openSettings
  @Environment(\.colorScheme) private var colorScheme
  private var theme: AppTheme { AppTheme.theme(for: colorScheme) }
  
  @State private var showMoreMenu = false
  @FocusState private var isTextFieldFocused: Bool
  
  var body: some View {
    HStack(spacing: 0) { // 主容器
      // 1. 搜索图标
      Image("icon_search")
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .frame(width: 14, height: 14)
        .foregroundColor(isTextFieldFocused ? theme.textPrimary : theme.textTertiary)
        .frame(width: 34, height: 34)
        .contentShape(Rectangle())
        .onTapGesture {
          isTextFieldFocused = true
        }
      
      // 2. 文本输入框
      TextField(
        "",
        text: $text,
        prompt: Text("search.placeholder")
          .foregroundColor(theme.textPlaceholder)
      )
      .textFieldStyle(.plain)
      .font(.system(size: 13))
      .foregroundColor(theme.textPrimary)
      .tint(theme.accent)
      .focused($isTextFieldFocused)
      
      // 3. 清除按钮 (仅在有文本时显示)
      if !text.isEmpty {
        Button(action: { text = "" }) {
          Image(systemName: "xmark.circle.fill")
            .foregroundColor(theme.textTertiary)
            .font(.system(size: 14))
        }
        .buttonStyle(.plain)
        .padding(.trailing, 8)
        .transition(.opacity)
      }

      // 4. 空闲时显示快捷键提示
      if text.isEmpty {
        Text("⌘⇧F")
          .font(.system(size: 10, weight: .medium, design: .monospaced))
          .foregroundColor(theme.textTertiary)
          .padding(.trailing, 8)
      }

      // 5. 分隔线
      Rectangle()
        .fill(theme.searchDivider)
        .frame(width: 1, height: 18)
        .padding(.horizontal, 4)
      
      // 6. 更多按钮
      Button(action: {
        showMoreMenu.toggle()
      }) {
        Image(systemName: "ellipsis")
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(showMoreMenu ? theme.textPrimary : theme.textSecondary)
          .frame(width: 32, height: 32)
          .contentShape(Rectangle()) // 增大点击区域
      }
      .buttonStyle(.plain)
      .popover(isPresented: $showMoreMenu, arrowEdge: .top) {
        MoreMenuView(
          onClearHistory: hasHistory ? onClearHistory : nil,
          onSettings: {
            openSettingsWindow(targetTab: nil)
          },
          onAbout: {
            openSettingsWindow(targetTab: .about)
          },
          onQuit: {
            NSApp.terminate(nil)
          }
        )
      }
    }
    // Match the Figma spacing: the trailing ⋯ sits 6px inside the rounded field
    // instead of touching its right edge.
    .padding(.trailing, 10)
    .frame(height: 36)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(theme.searchBackground)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .strokeBorder(
          isTextFieldFocused
            ? theme.accent
            : theme.searchBorder,
          lineWidth: 1
        )
    )
    .shadow(
      color: isTextFieldFocused ? theme.accent.opacity(0.12) : .clear,
      radius: 8
    )
    .animation(.easeOut(duration: 0.16), value: isTextFieldFocused)
    .onAppear {
      if AppState.shared.isPanelVisible {
        isTextFieldFocused = true
      }
    }
    .onChange(of: AppState.shared.searchFocusRequest) { _, request in
      if request == .focus {
        isTextFieldFocused = true
        // Reset signal
        DispatchQueue.main.async {
          AppState.shared.searchFocusRequest = .none
        }
      } else if request == .blur {
        isTextFieldFocused = false
        // Reset signal
        DispatchQueue.main.async {
          AppState.shared.searchFocusRequest = .none
        }
      }
    }
  }

  private func openSettingsWindow(targetTab: AppState.SettingsTab?) {
    // Close the panel first so it does not float above the Settings window.
    // The hosting view stays alive, so the captured `openSettings` action is
    // still valid after `orderOut`.
    AppState.shared.appDelegate?.closePanel(restorePrevious: true)
    NSApp.activate(ignoringOtherApps: true)

    DispatchQueue.main.async {
      if let targetTab {
        AppState.shared.settingsTab = targetTab
      }
      openSettings()
    }
  }
}

#Preview("搜索栏") {
    SearchBar(text: .constant(""), hasHistory: true, onClearHistory: {
        print("清除历史")
    })
    .frame(width: 600)
    .padding()
    .background(Color.pastableBackground)
}
