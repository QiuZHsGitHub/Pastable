import XCTest
@testable import Pastable

/// Preference contract: the capture pipeline reads these values on every
/// pasteboard change, so defaults, clamping and explicit overrides must be
/// predictable.
final class PreferencesTests: XCTestCase {
  private let keys = [
    Preferences.Key.saveText,
    Preferences.Key.saveImages,
    Preferences.Key.saveFiles,
    Preferences.Key.pasteAutomatically,
    Preferences.Key.removeFormatting,
    Preferences.Key.playSounds,
    Preferences.Key.historySize,
    Preferences.Key.historyRetentionDuration,
    Preferences.Key.searchMode,
    Preferences.Key.iCloudSyncEnabled
  ]

  private var original: [String: Any] = [:]
  private var originallyMissing: Set<String> = []

  override func setUp() {
    super.setUp()
    original = [:]
    originallyMissing = []
    for key in keys {
      if let value = UserDefaults.standard.object(forKey: key) {
        original[key] = value
      } else {
        originallyMissing.insert(key)
      }
      UserDefaults.standard.removeObject(forKey: key)
    }
    Preferences.registerDefaults()
  }

  override func tearDown() {
    for key in keys {
      if let value = original[key] {
        UserDefaults.standard.set(value, forKey: key)
      } else {
        UserDefaults.standard.removeObject(forKey: key)
      }
    }
    Preferences.registerDefaults()
    super.tearDown()
  }

  func testRegisteredDefaults() {
    XCTAssertTrue(Preferences.saveText)
    XCTAssertTrue(Preferences.saveImages)
    XCTAssertTrue(Preferences.saveFiles)
    XCTAssertTrue(Preferences.pasteAutomatically)
    XCTAssertFalse(Preferences.removeFormatting)
    XCTAssertTrue(Preferences.playSounds)
    XCTAssertEqual(Preferences.historyLimit, Preferences.defaultHistorySize)
    XCTAssertEqual(Preferences.retentionDuration, 0)
    XCTAssertFalse(Preferences.iCloudSyncEnabled)
  }

  func testExplicitBooleanOverridesWin() {
    UserDefaults.standard.set(false, forKey: Preferences.Key.saveText)
    UserDefaults.standard.set(false, forKey: Preferences.Key.saveImages)
    UserDefaults.standard.set(false, forKey: Preferences.Key.saveFiles)
    UserDefaults.standard.set(false, forKey: Preferences.Key.pasteAutomatically)
    UserDefaults.standard.set(true, forKey: Preferences.Key.removeFormatting)
    UserDefaults.standard.set(false, forKey: Preferences.Key.playSounds)

    XCTAssertFalse(Preferences.saveText)
    XCTAssertFalse(Preferences.saveImages)
    XCTAssertFalse(Preferences.saveFiles)
    XCTAssertFalse(Preferences.pasteAutomatically)
    XCTAssertTrue(Preferences.removeFormatting)
    XCTAssertFalse(Preferences.playSounds)
  }

  func testHistoryLimitClampsNonPositiveValuesToTheDefault() {
    UserDefaults.standard.set(0, forKey: Preferences.Key.historySize)
    XCTAssertEqual(Preferences.historyLimit, Preferences.defaultHistorySize)

    UserDefaults.standard.set(-25, forKey: Preferences.Key.historySize)
    XCTAssertEqual(Preferences.historyLimit, Preferences.defaultHistorySize)

    UserDefaults.standard.set(42, forKey: Preferences.Key.historySize)
    XCTAssertEqual(Preferences.historyLimit, 42)
  }

  func testRetentionDurationClampsNegativeValuesToZero() {
    UserDefaults.standard.set(-10, forKey: Preferences.Key.historyRetentionDuration)
    XCTAssertEqual(Preferences.retentionDuration, 0)

    UserDefaults.standard.set(3_600, forKey: Preferences.Key.historyRetentionDuration)
    XCTAssertEqual(Preferences.retentionDuration, 3_600)
  }

  func testSearchModeKeyIsReadableByAppState() {
    UserDefaults.standard.set(SearchService.SearchMode.exact.rawValue, forKey: Preferences.Key.searchMode)
    let stored = UserDefaults.standard.string(forKey: Preferences.Key.searchMode)
    XCTAssertEqual(stored, "exact")
    XCTAssertEqual(SearchService.SearchMode(rawValue: stored!), .exact)
  }
}
