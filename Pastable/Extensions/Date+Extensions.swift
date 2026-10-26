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

  func timeAgoDisplay() -> String {
    Self.relativeFormatterLock.lock()
    defer { Self.relativeFormatterLock.unlock() }
    return Self.relativeFormatter.localizedString(for: self, relativeTo: Date())
  }
}
