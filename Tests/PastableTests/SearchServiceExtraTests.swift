import XCTest
import AppKit
@testable import Pastable

/// Additional search rules: folding, mode differences, ranking and query
/// tokenization. Complements `SearchServiceTests`.
final class SearchServiceExtraTests: XCTestCase {
  private func makeItem(
    title: String,
    body: String? = nil,
    age: TimeInterval = 0,
    copies: Int = 1
  ) -> HistoryItem {
    let text = body ?? title
    let item = HistoryItem(contents: [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: Data(text.utf8)
      )
    ])
    item.title = title
    item.lastCopiedAt = Date().addingTimeInterval(-age)
    item.numberOfCopies = copies
    return item
  }

  func testTokensFoldCaseAndSplitWhitespace() {
    XCTAssertEqual(
      SearchService.tokens(for: "  Swift   CONCURRENCY \n"),
      ["swift", "concurrency"]
    )
  }

  func testWhitespaceOnlyQueryHasNoTokens() {
    XCTAssertTrue(SearchService.tokens(for: "   \n\t ").isEmpty)
    let items = [makeItem(title: "one"), makeItem(title: "two")]
    XCTAssertEqual(SearchService.shared.search(query: "   ", items: items).count, 2)
  }

  func testDiacriticInsensitiveMatching() {
    let items = [makeItem(title: "Café con leche"), makeItem(title: "Tea")]
    XCTAssertEqual(
      SearchService.shared.search(query: "cafe", items: items, mode: .exact).map(\.title),
      ["Café con leche"]
    )
  }

  func testWidthInsensitiveMatching() {
    let items = [makeItem(title: "Ｓｗｉｆｔ Concurrency")]
    XCTAssertEqual(
      SearchService.shared.search(query: "swift", items: items, mode: .exact).count,
      1
    )
  }

  func testExactModeRejectsFuzzySubsequence() {
    let items = [makeItem(title: "Swift Concurrency")]
    XCTAssertTrue(
      SearchService.shared.search(query: "swft", items: items, mode: .exact).isEmpty
    )
  }

  func testFuzzyModeMatchesBodySubsequence() {
    let items = [makeItem(title: "notes", body: "swift concurrency deep dive")]
    XCTAssertEqual(
      SearchService.shared.search(query: "swc", items: items, mode: .fuzzy).map(\.title),
      ["notes"]
    )
  }

  func testTokensCanMatchAcrossTitleAndBody() {
    let items = [makeItem(title: "alpha notes", body: "the beta release")]
    XCTAssertEqual(
      SearchService.shared.search(query: "alpha beta", items: items, mode: .exact).count,
      1
    )
  }

  func testMissingTokenRejectsTheRecord() {
    let items = [makeItem(title: "alpha notes", body: "the beta release")]
    XCTAssertTrue(
      SearchService.shared.search(query: "alpha gamma", items: items, mode: .exact).isEmpty
    )
  }

  func testPrefixHitRanksAboveMidWordHit() {
    let prefix = makeItem(title: "swift guide")
    let midWord = makeItem(title: "bswift guide")
    let results = SearchService.shared.search(query: "swift", items: [midWord, prefix], mode: .exact)

    XCTAssertEqual(results.first?.title, "swift guide")
  }

  func testBodyHitInTheLatestItemStillRanksAfterOlderTitleHits() {
    let olderTitleHit = makeItem(title: "needle", age: 7 * 86_400)
    let newerBodyHit = makeItem(title: "haystack", body: "needle", age: 0)
    let results = SearchService.shared.search(
      query: "needle",
      items: [newerBodyHit, olderTitleHit],
      mode: .exact
    )

    XCTAssertEqual(results.first?.title, "needle")
  }

  func testSearchPreservesAllMatches() {
    let items = (0..<5).map { makeItem(title: "match \($0)") }
    XCTAssertEqual(SearchService.shared.search(query: "match", items: items, mode: .exact).count, 5)
  }

  func testSearchDoesNotMutateInputOrderForEmptyQuery() {
    let items = [makeItem(title: "b"), makeItem(title: "a"), makeItem(title: "c")]
    XCTAssertEqual(
      SearchService.shared.search(query: "", items: items).map(\.title),
      ["b", "a", "c"]
    )
  }

  func testCJKCaseAndWidthFoldingIsStable() {
    XCTAssertEqual(SearchService.fold("ＡＢＣ"), SearchService.fold("abc"))
    XCTAssertEqual(SearchService.fold("开会"), "开会")
  }

  func testLongBodyIsSearchablePastTheTitleCap() {
    let body = String(repeating: "filler ", count: 700) + "uniquetail"
    let item = makeItem(title: "title", body: body)

    XCTAssertEqual(
      SearchService.shared.search(query: "uniquetail", items: [item], mode: .exact).count,
      1
    )
  }
}
