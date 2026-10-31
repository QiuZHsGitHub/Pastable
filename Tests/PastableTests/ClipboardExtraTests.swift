import XCTest
import AppKit
@testable import Pastable

/// Pasteboard normalization and copy round-trips beyond the happy path:
/// deterministic ordering, duplicate collapse, representation choice and
/// respecting the save toggles.
@MainActor
final class ClipboardExtraTests: XCTestCase {
  override func setUp() {
    super.setUp()
    Preferences.registerDefaults()
  }

  private func makePasteboard() -> NSPasteboard {
    NSPasteboard(name: NSPasteboard.Name("PastableExtraTests.\(UUID().uuidString)"))
  }

  private func textContent(_ text: String) -> HistoryItemContent {
    HistoryItemContent(
      type: NSPasteboard.PasteboardType.string.rawValue,
      value: Data(text.utf8)
    )
  }

  private func fileContent(_ path: String) -> HistoryItemContent {
    HistoryItemContent(
      type: NSPasteboard.PasteboardType.fileURL.rawValue,
      value: URL(fileURLWithPath: path).dataRepresentation
    )
  }

  private func solidImageData(size: Int = 10) -> (png: Data, tiff: Data) {
    let context = CGContext(
      data: nil,
      width: size,
      height: size,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(NSColor.systemGreen.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))
    let representation = NSBitmapImageRep(cgImage: context.makeImage()!)
    return (
      representation.representation(using: .png, properties: [:])!,
      representation.representation(using: .tiff, properties: [:])!
    )
  }

  // MARK: - Normalization

  func testNormalizationOrdersFilesThenOtherTypesByType() throws {
    let normalized = Clipboard.normalizedContents([
      RawContentSnapshot(type: NSPasteboard.PasteboardType.string.rawValue, value: Data("text".utf8)),
      RawContentSnapshot(type: NSPasteboard.PasteboardType.fileURL.rawValue, value: URL(fileURLWithPath: "/tmp/z.txt").dataRepresentation),
      RawContentSnapshot(type: NSPasteboard.PasteboardType.html.rawValue, value: Data("<b>html</b>".utf8)),
      RawContentSnapshot(type: NSPasteboard.PasteboardType.fileURL.rawValue, value: URL(fileURLWithPath: "/tmp/a.txt").dataRepresentation)
    ])

    XCTAssertEqual(normalized.map(\.type), [
      NSPasteboard.PasteboardType.fileURL.rawValue,
      NSPasteboard.PasteboardType.fileURL.rawValue,
      NSPasteboard.PasteboardType.html.rawValue,
      NSPasteboard.PasteboardType.string.rawValue
    ])
    XCTAssertTrue(normalized[0].value.flatMap {
      URL(dataRepresentation: $0, relativeTo: nil, isAbsolute: true)?.path
    } == "/tmp/a.txt")
    XCTAssertTrue(normalized[1].value.flatMap {
      URL(dataRepresentation: $0, relativeTo: nil, isAbsolute: true)?.path
    } == "/tmp/z.txt")
  }

  func testNormalizationKeepsTheFirstPayloadPerType() {
    let normalized = Clipboard.normalizedContents([
      RawContentSnapshot(type: NSPasteboard.PasteboardType.string.rawValue, value: Data("first".utf8)),
      RawContentSnapshot(type: NSPasteboard.PasteboardType.string.rawValue, value: Data("second".utf8))
    ])

    XCTAssertEqual(normalized.count, 1)
    XCTAssertEqual(String(data: normalized[0].value ?? Data(), encoding: .utf8), "first")
  }

  func testNormalizationSkipsEmptyImagePayloads() {
    let tiff = solidImageData().tiff
    let normalized = Clipboard.normalizedContents([
      RawContentSnapshot(type: NSPasteboard.PasteboardType.png.rawValue, value: Data()),
      RawContentSnapshot(type: NSPasteboard.PasteboardType.tiff.rawValue, value: tiff)
    ])

    XCTAssertEqual(normalized.count, 1)
    XCTAssertEqual(normalized[0].type, NSPasteboard.PasteboardType.tiff.rawValue)
  }

  func testSmallTIFFIsNotRecompressed() {
    let tiff = solidImageData(size: 4).tiff
    XCTAssertLessThan(tiff.count, 64_000)

    let normalized = Clipboard.normalizedContents([
      RawContentSnapshot(type: NSPasteboard.PasteboardType.tiff.rawValue, value: tiff)
    ])

    XCTAssertEqual(normalized.first?.type, NSPasteboard.PasteboardType.tiff.rawValue)
    XCTAssertEqual(normalized.first?.value, tiff)
  }

