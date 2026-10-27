import SwiftUI

/// Renders "why this card matched" during search: the slice of a record's text
/// the card should show, plus highlighting for every hit in it.
///
/// `SearchService` matches against the full body (`HistoryItem` caches up to
/// 8K folded characters), but a card only shows its first lines — without a
/// window that jumps to the hit, a body match deep in the text looks like a
/// false positive to the user.
enum SearchHighlight {
  /// Characters a card preview can show (mirrors the card's line cap).
  static let visibleLimit = 2_000
  /// Characters `SearchService` matches against; must stay in sync with
  /// `HistoryItem.normalizedSearchBody`.
  static let searchLimit = 8_000

  private static let compareOptions: String.CompareOptions = [
    .caseInsensitive, .diacriticInsensitive, .widthInsensitive
  ]

  /// The text slice to display on a card.
  struct Slice {
    let text: String
    /// True when the slice was moved to the first hit instead of the natural
    /// head of the text (and therefore carries "…" markers).
    let isWindow: Bool
  }

  /// Picks the display slice for a match: the head of `text` when the first
  /// hit is visible there, otherwise a window around the hit.
  static func windowedSlice(of text: String, tokens: [String]) -> Slice? {
    guard !tokens.isEmpty, !text.isEmpty else { return nil }
    let searchable = String(text.prefix(searchLimit))

    var firstHit: String.Index?
    for token in tokens {
      guard let hit = searchable.range(of: token, options: compareOptions) else { continue }
      if firstHit == nil || hit.lowerBound < firstHit! {
        firstHit = hit.lowerBound
      }
    }
    guard let firstHit else { return nil }

    let hitOffset = searchable.distance(from: searchable.startIndex, to: firstHit)
    if hitOffset < visibleLimit {
      return Slice(text: String(searchable.prefix(visibleLimit)), isWindow: false)
    }

    // Show context before the hit and a screenful after it.
    let start = searchable.index(searchable.startIndex, offsetBy: max(0, hitOffset - 120))
    let end = searchable.index(start, offsetBy: min(visibleLimit, searchable.distance(from: start, to: searchable.endIndex)))
    let window = searchable[start..<end]
    return Slice(text: "…" + window + "…", isWindow: true)
  }

  /// Highlights `tokens` in a plain string. `font`/`foreground` are written
  /// into the runs so `Text` keeps the card's typography without extra
  /// modifiers (nil leaves styling to the view).
  static func highlighted(
    _ text: String,
    tokens: [String],
    color: Color,
    font: Font? = nil,
    foreground: Color? = nil
  ) -> AttributedString {
    var result = AttributedString(text)
    if let font { result.font = font }
    if let foreground { result.foregroundColor = foreground }

    for token in tokens {
      // Zero-length matches would never advance the scan below.
      guard !token.isEmpty else { continue }
      var searchStart = text.startIndex
      while searchStart < text.endIndex,
            let hit = text.range(of: token, options: compareOptions, range: searchStart..<text.endIndex) {
        applyHighlight(&result, token: token, in: text, at: hit, color: color)
        searchStart = hit.upperBound
      }
    }
    return result
  }

  /// Highlights `tokens` inside the first `visibleLimit` characters of an
  /// attributed string (e.g. parsed RTF), preserving its own runs.
  static func highlightedHead(
    _ attributed: AttributedString,
    tokens: [String],
    color: Color
  ) -> AttributedString {
    var result = attributed
    let head = String(result.characters.prefix(visibleLimit))

    for token in tokens {
      guard !token.isEmpty else { continue }
      var searchStart = head.startIndex
      while searchStart < head.endIndex,
            let hit = head.range(of: token, options: compareOptions, range: searchStart..<head.endIndex) {
        applyHighlight(&result, token: token, in: head, at: hit, color: color)
        searchStart = hit.upperBound
      }
    }
    return result
  }

  /// Maps a `String.Index` range (character offsets) onto the identical
  /// character sequence of `result` and paints the background.
  private static func applyHighlight(
    _ result: inout AttributedString,
    token: String,
    in source: String,
    at hit: Range<String.Index>,
    color: Color
  ) {
    let lower = source.distance(from: source.startIndex, to: hit.lowerBound)
    let upper = source.distance(from: source.startIndex, to: hit.upperBound)
    let start = result.characters.index(result.startIndex, offsetBy: lower)
    let end = result.characters.index(start, offsetBy: upper - lower)
    result[start..<end].backgroundColor = color
  }
}
