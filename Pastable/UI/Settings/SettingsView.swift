import SwiftUI

struct SettingsView: View {
  @ObservedObject private var appState = AppState.shared

  var body: some View {
    TabView(selection: $appState.settingsTab) {
      GeneralSettingsView()
        .tabItem {
          Label("settings.general.title", systemImage: "gear")
        }
        .tag(AppState.SettingsTab.general)
      
      StorageSettingsView()
        .tabItem {
          Label("settings.storage.title", systemImage: "externaldrive")
        }
        .tag(AppState.SettingsTab.storage)
      
      ShortcutsSettingsView()
        .tabItem {
          Label("settings.shortcuts.title", systemImage: "command")
        }
        .tag(AppState.SettingsTab.shortcuts)
      


      AboutSettingsView()
        .tabItem {
          Label("settings.about.title", systemImage: "info.circle")
        }
        .tag(AppState.SettingsTab.about)
    }
    .frame(width: 450, height: 300)
    .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
    .background(WindowAccessor { window in
      window.level = .modalPanel
      window.center() // 也让它居中显示
    })
  }
}

/// 用于访问底层 NSWindow 的辅助视图
struct WindowAccessor: NSViewRepresentable {
  let callback: (NSWindow) -> Void
  
  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.async {
      if let window = view.window {
        self.callback(window)
      }
    }
    return view
  }
  
  func updateNSView(_ nsView: NSView, context: Context) {}
}

#Preview {
  SettingsView()
}
