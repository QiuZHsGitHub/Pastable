import Foundation

extension String {
  /// Truncate to at most `maxLength` characters (grapheme clusters).
  func shortened(to maxLength: Int) -> String {
    guard maxLength > 0 else { return "" }
    guard count > maxLength else { return self }
    return String(prefix(maxLength))
  }
}
