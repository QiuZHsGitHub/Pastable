import AppKit

final class ImageCache {
  static let shared = ImageCache()
  
  private let appIconCache = NSCache<NSString, NSImage>()
  private let fileIconCache = NSCache<NSString, NSImage>()
  private let thumbnailCache = NSCache<NSString, NSImage>()
  
  private init() {
    appIconCache.countLimit = 200
    fileIconCache.countLimit = 200
    thumbnailCache.countLimit = 200
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
  
  func thumbnail(forURL url: URL, loader: (URL) -> NSImage?) -> NSImage? {
    let key = url.absoluteString as NSString
    if let cached = thumbnailCache.object(forKey: key) {
      return cached
    }
    if let image = loader(url) {
      thumbnailCache.setObject(image, forKey: key)
      return image
    }
    return nil
  }
}
