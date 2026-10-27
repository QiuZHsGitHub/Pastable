import SwiftUI

struct StorageSettingsView: View {
  @AppStorage(Preferences.Key.historySize) private var historySize = 200
  @AppStorage(Preferences.Key.saveFiles) private var saveFiles = true
  @AppStorage(Preferences.Key.saveImages) private var saveImages = true
  @AppStorage(Preferences.Key.saveText) private var saveText = true
  @AppStorage(Preferences.Key.historyRetentionDuration) private var historyRetentionDuration = 0
  @AppStorage(Preferences.Key.iCloudSyncEnabled) private var iCloudSyncEnabled = false

  @ObservedObject private var cloudMonitor = CloudSyncMonitor.shared
  @State private var itemCount = 0
  @State private var storageSize = ""
  @State private var showClearConfirmation = false
  @State private var cleanupStatus: String?
  @State private var cleanupStatusToken = 0
  @State private var pendingSyncValue: Bool?
  @State private var showSyncRestartAlert = false

  private let retentionOptions: [(title: LocalizedStringKey, value: Int)] = [
    ("24 hours", 86_400),
    ("7 days", 604_800),
    ("1 month", 2_592_000),
    ("3 months", 7_776_000),
    ("6 months", 15_552_000),
    ("1 year", 31_536_000),
    ("Unlimited", 0)
  ]

