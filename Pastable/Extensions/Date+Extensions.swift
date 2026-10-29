import Foundation

extension Date {
  /// Shared because `RelativeDateTimeFormatter` is expensive to create and the
  /// card footer asks for a relative string on every render.
  private static let relativeFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter
  }()

  private static let relativeFormatterLock = NSLock()

  /// Minute-bucketed memo of formatter output. `localizedString` is a full ICU
  /// round-trip and every card body pass asks for one; during scrolling dozens
  /// of cards render within the same minute, so a dictionary hit replaces the
  /// formatter call. Results only change once a minute anyway.
  private static var relativeCache: [Int64: String] = [:]

  func timeAgoDisplay() -> String {
    let bucket = Int64(timeIntervalSince1970 / 60)
    Self.relativeFormatterLock.lock()
    defer { Self.relativeFormatterLock.unlock() }

    if let cached = Self.relativeCache[bucket] {
      return cached
    }
    // Bound the cache: entries are only useful near "now", so drop everything
    // once in a while instead of growing one entry per minute forever.
    if Self.relativeCache.count > 512 {
      Self.relativeCache.removeAll(keepingCapacity: true)
    }
    let value = Self.relativeFormatter.localizedString(for: self, relativeTo: Date())
    Self.relativeCache[bucket] = value
    return value
  }
}
