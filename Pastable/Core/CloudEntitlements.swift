import Foundation
import Security

/// Capability checks derived from the running binary's code signature.
///
/// The GitHub Releases build is signed ad-hoc and therefore cannot carry the
/// restricted iCloud entitlements: those require an Apple-issued provisioning
/// profile. CloudKit reacts to a missing entitlement by raising an Objective-C
/// exception instead of throwing a Swift error, so every CloudKit entry point
/// has to be gated on this check — a `do/catch` cannot save the process.
enum CloudEntitlements {
  /// The `com.apple.developer.icloud-services` values baked into the signature.
  static let iCloudServices: [String] = {
    guard let task = SecTaskCreateFromSelf(nil) else { return [] }
    let value = SecTaskCopyValueForEntitlement(
      task,
      "com.apple.developer.icloud-services" as CFString,
      nil
    )
    return value as? [String] ?? []
  }()

  /// `true` when this build may open a CloudKit container (App Store and
  /// developer-signed builds). The certificate-free direct download returns
  /// `false`, and the app then stays on the local store.
  static var isCloudKitAvailable: Bool {
    iCloudServices.contains("CloudKit")
  }
}
