import Foundation
import SwiftData

@MainActor
final class Storage {
  static let shared = Storage()

  /// The CloudKit container declared in `Pastable.entitlements`.
  static let iCloudContainerIdentifier = "iCloud.com.qzh.Pastable"

  var container: ModelContainer
  var context: ModelContext { container.mainContext }

  /// Location of the SQLite store, or `nil` when running in memory.
  private(set) var url: URL?

  /// Whether the user asked for iCloud sync for this launch.
  private(set) var iCloudSyncRequested: Bool
  /// Whether the container was actually opened with a CloudKit database.
  private(set) var isCloudSyncActive = false
  /// Populated when CloudKit could not be opened; the app then falls back to the
  /// local store so clipboard capture keeps working.
  private(set) var cloudSyncError: String?

  private let fileManager = FileManager.default
  private var capturesSinceMaintenance = 0
  private let maintenanceInterval = 25
  /// Safety valve so a broken predicate can never spin forever.
  private let maxMaintenanceBatchCount = 10_000

  /// Automatic trimming is paused when an existing store exceeds the configured
  /// limits. Deleting hundreds of legacy items without consent would be hostile;
  /// the launch prompt lets the user decide first.
  private(set) var isAutomaticMaintenanceEnabled = true

  static var defaultStorageURL: URL {
    let base: URL
    if let override = ProcessInfo.processInfo.environment["PASTABLE_STORAGE_DIR"],
       !override.isEmpty {
      base = URL(fileURLWithPath: override, isDirectory: true)
    } else {
      base = URL.applicationSupportDirectory.appending(path: "Pastable", directoryHint: .isDirectory)
    }
    return base.appending(path: "Storage.sqlite")
  }

  init(inMemory: Bool = false, url: URL? = nil, cloudSyncEnabled: Bool? = nil) {
    let requested = cloudSyncEnabled ?? Preferences.iCloudSyncEnabled
    self.iCloudSyncRequested = requested

    if inMemory {
      self.url = nil
      self.isCloudSyncActive = false
      self.container = try! Self.makeContainer(
        url: nil,
        inMemory: true,
        cloudSync: false
      )
      return
    }

    let resolvedURL = url ?? Self.defaultStorageURL
    self.url = resolvedURL

    try? FileManager.default.createDirectory(
      at: resolvedURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )

    // CloudKit is opt-in. Existing local records are adopted by the CloudKit
    // store when it opens, so enabling sync does not require a separate import.
    if requested {
      if CloudEntitlements.isCloudKitAvailable {
        do {
          self.container = try Self.makeContainer(
            url: resolvedURL,
            inMemory: false,
            cloudSync: true
          )
          self.isCloudSyncActive = true
          AppLogger.Storage.info("Opened SwiftData store with CloudKit sync")
          return
        } catch {
          let message = error.localizedDescription
          self.cloudSyncError = message
          AppLogger.Storage.error(
            "Cannot open iCloud store, falling back to local storage",
            error: error
          )
        }
      } else {
        // Asking SwiftData for a CloudKit-backed store without the restricted
        // iCloud entitlement does not fail cleanly — it aborts the process — so
        // this build opens the local store and reports why in Settings.
        self.cloudSyncError = NSLocalizedString(
          "settings.storage.icloud.unavailable_direct",
          comment: "iCloud sync is unavailable in the certificate-free build"
        )
        AppLogger.Storage.info(
          "iCloud sync requested but this build carries no iCloud entitlement; using local storage"
        )
      }
    }

    do {
      self.container = try Self.makeContainer(
        url: resolvedURL,
        inMemory: false,
        cloudSync: false
      )
    } catch {
      AppLogger.Storage.error("Cannot open database, moving it aside", error: error)
      Self.moveStoreAside(resolvedURL)

      do {
        self.container = try Self.makeContainer(
          url: resolvedURL,
          inMemory: false,
          cloudSync: false
        )
      } catch {
        AppLogger.Storage.error("Cannot recreate database, using in-memory store", error: error)
        self.url = nil
        self.container = try! Self.makeContainer(
          url: nil,
          inMemory: true,
          cloudSync: false
        )
      }
    }
  }

