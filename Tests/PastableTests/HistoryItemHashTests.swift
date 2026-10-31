import XCTest
import AppKit
@testable import Pastable

/// Content-identity rules: the hash is the dedupe key, so these tests pin down
/// exactly which payload wins and which representations must be ignored.
final class HistoryItemHashTests: XCTestCase {
  private func content(_ type: NSPasteboard.PasteboardType, _ data: Data) -> HistoryItemContent {
    HistoryItemContent(type: type.rawValue, value: data)
  }

  private func item(_ contents: [HistoryItemContent]) -> HistoryItem {
    HistoryItem(contents: contents)
  }

  private func rtf(_ text: String, bold: Bool = false) throws -> Data {
    let attributed = NSMutableAttributedString(string: text)
    if bold {
      attributed.addAttribute(
        .font,
        value: NSFont.boldSystemFont(ofSize: 14),
        range: NSRange(location: 0, length: attributed.length)
      )
    }
    return try attributed.data(
      from: NSRange(location: 0, length: attributed.length),
      documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
    )
  }

  func testSamePlainTextAlwaysHashesIdentically() {
    let first = item([content(.string, Data("hello".utf8))])
    let second = item([content(.string, Data("hello".utf8))])

    XCTAssertEqual(first.contentHash, second.contentHash)
    XCTAssertTrue(first.contentHash?.hasPrefix("text:") == true)
  }

  func testHashIsSensitiveToTextContent() {
    let hello = item([content(.string, Data("hello".utf8))])
    let world = item([content(.string, Data("world".utf8))])

    XCTAssertNotEqual(hello.contentHash, world.contentHash)
  }

  func testEmptyStringFallsThroughToImageRepresentation() {
    let imageBytes = Data([0x89, 0x50, 0x4E, 0x47, 0x00])
    let item = item([
      content(.string, Data()),
      content(.png, imageBytes)
    ])

    XCTAssertTrue(item.contentHash?.hasPrefix("image:") == true)
  }

  func testImageHashUsesImagePayloadNotOtherRepresentations() {
    let imageBytes = Data([0x01, 0x02, 0x03, 0x04])
    let withHTML = item([
      content(.png, imageBytes),
      content(.html, Data("<img src='x'>".utf8))
    ])
    let imageOnly = item([content(.png, imageBytes)])

    XCTAssertEqual(withHTML.contentHash, imageOnly.contentHash)
  }

  func testPNGAndTIFFWithDifferentBytesHashDifferently() {
    let png = item([content(.png, Data([0x01]))])
    let tiff = item([content(.tiff, Data([0x02]))])

    XCTAssertNotEqual(png.contentHash, tiff.contentHash)
  }

  func testFileHashIsIndependentOfURLOrder() throws {
    let a = try XCTUnwrap(URL(fileURLWithPath: "/tmp/a.txt").dataRepresentation)
    let b = try XCTUnwrap(URL(fileURLWithPath: "/tmp/b.txt").dataRepresentation)

    let forward = item([content(.fileURL, a), content(.fileURL, b)])
    let backward = item([content(.fileURL, b), content(.fileURL, a)])

    XCTAssertEqual(forward.contentHash, backward.contentHash)
    XCTAssertTrue(forward.contentHash?.hasPrefix("files:") == true)
  }

  func testFileHashIncludesEveryFile() throws {
    let a = try XCTUnwrap(URL(fileURLWithPath: "/tmp/a.txt").dataRepresentation)
    let b = try XCTUnwrap(URL(fileURLWithPath: "/tmp/b.txt").dataRepresentation)

    let oneFile = item([content(.fileURL, a)])
    let twoFiles = item([content(.fileURL, a), content(.fileURL, b)])

    XCTAssertNotEqual(oneFile.contentHash, twoFiles.contentHash)
  }

  func testRTFHashIgnoresFormattingOnly() async throws {
    let plain = try rtf("same string")
    let bold = try rtf("same string", bold: true)

    await MainActor.run {
      let plainItem = item([content(.rtf, plain)])
      let boldItem = item([content(.rtf, bold)])

      XCTAssertTrue(plainItem.contentHash?.hasPrefix("rtf:") == true)
      XCTAssertEqual(plainItem.contentHash, boldItem.contentHash)
    }
  }

  func testHTMLHashUsesVisibleText() async {
    await MainActor.run {
      let bold = item([content(.html, Data("<b>visible</b>".utf8))])
      let italic = item([content(.html, Data("<i>visible</i>".utf8))])

      XCTAssertTrue(bold.contentHash?.hasPrefix("html:") == true)
      XCTAssertEqual(bold.contentHash, italic.contentHash)
    }
  }

  func testRawFallbackHashesUnknownTypes() {
    let unknown = NSPasteboard.PasteboardType("com.example.private-payload")
    let first = item([content(unknown, Data([0x10, 0x20]))])
    let second = item([content(unknown, Data([0x10, 0x20]))])
    let other = item([content(unknown, Data([0x30, 0x40]))])

    XCTAssertTrue(first.contentHash?.hasPrefix("raw:") == true)
    XCTAssertEqual(first.contentHash, second.contentHash)
    XCTAssertNotEqual(first.contentHash, other.contentHash)
  }

  func testEmptyContentsProduceNoHash() {
    XCTAssertEqual(item([]).contentHash, "")
  }

  func testNilValuedPayloadsProduceNoHash() {
    let empty = HistoryItemContent(type: "com.example.empty", value: nil)
    XCTAssertEqual(item([empty]).contentHash, "")
  }

  func testRawSnapshotHashMatchesModelHash() {
    let snapshots = [
      RawContentSnapshot(type: NSPasteboard.PasteboardType.string.rawValue, value: Data("snapshot".utf8))
    ]
    XCTAssertEqual(
      HistoryItem.computeContentHash(rawContents: snapshots),
      item([content(.string, Data("snapshot".utf8))]).contentHash
    )
  }

  func testSupersedesIgnoresTransientTypesOnTheCandidate() {
    let existing = item([content(.string, Data("hello".utf8))])
    let candidate = item([
      content(.notesRichText, Data("volatile".utf8)),
      content(.string, Data("hello".utf8))
    ])

    XCTAssertTrue(existing.supersedes(candidate))
  }

  func testSupersedesRejectsCandidateWithExtraRealContent() {
    let existing = item([content(.string, Data("hello".utf8))])
    let candidate = item([
      content(.string, Data("hello".utf8)),
      content(.html, Data("<b>hello</b>".utf8))
    ])

    XCTAssertFalse(existing.supersedes(candidate))
  }

  func testSupersedesRejectsDifferentBytesForSameType() {
    let existing = item([content(.string, Data("hello".utf8))])
    let candidate = item([content(.string, Data("hello!".utf8))])

    XCTAssertFalse(existing.supersedes(candidate))
  }
}