  func testNormalizationIsStableAcrossInputOrder() {
    let png = solidImageData().png
    let a = RawContentSnapshot(type: NSPasteboard.PasteboardType.fileURL.rawValue, value: URL(fileURLWithPath: "/tmp/a").dataRepresentation)
    let b = RawContentSnapshot(type: NSPasteboard.PasteboardType.fileURL.rawValue, value: URL(fileURLWithPath: "/tmp/b").dataRepresentation)
    let text = RawContentSnapshot(type: NSPasteboard.PasteboardType.string.rawValue, value: Data("t".utf8))
    let image = RawContentSnapshot(type: NSPasteboard.PasteboardType.png.rawValue, value: png)

    let forward = Clipboard.normalizedContents([a, image, text, b])
    let backward = Clipboard.normalizedContents([text, b, image, a])

    XCTAssertEqual(forward.map(\.type), backward.map(\.type))
    XCTAssertEqual(forward.compactMap(\.value), backward.compactMap(\.value))
  }

  // MARK: - makeItem

  func testMakeItemRejectsEmptySnapshots() {
    XCTAssertNil(Clipboard.makeItem(from: [], frontmostApp: nil))
    XCTAssertNil(Clipboard.makeItem(
      from: [RawContentSnapshot(type: NSPasteboard.PasteboardType.string.rawValue, value: nil)],
      frontmostApp: nil
    ))
  }

  // MARK: - Snapshot

  func testSnapshotCapturesHTML() {
    let pasteboard = makePasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setData(Data("<b>hi</b>".utf8), forType: .html)

    let snapshot = Clipboard.snapshotContents(from: pasteboard)
    XCTAssertEqual(snapshot?.map(\.type), [NSPasteboard.PasteboardType.html.rawValue])
  }

  func testSnapshotIgnoresAutoGeneratedContent() {
    let pasteboard = makePasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setString("generated", forType: .string)
    pasteboard.setString("1", forType: .autoGenerated)

    XCTAssertNil(Clipboard.snapshotContents(from: pasteboard))
  }

  func testSnapshotIgnoresUnsupportedOnlyPayloads() {
    let pasteboard = makePasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setData(Data([0x00]), forType: NSPasteboard.PasteboardType("com.example.unknown"))

    XCTAssertNil(Clipboard.snapshotContents(from: pasteboard))
  }

  func testSnapshotKeepsOnlyTheFirstImageRepresentation() {
    let pasteboard = makePasteboard()
    defer { pasteboard.releaseGlobally() }
    let images = solidImageData()
    pasteboard.clearContents()
    let item = NSPasteboardItem()
    item.setData(images.png, forType: .png)
    item.setData(images.tiff, forType: .tiff)
    pasteboard.writeObjects([item])

    let snapshot = Clipboard.snapshotContents(from: pasteboard) ?? []
    XCTAssertEqual(snapshot.count, 1)
    XCTAssertEqual(snapshot.first?.type, NSPasteboard.PasteboardType.png.rawValue)
  }

  func testDisablingTextCaptureKeepsImages() {
    let key = Preferences.Key.saveText
    let original = UserDefaults.standard.object(forKey: key)
    UserDefaults.standard.set(false, forKey: key)
    defer {
      if let original { UserDefaults.standard.set(original, forKey: key) }
      else { UserDefaults.standard.removeObject(forKey: key) }
    }

    let pasteboard = makePasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    let item = NSPasteboardItem()
    item.setData(solidImageData().png, forType: .png)
    item.setString("caption", forType: .string)
    pasteboard.writeObjects([item])

    let snapshot = Clipboard.snapshotContents(from: pasteboard) ?? []
    XCTAssertEqual(snapshot.map(\.type), [NSPasteboard.PasteboardType.png.rawValue])
  }

  func testDisablingFileCaptureAlsoSkipsTheTextCompanion() {
    let key = Preferences.Key.saveFiles
    let original = UserDefaults.standard.object(forKey: key)
    UserDefaults.standard.set(false, forKey: key)
    defer {
      if let original { UserDefaults.standard.set(original, forKey: key) }
      else { UserDefaults.standard.removeObject(forKey: key) }
    }

    let pasteboard = makePasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    let item = NSPasteboardItem()
    item.setData(URL(fileURLWithPath: "/tmp/a.txt").dataRepresentation, forType: .fileURL)
    item.setString("/tmp/a.txt", forType: .string)
    pasteboard.writeObjects([item])

    XCTAssertNil(Clipboard.snapshotContents(from: pasteboard))
  }

  func testSnapshotKeepsTextAlongsideAnImageRepresentation() {
    let pasteboard = makePasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    let item = NSPasteboardItem()
    item.setData(solidImageData().png, forType: .png)
    item.setString("caption", forType: .string)
    pasteboard.writeObjects([item])

    let snapshot = Clipboard.snapshotContents(from: pasteboard) ?? []
    XCTAssertEqual(Set(snapshot.map(\.type)), Set([
      NSPasteboard.PasteboardType.png.rawValue,
      NSPasteboard.PasteboardType.string.rawValue
    ]))
  }

