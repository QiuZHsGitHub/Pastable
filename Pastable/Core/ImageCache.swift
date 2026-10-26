import AppKit

final class ImageCache: @unchecked Sendable {
  static let shared = ImageCache()

  private let appIconCache = NSCache<NSString, NSImage>()
  private let fileIconCache = NSCache<NSString, NSImage>()
  private let thumbnailCache = NSCache<NSString, NSImage>()

  private init() {
    appIconCache.countLimit = 200
    fileIconCache.countLimit = 200
    thumbnailCache.countLimit = 400
    // Decoded thumbnails dominate memory (a 560px preview is ~1MB decoded), so
    // bound the cache by bytes as well as by entry count.
    thumbnailCache.totalCostLimit = 96 * 1024 * 1024
  }

  func appIcon(forBundleId bundleId: String, path: String) -> NSImage? {
    if let cached = appIconCache.object(forKey: bundleId as NSString) {
      return cached
    }
    let icon = NSWorkspace.shared.icon(forFile: path)
    appIconCache.setObject(icon, forKey: bundleId as NSString)
    return icon
  }

  func fileIcon(forPath path: String) -> NSImage? {
    if let cached = fileIconCache.object(forKey: path as NSString) {
      return cached
    }
    let icon = NSWorkspace.shared.icon(forFile: path)
    fileIconCache.setObject(icon, forKey: path as NSString)
    return icon
  }

  func thumbnail(forKey key: String, loader: () -> NSImage?) -> NSImage? {
    if let cached = thumbnailCache.object(forKey: key as NSString) {
      return cached
    }
    guard let image = loader() else { return nil }
    storeThumbnail(image, forKey: key)
    return image
  }

  func cachedThumbnail(forKey key: String) -> NSImage? {
    thumbnailCache.object(forKey: key as NSString)
  }

  func storeThumbnail(_ image: NSImage?, forKey key: String) {
    guard let image else { return }
    thumbnailCache.setObject(image, forKey: key as NSString, cost: image.decodedByteCost)
  }
}

extension NSImage {
  /// Rough decoded footprint (RGBA bitmap) used as an NSCache cost value.
  /// Uses the point size so computing the cost never forces a decode.
  fileprivate var decodedByteCost: Int {
    max(1, Int(size.width * size.height) * 4)
  }
}
