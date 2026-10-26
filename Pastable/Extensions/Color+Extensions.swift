import SwiftUI

/// Brand and category hex values that do not change with appearance.
/// Surface/text tokens that do change live in `AppTheme`.
enum AppPalette {
  static let accentLight = "#C8402E"
  static let accentDark = "#E0523B"
  static let categoryAll = "#9AA0A6"
  static let categoryText = "#4E8F7C"
  static let categoryCode = "#4A7DB2"
  static let categoryLink = "#9A72A8"
  static let categoryMedia = "#C46F88"
  static let categoryColor = "#D9824B"
}

extension Color {
  /// Memoized: views re-parse the same handful of hex tokens on every render,
  /// which showed up as measurable cost in card-heavy lists.
  init(hex: String) {
    self = Self.hexMemo.color(key: hex) { Color(parsedHex: hex) }
  }

  private static let hexMemo = ColorMemo()

  private init(parsedHex: String) {
    let hex = parsedHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let a, r, g, b: UInt64
    switch hex.count {
    case 3: // RGB (12-bit)
      (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
    case 6: // RGB (24-bit)
      (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
    case 8: // ARGB (32-bit)
      (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
    default:
      (a, r, g, b) = (1, 1, 1, 0)
    }
    
    self.init(
      .sRGB,
      red: Double(r) / 255,
      green: Double(g) / 255,
      blue: Double(b) / 255,
      opacity: Double(a) / 255
    )
  }

  static let pastableAccent = Color(hex: AppPalette.accentLight)
  static let pastableBackground = Color(hex: "#2C2C2E")

  static let categoryAll = Color(hex: AppPalette.categoryAll)
  static let categoryText = Color(hex: AppPalette.categoryText)
  static let categoryCode = Color(hex: AppPalette.categoryCode)
  static let categoryLink = Color(hex: AppPalette.categoryLink)
  static let categoryMedia = Color(hex: AppPalette.categoryMedia)
  static let categoryColor = Color(hex: AppPalette.categoryColor)
  
  func toHex() -> String? {
    // Convert to sRGB color space if possible to ensure components exist
    guard let legacyColor = self.cgColor?.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil),
          let components = legacyColor.components,
          components.count >= 3
    else { return nil }
    
    let r = Float(components[0])
    let g = Float(components[1])
    let b = Float(components[2])
    
    return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
  }
}
