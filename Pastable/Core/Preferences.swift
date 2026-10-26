import Foundation

/// Single source of truth for every preference that changes runtime behaviour.
///
/// The Settings UI uses `@AppStorage` with the same keys, so reading the values here
/// keeps the UI and the capture/paste pipeline in sync. `registerDefaults()` is called
/// early in the launch sequence so a missing value never silently becomes `false`.
enum Preferences {
  enum Key {
    static let saveText = "saveText"
    static let saveImages = "saveImages"
    static let saveFiles = "saveFiles"
    static let pasteAutomatically = "pasteAutomatically"
    static let removeFormatting = "removeFormatting"
    static let playSounds = "playSounds"
    static let historySize = "historySize"
    static let historyRetentionDuration = "historyRetentionDuration"
    static let searchMode = "searchMode"
    static let maintenanceSnoozeUntil = "maintenanceSnoozeUntil"
    static let iCloudSyncEnabled = "iCloudSyncEnabled"
  }

  private static var defaults: UserDefaults { .standard }

  static let defaultHistorySize = 200

  static func registerDefaults() {
    defaults.register(defaults: [
      Key.saveText: true,
      Key.saveImages: true,
      Key.saveFiles: true,
      Key.pasteAutomatically: true,
      Key.removeFormatting: false,
      Key.playSounds: true,
      Key.historySize: defaultHistorySize,
      Key.historyRetentionDuration: 0,
      Key.searchMode: "fuzzy",
      Key.iCloudSyncEnabled: false
    ])
  }

  private static func bool(_ key: String, fallback: Bool) -> Bool {
    defaults.object(forKey: key) as? Bool ?? fallback
  }

  static var saveText: Bool { bool(Key.saveText, fallback: true) }
  static var saveImages: Bool { bool(Key.saveImages, fallback: true) }
  static var saveFiles: Bool { bool(Key.saveFiles, fallback: true) }
  static var pasteAutomatically: Bool { bool(Key.pasteAutomatically, fallback: true) }
  static var removeFormatting: Bool { bool(Key.removeFormatting, fallback: false) }
  static var playSounds: Bool { bool(Key.playSounds, fallback: true) }
  static var iCloudSyncEnabled: Bool {
    #if DEBUG
    if let override = ProcessInfo.processInfo.environment["PASTABLE_ICLOUD_SYNC"] {
      return override == "1" || override.lowercased() == "true"
    }
    #endif
    return bool(Key.iCloudSyncEnabled, fallback: false)
  }

  /// 0 / negative values mean "unlimited"; never return a negative limit.
  static var historyLimit: Int {
    let value = defaults.integer(forKey: Key.historySize)
    return value > 0 ? value : defaultHistorySize
  }

  /// Retention in seconds. `0` means unlimited.
  static var retentionDuration: Int {
    max(0, defaults.integer(forKey: Key.historyRetentionDuration))
  }
}