  private static func makeContainer(
    url: URL?,
    inMemory: Bool,
    cloudSync: Bool
  ) throws -> ModelContainer {
    let configuration: ModelConfiguration
    if inMemory {
      configuration = ModelConfiguration(
        isStoredInMemoryOnly: true,
        cloudKitDatabase: .none
      )
    } else {
      configuration = ModelConfiguration(
        url: url!,
        cloudKitDatabase: cloudSync
          ? .private(iCloudContainerIdentifier)
          : .none
      )
    }

    return try ModelContainer(
      for: HistoryItem.self,
      configurations: configuration
    )
  }

  /// Keep a corrupt store for debugging instead of silently deleting user data.
  private static func moveStoreAside(_ url: URL) {
    let fileManager = FileManager.default
    let stamp = Int(Date().timeIntervalSince1970)
    for suffix in ["", "-wal", "-shm"] {
      let source = URL(fileURLWithPath: url.path + suffix)
      guard fileManager.fileExists(atPath: source.path) else { continue }
      let destination = URL(fileURLWithPath: url.path + ".corrupt-\(stamp)" + suffix)
      try? fileManager.moveItem(at: source, to: destination)
    }
  }

  /// Human readable size of the store, including its WAL/SHM side files and the
  /// external blobs SwiftData keeps in `.Storage_SUPPORT`.
  var size: String {
    guard let url else { return "" }

    var total: Int64 = 0
    for suffix in ["", "-wal", "-shm"] {
      let path = url.path + suffix
      guard let attributes = try? fileManager.attributesOfItem(atPath: path),
            let bytes = attributes[.size] as? NSNumber else { continue }
      total += bytes.int64Value
    }

    let supportDirectory = url.deletingLastPathComponent()
      .appendingPathComponent(".Storage_SUPPORT", isDirectory: true)
    if let enumerator = fileManager.enumerator(
      at: supportDirectory,
      includingPropertiesForKeys: [.fileSizeKey],
      options: []
    ) {
      for case let fileURL as URL in enumerator {
        guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
              let fileSize = values.fileSize else { continue }
        total += Int64(fileSize)
      }
    }

    guard total > 0 else { return "" }
    return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
  }

  func itemCount() -> Int {
    (try? context.fetchCount(FetchDescriptor<HistoryItem>())) ?? 0
  }

  // MARK: - iCloud reconciliation

  /// Two devices can copy the same content independently and upload two records
  /// for the same hash. CloudKit has no unique constraints, so collapse those
  /// remote duplicates locally the next time the app reconciles.
  ///
  /// This only reads scalar columns (not the pasteboard blobs) and is therefore
  /// cheap enough to run at launch and whenever the panel opens.
  @discardableResult
  func deduplicateHistory(force: Bool = false) -> Int {
    guard force || isCloudSyncActive else { return 0 }

    let items: [HistoryItem]
    do {
      items = try context.fetch(
        FetchDescriptor<HistoryItem>(
          sortBy: [SortDescriptor(\.lastCopiedAt, order: .reverse)]
        )
      )
    } catch {
      AppLogger.Storage.error("Failed to load history for iCloud reconciliation", error: error)
      return 0
    }

    var keepers: [String: HistoryItem] = [:]
    var duplicates: [HistoryItem] = []

    for item in items {
      guard let hash = item.contentHash, !hash.isEmpty else { continue }
      if let keeper = keepers[hash] {
        mergeForCloud(keeper: keeper, duplicate: item)
        duplicates.append(item)
      } else {
        keepers[hash] = item
      }
    }

    guard !duplicates.isEmpty else { return 0 }
    for item in duplicates {
      context.delete(item)
    }

    do {
      try context.save()
      AppLogger.Storage.info("Merged \(duplicates.count) duplicate item(s) after iCloud sync")
      return duplicates.count
    } catch {
      AppLogger.Storage.error("Failed to merge iCloud duplicates", error: error)
      context.rollback()
      return 0
    }
  }

