import SwiftUI

@main
struct PastableApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  
  var body: some Scene {
    Settings {
      SettingsView()
        .modelContainer(Storage.shared.container)
        .preferredColorScheme(.dark)
    }
  }
}
