import Foundation

struct SearchResult: Identifiable {
  let id = UUID()
  let item: HistoryItem
  let score: Double // Higher is better
}

class SearchService {
  static let shared = SearchService()
  
  enum SearchMode: String, CaseIterable {
    case exact
    case fuzzy
  }
  
  func search(query: String, items: [HistoryItem], mode: SearchMode = .fuzzy) -> [HistoryItem] {
    guard !query.isEmpty else { return items }
    
    switch mode {
    case .exact:
      return items.filter { item in
        item.title.localizedCaseInsensitiveContains(query)
      }
      
    case .fuzzy:
      // Try simple search first as it's faster and often what users want
      let simpleResults = items.filter { item in
        item.title.localizedCaseInsensitiveContains(query)
      }
      
      if !simpleResults.isEmpty {
        return simpleResults
      }
      
      // Fallback to approximate matching
      return items.filter { item in
        smartMatch(query: query, target: item.title)
      }
    }
  }
  
  private func smartMatch(query: String, target: String) -> Bool {
    var queryIndex = query.startIndex
    var targetIndex = target.startIndex
    
    while queryIndex < query.endIndex && targetIndex < target.endIndex {
      if query[queryIndex].lowercased() == target[targetIndex].lowercased() {
        queryIndex = query.index(after: queryIndex)
      }
      targetIndex = target.index(after: targetIndex)
    }
    
    return queryIndex == query.endIndex
  }
}
