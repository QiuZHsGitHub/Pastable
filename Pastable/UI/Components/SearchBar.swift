import SwiftUI

struct SearchBar: View {
  @Binding var text: String
  var hasHistory: Bool = false
  var onClearHistory: (() -> Void)?
  
  @State private var showMoreMenu = false
  @FocusState private var isTextFieldFocused: Bool
  
  var body: some View {
    HStack(spacing: 0) { // 主容器
      // 1. 搜索图标
      Image(systemName: "magnifyingglass")
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(isTextFieldFocused ? .white : .white.opacity(0.5))
        .frame(width: 32)
        .contentShape(Rectangle())
        .onTapGesture {
          isTextFieldFocused = true
        }
      
      // 2. 文本输入框
      TextField("search.placeholder", text: $text)
        .textFieldStyle(.plain)
        .font(.system(size: 13)) //稍微调小字体以显得更精致
        .foregroundColor(.white)
        .focused($isTextFieldFocused)
      
      // 3. 清除按钮 (仅在有文本时显示)
      if !text.isEmpty {
        Button(action: { text = "" }) {
          Image(systemName: "xmark.circle.fill")
            .foregroundColor(.white.opacity(0.5))
            .font(.system(size: 14))
        }
        .buttonStyle(.plain)
        .padding(.trailing, 8)
        .transition(.opacity)
      }

      // 4. 分隔线
      Rectangle()
        .fill(Color.white.opacity(0.15))
        .frame(width: 1, height: 16)
        .padding(.horizontal, 4)
      
      // 5. 更多按钮
      Button(action: {
        showMoreMenu.toggle()
      }) {
        Image(systemName: "ellipsis")
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(showMoreMenu ? .white : .white.opacity(0.6)) // 菜单打开时高亮
          .frame(width: 32, height: 32)
          .contentShape(Rectangle()) // 增大点击区域
      }
      .buttonStyle(.plain)
      .popover(isPresented: $showMoreMenu, arrowEdge: .top) {
        MoreMenuView(
          onClearHistory: hasHistory ? onClearHistory : nil,
          onSettings: {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
          },
          onAbout: {
            AppState.shared.settingsTab = .about
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
          },
          onQuit: {
            NSApp.terminate(nil)
          }
        )
      }
    }
    .frame(height: 32)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(Color.white.opacity(isTextFieldFocused ? 0.15 : 0.08)) // 动态背景
    )
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.white.opacity(isTextFieldFocused ? 0.3 : 0.1), lineWidth: 1) // 细微边框
    )
    .animation(.easeInOut(duration: 0.2), value: isTextFieldFocused) // 平滑过渡
    .onChange(of: AppState.shared.searchFocusRequest) { request in
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
}

#Preview("搜索栏") {
    SearchBar(text: .constant(""), hasHistory: true, onClearHistory: {
        print("清除历史")
    })
    .frame(width: 600)
    .padding()
    .background(Color.pastableBackground)
}
