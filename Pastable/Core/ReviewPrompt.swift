import AppKit
import Foundation
import StoreKit

/// Coordinates the App Store review request.
///
/// Rules of the road:
/// - **Never at launch.** A fresh install has not delivered value yet; asking
///   then is the fastest way to collect a one-star review.
/// - **Only after a successful paste.** Copying a card is not the same as
///   seeing it land in the document, so only an actually posted Cmd+V counts.
/// - **Presented on a later panel open.** After a paste the shelf is closed and
///   the target app has focus, so the system prompt is deferred until the next
///   time the panel is visible and Pastable can legitimately host it.
/// - **At most three attempts a year.** StoreKit already rate-limits the system
///   prompt; the extra thresholds (1 / 20 / 80 successful pastes, 90 days
///   apart) keep us well inside that budget and give early users another chance
///   after they have lived with the app for a while.
@MainActor
final class ReviewPrompt {
  static let shared = ReviewPrompt()

  private enum Key {
    static let successfulPastes = "review.successfulPastes"
    static let lastRequestedAt = "review.lastRequestedAt"
    static let lastRequestedCount = "review.lastRequestedCount"
  }

  private let defaults: UserDefaults
  private var isPresenting = false

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  var successfulPasteCount: Int {
    defaults.integer(forKey: Key.successfulPastes)
  }

  /// Record a paste that actually posted Cmd+V to the target app.
  func recordSuccessfulPaste() {
    defaults.set(successfulPasteCount + 1, forKey: Key.successfulPastes)
  }

  /// Called from `AppDelegate.openPanel()`. The short delay lets the panel
  /// finish ordering itself on screen before StoreKit attaches its sheet.
  func requestIfNeeded(from controller: NSViewController?) {
    guard let controller, !isPresenting else { return }

    guard let stage = ReviewPromptPolicy.stageToRequest(
      successfulPastes: successfulPasteCount,
      lastRequestedCount: defaults.integer(forKey: Key.lastRequestedCount),
      lastRequestedAt: defaults.object(forKey: Key.lastRequestedAt) as? Date,
      now: Date()
    ) else { return }

    isPresenting = true
    Task { @MainActor [weak self] in
      guard let self else { return }
      try? await Task.sleep(nanoseconds: 900_000_000)
      self.isPresenting = false

      // The user may have dismissed the shelf in the meantime. Leave the
      // pending request alone so the next open can present it.
      guard controller.view.window?.isVisible == true else { return }

      self.defaults.set(stage, forKey: Key.lastRequestedCount)
      self.defaults.set(Date(), forKey: Key.lastRequestedAt)
      AppStore.requestReview(in: controller)
    }
  }
}

/// Pure decision logic, kept separate so it can be tested without StoreKit or
/// a running application.
enum ReviewPromptPolicy {
  /// Moments at which a request may be made. Each threshold is used once.
  static let thresholds = [1, 20, 80]

  /// StoreKit shows the prompt at most three times per year. Keeping 90 days
  /// between our own attempts means the three thresholds last a full year and
  /// leave room for Apple's own throttling.
  static let minimumInterval: TimeInterval = 90 * 24 * 60 * 60

  static func stageToRequest(
    successfulPastes: Int,
    lastRequestedCount: Int,
    lastRequestedAt: Date?,
    now: Date
  ) -> Int? {
    guard successfulPastes > 0 else { return nil }
    guard let threshold = thresholds.last(where: { successfulPastes >= $0 }) else { return nil }
    guard threshold > lastRequestedCount else { return nil }

    if let lastRequestedAt,
       now.timeIntervalSince(lastRequestedAt) < minimumInterval {
      return nil
    }

    return threshold
  }
}
