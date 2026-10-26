import XCTest
import AppKit
import SwiftData
@testable import Pastable

final class HistoryItemTests: XCTestCase {
  private func makeItem(_ text: String, types: [NSPasteboard.PasteboardType] = [.string]) -> HistoryItem {
    let contents = types.map {
      HistoryItemContent(type: $0.rawValue, value: Data(text.utf8))
    }
    return HistoryItem(contents: contents)
  }

  func testHashPrefersPlainTextOverFormatting() {
    let textOnly = makeItem("hello world")
    let withHTML = makeItem("hello world", types: [.string, .html, .rtf])

    XCTAssertEqual(textOnly.contentHash, withHTML.contentHash)
    XCTAssertTrue(textOnly.contentHash?.hasPrefix("text:") == true)
  }

  func testHashMatchesFilesRegardlessOfOrder() {
    let first = HistoryItemContent(
      type: NSPasteboard.PasteboardType.fileURL.rawValue,
      value: URL(fileURLWithPath: "/tmp/a.txt").dataRepresentation
    )
    let second = HistoryItemContent(
      type: NSPasteboard.PasteboardType.fileURL.rawValue,
      value: URL(fileURLWithPath: "/tmp/b.txt").dataRepresentation
    )

    let forward = HistoryItem(contents: [first, second])
    let backward = HistoryItem(contents: [second, first])

    XCTAssertEqual(forward.contentHash, backward.contentHash)
    XCTAssertTrue(forward.contentHash?.hasPrefix("files:") == true)
  }

  func testSupersedesRequiresAllNonTransientContents() {
    let existing = HistoryItem(contents: [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.notesRichText.rawValue,
        value: Data("volatile".utf8)
      ),
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: Data("hello".utf8)
      )
    ])

    let sameText = HistoryItem(contents: [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: Data("hello".utf8)
      )
    ])
    XCTAssertTrue(sameText.supersedes(existing))

    let differentText = HistoryItem(contents: [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: Data("world".utf8)
      )
    ])
    XCTAssertFalse(differentText.supersedes(existing))
  }


  func testEffectivelyEmptyDetectsBlankTextButKeepsImagesAndFiles() {
    let empty = HistoryItem(contents: [
      HistoryItemContent(type: NSPasteboard.PasteboardType.string.rawValue, value: Data())
    ])
    XCTAssertTrue(empty.isEffectivelyEmpty)

    let whitespace = HistoryItem(contents: [
      HistoryItemContent(type: NSPasteboard.PasteboardType.string.rawValue, value: Data("  \n".utf8))
    ])
    XCTAssertTrue(whitespace.isEffectivelyEmpty)

    let text = makeItem("hello")
    XCTAssertFalse(text.isEffectivelyEmpty)

    let image = HistoryItem(contents: [
      HistoryItemContent(type: NSPasteboard.PasteboardType.png.rawValue, value: Data([0x89, 0x50]))
    ])
    XCTAssertFalse(image.isEffectivelyEmpty)

    let file = HistoryItem(contents: [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.fileURL.rawValue,
        value: URL(fileURLWithPath: "/tmp/a.txt").dataRepresentation
      )
    ])
    XCTAssertFalse(file.isEffectivelyEmpty)
  }

  func testShortenedNeverExceedsLimit() {
    XCTAssertEqual("abcdef".shortened(to: 3), "abc")
    XCTAssertEqual("abc".shortened(to: 3), "abc")
    XCTAssertEqual("abc".shortened(to: 0), "")
    XCTAssertEqual("🙂🙂🙂".shortened(to: 2), "🙂🙂")
  }

  func testHexColorDetection() {
    XCTAssertEqual(makeItem("#FF8800").hexColor, "#FF8800")
    XCTAssertEqual(makeItem("  #abc  ").hexColor, "#abc")
    XCTAssertNil(makeItem("#12").hexColor)
  }

  func testCodeAndLinkClassification() {
    let code = makeItem("""
    func greet(name: String) {
      guard !name.isEmpty else { return }
      print("Hello \\(name)")
    }
    """)
    XCTAssertTrue(code.isCode)
    XCTAssertFalse(code.isLink)

    let link = makeItem("https://github.com/apple/swift")
    XCTAssertTrue(link.isLink)
    XCTAssertFalse(link.isCode)

    let prose = makeItem("今天下午三点开会，记得带上笔记本。")
    XCTAssertFalse(prose.isCode)
    XCTAssertFalse(prose.isLink)
  }

  func testImageAndFileClassificationUsesCachedValues() {
    let imageData = Data([0x89, 0x50, 0x4E, 0x47])
    let imageItem = HistoryItem(contents: [
      HistoryItemContent(type: NSPasteboard.PasteboardType.png.rawValue, value: imageData)
    ])
    XCTAssertFalse(imageItem.isCode)
    XCTAssertFalse(imageItem.isLink)

    let fileItem = HistoryItem(contents: [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.fileURL.rawValue,
        value: URL(fileURLWithPath: "/tmp/report.pdf").dataRepresentation
      )
    ])
    XCTAssertTrue(fileItem.isFile)
    XCTAssertFalse(fileItem.isCode)
  }

  func testDisplayMetadataFallsBackForLegacyRecords() {
    let item = makeItem("hello")

    // Legacy rows keep `-1` until the value is requested once.
    XCTAssertEqual(item.textLength, -1)
    XCTAssertEqual(item.displayTextLength, 5)
    XCTAssertEqual(item.displayTotalSize, 5)
  }

  func testDeriveDisplayMetadataFillsCounts() {
    let fileItem = HistoryItem(contents: [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.fileURL.rawValue,
        value: URL(fileURLWithPath: "/tmp/a.txt").dataRepresentation
      ),
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.fileURL.rawValue,
        value: URL(fileURLWithPath: "/tmp/b.txt").dataRepresentation
      )
    ])
    fileItem.deriveDisplayMetadata()

    XCTAssertEqual(fileItem.displayFileCount, 2)
    XCTAssertGreaterThan(fileItem.displayTotalSize, 0)
    XCTAssertEqual(fileItem.displayTextLength, fileItem.previewableText.count)
  }

  func testIsImageClassifiesWithoutDecoding() {
    // Not decodable image bytes: classification must still report "image"
    // because it only inspects the declared pasteboard types.
    let imageItem = HistoryItem(contents: [
      HistoryItemContent(type: NSPasteboard.PasteboardType.png.rawValue, value: Data([0x89, 0x50]))
    ])
    XCTAssertTrue(imageItem.isImage)

    let textItem = makeItem("plain text")
    XCTAssertFalse(textItem.isImage)
  }
}
