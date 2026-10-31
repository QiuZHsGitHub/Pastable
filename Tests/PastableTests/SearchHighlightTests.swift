import XCTest
import SwiftUI
@testable import Pastable

/// Search result presentation: which slice of a long clip a card shows and how
/// the matched characters are highlighted.
final class SearchHighlightTests: XCTestCase {
  private func highlightedCharacterCount(_ attributed: AttributedString) -> Int {
    attributed.runs.reduce(into: 0) { total, run in
      if run.backgroundColor != nil {
        total += attributed[run.range].characters.count
      }
    }
  }

  func testNoTokensMeansNoSlice() {
    XCTAssertNil(SearchHighlight.windowedSlice(of: "hello", tokens: []))
    XCTAssertNil(SearchHighlight.windowedSlice(of: "", tokens: ["hello"]))
  }

  func testVisibleHitReturnsTheHeadOfTheText() throws {
    let text = "alpha beta gamma"
    let slice = try XCTUnwrap(SearchHighlight.windowedSlice(of: text, tokens: ["beta"]))

    XCTAssertFalse(slice.isWindow)
    XCTAssertEqual(slice.text, text)
  }

  func testHeadSliceIsCappedAtVisibleLimit() throws {
    let text = String(repeating: "a", count: 4_000)
    let slice = try XCTUnwrap(SearchHighlight.windowedSlice(of: text, tokens: ["a"]))

    XCTAssertFalse(slice.isWindow)
    XCTAssertEqual(slice.text.count, SearchHighlight.visibleLimit)
  }

  func testDeepHitMovesTheWindowAroundTheMatch() throws {
    let prefix = String(repeating: "a", count: 2_500)
    let text = prefix + "needle" + String(repeating: "b", count: 2_000)

    let slice = try XCTUnwrap(SearchHighlight.windowedSlice(of: text, tokens: ["needle"]))

    XCTAssertTrue(slice.isWindow)
    XCTAssertTrue(slice.text.hasPrefix("…"))
    XCTAssertTrue(slice.text.hasSuffix("…"))
    XCTAssertTrue(slice.text.contains("needle"))
    XCTAssertEqual(slice.text.count, SearchHighlight.visibleLimit + 2)
  }

  func testEarliestTokenWinsTheWindow() throws {
    let text = String(repeating: "a", count: 2_500)
      + "first"
      + String(repeating: "b", count: 2_400)
      + "second"
    let slice = try XCTUnwrap(SearchHighlight.windowedSlice(of: text, tokens: ["second", "first"]))

    XCTAssertTrue(slice.text.contains("first"))
    XCTAssertFalse(slice.text.contains("second"), "the window is anchored on the earliest hit")
  }

  func testMatchingIsCaseAndDiacriticInsensitive() throws {
    let slice = try XCTUnwrap(SearchHighlight.windowedSlice(of: "Café service", tokens: ["cafe"]))
    XCTAssertFalse(slice.isWindow)
    XCTAssertEqual(slice.text, "Café service")
  }

  func testHitBeyondSearchLimitIsNotPresented() {
    let text = String(repeating: "a", count: SearchHighlight.searchLimit + 100) + "needle"
    XCTAssertNil(SearchHighlight.windowedSlice(of: text, tokens: ["needle"]))
  }

  func testHighlightPaintsEveryOccurrence() {
    let result = SearchHighlight.highlighted(
      "alpha beta ALPHA",
      tokens: ["alpha"],
      color: .red
    )

    XCTAssertEqual(String(result.characters), "alpha beta ALPHA")
    XCTAssertEqual(highlightedCharacterCount(result), 10)
  }

  func testHighlightHandlesMultipleTokens() {
    let result = SearchHighlight.highlighted(
      "swift and concurrency",
      tokens: ["swift", "concurrency"],
      color: .yellow
    )

    XCTAssertEqual(highlightedCharacterCount(result), 5 + 11)
  }

  func testEmptyTokenIsIgnored() {
    let result = SearchHighlight.highlighted("hello", tokens: [""], color: .red)
    XCTAssertEqual(highlightedCharacterCount(result), 0)
    XCTAssertEqual(String(result.characters), "hello")
  }

  func testHighlightKeepsRequestedTypography() {
    let result = SearchHighlight.highlighted(
      "hello",
      tokens: ["ell"],
      color: .red,
      font: .body,
      foreground: .primary
    )

    // Three highlighted characters, plus the untouched rest of the run.
    XCTAssertEqual(highlightedCharacterCount(result), 3)
    XCTAssertEqual(String(result.characters), "hello")
  }

  func testHighlightedHeadPreservesRichTextAndItsRuns() {
    var attributed = AttributedString("rich text preview")
    attributed.font = .headline

    let result = SearchHighlight.highlightedHead(attributed, tokens: ["text"], color: .blue)

    XCTAssertEqual(String(result.characters), "rich text preview")
    XCTAssertEqual(highlightedCharacterCount(result), 4)
  }

  func testHighlightedHeadIgnoresHitsPastTheVisibleLimit() {
    let text = String(repeating: "a", count: SearchHighlight.visibleLimit + 50) + "needle"
    let result = SearchHighlight.highlightedHead(
      AttributedString(text),
      tokens: ["needle"],
      color: .red
    )

    XCTAssertEqual(highlightedCharacterCount(result), 0)
  }

  func testWindowedSliceTextIsSufficientForHighlighting() throws {
    let prefix = String(repeating: "a", count: 2_500)
    let text = prefix + "needle" + String(repeating: "b", count: 500)
    let slice = try XCTUnwrap(SearchHighlight.windowedSlice(of: text, tokens: ["needle"]))

    let highlighted = SearchHighlight.highlighted(slice.text, tokens: ["needle"], color: .red)
    XCTAssertEqual(highlightedCharacterCount(highlighted), 6)
  }
}
