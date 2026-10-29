import XCTest

/// Guards the `Localizable.strings` tables: every locale must define exactly the
/// same keys as English, with the same format specifiers in the same order.
final class LocalizationTests: XCTestCase {
  private static let resourcesURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent() // PastableTests
    .deletingLastPathComponent() // Tests
    .deletingLastPathComponent() // repository root
    .appendingPathComponent("Pastable/Resources")

  private static let entryPattern = try! NSRegularExpression(
    pattern: #"^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;\s*$"#
  )

  private static let placeholderPattern = try! NSRegularExpression(
    pattern: #"%(?:\d+\$)?[-+ 0#]*\d*(?:\.\d+)?(?:hh|h|ll|l|q|L|z|t|j)?[@dDuUxXoOfFeEgGcCsSpaA]"#
  )

  private func localeDirectories() throws -> [URL] {
    try FileManager.default
      .contentsOfDirectory(
        at: Self.resourcesURL,
        includingPropertiesForKeys: nil
      )
      .filter { $0.pathExtension == "lproj" }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }
  }

  private func load(_ locale: URL) throws -> [String: String] {
    let text = try String(
      contentsOf: locale.appendingPathComponent("Localizable.strings"),
      encoding: .utf8
    )

    var entries: [String: String] = [:]
    var inBlockComment = false
    for line in text.components(separatedBy: .newlines) {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if inBlockComment {
        if trimmed.contains("*/") { inBlockComment = false }
        continue
      }
      if trimmed.hasPrefix("/*") {
        if !trimmed.contains("*/") { inBlockComment = true }
        continue
      }
      if trimmed.isEmpty || trimmed.hasPrefix("//") { continue }

      let range = NSRange(line.startIndex..<line.endIndex, in: line)
      guard let match = Self.entryPattern.firstMatch(in: line, range: range),
            let keyRange = Range(match.range(at: 1), in: line),
            let valueRange = Range(match.range(at: 2), in: line)
      else {
        XCTFail("Unparseable line in \(locale.lastPathComponent): \(line)")
        continue
      }
      entries[String(line[keyRange])] = String(line[valueRange])
    }
    return entries
  }

  private func placeholders(in value: String) -> [String] {
    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    return Self.placeholderPattern.matches(in: value, range: range).compactMap {
      Range($0.range, in: value).map { String(value[$0]) }
    }
  }

  func testEveryLocaleMatchesTheEnglishKeySetAndPlaceholders() throws {
    let base = try load(Self.resourcesURL.appendingPathComponent("en.lproj"))
    XCTAssertFalse(base.isEmpty, "English table should not be empty")

    let locales = try localeDirectories()
    let names = locales.map(\.lastPathComponent)
    for required in ["en.lproj", "zh-Hans.lproj", "zh-Hant.lproj"] {
      XCTAssertTrue(names.contains(required), "Missing \(required)")
    }

    for locale in locales where locale.lastPathComponent != "en.lproj" {
      let name = locale.lastPathComponent
      let entries = try load(locale)

      XCTAssertEqual(
        Set(entries.keys),
        Set(base.keys),
        "\(name) has a different key set than en.lproj"
      )

      for (key, value) in entries {
        guard let english = base[key] else { continue }
        XCTAssertEqual(
          placeholders(in: value),
          placeholders(in: english),
          "\(name) placeholder mismatch for \(key)"
        )
        XCTAssertTrue(
          value.contains("%") == english.contains("%"),
          "\(name) drops or adds a format specifier for \(key)"
        )
      }
    }
  }

  func testMaintenanceMessageKeepsBothParagraphs() throws {
    for locale in try localeDirectories() {
      let entries = try load(locale)
      XCTAssertTrue(
        entries["maintenance.message"]?.contains("\\n") == true,
        "\(locale.lastPathComponent) lost the paragraph break in maintenance.message"
      )
    }
  }
}