  private func mergeForCloud(keeper: HistoryItem, duplicate: HistoryItem) {
    let keeperWasNewer = keeper.lastCopiedAt >= duplicate.lastCopiedAt
    keeper.firstCopiedAt = min(keeper.firstCopiedAt, duplicate.firstCopiedAt)
    keeper.lastCopiedAt = max(keeper.lastCopiedAt, duplicate.lastCopiedAt)
    keeper.numberOfCopies += duplicate.numberOfCopies
    if keeper.pin == nil {
      keeper.pin = duplicate.pin
    }
    if !keeperWasNewer {
      keeper.application = duplicate.application
    }
  }

  struct MaintenancePreview {
    let total: Int
    let limit: Int
    let expired: Int
    let retentionDuration: Int
    let size: String

    var overLimit: Int { max(0, total - limit) }
    var needsAttention: Bool { overLimit > 0 || expired > 0 }
    var suggestedLimit: Int { max(1_000, ((total / 500) + 1) * 500) }
  }

  /// Cheap summary (counts only, no blob loading) used by the launch prompt.
  func maintenancePreview() -> MaintenancePreview {
    let total = itemCount()
    let limit = Preferences.historyLimit
    let retention = Preferences.retentionDuration

    var expired = 0
    if retention > 0 {
      let cutoffDate = Date().addingTimeInterval(-TimeInterval(retention))
      let descriptor = FetchDescriptor<HistoryItem>(
        predicate: #Predicate { $0.lastCopiedAt < cutoffDate && $0.pin == nil }
      )
      expired = (try? context.fetchCount(descriptor)) ?? 0
    }

    return MaintenancePreview(
      total: total,
      limit: limit,
      expired: expired,
      retentionDuration: retention,
      size: size
    )
  }

  func pauseAutomaticMaintenance() {
    isAutomaticMaintenanceEnabled = false
  }

  func resumeAutomaticMaintenance() {
    isAutomaticMaintenanceEnabled = true
  }

  // MARK: - Capture