  func testDisablingImageCaptureAlsoSkipsTheTextCompanion() {
    let key = Preferences.Key.saveImages
    let original = UserDefaults.standard.object(forKey: key)
    UserDefaults.standard.set(false, forKey: key)
    defer {
      if let original { UserDefaults.standard.set(original, forKey: key) }
      else { UserDefaults.standard.removeObject(forKey: key) }
    }

    let pasteboard = makePasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    let item = NSPasteboardItem()
    item.setData(solidImageData().png, forType: .png)
    item.setString("caption", forType: .string)
    pasteboard.writeObjects([item])

    XCTAssertNil(Clipboard.snapshotContents(from: pasteboard))
  }

  // MARK: - Copy

  func testCopyMixedFileAndTextProducesSeparateItems() {
    let pasteboard = makePasteboard()
    defer { pasteboard.releaseGlobally() }

    let item = HistoryItem(contents: [
      fileContent("/tmp/a.txt"),
      textContent("note")
    ])
    Clipboard(pasteboard: pasteboard).copy(item)

    let items = pasteboard.pasteboardItems ?? []
    XCTAssertEqual(items.count, 2)
    XCTAssertEqual(Set(items[0].types), Set([.fileURL, .fromPastable]))
    XCTAssertEqual(items[1].types, [.string])
    XCTAssertEqual(items[1].string(forType: .string), "note")
    XCTAssertNil(Clipboard.snapshotContents(from: pasteboard))
  }

  func testCopyImageIgnoresRemoveFormatting() {
    let key = Preferences.Key.removeFormatting
    let original = UserDefaults.standard.object(forKey: key)
    UserDefaults.standard.set(true, forKey: key)
    defer {
      if let original { UserDefaults.standard.set(original, forKey: key) }
      else { UserDefaults.standard.removeObject(forKey: key) }
    }

    let pasteboard = makePasteboard()
    defer { pasteboard.releaseGlobally() }
    let png = solidImageData().png
    let item = HistoryItem(contents: [
      HistoryItemContent(type: NSPasteboard.PasteboardType.png.rawValue, value: png)
    ])

    Clipboard(pasteboard: pasteboard).copy(item)

    XCTAssertEqual(pasteboard.data(forType: .png), png)
    XCTAssertNil(pasteboard.string(forType: .string))
  }

  func testCopyingAnEmptyItemClearsThePasteboard() {
    let pasteboard = makePasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setString("stale", forType: .string)

    Clipboard(pasteboard: pasteboard).copy(HistoryItem(contents: []))

    XCTAssertNil(pasteboard.string(forType: .string))
    XCTAssertEqual(pasteboard.pasteboardItems?.count ?? 0, 0)
  }

  func testCopyWithoutFormattingKeepsRichTextWhenThereIsNoPlainText() {
    let key = Preferences.Key.removeFormatting
    let original = UserDefaults.standard.object(forKey: key)
    UserDefaults.standard.set(true, forKey: key)
    defer {
      if let original { UserDefaults.standard.set(original, forKey: key) }
      else { UserDefaults.standard.removeObject(forKey: key) }
    }

    let pasteboard = makePasteboard()
    defer { pasteboard.releaseGlobally() }
    let html = Data("<b>rich</b>".utf8)
    let item = HistoryItem(contents: [
      HistoryItemContent(type: NSPasteboard.PasteboardType.html.rawValue, value: html)
    ])

    Clipboard(pasteboard: pasteboard).copy(item)

    XCTAssertEqual(pasteboard.data(forType: .html), html)
    XCTAssertNil(pasteboard.string(forType: .string))
  }

  func testSynchronousPasteHonoursThePreference() {
    let key = Preferences.Key.pasteAutomatically
    let original = UserDefaults.standard.object(forKey: key)
    UserDefaults.standard.set(false, forKey: key)
    defer {
      if let original { UserDefaults.standard.set(original, forKey: key) }
      else { UserDefaults.standard.removeObject(forKey: key) }
    }

    XCTAssertFalse(Clipboard(pasteboard: makePasteboard()).paste())
  }

  func testAsyncPasteHonoursThePreference() async {
    let key = Preferences.Key.pasteAutomatically
    let original = UserDefaults.standard.object(forKey: key)
    UserDefaults.standard.set(false, forKey: key)
    defer {
      if let original { UserDefaults.standard.set(original, forKey: key) }
      else { UserDefaults.standard.removeObject(forKey: key) }
    }

    let result = await Clipboard(pasteboard: makePasteboard()).paste(whenReadyFor: nil)
    XCTAssertFalse(result)
  }

  func testCopyIsMarkedSoThePollerIgnoresIt() {
    let pasteboard = makePasteboard()
    defer { pasteboard.releaseGlobally() }

    Clipboard(pasteboard: pasteboard).copy(HistoryItem(contents: [textContent("own write")]))

    XCTAssertEqual(pasteboard.string(forType: .string), "own write")
    XCTAssertNil(Clipboard.snapshotContents(from: pasteboard))
  }
}
