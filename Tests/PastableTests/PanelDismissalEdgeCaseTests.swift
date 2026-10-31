import XCTest
import CoreGraphics
@testable import Pastable

/// Boundary cases for the WindowServer hit-test used to decide whether an
/// outside click should dismiss the shelf.
final class PanelDismissalEdgeCaseTests: XCTestCase {
  private let ownPID = 7_777
  private let point = CGPoint(x: 100, y: 100)

  private func window(
    pid: Int? = nil,
    alpha: Double = 1,
    bounds: [String: Any]? = ["X": 0, "Y": 0, "Width": 200, "Height": 200]
  ) -> [String: Any] {
    var value: [String: Any] = [
      kCGWindowOwnerPID as String: pid ?? ownPID,
      kCGWindowAlpha as String: alpha
    ]
    if let bounds {
      value[kCGWindowBounds as String] = bounds
    }
    return value
  }

  func testAlphaExactlyAtTheThresholdIsTreatedAsInvisible() {
    XCTAssertFalse(
      AppDelegate.isPoint(point, coveredBy: [window(alpha: 0.01)], ownedBy: ownPID)
    )
    XCTAssertTrue(
      AppDelegate.isPoint(point, coveredBy: [window(alpha: 0.02)], ownedBy: ownPID)
    )
  }

  func testZeroSizedWindowNeverCoversAPoint() {
    let degenerate = ["X": 100, "Y": 100, "Width": 0, "Height": 0]
    XCTAssertFalse(
      AppDelegate.isPoint(point, coveredBy: [window(bounds: degenerate)], ownedBy: ownPID)
    )
  }

  func testWindowBoundsAreHalfOpen() {
    let bounds = ["X": 0, "Y": 0, "Width": 100, "Height": 100]
    XCTAssertTrue(
      AppDelegate.isPoint(CGPoint(x: 0, y: 0), coveredBy: [window(bounds: bounds)], ownedBy: ownPID)
    )
    XCTAssertFalse(
      AppDelegate.isPoint(CGPoint(x: 100, y: 100), coveredBy: [window(bounds: bounds)], ownedBy: ownPID)
    )
  }

  func testMissingBoundsAreSkipped() {
    XCTAssertFalse(
      AppDelegate.isPoint(point, coveredBy: [window(bounds: nil)], ownedBy: ownPID)
    )
  }

  func testMissingOwnerPIDIsSkipped() {
    var value = window()
    value.removeValue(forKey: kCGWindowOwnerPID as String)
    XCTAssertFalse(AppDelegate.isPoint(point, coveredBy: [value], ownedBy: ownPID))
  }

  func testAnyCoveringOwnWindowWins() {
    let windows = [
      window(bounds: ["X": 500, "Y": 500, "Width": 100, "Height": 100]),
      window(bounds: ["X": 0, "Y": 0, "Width": 300, "Height": 300])
    ]
    XCTAssertTrue(AppDelegate.isPoint(point, coveredBy: windows, ownedBy: ownPID))
  }

  func testOtherAppsWindowsNeverCount() {
    let windows = [
      window(pid: ownPID + 1, bounds: ["X": 0, "Y": 0, "Width": 300, "Height": 300]),
      window(pid: ownPID + 2, bounds: ["X": 0, "Y": 0, "Width": 300, "Height": 300])
    ]
    XCTAssertFalse(AppDelegate.isPoint(point, coveredBy: windows, ownedBy: ownPID))
  }

  func testEmptyWindowListDoesNotCoverThePoint() {
    XCTAssertFalse(AppDelegate.isPoint(point, coveredBy: [], ownedBy: ownPID))
  }
}
