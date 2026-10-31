import XCTest

/// Static checks between the Swift sources and the localization tables:
/// every `NSLocalizedString` key used by the app must exist in English, and
/// the dynamic category keys must resolve too.
final class LocalizationSourceUsageTests: XCTestCase {
  private static let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent() // PastableTests
    .deletingLastPathComponent() // Tests
    .deletingLastPathComponent() // repository root

  private static let resourcesURL = repositoryRoot.appendingPathComponent("Pastable/Resources")
  private static let sourcesURL = repositoryRoot.appendingPathComponent("Pastable")

  private static let keyPattern = try! NSRegularExpression(
    pattern: #"NSLocalizedString\("([^"\\]+)""#
  )

  private static let entryPattern = try! NSRegularExpression(
    pattern: #"^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;\s*$"#
  )

  private func englishTable() throws -> [String: String] {
    let text = try String(
      contentsOf: Self.resourcesURL
        .appendingPathComponent("en.lproj")
        .appendingPathComponent("Localizable.strings"),
      encoding: .utf8
    )

    var entries: [String: String] = [:]
    for line in text.components(separatedBy: .newlines) {
      let range = NSRange(line.startIndex..<line.endIndex, in: line)
      guard let match = Self.entryPattern.firstMatch(in: line, range: range),
            let keyRange = Range(match.range(at: 1), in: line),
            let valueRange = Range(match.range(at: 2), in: line) else { continue }
      entries[String(line[keyRange])] = String(line[valueRange])
    }
    return entries
  }

  private func swiftSources() throws -> [URL] {
    guard let enumerator = FileManager.default.enumerator(
      at: Self.sourcesURL,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]
    ) else { return [] }

    var files: [URL] = []
    for case let url as URL in enumerator where url.pathExtension == "swift" {
      files.append(url)
    }
    return files.sorted { $0.path < $1.path }
  }

  func testEveryLocalizedKeyUsedInSourceExistsInEnglish() throws {
    let table = try englishTable()
    XCTAssertFalse(table.isEmpty)

    var missing: [String] = []
    for file in try swiftSources() {
      let source = try String(contentsOf: file, encoding: .utf8)
      let range = NSRange(source.startIndex..<source.endIndex, in: source)
      for match in Self.keyPattern.matches(in: source, range: range) {
        guard let keyRange = Range(match.range(at: 1), in: source) else { continue }
        let key = String(source[keyRange])
        // Interpolated keys (e.g. "category.\(x)") do not match the pattern;
        // only literal keys are checked here.
        if table[key] == nil {
          missing.append("\(key) (\(file.lastPathComponent))")
        }
      }
    }

    XCTAssertTrue(missing.isEmpty, "Missing localization keys: \(Set(missing).sorted())")
  }

  func testDynamicCategoryKeysExist() throws {
    let table = try englishTable()
    let categories = ["All", "Text", "Code", "Links", "Others"]
    for category in categories {
      XCTAssertNotNil(
        table["category.\(category.lowercased())"],
        "missing dynamic key for \(category)"
      )
    }
    for key in ["category.link", "category.image", "category.file", "category.color"] {
      XCTAssertNotNil(table[key], "missing card badge key \(key)")
    }
  }

  func testEnglishValuesAreNotEmpty() throws {
    let table = try englishTable()
    let empty = table.filter { $0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    XCTAssertTrue(empty.isEmpty, "empty English values: \(empty.keys.sorted())")
  }
}
