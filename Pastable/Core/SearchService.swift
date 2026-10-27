import Foundation

final class SearchService {
  static let shared = SearchService()

  enum SearchMode: String, CaseIterable {
    case exact
    case fuzzy
  }

  /// Query split into folded tokens — exactly what `search` matches against.
  /// Cards use it to show why they matched (see `SearchHighlight`).
  static func tokens(for query: String) -> [String] {
    query
      .split(whereSeparator: \.isWhitespace)
      .map { fold(String($0)) }
      .filter { !$0.isEmpty }
  }

  /// Search both the title and the full preview text, require every token to
  /// match, and rank title hits above body hits. This keeps large histories fast
  /// while making multi-word queries behave the way users expect.
  func search(query: String, items: [HistoryItem], mode: SearchMode = .fuzzy) -> [HistoryItem] {
    let tokens = Self.tokens(for: query)

    guard !tokens.isEmpty else { return items }

    let now = Date()
    var scored: [(item: HistoryItem, score: Double)] = []
    scored.reserveCapacity(items.count)

    for item in items {
      // Long clipboard entries should not make every keystroke O(size of history).
      // Normalized title/body are cached per item (see HistoryItem), so this
      // loop only performs the actual matching work.
      let title = item.normalizedSearchTitle
      let body = item.normalizedSearchBody

      var total = 0.0
      var matchedAll = true

      for token in tokens {
        if let score = Self.substringScore(token: token, in: title, base: 100) {
          total += score
        } else if let score = Self.substringScore(token: token, in: body, base: 60) {
          total += score
        } else if mode == .fuzzy, let score = Self.fuzzyScore(token: token, in: title, base: 24) {
          total += score
        } else if mode == .fuzzy, let score = Self.fuzzyScore(token: token, in: body, base: 12) {
          total += score
        } else {
          matchedAll = false
          break
        }
      }

      guard matchedAll else { continue }

      // Small recency / frequency tie-breakers so common copies float up.
      let age = max(0, now.timeIntervalSince(item.lastCopiedAt))
      total += max(0, 3 - age / 86_400)
      total += min(2, Double(item.numberOfCopies) * 0.1)

      scored.append((item, total))
    }

    return scored
      .sorted { lhs, rhs in
        if lhs.score == rhs.score {
          return lhs.item.lastCopiedAt > rhs.item.lastCopiedAt
        }
        return lhs.score > rhs.score
      }
      .map(\.item)
  }

  // MARK: - Matching

  /// Case/diacritic/width-insensitive folding shared by the search tokens and
  /// the per-item index (HistoryItem.normalizedSearchTitle/Body).
  static func fold(_ value: String) -> String {
    value.folding(
      options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
      locale: .current
    )
  }

  private static func substringScore(token: String, in text: String, base: Double) -> Double? {
    guard !token.isEmpty, !text.isEmpty, let range = text.range(of: token) else { return nil }

    var score = base
    if range.lowerBound == text.startIndex {
      score += 15
    } else {
      let previous = text[text.index(before: range.lowerBound)]
      if !previous.isLetter && !previous.isNumber {
        score += 8
      }
    }
    return score
  }

  /// Ordered subsequence matching, used only as a fallback in fuzzy mode.
  private static func fuzzyScore(token: String, in text: String, base: Double) -> Double? {
    guard !token.isEmpty, !text.isEmpty else { return nil }

    var tokenIndex = token.startIndex
    var textIndex = text.startIndex
    var firstMatchOffset: Int?
    var offset = 0
    var gaps = 0

    while tokenIndex < token.endIndex && textIndex < text.endIndex {
      if token[tokenIndex] == text[textIndex] {
        if firstMatchOffset == nil {
          firstMatchOffset = offset
        }
        tokenIndex = token.index(after: tokenIndex)
      } else if firstMatchOffset != nil {
        gaps += 1
      }
      textIndex = text.index(after: textIndex)
      offset += 1
    }

    guard tokenIndex == token.endIndex, let firstMatchOffset else { return nil }

    let positionBonus = firstMatchOffset == 0 ? 8.0 : 0.0
    let gapPenalty = min(10.0, Double(gaps) * 0.5)
    return max(1, base + positionBonus - gapPenalty)
  }
}
