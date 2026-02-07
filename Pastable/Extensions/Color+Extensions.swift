import SwiftUI

extension Color {
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
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

  static let pastableOrange = Color(hex: "#F56300")
  static let pastableDarkBlue = Color(hex: "#1C2533")
  static let pastableBackground = Color(hex: "#2C2C2E")
  
  // 渐变色
  static let pastableOrangeGradientStart = Color(hex: "#FF6900")
  static let pastableOrangeGradientEnd = Color(hex: "#F54900")
  // Theme Colors (Semantic - Deep Elegant Dark Mode)
  static let themeText = Color(hex: "#334155")       // Slate-700 (Calm Blue-Grey)
  static let themeCode = Color(hex: "#4C1D95")       // Violet-900 (Deep Purple)
  static let themeLink = Color(hex: "#1E40AF")       // Blue-800 (Deep Ocean)
  static let themeOther = Color(hex: "#BE123C")      // Rose-700 (Deep Pink/Red)
  static let themeAll = Color(hex: "#1F2937")        // Gray-800 (Charcoal)
  
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
