import AppKit
import CloudKit
import Combine
import CoreData
import Foundation

/// Reports whether this Mac can currently use the app's private CloudKit
/// database. The actual record sync is handled by SwiftData; this monitor only
/// powers the status row in Settings.
@MainActor
final class CloudSyncMonitor: ObservableObject {
  static let shared = CloudSyncMonitor()

  enum State: Equatable {
    case checking
    case available
    case noAccount
    case restricted
    case unavailable(String)
  }

  @Published private(set) var state: State = .checking
  @Published private(set) var lastError: String?

  private var observer: NSObjectProtocol?
  private var lastEventSucceeded = false

  private init() {
    observer = NotificationCenter.default.addObserver(
      forName: NSPersistentCloudKitContainer.eventChangedNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let event = notification.userInfo?[
        NSPersistentCloudKitContainer.eventNotificationUserInfoKey
      ] as? NSPersistentCloudKitContainer.Event else { return }

      Task { @MainActor in
        self?.handle(event)
      }
    }
  }

  deinit {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  func refresh() async {
    do {
      let container = CKContainer(identifier: Storage.iCloudContainerIdentifier)
      let status = try await container.accountStatus()
      switch status {
      case .available:
        if let lastError {
          state = .unavailable(lastError)
        } else if lastEventSucceeded {
          state = .available
        } else {
          state = .checking
        }
      case .noAccount:
        state = .noAccount
      case .restricted:
        state = .restricted
      case .couldNotDetermine, .temporarilyUnavailable:
        state = .unavailable(NSLocalizedString("settings.storage.icloud.check_failed", comment: "iCloud status check failed"))
      @unknown default:
        state = .unavailable(NSLocalizedString("settings.storage.icloud.check_failed", comment: "iCloud status check failed"))
      }
    } catch {
      state = .unavailable(error.localizedDescription)
    }
  }

  private func handle(_ event: NSPersistentCloudKitContainer.Event) {
    // Event notifications are also posted when an operation starts.
    guard event.endDate != nil else { return }

    if event.succeeded {
      lastEventSucceeded = true
      lastError = nil
      if state != .noAccount && state != .restricted {
        state = .available
      }
    } else {
      lastEventSucceeded = false
      let message = event.error?.localizedDescription
        ?? NSLocalizedString("settings.storage.icloud.check_failed", comment: "iCloud status check failed")
      lastError = message
      state = .unavailable(message)
    }
  }
}

enum AppRelauncher {
  /// Relaunch a fresh instance before quitting the current one. This is needed
  /// because the SwiftData container (local vs. CloudKit) is chosen at launch.
  @MainActor
  static func relaunch() {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-n", Bundle.main.bundlePath]
    do {
      try process.run()
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
        NSApp.terminate(nil)
      }
    } catch {
      AppLogger.Storage.error("Cannot relaunch Pastable", error: error)
    }
  }
}
