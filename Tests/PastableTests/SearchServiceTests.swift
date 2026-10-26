import XCTest
import AppKit
@testable import Pastable

final class SearchServiceTests: XCTestCase {
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

  func testEmptyQueryReturnsAllItems() {
    let items = [makeItem(title: "one"), makeItem(title: "two")]
    XCTAssertEqual(SearchService.shared.search(query: "", items: items).count, 2)
  }

  func testExactModeMatchesCaseInsensitively() {
    let items = [makeItem(title: "Swift Concurrency"), makeItem(title: "Kotlin Coroutines")]
    let results = SearchService.shared.search(query: "swift", items: items, mode: .exact)
    XCTAssertEqual(results.map(\.title), ["Swift Concurrency"])
  }

  func testExactModeRequiresEveryToken() {
    let items = [
      makeItem(title: "Swift 5.9 release notes"),
      makeItem(title: "Swift release notes")
    ]
    let results = SearchService.shared.search(query: "swift 5.9", items: items, mode: .exact)
    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results.first?.title, "Swift 5.9 release notes")
  }

  func testFuzzyModeFindsSubsequence() {
    let items = [makeItem(title: "Swift Concurrency"), makeItem(title: "Java Streams")]
    let results = SearchService.shared.search(query: "swft", items: items, mode: .fuzzy)
    XCTAssertEqual(results.map(\.title), ["Swift Concurrency"])
  }

  func testFuzzyModeDoesNotMatchUnrelatedText() {
    let items = [makeItem(title: "Swift Concurrency")]
    XCTAssertTrue(SearchService.shared.search(query: "xyz", items: items, mode: .fuzzy).isEmpty)
  }

  func testTitleHitsRankAboveBodyHits() {
    let titleHit = makeItem(title: "alpha", body: "body")
    let bodyHit = makeItem(title: "body", body: "alpha")
    let results = SearchService.shared.search(query: "alpha", items: [bodyHit, titleHit], mode: .exact)
    XCTAssertEqual(results.first?.title, "alpha")
  }

  func testSearchesFullBodyBeyondTruncatedTitle() {
    let body = String(repeating: "header ", count: 300) + "needle-in-the-middle"
    let item = makeItem(title: "header", body: body)
    XCTAssertEqual(item.title.count <= 1_001, true)

    let results = SearchService.shared.search(query: "needle-in-the-middle", items: [item], mode: .exact)
    XCTAssertEqual(results.count, 1)
  }

  func testChineseSubstringSearch() {
    let items = [makeItem(title: "明天下午三点开会"), makeItem(title: "买咖啡")]
    let results = SearchService.shared.search(query: "下午", items: items, mode: .exact)
    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results.first?.title, "明天下午三点开会")
  }

  func testRecencyBreaksTies() {
    let older = makeItem(title: "same", age: 3_600)
    let newer = makeItem(title: "same", age: 10)
    let results = SearchService.shared.search(query: "same", items: [older, newer], mode: .exact)
    XCTAssertEqual(results.first?.lastCopiedAt, newer.lastCopiedAt)
  }

  func testRepeatedCopiesRankHigher() {
    let frequent = makeItem(title: "same", copies: 12)
    let rare = makeItem(title: "same", copies: 1)
    frequent.lastCopiedAt = rare.lastCopiedAt
    let results = SearchService.shared.search(query: "same", items: [rare, frequent], mode: .exact)
    XCTAssertEqual(results.first?.numberOfCopies, 12)
  }
}
