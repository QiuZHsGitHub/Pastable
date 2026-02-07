import SwiftUI

struct SettingsView: View {
  var body: some View {
    TabView {
      GeneralSettingsView()
        .tabItem {
          Label("settings.general.title", systemImage: "gear")
        }
      
      StorageSettingsView()
        .tabItem {
          Label("settings.storage.title", systemImage: "externaldrive")
        }
      
      ShortcutsSettingsView()
        .tabItem {
          Label("settings.shortcuts.title", systemImage: "command")
        }
      


      AboutSettingsView()
        .tabItem {
          Label("settings.about.title", systemImage: "info.circle")
        }
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
