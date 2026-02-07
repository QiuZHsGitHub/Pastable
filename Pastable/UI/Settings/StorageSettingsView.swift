import SwiftUI
import SwiftData

struct StorageSettingsView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var items: [HistoryItem]
  
  @AppStorage("historySize") private var historySize = 200
  @AppStorage("saveFiles") private var saveFiles = false
  @AppStorage("saveImages") private var saveImages = true
  @AppStorage("saveText") private var saveText = true
  @AppStorage("historyRetentionDuration") private var historyRetentionDuration = 0 // 0 = Unlimited
  
  private let retentionOptions: [(title: LocalizedStringKey, value: Int)] = [
    ("24 hours", 86400),
    ("7 days", 604800),
    ("1 month", 2592000),
    ("3 months", 7776000),
    ("6 months", 15552000),
    ("1 year", 31536000),
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
      }
      
      Section {
        Button(role: .destructive, action: {
          clearHistory()
        }) {
          Text("settings.storage.clear_all")
        }
      }
    }
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)
    .padding()
  }
  
  private func clearHistory() {
    for item in items {
      modelContext.delete(item)
    }
    // 可选：调用 AppState 或 Storage 刷新
  }
}

#Preview {
  StorageSettingsView()
}
