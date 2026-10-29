import XCTest
import CoreGraphics
@testable import Pastable

/// The shelf only dismisses on clicks that hit empty desktop space. These tests
/// cover the WindowServer hit-test rule that decides that (`AppDelegate.isPoint`).
final class PanelDismissalTests: XCTestCase {
  private let point = CGPoint(x: 200, y: 200)

  private func window(
    layer: Int = 0,
    alpha: Double = 1,
    frame: CGRect = CGRect(x: 0, y: 0, width: 400, height: 400)
  ) -> [String: Any] {
    [
      kCGWindowLayer as String: layer,
      kCGWindowAlpha as String: alpha,
      kCGWindowBounds as String: [
        "X": frame.origin.x,
        "Y": frame.origin.y,
        "Width": frame.width,
        "Height": frame.height
      ]
    ]
  }

  func testClickOnAnotherAppWindowDoesNotDismiss() {
    XCTAssertTrue(AppDelegate.isPoint(point, coveredBy: [window()]))
  }

  func testClickOnDesktopCountsAsEmptySpace() {
    // Wallpaper and desktop icons live on negative window layers.
    XCTAssertFalse(AppDelegate.isPoint(point, coveredBy: [window(layer: -2_147_483_603)]))
  }

  func testTransparentWindowDoesNotSwallowTheClick() {
    XCTAssertFalse(AppDelegate.isPoint(point, coveredBy: [window(alpha: 0)]))
  }

  func testClickOutsideWindowBoundsCountsAsEmptySpace() {
    let offscreen = CGRect(x: 500, y: 500, width: 100, height: 100)
    XCTAssertFalse(AppDelegate.isPoint(point, coveredBy: [window(frame: offscreen)]))
  }

  func testAnyCoveringWindowWins() {
    let offscreen = CGRect(x: 500, y: 500, width: 100, height: 100)
    XCTAssertTrue(AppDelegate.isPoint(point, coveredBy: [
      window(layer: -2_147_483_603),
      window(alpha: 0),
      window(frame: offscreen),
      window(layer: 25) // status bar / panel level
    ]))
  }
}
