import XCTest
import AppKit
@testable import Pastable

final class AppStateTests: XCTestCase {
  func testBlankTextItemsAreHiddenFromDisplay() async {
    await MainActor.run {
      let state = AppState()

      let blank = HistoryItem(contents: [
        HistoryItemContent(
          type: NSPasteboard.PasteboardType.string.rawValue,
          value: Data()
        )
      ])
      let text = HistoryItem(contents: [
        HistoryItemContent(
          type: NSPasteboard.PasteboardType.string.rawValue,
          value: Data("real content".utf8)
        )
      ])

      state.updateItems([blank, text])

      XCTAssertEqual(state.displayItems.count, 1)
      XCTAssertEqual(state.displayItems.first?.title, "real content")
    }
  }
}
