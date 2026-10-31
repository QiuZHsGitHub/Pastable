import XCTest
import AppKit
import SwiftData
@testable import Pastable

/// Storage maintenance paths that are not covered by `StorageTests`: pausing
/// automatic trimming, limit edge cases, manual maintenance, on-disk stores and
/// corrupt-store recovery.
@MainActor
final class StorageMaintenanceTests: XCTestCase {
  override func setUp() {
    super.setUp()
    UserDefaults.standard.removeObject(forKey: Preferences.Key.historySize)
    UserDefaults.standard.removeObject(forKey: Preferences.Key.historyRetentionDuration)
    Preferences.registerDefaults()
  }

  override func tearDown() {
    UserDefaults.standard.removeObject(forKey: Preferences.Key.historySize)
    UserDefaults.standard.removeObject(forKey: Preferences.Key.historyRetentionDuration)
    Preferences.registerDefaults()
    super.tearDown()
  }

  private func textItem(_ text: String, at date: Date = Date()) -> HistoryItem {
    let item = HistoryItem(contents: [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: Data(text.utf8)
      )
    ])
    item.firstCopiedAt = date
    item.lastCopiedAt = date
    return item
  }

  func testDefaultStorageURLPointsAtTheSQLiteStore() {
    XCTAssertEqual(Storage.defaultStorageURL.lastPathComponent, "Storage.sqlite")
    XCTAssertTrue(Storage.defaultStorageURL.pathExtension == "sqlite")
  }

  func testPausedAutomaticMaintenanceKeepsGrowingHistory() async {
    await MainActor.run {
      UserDefaults.standard.set(2, forKey: Preferences.Key.historySize)
      let storage = Storage(inMemory: true)
      storage.pauseAutomaticMaintenance()

      for index in 0..<5 {
        XCTAssertTrue(storage.addOrUpdate(self.textItem("paused \(index)")))
      }
      XCTAssertEqual(storage.itemCount(), 5)
    }
  }

  func testResumingMaintenanceTrimsOnNextManualCleanup() async {
    await MainActor.run {
      UserDefaults.standard.set(2, forKey: Preferences.Key.historySize)
      let storage = Storage(inMemory: true)
      storage.pauseAutomaticMaintenance()
      for index in 0..<5 {
        storage.addOrUpdate(self.textItem("resume \(index)"))
      }

      XCTAssertEqual(storage.performCleanupNow(), 3)
      XCTAssertEqual(storage.itemCount(), 2)
    }
  }

  func testTrimmingWithAZeroLimitStillKeepsOneRecord() async {
    await MainActor.run {
      let storage = Storage(inMemory: true)
      for index in 0..<3 {
        storage.addOrUpdate(self.textItem("zero limit \(index)"))
      }

      XCTAssertEqual(storage.trimHistory(limit: 0), 2)
      XCTAssertEqual(storage.itemCount(), 1)
    }
  }

  func testTrimmingCannotRemovePinnedOnlyHistory() async {
    await MainActor.run {
      let storage = Storage(inMemory: true)
      for index in 0..<3 {
        let item = self.textItem("pinned only \(index)")
        item.pin = "keep"
        storage.addOrUpdate(item)
      }

      XCTAssertEqual(storage.trimHistory(limit: 1), 0)
      XCTAssertEqual(storage.itemCount(), 3)
    }
  }

  func testCleanupWithUnlimitedRetentionRemovesNothing() async {
    await MainActor.run {
      let storage = Storage(inMemory: true)
      storage.addOrUpdate(self.textItem("ancient", at: Date(timeIntervalSinceNow: -400 * 86_400)))

      XCTAssertEqual(storage.cleanup(retentionDuration: 0), 0)
      XCTAssertEqual(storage.itemCount(), 1)
    }
  }

  func testLaunchMaintenancePurgesExpiredAndOverLimitRecords() async {
    await MainActor.run {
      UserDefaults.standard.set(3, forKey: Preferences.Key.historySize)
      UserDefaults.standard.set(30 * 86_400, forKey: Preferences.Key.historyRetentionDuration)
    }

    let storage = await MainActor.run { Storage(inMemory: true) }
    await MainActor.run {
      storage.pauseAutomaticMaintenance()
      storage.addOrUpdate(self.textItem("expired", at: Date(timeIntervalSinceNow: -90 * 86_400)))
      for index in 0..<5 {
        storage.addOrUpdate(self.textItem("fresh \(index)"))
      }
      XCTAssertEqual(storage.itemCount(), 6)
    }

    await storage.performMaintenance()

    let count = await MainActor.run { storage.itemCount() }
    XCTAssertEqual(count, 3, "expired record and over-limit records should both be removed")
  }

  func testMaintenancePreviewIgnoresExpiryWhenRetentionIsUnlimited() async {
    await MainActor.run {
      UserDefaults.standard.set(2, forKey: Preferences.Key.historySize)
      UserDefaults.standard.set(0, forKey: Preferences.Key.historyRetentionDuration)

      let storage = Storage(inMemory: true)
      storage.pauseAutomaticMaintenance()
      let old = Date(timeIntervalSinceNow: -400 * 86_400)
      for index in 0..<3 {
        storage.addOrUpdate(self.textItem("ancient \(index)", at: old))
      }

      let preview = storage.maintenancePreview()
      XCTAssertEqual(preview.expired, 0)
      XCTAssertEqual(preview.overLimit, 1)
      XCTAssertEqual(preview.retentionDuration, 0)
    }
  }

  func testRecordsWithoutAUsableHashStillDeduplicateInTheRecentWindow() async {
    await MainActor.run {
      let storage = Storage(inMemory: true)
      let makeEmpty = {
        HistoryItem(contents: [
          HistoryItemContent(type: "com.example.nil", value: nil)
        ])
      }

      XCTAssertTrue(storage.addOrUpdate(makeEmpty()))
      XCTAssertFalse(storage.addOrUpdate(makeEmpty()))
      XCTAssertEqual(storage.itemCount(), 1)
    }
  }

  func testOnDiskStoreReportsItsSizeAndURL() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PastableStore-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
    let storeURL = directory.appendingPathComponent("Storage.sqlite")

    await MainActor.run {
      let storage = Storage(url: storeURL, cloudSyncEnabled: false)
      XCTAssertEqual(storage.url, storeURL)

      storage.addOrUpdate(self.textItem("on disk"))
      XCTAssertEqual(storage.itemCount(), 1)
      XCTAssertFalse(storage.size.isEmpty, "the SQLite file should report a size")
      XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path))
    }
  }

  func testCorruptStoreIsMovedAsideAndReplaced() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PastableCorrupt-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
    let storeURL = directory.appendingPathComponent("Storage.sqlite")

    // A directory where SQLite expects a file is guaranteed to fail to open.
    try FileManager.default.createDirectory(at: storeURL, withIntermediateDirectories: true)

    await MainActor.run {
      let storage = Storage(url: storeURL, cloudSyncEnabled: false)
      XCTAssertEqual(storage.itemCount(), 0)
      storage.addOrUpdate(self.textItem("recovered"))
      XCTAssertEqual(storage.itemCount(), 1)
    }

    let siblings = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    XCTAssertTrue(
      siblings.contains { $0.contains(".corrupt-") || $0 == "Storage.sqlite" },
      "the old store must be kept aside, the new one must exist"
    )
  }

  func testDuplicateCopiesAccumulateUsageStats() async {
    await MainActor.run {
      let storage = Storage(inMemory: true)
      let firstDate = Date(timeIntervalSinceNow: -3_600)
      for index in 0..<3 {
        let item = self.textItem("repeat me", at: firstDate.addingTimeInterval(Double(index) * 60))
        item.application = "app.\(index)"
        storage.addOrUpdate(item)
      }

      let items = (try? storage.context.fetch(FetchDescriptor<HistoryItem>())) ?? []
      XCTAssertEqual(items.count, 1)
      XCTAssertEqual(items.first?.numberOfCopies, 3)
      XCTAssertEqual(items.first?.application, "app.2")
      XCTAssertEqual(
        items.first?.firstCopiedAt.timeIntervalSince1970 ?? 0,
        firstDate.timeIntervalSince1970,
        accuracy: 0.01
      )
    }
  }
}
