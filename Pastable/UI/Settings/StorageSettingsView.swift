import SwiftUI

struct StorageSettingsView: View {
  @AppStorage(Preferences.Key.historySize) private var historySize = 200
  @AppStorage(Preferences.Key.saveFiles) private var saveFiles = true
  @AppStorage(Preferences.Key.saveImages) private var saveImages = true
  @AppStorage(Preferences.Key.saveText) private var saveText = true
  @AppStorage(Preferences.Key.historyRetentionDuration) private var historyRetentionDuration = 0

  @State private var itemCount = 0
  @State private var storageSize = ""
  @State private var showClearConfirmation = false

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
          Storage.shared.resumeAutomaticMaintenance()
          Storage.shared.cleanup()
          Storage.shared.trimHistory()
          refreshStats()
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
  }

  private func refreshStats() {
    itemCount = Storage.shared.itemCount()
    storageSize = Storage.shared.size
  }
}

#Preview {
  StorageSettingsView()
}