  /// Insert a new item or update the existing item with the same content.
  ///
  /// The content hash is authoritative: it deliberately ignores formatting-only
  /// differences, so copying the same text first as plain text and later as rich
  /// text must collapse into one history entry. Legacy records without a hash are
  /// backfilled on the fly.
  @discardableResult
  func addOrUpdate(_ newItem: HistoryItem) -> Bool {
    do {
      if newItem.contentHash == nil || newItem.contentHash?.isEmpty == true {
        newItem.contentHash = HistoryItem.computeContentHash(contents: newItem.contentItems)
      }
      let hash = newItem.contentHash ?? ""

      if !hash.isEmpty {
        let descriptor = FetchDescriptor<HistoryItem>(
          predicate: #Predicate { $0.contentHash == hash },
          sortBy: [SortDescriptor(\.lastCopiedAt, order: .reverse)]
        )
        var matches = try context.fetch(descriptor)

        // Backfill missing hashes for recent items so a legacy record can still
        // be recognized as a duplicate.
        if matches.isEmpty {
          var missingDescriptor = FetchDescriptor<HistoryItem>(
            predicate: #Predicate { $0.contentHash == nil || $0.contentHash == "" },
            sortBy: [SortDescriptor(\.lastCopiedAt, order: .reverse)]
          )
          missingDescriptor.fetchLimit = 200
          let missing = try context.fetch(missingDescriptor)
          if !missing.isEmpty {
            for item in missing {
              item.contentHash = HistoryItem.computeContentHash(contents: item.contentItems)
            }
            matches = try context.fetch(descriptor)
          }
        }

        if let keeper = matches.first {
          merge(newItem, into: keeper, extraDuplicates: Array(matches.dropFirst()))
          try context.save()
          return false
        }
      } else {
        // Content without a usable hash: fall back to a recent-window comparison.
        var descriptor = FetchDescriptor<HistoryItem>(
          sortBy: [SortDescriptor(\.lastCopiedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 200
        let recent = try context.fetch(descriptor)
        if let existing = recent.first(where: { $0.supersedes(newItem) }) {
          merge(newItem, into: existing, extraDuplicates: [])
          try context.save()
          return false
        }
      }

      context.insert(newItem)
      try context.save()
      newItem.scheduleTextRecognitionIfNeeded()

      capturesSinceMaintenance += 1
      runFrequentMaintenance()
      return true
    } catch {
      AppLogger.Storage.error("Failed to add/update item", error: error)
      return false
    }
  }

  /// Merge a duplicate capture into the retained record. Using the hash as the
  /// dedupe key also lets us collapse legacy duplicates that share a hash.
  private func merge(_ newItem: HistoryItem, into keeper: HistoryItem, extraDuplicates: [HistoryItem]) {
    keeper.lastCopiedAt = max(keeper.lastCopiedAt, newItem.lastCopiedAt)
    keeper.firstCopiedAt = min(keeper.firstCopiedAt, newItem.firstCopiedAt)
    keeper.numberOfCopies += newItem.numberOfCopies
    keeper.application = newItem.application

    for duplicate in extraDuplicates {
      keeper.numberOfCopies += duplicate.numberOfCopies
      keeper.firstCopiedAt = min(keeper.firstCopiedAt, duplicate.firstCopiedAt)
      context.delete(duplicate)
    }
  }

  private func runFrequentMaintenance() {
    guard isAutomaticMaintenanceEnabled else { return }
    trimHistory()

    guard capturesSinceMaintenance >= maintenanceInterval else { return }
    capturesSinceMaintenance = 0
    let retention = Preferences.retentionDuration
    if retention > 0 {
      cleanup(retentionDuration: retention)
    }
  }

  // MARK: - Trimming / retention

  /// Fetch and delete one batch of matching records. Returns the number of
  /// removed records, `0` when nothing matched, or `nil` when saving failed
  /// (callers stop looping in that case).
  private func deleteOneBatch(
    _ predicate: Predicate<HistoryItem>?,
    fetchLimit: Int
  ) -> Int? {
    var descriptor = FetchDescriptor<HistoryItem>(
      predicate: predicate,
      sortBy: [SortDescriptor(\.lastCopiedAt, order: .forward)]
    )
    descriptor.fetchLimit = max(1, fetchLimit)

    guard let batch = try? context.fetch(descriptor), !batch.isEmpty else { return 0 }
    for item in batch {
      context.delete(item)
    }

    do {
      try context.save()
      return batch.count
    } catch {
      AppLogger.Storage.error("Failed to delete history batch", error: error)
      return nil
    }
  }

  /// Delete the oldest unpinned records until at most `limit` records remain.
  @discardableResult
  func trimHistory(limit: Int? = nil) -> Int {
    let effectiveLimit = max(1, limit ?? Preferences.historyLimit)
    var removed = 0

    while removed < maxMaintenanceBatchCount {
      guard let total = try? context.fetchCount(FetchDescriptor<HistoryItem>()),
            total > effectiveLimit else {
        break
      }
      guard let batch = deleteOneBatch(
        #Predicate { $0.pin == nil },
        fetchLimit: min(20, total - effectiveLimit)
      ), batch > 0 else {
        break
      }
      removed += batch
    }

    return removed
  }

  /// Delete unpinned records whose last use is older than the retention window.
  @discardableResult
  func cleanup(retentionDuration: Int? = nil) -> Int {
    let effectiveDuration = retentionDuration ?? Preferences.retentionDuration
    guard effectiveDuration > 0 else { return 0 }

    let cutoffDate = Date().addingTimeInterval(-TimeInterval(effectiveDuration))
    var removed = 0

    while removed < maxMaintenanceBatchCount {
      guard let batch = deleteOneBatch(
        #Predicate { $0.lastCopiedAt < cutoffDate && $0.pin == nil },
        fetchLimit: 20
      ), batch > 0 else {
        break
      }
      removed += batch
    }

    return removed
  }

  /// Manual "Clean Up Now" from Settings: run every cleanup pass immediately
  /// (blank legacy records, retention expiry, over-limit trimming) and return
  /// how many records were removed so the UI can report the result. Without
  /// the returned count the button looks dead when everything is already
  /// within the configured limits.
  @discardableResult
  func performCleanupNow() -> Int {
    resumeAutomaticMaintenance()
    let emptyRemoved = purgeEmptyItems()
    let retentionRemoved = cleanup()
    let trimmed = trimHistory()

    let total = emptyRemoved + retentionRemoved + trimmed
    if total > 0 {
      AppLogger.Storage.info("Manual cleanup removed \(total) items")
    }
    return total
  }

  /// Batched maintenance used at launch so an oversized legacy store does not
  /// block the first frame or spike memory by loading every image at once.
  func performMaintenance() async {
    if isCloudSyncActive {
      deduplicateHistory()
    }
    let emptyRemoved = purgeEmptyItems()
    let retentionRemoved = await purgeExpiredInBatches()
    let trimmed = await trimInBatches()
    if emptyRemoved + retentionRemoved + trimmed > 0 {
      AppLogger.Storage.info("Maintenance removed \(emptyRemoved + retentionRemoved + trimmed) items")
    }
  }

  /// Remove legacy blank text captures. Only title-less records are inspected,
  /// and `isEffectivelyEmpty` avoids loading image/file blobs.
  @discardableResult
  func purgeEmptyItems() -> Int {
    do {
      let descriptor = FetchDescriptor<HistoryItem>(predicate: #Predicate { $0.title == "" })
      let candidates = try context.fetch(descriptor)
      let empty = candidates.filter { $0.isEffectivelyEmpty }
      guard !empty.isEmpty else { return 0 }

      for item in empty {
        context.delete(item)
      }
      try context.save()
      return empty.count
    } catch {
      AppLogger.Storage.error("Failed to purge empty items", error: error)
      return 0
    }
  }

  private func trimInBatches() async -> Int {
    let limit = max(1, Preferences.historyLimit)
    var removed = 0

    while removed < maxMaintenanceBatchCount {
      guard let total = try? context.fetchCount(FetchDescriptor<HistoryItem>()), total > limit else {
        break
      }
      guard let batch = deleteOneBatch(
        #Predicate { $0.pin == nil },
        fetchLimit: min(20, total - limit)
      ), batch > 0 else {
        break
      }
      removed += batch
      await Task.yield()
    }

    return removed
  }

  private func purgeExpiredInBatches() async -> Int {
    let duration = Preferences.retentionDuration
    guard duration > 0 else { return 0 }

    let cutoffDate = Date().addingTimeInterval(-TimeInterval(duration))
    var removed = 0

    while removed < maxMaintenanceBatchCount {
      guard let batch = deleteOneBatch(
        #Predicate { $0.lastCopiedAt < cutoffDate && $0.pin == nil },
        fetchLimit: 20
      ), batch > 0 else {
        break
      }
      removed += batch
      await Task.yield()
    }

    return removed
  }

  func clearAll() {
    // SwiftData's batch delete cannot handle this model's mandatory inverse
    // relationship, so delete in small batches and let the cascade rule clean
    // up the contents.
    var removed = 0
    while removed < maxMaintenanceBatchCount {
      guard let batch = deleteOneBatch(nil, fetchLimit: 20), batch > 0 else {
        break
      }
      removed += batch
    }
  }
}
