import XCTest
import AppKit
@testable import Pastable

/// Title, preview, classification and metadata rules that the cards depend on.
final class HistoryItemDisplayTests: XCTestCase {
  private func textItem(_ text: String) -> HistoryItem {
    HistoryItem(contents: [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: Data(text.utf8)
      )
    ])
  }

  private func fileItem(_ paths: [String]) -> HistoryItem {
    HistoryItem(contents: paths.map { path in
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.fileURL.rawValue,
        value: URL(fileURLWithPath: path).dataRepresentation
      )
    })
  }

  private func imageItem(_ bytes: Data = Data([0x89, 0x50, 0x4E, 0x47])) -> HistoryItem {
    HistoryItem(contents: [
      HistoryItemContent(type: NSPasteboard.PasteboardType.png.rawValue, value: bytes)
    ])
  }

  // MARK: - Title

  func testTitleTrimsWhitespaceAroundText() {
    XCTAssertEqual(textItem("   hello world \n").title, "hello world")
  }

  func testTitleIsCappedAtOneThousandCharacters() {
    let long = String(repeating: "a", count: 2_500)
    let title = textItem(long).title
    XCTAssertEqual(title.count, 1_000)
  }

  func testFileTitleUsesTheFileName() {
    let item = fileItem(["/Users/me/Documents/Report.pdf"])
    XCTAssertEqual(item.title, "Report.pdf")
  }

  func testFileTitleIsTheFirstFileOnly() {
    let item = fileItem(["/tmp/first.txt", "/tmp/second.txt"])
    XCTAssertEqual(item.title, "first.txt")
  }

  func testImageTitleStaysEmptyForTheOCRPass() {
    let item = imageItem()
    XCTAssertEqual(item.title, "")
  }

  func testImageTitleStaysEmptyEvenWhenTextIsAttached() {
    let item = HistoryItem(contents: [
      HistoryItemContent(type: NSPasteboard.PasteboardType.png.rawValue, value: Data([0x89])),
      HistoryItemContent(type: NSPasteboard.PasteboardType.string.rawValue, value: Data("caption".utf8))
    ])
    XCTAssertEqual(item.title, "")
  }

  // MARK: - Preview text

  func testPreviewPrefersPlainTextOverRichRepresentations() {
    let item = HistoryItem(contents: [
      HistoryItemContent(type: NSPasteboard.PasteboardType.string.rawValue, value: Data("plain".utf8)),
      HistoryItemContent(type: NSPasteboard.PasteboardType.html.rawValue, value: Data("<b>rich</b>".utf8))
    ])
    XCTAssertEqual(item.previewableText, "plain")
  }

  func testPreviewFallsBackToHTMLVisibleText() async {
    await MainActor.run {
      let item = HistoryItem(contents: [
        HistoryItemContent(type: NSPasteboard.PasteboardType.html.rawValue, value: Data("<p>rich text</p>".utf8))
      ])
      XCTAssertEqual(
        item.previewableText.trimmingCharacters(in: .whitespacesAndNewlines),
        "rich text"
      )
    }
  }

  func testPreviewListsFileURLsOnSeparateLines() {
    let item = fileItem(["/tmp/a.txt", "/tmp/b.txt"])
    let lines = item.previewableText.components(separatedBy: "\n")
    XCTAssertEqual(lines.count, 2)
    XCTAssertTrue(lines[0].hasSuffix("/tmp/a.txt"))
    XCTAssertTrue(lines[1].hasSuffix("/tmp/b.txt"))
  }

  func testPreviewFallsBackToAnExternallyAssignedTitleForLegacyRecords() {
    // Legacy image rows may carry an OCR title but no persisted preview.
    let item = imageItem()
    item.cachedPreviewText = nil
    item.title = "recognized headline"
    XCTAssertEqual(item.previewableText, "recognized headline")
  }

  func testPreviewForImageIsEmpty() {
    XCTAssertEqual(imageItem().previewableText, "")
  }

  // MARK: - Display metadata

  func testDisplayMetadataCountsTextAndBytes() {
    let item = textItem("hello")
    XCTAssertEqual(item.textLength, -1, "new records start un-derived")
    XCTAssertEqual(item.displayTextLength, 5)
    XCTAssertEqual(item.displayTotalSize, 5)
    XCTAssertEqual(item.displayFileCount, 0)
  }

  func testDisplayMetadataCountsFiles() {
    let item = fileItem(["/tmp/a.txt", "/tmp/b.txt"])
    item.deriveDisplayMetadata()

    XCTAssertEqual(item.displayFileCount, 2)
    XCTAssertEqual(item.textLength, item.previewableText.count)
    XCTAssertGreaterThan(item.displayTotalSize, 0)
  }

  func testImageTotalSizeUsesImagePayload() {
    let bytes = Data([0x01, 0x02, 0x03, 0x04, 0x05])
    let item = imageItem(bytes)
    item.deriveDisplayMetadata()

    XCTAssertEqual(item.displayTotalSize, bytes.count)
    XCTAssertEqual(item.displayTextLength, 0)
    XCTAssertEqual(item.displayFileCount, 0)
  }

  func testDisplayMetadataCacheInvalidationAfterOCR() {
    let item = textItem("hello")
    XCTAssertEqual(item.displayTextLength, 5)

    item.cachedPreviewText = "hello world"
    item.invalidateSearchCache()

    XCTAssertEqual(item.displayTextLength, 11)
  }

  func testThumbnailCacheKeysDeriveFromHash() {
    let item = textItem("hello")
    let hash = item.contentHash ?? ""

    XCTAssertEqual(item.thumbnailCacheKey, "thumb:" + hash)
    XCTAssertEqual(item.attributedPreviewCacheKey, "rtf:" + hash)
    XCTAssertFalse(item.thumbnailCacheKey.isEmpty)
  }

  func testLegacyRecordWithoutHashKeepsAUniquePreviewCacheKey() {
    let item = textItem("legacy")
    item.contentHash = nil

    XCTAssertTrue(item.attributedPreviewCacheKey.hasPrefix("rtf:id:"))
  }

  // MARK: - Classification

  func testCodeNeedsADocCommentOrEnoughSignals() {
    XCTAssertTrue(textItem("/// documentation comment").isCode)
    XCTAssertTrue(textItem("func greet(name: String) {\n  print(name)\n}").isCode)

    XCTAssertFalse(textItem("hello world").isCode)
    XCTAssertFalse(textItem("今天下午三点开会，记得带上笔记本。").isCode)
    XCTAssertFalse(textItem("short").isCode)
  }

  func testImageAndFileAreNeverClassifiedAsCode() {
    let image = imageItem()
    XCTAssertFalse(image.isCode)
    XCTAssertFalse(image.isLink)

    let file = fileItem(["/tmp/report.pdf"])
    XCTAssertTrue(file.isFile)
    XCTAssertFalse(file.isCode)
  }

  func testLinkDetectionRequiresTheWholeString() {
    XCTAssertTrue(textItem("https://example.com/docs").isLink)
    XCTAssertFalse(textItem("Please visit https://example.com/docs for details").isLink)
    XCTAssertFalse(textItem("plain words only").isLink)
  }

  func testHexColorDetectionAcceptsThreeSixAndEightDigits() {
    XCTAssertEqual(textItem("#abc").hexColor, "#abc")
    XCTAssertEqual(textItem("#ABCDEF").hexColor, "#ABCDEF")
    XCTAssertEqual(textItem("#11223344").hexColor, "#11223344")
    XCTAssertNil(textItem("#12345").hexColor)
    XCTAssertNil(textItem("color: #fff").hexColor)
  }

  func testLongTextIsNeverMistakenForHexColor() {
    let item = textItem(String(repeating: "a", count: 65) + "#fff")
    XCTAssertNil(item.hexColor)
  }

  func testIsImageFileUsesContentTypeOfTheFile() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PastableTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let pngURL = directory.appendingPathComponent("pixel.png")
    let textURL = directory.appendingPathComponent("notes.txt")
    let image = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: 1,
      pixelsHigh: 1,
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: 0,
      bitsPerPixel: 0
    )!
    try image.representation(using: .png, properties: [:])!.write(to: pngURL)
    try Data("plain text".utf8).write(to: textURL)

    XCTAssertTrue(fileItem([pngURL.path]).isImageFile)
    XCTAssertFalse(fileItem([textURL.path]).isImageFile)
    XCTAssertFalse(fileItem([directory.appendingPathComponent("missing.png").path]).isImageFile)
  }

  func testUniversalClipboardImageIsDetectedWithoutAnImageType() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PastableTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let jpegURL = directory.appendingPathComponent("handoff.jpeg")
    let payload = Data([0xAA, 0xBB, 0xCC])
    try payload.write(to: jpegURL)

    let item = HistoryItem(contents: [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.universalClipboard.rawValue,
        value: Data("1".utf8)
      ),
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.fileURL.rawValue,
        value: jpegURL.dataRepresentation
      )
    ])

    XCTAssertTrue(item.universalClipboard)
    XCTAssertTrue(item.isImage)
    XCTAssertEqual(item.imageData, payload)
  }

  func testUniversalClipboardTextHidesItsFileURLPlaceholder() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PastableTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let fileURL = directory.appendingPathComponent("payload.txt")
    try Data("handoff".utf8).write(to: fileURL)

    let item = HistoryItem(contents: [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.universalClipboard.rawValue,
        value: Data("1".utf8)
      ),
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: Data("handoff".utf8)
      ),
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.fileURL.rawValue,
        value: fileURL.dataRepresentation
      )
    ])

    XCTAssertTrue(item.fileURLs.isEmpty)
    XCTAssertFalse(item.isFile)
    XCTAssertEqual(item.previewableText, "handoff")
  }

  func testSearchIndexIsRebuiltAfterTitleChanges() {
    let item = textItem("old content")
    XCTAssertEqual(item.normalizedSearchTitle, "old content")

    item.title = "new content"
    item.invalidateSearchCache()

    XCTAssertEqual(item.normalizedSearchTitle, "new content")
  }

  func testWarmUpIsIdempotentUntilTheCacheIsInvalidated() {
    let item = textItem("hello")

    XCTAssertTrue(item.warmUpSearchIndex())
    XCTAssertFalse(item.warmUpSearchIndex())
    XCTAssertTrue(item.warmUpDisplayCaches())
    XCTAssertFalse(item.warmUpDisplayCaches())

    item.invalidateSearchCache()

    XCTAssertTrue(item.warmUpSearchIndex())
    XCTAssertTrue(item.warmUpDisplayCaches())
  }

  func testWarmUpHelpersDoNotChangeClassification() {
    let code = textItem("func f() { return 1 }")
    let before = code.isCode
    code.warmUpDisplayCaches()
    code.warmUpSearchIndex()

    XCTAssertEqual(code.isCode, before)
    XCTAssertFalse(code.normalizedSearchTitle.isEmpty)
  }
}
