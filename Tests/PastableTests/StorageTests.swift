import XCTest
import AppKit
import SwiftData
@testable import Pastable

final class StorageTests: XCTestCase {
  override func setUp() {
    super.setUp()
    UserDefaults.standard.removeObject(forKey: Preferences.Key.historySize)
    UserDefaults.standard.removeObject(forKey: Preferences.Key.historyRetentionDuration)
    Preferences.registerDefaults()
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

  func testDeduplicationUpdatesUsageButKeepsFirstCopyDate() async {
    await MainActor.run {
      let storage = Storage(inMemory: true)
      let firstDate = Date(timeIntervalSinceNow: -600)

      let first = self.textItem("hello world", at: firstDate)
      XCTAssertTrue(storage.addOrUpdate(first))

      let secondDate = Date()
      let second = self.textItem("hello world", at: secondDate)
      second.application = "com.apple.Safari"
      XCTAssertFalse(storage.addOrUpdate(second))

      XCTAssertEqual(storage.itemCount(), 1)

      let items = (try? storage.context.fetch(FetchDescriptor<HistoryItem>())) ?? []
      XCTAssertEqual(items.count, 1)
      XCTAssertEqual(items.first?.numberOfCopies, 2)
      XCTAssertEqual(items.first?.application, "com.apple.Safari")
      XCTAssertEqual(
        items.first?.firstCopiedAt.timeIntervalSince1970 ?? 0,
        firstDate.timeIntervalSince1970,
        accuracy: 0.01
      )
      XCTAssertEqual(
        items.first?.lastCopiedAt.timeIntervalSince1970 ?? 0,
        secondDate.timeIntervalSince1970,
        accuracy: 0.01
      )
    }
  }

  func testDeduplicatesFormattingVariantsByPreferredHash() async {
    await MainActor.run {
      let storage = Storage(inMemory: true)

      let textOnly = self.textItem("same content")
      XCTAssertTrue(storage.addOrUpdate(textOnly))

      let withHTML = HistoryItem(contents: [
        HistoryItemContent(
          type: NSPasteboard.PasteboardType.string.rawValue,
          value: Data("same content".utf8)
        ),
        HistoryItemContent(
          type: NSPasteboard.PasteboardType.html.rawValue,
          value: Data("<p>same content</p>".utf8)
        )
      ])
      XCTAssertFalse(storage.addOrUpdate(withHTML))
      XCTAssertEqual(storage.itemCount(), 1)
      XCTAssertEqual(
        (try? storage.context.fetch(FetchDescriptor<HistoryItem>()))?.first?.numberOfCopies,
        2
      )
    }
  }

  func testTrimHistoryKeepsNewestItems() async {
    await MainActor.run {
      let storage = Storage(inMemory: true)
      let base = Date(timeIntervalSinceNow: -10_000)

      for index in 0..<12 {
        let item = self.textItem("item \(index)", at: base.addingTimeInterval(Double(index)))
        XCTAssertTrue(storage.addOrUpdate(item))
      }

      XCTAssertEqual(storage.trimHistory(limit: 5), 7)
      XCTAssertEqual(storage.itemCount(), 5)

      let items = (try? storage.context.fetch(
        FetchDescriptor<HistoryItem>(sortBy: [SortDescriptor(\.lastCopiedAt, order: .reverse)])
      )) ?? []
      XCTAssertEqual(
        Set(items.map(\.title)),
        Set((7..<12).map { "item \($0)" })
      )
    }
  }

  func testTrimHistoryNeverDeletesPinnedItems() async {
    await MainActor.run {
      let storage = Storage(inMemory: true)
      let base = Date(timeIntervalSinceNow: -10_000)

      for index in 0..<6 {
        let item = self.textItem("pinned-test \(index)", at: base.addingTimeInterval(Double(index)))
        storage.addOrUpdate(item)
        if index < 2 {
          item.pin = "keep"
        }
      }
      try? storage.context.save()

      storage.trimHistory(limit: 3)

      let items = (try? storage.context.fetch(FetchDescriptor<HistoryItem>())) ?? []
      XCTAssertEqual(items.count, 3)
      XCTAssertEqual(items.filter { $0.pin != nil }.count, 2)
    }
  }

  func testCleanupRemovesExpiredUnpinnedItems() async {
    await MainActor.run {
      let storage = Storage(inMemory: true)
      let pinned = self.textItem("pinned old", at: Date(timeIntervalSinceNow: -40 * 86_400))
      pinned.pin = "keep"
      storage.addOrUpdate(pinned)

      storage.addOrUpdate(self.textItem("old", at: Date(timeIntervalSinceNow: -40 * 86_400)))
      storage.addOrUpdate(self.textItem("recent", at: Date(timeIntervalSinceNow: -2 * 86_400)))

      XCTAssertEqual(storage.cleanup(retentionDuration: 30 * 86_400), 1)
      XCTAssertEqual(storage.itemCount(), 2)

      let titles = Set(((try? storage.context.fetch(FetchDescriptor<HistoryItem>())) ?? []).map(\.title))
      XCTAssertEqual(titles, ["pinned old", "recent"])
    }
  }

  func testLegacyItemsWithoutHashAreBackfilledBeforeInsert() async {
    await MainActor.run {
      let storage = Storage(inMemory: true)

      let legacy = self.textItem("legacy duplicate")
      legacy.contentHash = nil
      storage.context.insert(legacy)
      try? storage.context.save()
      XCTAssertEqual(storage.itemCount(), 1)

      XCTAssertFalse(storage.addOrUpdate(self.textItem("legacy duplicate")))
      XCTAssertEqual(storage.itemCount(), 1)
      XCTAssertEqual(
        (try? storage.context.fetch(FetchDescriptor<HistoryItem>()))?.first?.numberOfCopies,
        2
      )
    }
  }


  func testMaintenancePreviewCountsWithoutLoadingData() async {
    await MainActor.run {
      let storage = Storage(inMemory: true)
      let old = Date(timeIntervalSinceNow: -40 * 86_400)
      storage.addOrUpdate(self.textItem("old one", at: old))
      storage.addOrUpdate(self.textItem("old two", at: old))
      storage.addOrUpdate(self.textItem("recent", at: Date()))

      UserDefaults.standard.set(2, forKey: Preferences.Key.historySize)
      UserDefaults.standard.set(30 * 86_400, forKey: Preferences.Key.historyRetentionDuration)

      let preview = storage.maintenancePreview()
      XCTAssertEqual(preview.total, 3)
      XCTAssertEqual(preview.limit, 2)
      XCTAssertEqual(preview.overLimit, 1)
      XCTAssertEqual(preview.expired, 2)
      XCTAssertTrue(preview.needsAttention)
      XCTAssertGreaterThanOrEqual(preview.suggestedLimit, 1_000)
    }
  }


  func testDuplicateHashesAreMergedOnNextCapture() async {
    await MainActor.run {
      let storage = Storage(inMemory: true)
      storage.addOrUpdate(self.textItem("merge me"))

      // Simulate a legacy store that already contains a second row with the
      // same hash (for example, before hash-based dedupe existed).
      let legacyDuplicate = self.textItem("merge me")
      storage.context.insert(legacyDuplicate)
      try? storage.context.save()
      XCTAssertEqual(storage.itemCount(), 2)

      XCTAssertFalse(storage.addOrUpdate(self.textItem("merge me")))
      XCTAssertEqual(storage.itemCount(), 1)
      XCTAssertEqual(
        (try? storage.context.fetch(FetchDescriptor<HistoryItem>()))?.first?.numberOfCopies,
        3
      )
    }
  }


  func testPurgeEmptyItemsRemovesBlankTextRecords() async {
    await MainActor.run {
      let storage = Storage(inMemory: true)
      let blank = HistoryItem(contents: [
        HistoryItemContent(type: NSPasteboard.PasteboardType.string.rawValue, value: Data())
      ])
      storage.addOrUpdate(blank)
      storage.addOrUpdate(self.textItem("real content"))
      XCTAssertEqual(storage.itemCount(), 2)

      XCTAssertEqual(storage.purgeEmptyItems(), 1)
      XCTAssertEqual(storage.itemCount(), 1)
      XCTAssertEqual(
        (try? storage.context.fetch(FetchDescriptor<HistoryItem>()))?.first?.title,
        "real content"
      )
    }
  }

  func testClearAllRemovesItemsAndContents() async {
    await MainActor.run {
      let storage = Storage(inMemory: true)
      storage.addOrUpdate(self.textItem("one"))
      storage.addOrUpdate(self.textItem("two"))
      XCTAssertEqual(storage.itemCount(), 2)

      storage.clearAll()
      XCTAssertEqual(storage.itemCount(), 0)
      let contentCount = try? storage.context.fetchCount(FetchDescriptor<HistoryItemContent>())
      XCTAssertEqual(contentCount, 0)
    }
  }

  func testInMemoryStoreHasNoFileSize() async {
    await MainActor.run {
      let storage = Storage(inMemory: true)
      XCTAssertEqual(storage.size, "")
      XCTAssertNil(storage.url)
    }
  }
}
