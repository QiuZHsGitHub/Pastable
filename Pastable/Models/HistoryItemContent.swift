import Foundation
import SwiftData

/// A snapshot of one pasteboard representation, decoupled from SwiftData so it
/// can cross thread boundaries while capturing.
struct RawContentSnapshot: Sendable {
  let type: String
  let value: Data?
}

@Model
class HistoryItemContent {
  var type: String = ""
  /// External storage keeps large screenshots out of the CloudKit record
  /// (records have a small inline payload limit; SwiftData maps this to an
  /// asset instead).
  @Attribute(.externalStorage) var value: Data?

  @Relationship
  var item: HistoryItem?

  init(type: String, value: Data? = nil) {
    self.type = type
    self.value = value
  }
}
