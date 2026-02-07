import Foundation
import SwiftData

@MainActor
class Storage {
  static let shared = Storage()

  var container: ModelContainer
  var context: ModelContext { container.mainContext }
  var size: String {
    guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).allValues.first?.value as? Int64, size > 1 else {
      return ""
    }

    return ByteCountFormatter().string(fromByteCount: size)
  }

  private let url = URL.applicationSupportDirectory.appending(path: "Pastable/Storage.sqlite")

  init() {
    var config = ModelConfiguration(url: url)

    #if DEBUG
    if CommandLine.arguments.contains("enable-testing") {
      config = ModelConfiguration(isStoredInMemoryOnly: true)
    }
    #endif

    do {
      container = try ModelContainer(for: HistoryItem.self, configurations: config)
    } catch let error {
      fatalError("Cannot load database: \(error.localizedDescription).")
    }
  }
  
  /// 清理过期历史记录
  /// - Parameter duration: 保留时长（秒），0 表示不清理
  func cleanup(retentionDuration: Int) {
    guard retentionDuration > 0 else { return }
    
    let cutoffDate = Date().addingTimeInterval(-TimeInterval(retentionDuration))
    
    do {
      // 查找早于 cutoffDate 的记录
      // 注意: CloudKit/SwiftData 有时对复杂 Predicate 支持有限，尝试直接比较
      let descriptor = FetchDescriptor<HistoryItem>(
        predicate: #Predicate { $0.firstCopiedAt < cutoffDate }
      )
      
      let itemsToDelete = try context.fetch(descriptor)
      
      for item in itemsToDelete {
        context.delete(item)
      }
      
      try context.save()
      print("Cleaned up \(itemsToDelete.count) expired items.")
    } catch {
      print("Failed to cleanup history: \(error)")
    }
  }
  
  /// 添加新记录或更新已有记录（去重）
  func addOrUpdate(_ newItem: HistoryItem) {
    do {
      // Prefer hash-based deduplication (stable across RTF/HTML variations)
      if newItem.contentHash == nil || newItem.contentHash?.isEmpty == true {
        newItem.contentHash = HistoryItem.computeContentHash(contents: newItem.contents)
      }
      let hash = newItem.contentHash ?? ""
        var items: [HistoryItem]
      if !hash.isEmpty {
        let descriptor = FetchDescriptor<HistoryItem>(
          predicate: #Predicate { $0.contentHash == hash },
          sortBy: [SortDescriptor(\.firstCopiedAt, order: .reverse)]
        )
        items = try context.fetch(descriptor)
        
        // Backfill missing hashes for recent items to avoid duplicate inserts
        if items.isEmpty {
          var missingDescriptor = FetchDescriptor<HistoryItem>(
            predicate: #Predicate { $0.contentHash == nil || $0.contentHash == "" },
            sortBy: [SortDescriptor(\.firstCopiedAt, order: .reverse)]
          )
          missingDescriptor.fetchLimit = 200
          let missing = try context.fetch(missingDescriptor)
          for item in missing {
            item.contentHash = HistoryItem.computeContentHash(contents: item.contents)
          }
          if missing.contains(where: { $0.contentHash == hash }) {
            // Re-fetch after backfill to get the matching item
            items = try context.fetch(descriptor)
          }
        }
      } else {
        // Fallback: fetch all and compare
        let descriptor = FetchDescriptor<HistoryItem>(
          sortBy: [SortDescriptor(\.firstCopiedAt, order: .reverse)]
        )
        items = try context.fetch(descriptor)
      }
      #if DEBUG
      debugLog("pre-check", [
        "existingCount": "\(items.count)",
        "newContents": "\(newItem.contents.count)",
        "newTitlePreview": "\(newItem.title.prefix(40))"
      ])
      #endif

      // Backfill missing hashes for existing items in this fetch
      for item in items where item.contentHash == nil || item.contentHash?.isEmpty == true {
        item.contentHash = HistoryItem.computeContentHash(contents: item.contents)
      }
      
      // 查找是否存在相同内容的记录
      if let existingItem = items.first(where: { $0.supersedes(newItem) }) {
        #if DEBUG
        debugLog("dedup-hit", [
          "existingId": "\(existingItem.persistentModelID)",
          "newId": "\(newItem.persistentModelID)",
          "existingCopies": "\(existingItem.numberOfCopies)",
          "newContents": "\(newItem.contents.count)"
        ])
        #endif
        // 发现重复：更新时间戳将其置顶
        existingItem.firstCopiedAt = Date()
        existingItem.lastCopiedAt = Date()
        existingItem.numberOfCopies += 1
        existingItem.application = newItem.application // 更新来源应用
        
        try context.save()
      } else {
        #if DEBUG
        debugLog("insert", [
          "newId": "\(newItem.persistentModelID)",
          "newContents": "\(newItem.contents.count)",
          "hash": hash
        ])
        #endif
        // 无重复：插入新记录
        context.insert(newItem)
        try context.save()
      }
    } catch {
      print("Failed to add/update item: \(error)")
    }
  }

  #if DEBUG
  private func debugLog(_ tag: String, _ fields: [String: String]) {
    let ts = ISO8601DateFormatter().string(from: Date())
    let payload = fields.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
    print("[Storage][\(tag)] \(ts) \(payload)")
  }
  #endif
}
