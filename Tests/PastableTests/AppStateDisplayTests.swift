import XCTest
import AppKit
@testable import Pastable

/// Filtering, lazily grown display window and keyboard selection in `AppState`.
@MainActor
final class AppStateDisplayTests: XCTestCase {
  private func item(_ text: String, at date: Date = Date()) -> HistoryItem {
    let item = HistoryItem(contents: [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: Data(text.utf8)
      )
    ])
    item.lastCopiedAt = date
    return item
  }

  private func codeItem(_ text: String = "func f() { return 1 }") -> HistoryItem {
    item(text)
  }

  private func linkItem(_ text: String = "https://example.com/docs") -> HistoryItem {
    item(text)
  }

  private func imageItem() -> HistoryItem {
    HistoryItem(contents: [
      HistoryItemContent(type: NSPasteboard.PasteboardType.png.rawValue, value: Data([0x89, 0x50]))
    ])
  }

  private func fileItem() -> HistoryItem {
    HistoryItem(contents: [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.fileURL.rawValue,
        value: URL(fileURLWithPath: "/tmp/report.pdf").dataRepresentation
      )
    ])
  }

  func testUpdateItemsSortsNewestFirst() {
    let state = AppState()
    let oldest = item("oldest", at: Date(timeIntervalSinceNow: -300))
    let middle = item("middle", at: Date(timeIntervalSinceNow: -200))
    let newest = item("newest", at: Date(timeIntervalSinceNow: -100))

    state.updateItems([oldest, newest, middle])

    XCTAssertEqual(state.displayItems.map(\.title), ["newest", "middle", "oldest"])
  }

  func testUpdateItemsDeduplicatesTheSamePersistentInstance() {
    let state = AppState()
    let duplicate = item("only once")

    state.updateItems([duplicate, duplicate])

    XCTAssertEqual(state.displayItems.count, 1)
  }

  func testUpdateItemsHidesEffectivelyEmptyRecords() {
    let state = AppState()
    let blank = HistoryItem(contents: [
      HistoryItemContent(type: NSPasteboard.PasteboardType.string.rawValue, value: Data("  \n".utf8))
    ])
    let real = item("real")

    state.updateItems([blank, real])

    XCTAssertEqual(state.displayItems.map(\.title), ["real"])
  }

  func testUpdateItemsClearsStaleSelection() {
    let state = AppState()
    let first = item("first", at: Date(timeIntervalSinceNow: -10))
    let second = item("second")
    state.updateItems([first, second])
    state.selectedItemID = first.persistentModelID

    state.updateItems([second])

    XCTAssertNil(state.selectedItemID)
    XCTAssertNil(state.hoveredItemID)
  }

  func testCategoryFiltersGroupByClassification() {
    let state = AppState()
    let text = item("hello world", at: Date(timeIntervalSinceNow: -5))
    let code = codeItem()
    let link = linkItem()
    let image = imageItem()
    let file = fileItem()

    state.updateItems([text, code, link, image, file])
    XCTAssertEqual(state.displayItems.count, 5)

    state.selectedCategory = "Text"
    XCTAssertEqual(state.displayItems.map(\.title), ["hello world"])

    state.selectedCategory = "Code"
    XCTAssertEqual(state.displayItems.map(\.title), [code.title])

    // File URLs also satisfy the link detector, so Links may contain both.
    state.selectedCategory = "Links"
    XCTAssertEqual(
      Set(state.displayItems.map(\.title)),
      Set(["https://example.com/docs", "report.pdf"])
    )

    state.selectedCategory = "Others"
    XCTAssertEqual(
      Set(state.displayItems.map(\.title)),
      Set([image.title, file.title])
    )
  }

  func testUnknownCategoryShowsEverything() {
    let state = AppState()
    state.updateItems([item("a"), codeItem(), imageItem()])

    state.selectedCategory = "SomethingElse"

    XCTAssertEqual(state.displayItems.count, 3)
  }

  func testCategoryFilterCombinesWithSearch() {
    let state = AppState()
    let textMatch = item("needle in prose")
    let codeMatch = codeItem("func needle() { return 1 }")
    let codeMiss = codeItem("func other() { return 1 }")

    state.updateItems([textMatch, codeMatch, codeMiss])
    state.searchText = "needle"
    state.performSearch(query: "needle")

    state.selectedCategory = "Code"
    XCTAssertEqual(state.displayItems.map(\.title), [codeMatch.title])

    state.selectedCategory = "Text"
    XCTAssertEqual(state.displayItems.map(\.title), [textMatch.title])
  }

  func testSearchUpdatesTokensAndFilteredResults() {
    let state = AppState()
    state.updateItems([item("alpha beta"), item("gamma")])

    state.searchText = "alpha beta"
    state.performSearch(query: "alpha beta")

    XCTAssertEqual(state.searchTokens, ["alpha", "beta"])
    XCTAssertEqual(state.displayItems.count, 1)
  }

  func testClearingSearchRestoresEveryItem() {
    let state = AppState()
    state.updateItems([item("alpha"), item("beta")])
    state.searchText = "alpha"
    state.performSearch(query: "alpha")
    XCTAssertEqual(state.displayItems.count, 1)

    state.searchText = "   "
    state.performSearch(query: "   ")

    XCTAssertTrue(state.searchTokens.isEmpty)
    XCTAssertEqual(state.displayItems.count, 2)
  }

  func testDisplayWindowStartsAtOneBatchAndGrows() {
    let state = AppState()
    let items = (0..<135).map { index in
      item("item \(index)", at: Date(timeIntervalSinceNow: -Double(index)))
    }
    state.updateItems(items)

    XCTAssertEqual(state.displayItems.count, AppState.displayWindowBatchSize)
    XCTAssertFalse(state.displayItems.contains { $0.title == "item 120" })

    state.expandDisplayWindow()
    XCTAssertEqual(state.displayItems.count, 135)

    state.expandDisplayWindow()
    XCTAssertEqual(state.displayItems.count, 135, "expansion is a no-op once everything is visible")
  }

  func testDisplayWindowExpandsOnlyNearItsEnd() {
    let state = AppState()
    let items = (0..<130).map { index in
      item("item \(index)", at: Date(timeIntervalSinceNow: -Double(index)))
    }
    state.updateItems(items)

    state.expandDisplayWindowIfNeeded(around: state.displayItems[5].persistentModelID)
    XCTAssertEqual(state.displayItems.count, 120)

    state.expandDisplayWindowIfNeeded(around: state.displayItems[115].persistentModelID)
    XCTAssertEqual(state.displayItems.count, 130)
  }

  func testMoveSelectionStartsAtTheFirstItemAndClamps() {
    let state = AppState()
    let items = (0..<5).map { index in
      item("sel \(index)", at: Date(timeIntervalSinceNow: -Double(index)))
    }
    state.updateItems(items)

    state.moveSelection(by: 1)
    XCTAssertEqual(state.selectedIndex, 0)

    state.moveSelection(by: 2)
    XCTAssertEqual(state.selectedIndex, 2)

    state.moveSelection(by: -100)
    XCTAssertEqual(state.selectedIndex, 0)

    state.moveSelection(by: 100)
    XCTAssertEqual(state.selectedIndex, 4)
  }

  func testMoveSelectionWalksPastTheLoadedWindow() {
    let state = AppState()
    let items = (0..<130).map { index in
      item("walk \(index)", at: Date(timeIntervalSinceNow: -Double(index)))
    }
    state.updateItems(items)
    state.selectedItemID = state.displayItems[119].persistentModelID

    state.moveSelection(by: 1)

    XCTAssertEqual(state.displayItems.count, 130)
    XCTAssertEqual(state.selectedIndex, 120)
  }

  func testSelectionHelpers() {
    let state = AppState()
    let first = item("first", at: Date(timeIntervalSinceNow: -10))
    let second = item("second")
    state.updateItems([first, second])

    state.selectFirstIfNeeded()
    XCTAssertEqual(state.selectedIndex, 0)

    state.selectFirstIfNeeded()
    XCTAssertEqual(state.selectedIndex, 0, "an existing selection is preserved")

    XCTAssertTrue(state.item(with: first.persistentModelID) === first)

    state.resetSelection()
    XCTAssertNil(state.selectedItemID)
    XCTAssertNil(state.hoveredItemID)
  }

  func testEmptyHistoryHasNoSelection() {
    let state = AppState()
    state.updateItems([])

    state.moveSelection(by: 1)
    state.selectFirstIfNeeded()

    XCTAssertNil(state.selectedItemID)
    XCTAssertNil(state.selectedIndex)
    XCTAssertTrue(state.displayItems.isEmpty)
  }
}
