import XCTest
import AppKit
import SwiftUI
@testable import Pastable

/// User-facing error text and the small display helpers around it.
final class UtilityExtensionTests: XCTestCase {
  private let underlying = NSError(
    domain: "PastableTests",
    code: 42,
    userInfo: [NSLocalizedDescriptionKey: "boom"]
  )

  func testAppErrorDescriptionsAndRecoverySuggestions() {
    let cases: [(AppError, String)] = [
      (.storageInitializationFailed(underlying: underlying), "无法初始化数据库"),
      (.clipboardAccessDenied, "无法访问剪贴板"),
      (.clipboardReadFailed(reason: "denied"), "读取剪贴板失败：denied"),
      (.itemStorageFailed(reason: "disk full"), "保存项目失败：disk full"),
      (.itemRetrievalFailed(reason: "timeout"), "获取项目失败：timeout"),
      (.invalidContent(reason: "empty"), "无效的内容：empty"),
      (.imageProcessingFailed(reason: "bad bytes"), "图片处理失败：bad bytes")
    ]

    for (error, expected) in cases {
      let description = error.errorDescription ?? ""
      XCTAssertTrue(description.contains(expected), "unexpected description: \(description)")
      XCTAssertFalse(error.recoverySuggestion?.isEmpty ?? true)
    }
  }

  func testAppErrorExposesTheUnderlyingError() {
    let error = AppError.storageInitializationFailed(underlying: underlying)
    let exposed = error.underlyingError as NSError?
    XCTAssertEqual(exposed?.domain, "PastableTests")
    XCTAssertEqual(exposed?.code, 42)
  }

  func testClipboardErrorDescriptionsAndRecoverySuggestions() {
    let cases: [(ClipboardError, String)] = [
      (.pasteboardUnavailable, "剪贴板不可用"),
      (.invalidContentType, "不支持的内容类型"),
      (.dataExtractionFailed(reason: "bad data"), "提取数据失败：bad data"),
      (.noPlainTextToPaste, "无法获取纯文本")
    ]

    for (error, expected) in cases {
      XCTAssertTrue((error.errorDescription ?? "").contains(expected))
      XCTAssertFalse(error.recoverySuggestion?.isEmpty ?? true)
    }
  }

  func testStorageErrorDescriptionsIncludeTheReason() {
    XCTAssertTrue(
      (StorageError.fetchFailed(underlying: underlying).errorDescription ?? "").contains("boom")
    )
    XCTAssertTrue(
      (StorageError.cleanupFailed(underlying: underlying).errorDescription ?? "")
        .contains("清理数据失败")
    )
    XCTAssertTrue(
      (StorageError.containerInitializationFailed(underlying: underlying).errorDescription ?? "")
        .contains("无法初始化数据库")
    )
  }

  func testAttributedStringWithoutBackgroundHasNoColor() {
    XCTAssertNil(NSAttributedString(string: "").effectiveBackgroundColor)
    XCTAssertNil(NSAttributedString(string: "plain").effectiveBackgroundColor)
  }

  func testAttributedStringTransparentBackgroundIsIgnored() {
    let attributed = NSAttributedString(
      string: "clear",
      attributes: [.backgroundColor: NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 0)]
    )
    XCTAssertNil(attributed.effectiveBackgroundColor)
  }

  func testAttributedStringOpaqueBackgroundIsReported() {
    let attributed = NSAttributedString(
      string: "red",
      attributes: [.backgroundColor: NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)]
    )
    XCTAssertEqual(attributed.effectiveBackgroundColor?.toHex(), "#FF0000")
  }

  func testShortenedHandlesNegativeAndExactLengths() {
    XCTAssertEqual("abcdef".shortened(to: -1), "")
    XCTAssertEqual("abcdef".shortened(to: 6), "abcdef")
    XCTAssertEqual("".shortened(to: 5), "")
  }

  func testTimeAgoDisplayIsNeverEmpty() {
    XCTAssertFalse(Date().timeAgoDisplay().isEmpty)
    XCTAssertFalse(Date(timeIntervalSinceNow: -2 * 86_400).timeAgoDisplay().isEmpty)
    XCTAssertFalse(Date(timeIntervalSinceNow: 3_600).timeAgoDisplay().isEmpty)
  }

  func testTimeAgoDisplayIsStableForTheSameDate() {
    let date = Date(timeIntervalSinceNow: -125)
    XCTAssertEqual(date.timeAgoDisplay(), date.timeAgoDisplay())
  }

  func testRawContentSnapshotCarriesOptionalPayloads() {
    let snapshot = RawContentSnapshot(type: "public.utf8-plain-text", value: Data("x".utf8))
    XCTAssertEqual(snapshot.type, "public.utf8-plain-text")
    XCTAssertEqual(snapshot.value, Data("x".utf8))

    let empty = RawContentSnapshot(type: "public.rtf", value: nil)
    XCTAssertNil(empty.value)
  }
}
