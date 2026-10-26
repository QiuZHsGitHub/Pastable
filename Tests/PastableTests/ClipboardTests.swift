import XCTest
import AppKit
@testable import Pastable

final class ClipboardTests: XCTestCase {
  override func setUp() {
    super.setUp()
    Preferences.registerDefaults()
  }

  private func makePasteboard() -> NSPasteboard {
    NSPasteboard(name: NSPasteboard.Name("PastableTests.\(UUID().uuidString)"))
  }

  private func fileContent(_ path: String) -> HistoryItemContent {
    HistoryItemContent(
      type: NSPasteboard.PasteboardType.fileURL.rawValue,
      value: URL(fileURLWithPath: path).dataRepresentation
    )
  }

  private func textContent(_ text: String) -> HistoryItemContent {
    HistoryItemContent(
      type: NSPasteboard.PasteboardType.string.rawValue,
      value: Data(text.utf8)
    )
  }

  /// Returns a solid image whose TIFF representation is large but whose PNG is tiny.
  private func solidImageData(size: Int = 500) -> (png: Data, tiff: Data) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
      data: nil,
      width: size,
      height: size,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(NSColor.systemBlue.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))
    let image = context.makeImage()!
    let representation = NSBitmapImageRep(cgImage: image)

    return (
      representation.representation(using: .png, properties: [:])!,
      representation.representation(using: .tiff, properties: [:])!
    )
  }

  func testSnapshotCapturesText() async {
    await MainActor.run {
      let pasteboard = self.makePasteboard()
      defer { pasteboard.releaseGlobally() }

      pasteboard.clearContents()
      pasteboard.setString("hello clipboard", forType: .string)

      let snapshot = Clipboard.snapshotContents(from: pasteboard)
      XCTAssertEqual(snapshot?.count, 1)
      XCTAssertEqual(snapshot?.first?.type, NSPasteboard.PasteboardType.string.rawValue)
      XCTAssertEqual(snapshot?.first?.value.flatMap { String(data: $0, encoding: .utf8) }, "hello clipboard")
    }
  }


  func testSnapshotIgnoresEmptyAndWhitespaceOnlyText() async {
    await MainActor.run {
      let pasteboard = self.makePasteboard()
      defer { pasteboard.releaseGlobally() }

      pasteboard.clearContents()
      pasteboard.setString("", forType: .string)
      XCTAssertNil(Clipboard.snapshotContents(from: pasteboard))

      pasteboard.clearContents()
      pasteboard.setString("  \n\t ", forType: .string)
      XCTAssertNil(Clipboard.snapshotContents(from: pasteboard))
    }
  }

  func testSnapshotIgnoresConcealedAndOwnWrites() async {
    await MainActor.run {
      let concealed = self.makePasteboard()
      defer { concealed.releaseGlobally() }
      concealed.clearContents()
      concealed.setString("secret", forType: .string)
      concealed.setString("1", forType: .concealed)
      XCTAssertNil(Clipboard.snapshotContents(from: concealed))

      let own = self.makePasteboard()
      defer { own.releaseGlobally() }
      own.clearContents()
      own.setString("own copy", forType: .string)
      own.setString("", forType: .fromPastable)
      XCTAssertNil(Clipboard.snapshotContents(from: own))
    }
  }

  func testSnapshotRespectsSaveTextPreference() async {
    let key = Preferences.Key.saveText
    let original = UserDefaults.standard.object(forKey: key)
    UserDefaults.standard.set(false, forKey: key)
    defer {
      if let original { UserDefaults.standard.set(original, forKey: key) }
      else { UserDefaults.standard.removeObject(forKey: key) }
    }

    await MainActor.run {
      let pasteboard = self.makePasteboard()
      defer { pasteboard.releaseGlobally() }
      pasteboard.clearContents()
      pasteboard.setString("text", forType: .string)

      XCTAssertNil(Clipboard.snapshotContents(from: pasteboard))
    }
  }

  func testSnapshotRespectsSaveImagesPreference() async {
    let key = Preferences.Key.saveImages
    let original = UserDefaults.standard.object(forKey: key)
    UserDefaults.standard.set(false, forKey: key)
    defer {
      if let original { UserDefaults.standard.set(original, forKey: key) }
      else { UserDefaults.standard.removeObject(forKey: key) }
    }

    await MainActor.run {
      let pasteboard = self.makePasteboard()
      defer { pasteboard.releaseGlobally() }
      pasteboard.clearContents()
      pasteboard.setData(self.solidImageData(size: 10).png, forType: .png)

      XCTAssertNil(Clipboard.snapshotContents(from: pasteboard))
    }
  }

  func testSnapshotRespectsSaveFilesPreference() async {
    let key = Preferences.Key.saveFiles
    let original = UserDefaults.standard.object(forKey: key)
    UserDefaults.standard.set(false, forKey: key)
    defer {
      if let original { UserDefaults.standard.set(original, forKey: key) }
      else { UserDefaults.standard.removeObject(forKey: key) }
    }

    await MainActor.run {
      let pasteboard = self.makePasteboard()
      defer { pasteboard.releaseGlobally() }
      pasteboard.clearContents()
      let item = NSPasteboardItem()
      item.setData(URL(fileURLWithPath: "/tmp/a.txt").dataRepresentation, forType: .fileURL)
      item.setString("/tmp/a.txt", forType: .string)
      pasteboard.writeObjects([item])

      XCTAssertNil(Clipboard.snapshotContents(from: pasteboard))
    }
  }

  func testSnapshotCapturesMultipleFileURLs() async {
    await MainActor.run {
      let pasteboard = self.makePasteboard()
      defer { pasteboard.releaseGlobally() }

      let items = ["/tmp/a.txt", "/tmp/b.txt"].map { path -> NSPasteboardItem in
        let item = NSPasteboardItem()
        item.setData(URL(fileURLWithPath: path).dataRepresentation, forType: .fileURL)
        return item
      }
      pasteboard.clearContents()
      pasteboard.writeObjects(items)

      let snapshot = Clipboard.snapshotContents(from: pasteboard) ?? []
      XCTAssertEqual(snapshot.filter { $0.type == NSPasteboard.PasteboardType.fileURL.rawValue }.count, 2)
    }
  }

  func testNormalizeConvertsLargeTIFFToPNG() {
    let data = solidImageData(size: 500)
    XCTAssertGreaterThan(data.tiff.count, 64_000)

    let normalized = Clipboard.normalizedContents([
      RawContentSnapshot(type: NSPasteboard.PasteboardType.tiff.rawValue, value: data.tiff)
    ])

    XCTAssertEqual(normalized.count, 1)
    XCTAssertEqual(normalized.first?.type, NSPasteboard.PasteboardType.png.rawValue)
    XCTAssertLessThan(normalized.first?.value?.count ?? .max, data.tiff.count)
  }

  func testNormalizePrefersPNGAndDropsTIFF() {
    let data = solidImageData(size: 10)
    let normalized = Clipboard.normalizedContents([
      RawContentSnapshot(type: NSPasteboard.PasteboardType.tiff.rawValue, value: data.tiff),
      RawContentSnapshot(type: NSPasteboard.PasteboardType.png.rawValue, value: data.png)
    ])

    XCTAssertEqual(normalized.count, 1)
    XCTAssertEqual(normalized.first?.type, NSPasteboard.PasteboardType.png.rawValue)
    XCTAssertEqual(normalized.first?.value, data.png)
  }

  func testMakeItemUsesProvidedHash() async {
    await MainActor.run {
      let snapshot = [
        RawContentSnapshot(
          type: NSPasteboard.PasteboardType.string.rawValue,
          value: Data("hello".utf8)
        )
      ]
      let item = Clipboard.makeItem(from: snapshot, frontmostApp: "com.apple.Safari", hash: "text:fixed")
      XCTAssertEqual(item?.contentHash, "text:fixed")
      XCTAssertEqual(item?.application, "com.apple.Safari")
      XCTAssertEqual(item?.text, "hello")
    }
  }

  func testCopyMultipleFilesKeepsSeparatePasteboardItems() async {
    await MainActor.run {
      let pasteboard = self.makePasteboard()
      defer { pasteboard.releaseGlobally() }

      let item = HistoryItem(contents: [
        self.fileContent("/tmp/a.txt"),
        self.fileContent("/tmp/b.txt")
      ])

      let clipboard = Clipboard(pasteboard: pasteboard)
      clipboard.copy(item)

      let pasteboardItems = pasteboard.pasteboardItems ?? []
      XCTAssertEqual(pasteboardItems.count, 2)

      let paths = Set(pasteboardItems.compactMap { item -> String? in
        guard let data = item.data(forType: .fileURL),
              let url = URL(dataRepresentation: data, relativeTo: nil, isAbsolute: true) else {
          return nil
        }
        return url.path
      })
      XCTAssertEqual(paths, ["/tmp/a.txt", "/tmp/b.txt"])
    }
  }

  func testCopyRespectsRemoveFormatting() async {
    let key = Preferences.Key.removeFormatting
    let original = UserDefaults.standard.object(forKey: key)
    UserDefaults.standard.set(true, forKey: key)
    defer {
      if let original { UserDefaults.standard.set(original, forKey: key) }
      else { UserDefaults.standard.removeObject(forKey: key) }
    }

    await MainActor.run {
      let pasteboard = self.makePasteboard()
      defer { pasteboard.releaseGlobally() }

      let item = HistoryItem(contents: [
        self.textContent("plain"),
        HistoryItemContent(
          type: NSPasteboard.PasteboardType.html.rawValue,
          value: Data("<b>plain</b>".utf8)
        )
      ])

      Clipboard(pasteboard: pasteboard).copy(item)

      XCTAssertEqual(pasteboard.string(forType: .string), "plain")
      XCTAssertFalse(pasteboard.types?.contains(.html) ?? false)
    }
  }

  func testCopyMarksPasteboardAsOwnWrite() async {
    await MainActor.run {
      let pasteboard = self.makePasteboard()
      defer { pasteboard.releaseGlobally() }

      let item = HistoryItem(contents: [self.textContent("round trip")])
      Clipboard(pasteboard: pasteboard).copy(item)

      XCTAssertEqual(pasteboard.string(forType: .string), "round trip")
      XCTAssertNil(Clipboard.snapshotContents(from: pasteboard))
    }
  }
}
