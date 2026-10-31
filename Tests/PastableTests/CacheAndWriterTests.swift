import XCTest
import AppKit
import SwiftData
@testable import Pastable

/// Process-wide caches and the batched writer that cards use while scrolling.
@MainActor
final class CacheAndWriterTests: XCTestCase {
  override func setUp() {
    super.setUp()
    DeferredModelWriter.shared.flush()
  }

  override func tearDown() {
    DeferredModelWriter.shared.flush()
    super.tearDown()
  }

  private func makeImage(size: Int = 4) -> NSImage {
    let context = CGContext(
      data: nil,
      width: size,
      height: size,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(NSColor.systemTeal.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))
    return NSImage(
      cgImage: context.makeImage()!,
      size: NSSize(width: size, height: size)
    )
  }

  // MARK: - ImageCache

  func testStoringAndReadingBackAThumbnail() {
    let key = "test-thumb-\(UUID().uuidString)"
    XCTAssertNil(ImageCache.shared.cachedThumbnail(forKey: key))

    let stored = ImageCache.shared.storeThumbnail(makeImage(), forKey: key)
    XCTAssertNotNil(stored)
    XCTAssertNotNil(ImageCache.shared.cachedThumbnail(forKey: key))
  }

  func testStoringNilDoesNotPopulateTheCache() {
    let key = "test-thumb-nil-\(UUID().uuidString)"
    XCTAssertNil(ImageCache.shared.storeThumbnail(nil, forKey: key))
    XCTAssertNil(ImageCache.shared.cachedThumbnail(forKey: key))
  }

  func testThumbnailLoaderRunsOnlyOnAMiss() {
    let key = "test-thumb-loader-\(UUID().uuidString)"
    var loads = 0

    let first = ImageCache.shared.thumbnail(forKey: key) {
      loads += 1
      return self.makeImage()
    }
    let second = ImageCache.shared.thumbnail(forKey: key) {
      loads += 1
      return self.makeImage()
    }

    XCTAssertNotNil(first)
    XCTAssertNotNil(second)
    XCTAssertEqual(loads, 1)
  }

  func testThumbnailLoaderMissReturnsNilWithoutCaching() {
    let key = "test-thumb-miss-\(UUID().uuidString)"
    XCTAssertNil(ImageCache.shared.thumbnail(forKey: key) { nil })
    XCTAssertNil(ImageCache.shared.cachedThumbnail(forKey: key))
  }

  // MARK: - PreviewCache

  func testPreviewCacheRoundTripsTheSameArtifact() {
    let key = "test-preview-\(UUID().uuidString)"
    let preview = AttributedPreview(text: AttributedString("preview"), backgroundHex: "#112233")

    XCTAssertNil(PreviewCache.shared.preview(forKey: key))
    PreviewCache.shared.store(preview, forKey: key)

    let cached = PreviewCache.shared.preview(forKey: key)
    XCTAssertTrue(cached === preview)
    XCTAssertEqual(cached?.backgroundHex, "#112233")
    XCTAssertGreaterThan(cached?.cost ?? 0, 0)
  }

  func testPreviewCacheIgnoresNil() {
    let key = "test-preview-nil-\(UUID().uuidString)"
    PreviewCache.shared.store(nil, forKey: key)
    XCTAssertNil(PreviewCache.shared.preview(forKey: key))
  }

  // MARK: - DeferredModelWriter

  private func makeStorage() -> (Storage, HistoryItem) {
    let storage = Storage(inMemory: true)
    let item = HistoryItem(contents: [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: Data("deferred".utf8)
      )
    ])
    storage.context.insert(item)
    try? storage.context.save()
    return (storage, item)
  }

  func testWritesAreDeferredUntilFlush() {
    let (storage, item) = makeStorage()

    DeferredModelWriter.shared.enqueue(context: storage.context) {
      item.title = "written later"
    }

    XCTAssertNotEqual(item.title, "written later")
    DeferredModelWriter.shared.flush()
    XCTAssertEqual(item.title, "written later")
  }

  func testFlushAppliesEveryQueuedWrite() {
    let (storage, first) = makeStorage()
    let second = HistoryItem(contents: [])
    storage.context.insert(second)

    DeferredModelWriter.shared.enqueue(context: storage.context) { first.title = "one" }
    DeferredModelWriter.shared.enqueue(context: storage.context) { second.title = "two" }

    DeferredModelWriter.shared.flush()

    XCTAssertEqual(first.title, "one")
    XCTAssertEqual(second.title, "two")
  }

  func testFlushWithoutAContextStillRunsTheWrite() {
    var didRun = false
    DeferredModelWriter.shared.enqueue(context: nil) { didRun = true }
    XCTAssertFalse(didRun)

    DeferredModelWriter.shared.flush()
    XCTAssertTrue(didRun)
  }

  func testFlushingTwiceIsSafe() {
    let (storage, item) = makeStorage()
    DeferredModelWriter.shared.enqueue(context: storage.context) { item.title = "idempotent" }

    DeferredModelWriter.shared.flush()
    DeferredModelWriter.shared.flush()

    XCTAssertEqual(item.title, "idempotent")
  }
}
