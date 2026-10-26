import SwiftUI
import AppKit
import ApplicationServices

struct GeneralSettingsView: View {
  @AppStorage(Preferences.Key.pasteAutomatically) private var pasteAutomatically = true
  @AppStorage(Preferences.Key.removeFormatting) private var removeFormatting = false
  @AppStorage(Preferences.Key.playSounds) private var playSounds = true
  @AppStorage(Preferences.Key.searchMode) private var searchMode: SearchService.SearchMode = .fuzzy
  @State private var launchAtLogin = LaunchAtLogin.isEnabled
  @State private var accessibilityTrusted = AXIsProcessTrusted()
  @State private var errorMessage = ""
  @State private var showError = false

  var body: some View {
    Form {
      Section {
        Toggle("settings.general.launch_at_login", isOn: launchAtLoginBinding)
      }

      Section(header: Text("settings.general.behavior").font(.subheadline)) {
        Picker("settings.general.search_mode", selection: $searchMode) {
          Text("settings.general.search_mode.exact").tag(SearchService.SearchMode.exact)
          Text("settings.general.search_mode.fuzzy").tag(SearchService.SearchMode.fuzzy)
        }
        .pickerStyle(.menu)

        Toggle("settings.general.auto_paste", isOn: $pasteAutomatically)
        Toggle("settings.general.remove_formatting", isOn: $removeFormatting)
        Toggle("settings.general.play_sounds", isOn: $playSounds)
      }

      Section(header: Text("settings.general.permissions").font(.subheadline)) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: accessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .foregroundStyle(accessibilityTrusted ? .green : .orange)
            .font(.system(size: 14))

          VStack(alignment: .leading, spacing: 3) {
            Text(accessibilityTrusted
                 ? "settings.general.accessibility.granted"
                 : "settings.general.accessibility.required")
            if !accessibilityTrusted {
              Text("settings.general.accessibility.hint")
                .font(.caption)
                .foregroundStyle(.secondary)
              Text("settings.general.accessibility.restart_hint")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }

          Spacer()

          if !accessibilityTrusted {
            Button("settings.general.accessibility.recheck") {
              accessibilityTrusted = AXIsProcessTrusted()
            }
            Button("accessibility.open_settings") {
              openAccessibilitySettings()
            }
          }
        }
      }
    }
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)
    .padding()
    .onAppear {
      launchAtLogin = LaunchAtLogin.isEnabled
      accessibilityTrusted = AXIsProcessTrusted()
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
      launchAtLogin = LaunchAtLogin.isEnabled
      accessibilityTrusted = AXIsProcessTrusted()
    }
    .onChange(of: searchMode) { _, _ in
      AppState.shared.refreshSearch()
    }
    .alert("settings.general.login_item_error", isPresented: $showError) {
      Button("common.ok", role: .cancel) {}
    } message: {
      Text(errorMessage)
    }
  }

  private var launchAtLoginBinding: Binding<Bool> {
    Binding(
      get: { launchAtLogin },
      set: { newValue in
        do {
          try LaunchAtLogin.setEnabled(newValue)
          launchAtLogin = LaunchAtLogin.isEnabled

          if newValue && LaunchAtLogin.requiresApproval {
            errorMessage = NSLocalizedString(
              "settings.general.launch_at_login_approval",
              comment: "Login item requires approval in System Settings"
            )
            showError = true
          }
        } catch {
          launchAtLogin = LaunchAtLogin.isEnabled
          errorMessage = error.localizedDescription
          showError = true
        }
      }
    )
  }

  private func openAccessibilitySettings() {
    // Ask macOS to register this exact binary in the Accessibility list.
    // Opening only the pane can leave the user looking at an older Pastable
    // entry (especially with ad-hoc Debug builds).
    let options = [
      kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
    ] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)

    guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
      return
    }
    NSWorkspace.shared.open(url)
  }
}

#Preview {
  GeneralSettingsView()
}
