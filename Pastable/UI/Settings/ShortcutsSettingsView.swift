import SwiftUI
import KeyboardShortcuts

struct ShortcutsSettingsView: View {
  var body: some View {
    Form {
      Section(header: Text("settings.general.shortcuts").font(.subheadline)) {
        HStack {
          Text("settings.general.popup_window")
          Spacer()
          KeyboardShortcuts.Recorder(for: .togglePanel)
        }
      }
    }
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)
    .padding()
  }
}

#Preview {
  ShortcutsSettingsView()
}
