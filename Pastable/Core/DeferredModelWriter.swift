import Foundation
import SwiftData

/// Batches the tiny "generated while rendering" writes that cards produce as
/// they scroll into view (legacy thumbnail blobs, RTF background colors).
///
/// Each write used to end in its own `modelContext.save()` right inside the
/// card's load task, and every save makes the `@Query` behind the shelf refetch
/// and re-render the whole list — a burst of legacy cards generating artifacts
/// mid-scroll produced one full-list re-render per card. Writes are tiny and
/// idempotent (at most once per record), so they can safely sit for a beat and
/// be applied together with a single save.
@MainActor
final class DeferredModelWriter {
  static let shared = DeferredModelWriter()

  private var pendingWrites: [() -> Void] = []
  private var pendingContexts: [ModelContext] = []
  private var flushTask: Task<Void, Never>?

  private init() {}

  func enqueue(context: ModelContext?, _ write: @escaping () -> Void) {
    pendingWrites.append(write)
    if let context, !pendingContexts.contains(where: { $0 === context }) {
      pendingContexts.append(context)
    }
    scheduleFlush()
  }

  /// Applies everything now. Called after the debounce and whenever the shelf
  /// closes, so persisted artifacts are never more than a panel-close away.
  func flush() {
    flushTask?.cancel()
    flushTask = nil

    let writes = pendingWrites
    let contexts = pendingContexts
    pendingWrites.removeAll()
    pendingContexts.removeAll()

    for write in writes {
      write()
    }
    for context in contexts {
      try? context.save()
    }
  }

  private func scheduleFlush() {
    flushTask?.cancel()
    flushTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 1_200_000_000)
      guard let self, !Task.isCancelled else { return }
      self.flush()
    }
  }
}
