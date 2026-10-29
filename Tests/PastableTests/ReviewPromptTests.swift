import XCTest
@testable import Pastable

final class ReviewPromptTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_800_000_000)
  private var ninetyDays: TimeInterval { ReviewPromptPolicy.minimumInterval }

  func testNoPasteMeansNoPrompt() {
    XCTAssertNil(ReviewPromptPolicy.stageToRequest(
      successfulPastes: 0,
      lastRequestedCount: 0,
      lastRequestedAt: nil,
      now: now
    ))
  }

  func testFirstSuccessfulPasteQualifies() {
    XCTAssertEqual(ReviewPromptPolicy.stageToRequest(
      successfulPastes: 1,
      lastRequestedCount: 0,
      lastRequestedAt: nil,
      now: now
    ), 1)
  }

  func testFirstStageIsNotRepeated() {
    XCTAssertNil(ReviewPromptPolicy.stageToRequest(
      successfulPastes: 12,
      lastRequestedCount: 1,
      lastRequestedAt: now.addingTimeInterval(-ninetyDays * 2),
      now: now
    ))
  }

  func testSecondStageWaitsNinetyDays() {
    let last = now.addingTimeInterval(-ninetyDays + 60)
    XCTAssertNil(ReviewPromptPolicy.stageToRequest(
      successfulPastes: 20,
      lastRequestedCount: 1,
      lastRequestedAt: last,
      now: now
    ))

    XCTAssertEqual(ReviewPromptPolicy.stageToRequest(
      successfulPastes: 20,
      lastRequestedCount: 1,
      lastRequestedAt: now.addingTimeInterval(-ninetyDays),
      now: now
    ), 20)
  }

  func testThirdStageAndNoRepeat() {
    XCTAssertEqual(ReviewPromptPolicy.stageToRequest(
      successfulPastes: 80,
      lastRequestedCount: 20,
      lastRequestedAt: now.addingTimeInterval(-ninetyDays - 1),
      now: now
    ), 80)

    XCTAssertNil(ReviewPromptPolicy.stageToRequest(
      successfulPastes: 800,
      lastRequestedCount: 80,
      lastRequestedAt: now.addingTimeInterval(-ninetyDays * 3),
      now: now
    ))
  }

  func testFutureTimestampDoesNotBypassTheInterval() {
    XCTAssertNil(ReviewPromptPolicy.stageToRequest(
      successfulPastes: 20,
      lastRequestedCount: 1,
      lastRequestedAt: now.addingTimeInterval(60),
      now: now
    ))
  }
}
