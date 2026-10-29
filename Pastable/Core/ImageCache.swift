import AppKit

final class ImageCache: @unchecked Sendable {
  static let shared = ImageCache()

  private let appIconCache = NSCache<NSString, NSImage>()
  private let fileIconCache = NSCache<NSString, NSImage>()
  private let thumbnailCache = NSCache<NSString, NSImage>()
  private let appPathCache = NSCache<NSString, NSString>()

  private init() {
    appIconCache.countLimit = 200
    fileIconCache.countLimit = 200
    thumbnailCache.countLimit = 400
    // Decoded thumbnails dominate memory (a 560px preview is ~1MB decoded), so
    // bound the cache by bytes as well as by entry count.
    thumbnailCache.totalCostLimit = 96 * 1024 * 1024
  }

  /// App icon for a bundle id. The LaunchServices path lookup runs here too —
  /// `NSWorkspace.urlForApplication` can hit disk, so this whole entry point is
  /// meant to be called from the card's background load, never from `body`.
  func appIcon(forBundleId bundleId: String) -> NSImage? {
    if let cached = appIconCache.object(forKey: bundleId as NSString) {
      return cached
    }
    guard let path = appPath(forBundleId: bundleId) else { return nil }
    let icon = NSWorkspace.shared.icon(forFile: path)
    appIconCache.setObject(icon, forKey: bundleId as NSString)
    return icon
  }

  /// Cache-only lookup used to prime freshly built cards on the main thread.
  /// Never resolves anything — a miss means the background load fills it in.
  func cachedAppIcon(forBundleId bundleId: String) -> NSImage? {
    appIconCache.object(forKey: bundleId as NSString)
  }

  func fileIcon(forPath path: String) -> NSImage? {
    if let cached = fileIconCache.object(forKey: path as NSString) {
      return cached
    }
    let icon = NSWorkspace.shared.icon(forFile: path)
    fileIconCache.setObject(icon, forKey: path as NSString)
    return icon
  }

  /// Cache-only counterpart of `fileIcon(forPath:)` for main-thread priming.
  func cachedFileIcon(forPath path: String) -> NSImage? {
    fileIconCache.object(forKey: path as NSString)
  }

  /// Resolved app path for a bundle id, memoized so repeated cards from the
  /// same source app never repeat the LaunchServices lookup.
  private func appPath(forBundleId bundleId: String) -> String? {
    if let cached = appPathCache.object(forKey: bundleId as NSString) {
      return cached as String
    }
    guard let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)?.path else {
      return nil
    }
    appPathCache.setObject(path as NSString, forKey: bundleId as NSString)
    return path
  }

  func thumbnail(forKey key: String, loader: () -> NSImage?) -> NSImage? {
    if let cached = thumbnailCache.object(forKey: key as NSString) {
      return cached
    }
    guard let image = loader() else { return nil }
    return storeThumbnail(image, forKey: key)
  }

  func cachedThumbnail(forKey key: String) -> NSImage? {
    thumbnailCache.object(forKey: key as NSString)
  }

  /// Stores a fully decoded copy and returns it, so the caller renders from the
  /// decoded bitmap and the first draw never pays the decode on screen.
  @discardableResult
  func storeThumbnail(_ image: NSImage?, forKey key: String) -> NSImage? {
    guard let image else { return nil }
    let decoded = image.decodedForDisplay()
    thumbnailCache.setObject(decoded, forKey: key as NSString, cost: decoded.decodedByteCost)
    return decoded
  }
}

extension NSImage {
  /// Rough decoded footprint (RGBA bitmap) used as an NSCache cost value.
  /// Uses the point size so computing the cost never forces a decode.
  fileprivate var decodedByteCost: Int {
    max(1, Int(size.width * size.height) * 4)
  }

  /// Returns an image backed by a fully decoded bitmap. `NSImage(data:)` and
  /// ImageIO thumbnails decode lazily at first draw — i.e. on the main thread
  /// the moment a card scrolls into view — which shows up as scroll hitches.
  /// Drawing once into a bitmap context (here, on the loading task) moves that
  /// cost off the render path.
  func decodedForDisplay() -> NSImage {
    guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
      return self
    }
    let width = cgImage.width
    let height = cgImage.height
    guard width > 0, height > 0,
          let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else {
      return self
    }
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let decoded = context.makeImage() else { return self }
    return NSImage(cgImage: decoded, size: size)
  }
}