  var body: some View {
    Form {
      Section(header: Text("settings.storage.types").font(.subheadline)) {
        Toggle("settings.storage.save_text", isOn: $saveText)
        Toggle("settings.storage.save_images", isOn: $saveImages)
        Toggle("settings.storage.save_files", isOn: $saveFiles)
      }

      Section(header: Text("settings.storage.icloud").font(.subheadline)) {
        Toggle("settings.storage.icloud_sync", isOn: iCloudSyncBinding)

        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Image(systemName: syncStatus.symbol)
            .foregroundStyle(syncStatus.color)
          Text(syncStatus.text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)

        if let error = syncErrorMessage {
          Text(error)
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
        }

        Text("settings.storage.icloud.footer")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section(header: Text("settings.storage.capacity").font(.subheadline)) {
        Picker("settings.storage.history_count", selection: $historySize) {
          ForEach([50, 100, 200, 500, 1000], id: \.self) { size in
            Text("\(size)").tag(size)
          }
        }

        Picker("settings.storage.retention", selection: $historyRetentionDuration) {
          ForEach(retentionOptions, id: \.value) { option in
            Text(option.title).tag(option.value)
          }
        }

        HStack {
          Text("settings.storage.items")
          Spacer()
          Text("\(itemCount)")
            .foregroundStyle(.secondary)
        }

        if !storageSize.isEmpty {
          HStack {
            Text("settings.storage.database_size")
            Spacer()
            Text(storageSize)
              .foregroundStyle(.secondary)
          }
        }

        Button("settings.storage.cleanup_now") {
          let removed = Storage.shared.performCleanupNow()
          refreshStats()
          cleanupStatus = removed > 0
            ? String(
              format: NSLocalizedString("settings.storage.cleanup_removed", comment: "Cleanup removed N items"),
              removed
            )
            : NSLocalizedString("settings.storage.cleanup_nothing", comment: "Nothing to clean up")
          scheduleCleanupStatusReset()
        }

        if let cleanupStatus {
          Text(cleanupStatus)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      Section {
        Button(role: .destructive) {
          showClearConfirmation = true
        } label: {
          Text("settings.storage.clear_all")
        }
      }
    }
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)
    .padding()
    .onAppear(perform: refreshStats)
    .task {
      await cloudMonitor.refresh()
    }
    .onChange(of: historySize) { _, newValue in
      Storage.shared.resumeAutomaticMaintenance()
      Storage.shared.trimHistory(limit: newValue)
      refreshStats()
    }
    .onChange(of: historyRetentionDuration) { _, newValue in
      Storage.shared.resumeAutomaticMaintenance()
      Storage.shared.cleanup(retentionDuration: newValue)
      refreshStats()
    }
    .confirmationDialog(
      "clear_history.title",
      isPresented: $showClearConfirmation,
      titleVisibility: .visible
    ) {
      Button("clear_history.confirm", role: .destructive) {
        Storage.shared.clearAll()
        AppState.shared.resetSelection()
        refreshStats()
      }
      Button("common.cancel", role: .cancel) {}
    } message: {
      Text("clear_history.message")
    }
    .alert(syncAlertTitle, isPresented: $showSyncRestartAlert) {
      Button("settings.storage.icloud.restart_now") {
        if let pendingSyncValue {
          iCloudSyncEnabled = pendingSyncValue
        }
        pendingSyncValue = nil
        AppRelauncher.relaunch()
      }
      Button("settings.storage.icloud.restart_later") {
        if let pendingSyncValue {
          iCloudSyncEnabled = pendingSyncValue
        }
        pendingSyncValue = nil
      }
      Button("common.cancel", role: .cancel) {
        pendingSyncValue = nil
      }
    } message: {
      Text(syncAlertMessage)
    }
  }

  // MARK: - iCloud

  /// The toggle intentionally does not write `@AppStorage` directly: the user
  /// must confirm that clipboard data will be uploaded before it takes effect.
  private var iCloudSyncBinding: Binding<Bool> {
    Binding(
      get: { iCloudSyncEnabled },
      set: { newValue in
        guard newValue != iCloudSyncEnabled else { return }
        pendingSyncValue = newValue
        showSyncRestartAlert = true
      }
    )
  }

  private var syncAlertTitle: LocalizedStringKey {
    (pendingSyncValue ?? iCloudSyncEnabled)
      ? "settings.storage.icloud.enable_title"
      : "settings.storage.icloud.disable_title"
  }

  private var syncAlertMessage: LocalizedStringKey {
    (pendingSyncValue ?? iCloudSyncEnabled)
      ? "settings.storage.icloud.enable_message"
      : "settings.storage.icloud.disable_message"
  }

  private var syncErrorMessage: String? {
    guard iCloudSyncEnabled,
          iCloudSyncEnabled == Storage.shared.iCloudSyncRequested else {
      return nil
    }
    guard Storage.shared.isCloudSyncActive else {
      return Storage.shared.cloudSyncError
    }
    if case .unavailable = cloudMonitor.state {
      return cloudMonitor.lastError
    }
    return nil
  }

  private var syncStatus: (symbol: String, color: Color, text: LocalizedStringKey) {
    if iCloudSyncEnabled != Storage.shared.iCloudSyncRequested {
      return (
        "arrow.clockwise.circle",
        .orange,
        "settings.storage.icloud.restart_pending"
      )
    }

    guard iCloudSyncEnabled else {
      return ("icloud.slash", .secondary, "settings.storage.icloud.local_only")
    }

    guard Storage.shared.isCloudSyncActive else {
      return (
        "exclamationmark.icloud",
        .orange,
        "settings.storage.icloud.start_failed"
      )
    }

    switch cloudMonitor.state {
    case .checking:
      return ("icloud", .secondary, "settings.storage.icloud.checking")
    case .available:
      return ("checkmark.icloud", .green, "settings.storage.icloud.connected")
    case .noAccount:
      return ("person.crop.circle.badge.exclamationmark", .orange, "settings.storage.icloud.no_account")
    case .restricted:
      return ("lock.icloud", .orange, "settings.storage.icloud.restricted")
    case .unavailable:
      return ("exclamationmark.icloud", .orange, "settings.storage.icloud.start_failed")
    }
  }

  private func refreshStats() {
    itemCount = Storage.shared.itemCount()
    storageSize = Storage.shared.size
  }

  /// Auto-hide the cleanup result after a few seconds so the row does not
  /// linger until the next click.
  private func scheduleCleanupStatusReset() {
    cleanupStatusToken += 1
    let token = cleanupStatusToken
    Task { @MainActor in
      try? await Task.sleep(nanoseconds: 5_000_000_000)
      if cleanupStatusToken == token {
        cleanupStatus = nil
      }
    }
  }
}

#Preview {
  StorageSettingsView()
}
