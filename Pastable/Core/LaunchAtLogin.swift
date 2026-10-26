import Foundation
import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp` so the Settings toggle reflects
/// the real login-item state instead of a value that was never applied.
enum LaunchAtLogin {
  static var isEnabled: Bool {
    switch SMAppService.mainApp.status {
    case .enabled, .requiresApproval:
      return true
    default:
      return false
    }
  }

  static var requiresApproval: Bool {
    SMAppService.mainApp.status == .requiresApproval
  }

  static func setEnabled(_ enabled: Bool) throws {
    if enabled {
      guard SMAppService.mainApp.status != .enabled else { return }
      try SMAppService.mainApp.register()
    } else {
      guard SMAppService.mainApp.status != .notRegistered else { return }
      try SMAppService.mainApp.unregister()
    }
  }
}
