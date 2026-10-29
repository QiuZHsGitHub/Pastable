import XCTest
import CoreGraphics
@testable import Pastable

/// Clicking anywhere outside the shelf dismisses it, except clicks on
/// Pastable's own windows (status item, Settings, popover/menu). These tests
/// cover the WindowServer hit-test that recognizes those own windows
/// (`AppDelegate.isPoint(_:coveredBy:ownedBy:)`).
final class PanelDismissalTests: XCTestCase {
  private let point = CGPoint(x: 200, y: 200)
  private let ownPID = 4242

  private func window(
    pid: Int? = nil,
    alpha: Double = 1,
    frame: CGRect = CGRect(x: 0, y: 0, width: 400, height: 400)
  ) -> [String: Any] {
    [
      kCGWindowOwnerPID as String: pid ?? ownPID,
      kCGWindowAlpha as String: alpha,
      kCGWindowBounds as String: [
        "X": frame.origin.x,
        "Y": frame.origin.y,
        "Width": frame.width,
        "Height": frame.height
      ]
    ]
  }

  func testClickOnOwnWindowKeepsThePanel() {
    XCTAssertTrue(AppDelegate.isPoint(point, coveredBy: [window()], ownedBy: ownPID))
  }

  func testClickOnAnotherAppsWindowDismisses() {
    XCTAssertFalse(AppDelegate.isPoint(point, coveredBy: [window(pid: ownPID + 1)], ownedBy: ownPID))
  }

  func testTransparentOwnWindowDoesNotKeepThePanel() {
    XCTAssertFalse(AppDelegate.isPoint(point, coveredBy: [window(alpha: 0)], ownedBy: ownPID))
  }

  func testClickOutsideOwnWindowBoundsDismisses() {
    let offscreen = CGRect(x: 500, y: 500, width: 100, height: 100)
    XCTAssertFalse(AppDelegate.isPoint(point, coveredBy: [window(frame: offscreen)], ownedBy: ownPID))
  }
}
