import Foundation
import SwiftData

@MainActor
final class Storage {
  static let shared = Storage()

  var container: ModelContainer
  var context: ModelContext { container.mainContext }

  /// Location of the SQLite store, or `nil` when running in memory.
  private(set) var url: URL?

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

  init(inMemory: Bool = false, url: URL? = nil) {
    if inMemory {
      self.url = nil
      self.container = try! ModelContainer(
        for: HistoryItem.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
      )
      return
    }

    let resolvedURL = url ?? Self.defaultStorageURL
    self.url = resolvedURL

    try? FileManager.default.createDirectory(
      at: resolvedURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )

    do {
      self.container = try ModelContainer(
        for: HistoryItem.self,
        configurations: ModelConfiguration(url: resolvedURL)
      )
    } catch {
      AppLogger.Storage.error("Cannot open database, moving it aside", error: error)
      Self.moveStoreAside(resolvedURL)

      do {
        self.container = try ModelContainer(
          for: HistoryItem.self,
          configurations: ModelConfiguration(url: resolvedURL)
        )
      } catch {
        AppLogger.Storage.error("Cannot recreate database, using in-memory store", error: error)
        self.url = nil
        self.container = try! ModelContainer(
          for: HistoryItem.self,
          configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
      }
    }
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

  /// Human readable size of the store including its WAL/SHM side files.
  var size: String {
    guard let url else { return "" }

    var total: Int64 = 0
    for suffix in ["", "-wal", "-shm"] {
      let path = url.path + suffix
      guard let attributes = try? fileManager.attributesOfItem(atPath: path),
            let bytes = attributes[.size] as? NSNumber else { continue }
      total += bytes.int64Value
    }

    guard total > 0 else { return "" }
    return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
  }

  func itemCount() -> Int {
    (try? context.fetchCount(FetchDescriptor<HistoryItem>())) ?? 0
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
        newItem.contentHash = HistoryItem.computeContentHash(contents: newItem.contents)
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
              item.contentHash = HistoryItem.computeContentHash(contents: item.contents)
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

      var descriptor = FetchDescriptor<HistoryItem>(
        predicate: #Predicate { $0.pin == nil },
        sortBy: [SortDescriptor(\.lastCopiedAt, order: .forward)]
      )
      descriptor.fetchLimit = min(20, total - effectiveLimit)

      guard let batch = try? context.fetch(descriptor), !batch.isEmpty else { break }
      for item in batch {
        context.delete(item)
      }

      do {
        try context.save()
      } catch {
        AppLogger.Storage.error("Failed to trim history", error: error)
        break
      }
      removed += batch.count
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
      var descriptor = FetchDescriptor<HistoryItem>(
        predicate: #Predicate { $0.lastCopiedAt < cutoffDate && $0.pin == nil },
        sortBy: [SortDescriptor(\.lastCopiedAt, order: .forward)]
      )
      descriptor.fetchLimit = 20

      guard let batch = try? context.fetch(descriptor), !batch.isEmpty else { break }
      for item in batch {
        context.delete(item)
      }

      do {
        try context.save()
      } catch {
        AppLogger.Storage.error("Failed to cleanup history", error: error)
        break
      }
      removed += batch.count
    }

    return removed
  }

  /// Batched maintenance used at launch so an oversized legacy store does not
  /// block the first frame or spike memory by loading every image at once.
  func performMaintenance() async {
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

      var descriptor = FetchDescriptor<HistoryItem>(
        predicate: #Predicate { $0.pin == nil },
        sortBy: [SortDescriptor(\.lastCopiedAt, order: .forward)]
      )
      descriptor.fetchLimit = min(20, total - limit)

      guard let batch = try? context.fetch(descriptor), !batch.isEmpty else { break }
      for item in batch {
        context.delete(item)
      }
      try? context.save()
      removed += batch.count
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
      var descriptor = FetchDescriptor<HistoryItem>(
        predicate: #Predicate { $0.lastCopiedAt < cutoffDate && $0.pin == nil },
        sortBy: [SortDescriptor(\.lastCopiedAt, order: .forward)]
      )
      descriptor.fetchLimit = 20

      guard let batch = try? context.fetch(descriptor), !batch.isEmpty else { break }
      for item in batch {
        context.delete(item)
      }
      try? context.save()
      removed += batch.count
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
      var descriptor = FetchDescriptor<HistoryItem>()
      descriptor.fetchLimit = 20

      guard let batch = try? context.fetch(descriptor), !batch.isEmpty else { break }
      for item in batch {
        context.delete(item)
      }
      do {
        try context.save()
      } catch {
        AppLogger.Storage.error("Failed to clear history", error: error)
        return
      }
      removed += batch.count
    }
  }
}
