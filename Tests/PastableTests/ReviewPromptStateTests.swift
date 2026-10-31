import XCTest
@testable import Pastable

/// Persistence and threshold selection around the review prompt. The StoreKit
/// sheet itself is intentionally out of scope (it needs a real app session).
@MainActor
final class ReviewPromptStateTests: XCTestCase {
  private var suiteName = ""
  private var defaults: UserDefaults!

  override func setUp() {
    super.setUp()
    suiteName = "PastableTests.Review.\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: suiteName)
    defaults.removePersistentDomain(forName: suiteName)
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: suiteName)
    defaults = nil
    super.tearDown()
  }

  func testSuccessfulPasteCountStartsAtZeroAndIncrements() {
    let prompt = ReviewPrompt(defaults: defaults)
    XCTAssertEqual(prompt.successfulPasteCount, 0)

    prompt.recordSuccessfulPaste()
    prompt.recordSuccessfulPaste()

    XCTAssertEqual(prompt.successfulPasteCount, 2)
  }

  func testThresholdSelectionUsesTheHighestReachedStage() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    XCTAssertEqual(
      ReviewPromptPolicy.stageToRequest(
        successfulPastes: 19,
        lastRequestedCount: 0,
        lastRequestedAt: nil,
        now: now
      ),
      1
    )
    XCTAssertEqual(
      ReviewPromptPolicy.stageToRequest(
        successfulPastes: 20,
        lastRequestedCount: 0,
        lastRequestedAt: nil,
        now: now
      ),
      20
    )
    XCTAssertNil(
      ReviewPromptPolicy.stageToRequest(
        successfulPastes: 19,
        lastRequestedCount: 1,
        lastRequestedAt: now.addingTimeInterval(-ReviewPromptPolicy.minimumInterval * 2),
        now: now
      ),
      "stage 1 is already used, stage 20 has not been reached"
    )
  }

  func testPolicyConstantsAreStable() {
    XCTAssertEqual(ReviewPromptPolicy.thresholds, [1, 20, 80])
    XCTAssertEqual(ReviewPromptPolicy.minimumInterval, 90 * 24 * 60 * 60)
  }

  func testHighestStageIsNotRepeatedAndLowerStagesRollForward() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let longAgo = now.addingTimeInterval(-ReviewPromptPolicy.minimumInterval * 5)

    XCTAssertNil(
      ReviewPromptPolicy.stageToRequest(
        successfulPastes: 10_000,
        lastRequestedCount: 80,
        lastRequestedAt: longAgo,
        now: now
      ),
      "the highest stage must never be requested twice"
    )

    XCTAssertEqual(
      ReviewPromptPolicy.stageToRequest(
        successfulPastes: 10_000,
        lastRequestedCount: 20,
        lastRequestedAt: longAgo,
        now: now
      ),
      80,
      "a user who skipped stages rolls forward to the highest reached one"
    )
  }
}
