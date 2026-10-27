import AppKit

/// Immutable, derived preview artifacts for one card body. Built once off the
/// main thread and then shared by every `CardCell` that renders the record.
final class AttributedPreview: @unchecked Sendable {
  let text: AttributedString
  /// Hex string (not `Color`) so the cached value stays cheap to retain.
  let backgroundHex: String?

  init(text: AttributedString, backgroundHex: String?) {
    self.text = text
    self.backgroundHex = backgroundHex
  }

  /// Rough memory footprint used as the NSCache cost value.
  var cost: Int { max(1, text.unicodeScalars.count) }
}

/// Process-wide cache for expensive card-preview artifacts that are not
/// images (currently parsed RTF). `LazyHStack` drops `CardCell` state whenever
/// a card leaves the visible band, so without this cache the same RTF payload
/// would be re-parsed every time its card scrolled back into view. Mirrors
/// `ImageCache`, which already covers thumbnails and icons.
final class PreviewCache: @unchecked Sendable {
  static let shared = PreviewCache()

  private let previewCache = NSCache<NSString, AttributedPreview>()

  private init() {
    previewCache.countLimit = 300
    // A single rich-text clip can carry a lot of attributed runs; bound by
    // characters as well as by entry count.
    previewCache.totalCostLimit = 2_000_000
  }

  func preview(forKey key: String) -> AttributedPreview? {
    previewCache.object(forKey: key as NSString)
  }

  func store(_ preview: AttributedPreview?, forKey key: String) {
    guard let preview else { return }
    previewCache.setObject(preview, forKey: key as NSString, cost: preview.cost)
  }
}
