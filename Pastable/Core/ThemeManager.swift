import SwiftUI
import AppKit

// MARK: - Tokens

/// Solid semantic tokens for the two appearances. Every value is an opaque
/// six-digit hex string; text never relies on white/black alpha.
struct AppTheme {
  let scheme: ColorScheme

  init(_ scheme: ColorScheme) {
    self.scheme = scheme
  }

  var isDark: Bool { scheme == .dark }

  // Panel
  var panelTop: Color { color(isDark ? "#2B2C31" : "#EDF0F4") }
  var panelMid: Color { color(isDark ? "#26272C" : "#E4E8EE") }
  var panelBottom: Color { color(isDark ? "#151619" : "#D7DCE4") }
  var panelBorder: Color { color(isDark ? "#363941" : "#C9D1DB") }

  // Cards
  var cardBaseHex: String { isDark ? "#111214" : "#FFFFFF" }
  var cardBase: Color { color(cardBaseHex) }
  var cardBorder: Color { color(isDark ? "#2D3036" : "#D8DEE7") }
  var imageBorder: Color { color(isDark ? "#34373D" : "#D3DAE3") }
  var cardTintNormal: Double { isDark ? 0.18 : 0.12 }
  var cardTintSelected: Double { isDark ? 0.24 : 0.20 }

  // Text — solid only
  var textPrimary: Color { color(isDark ? "#F3F4F6" : "#101216") }
  var textBody: Color { color(isDark ? "#D9DCE1" : "#2B3037") }
  var textSecondary: Color { color(isDark ? "#A8ADB6" : "#414750") }
  var textTertiary: Color { color(isDark ? "#8B9099" : "#515861") }
  var textPlaceholder: Color { color(isDark ? "#7E838C" : "#656D78") }

  // Search
  var searchBackground: Color { color(isDark ? "#1A1C21" : "#FFFFFF") }
  var searchBorder: Color { color(isDark ? "#30333A" : "#C9D1DB") }
  var searchDivider: Color { color(isDark ? "#34373D" : "#DCE1E8") }

  // Category tabs
  var tabBackground: Color { color(isDark ? "#1D1F24" : "#FFFFFF") }
  var tabBorder: Color { color(isDark ? "#2C2F36" : "#D3DAE3") }
  var tabHoverBackground: Color { color(isDark ? "#24262C" : "#F0F3F7") }
  var tabSelectedBackground: Color { color(isDark ? "#3A2418" : "#FFE8D6") }
  var tabText: Color { color(isDark ? "#B9BDC4" : "#3C424B") }
  var tabTextSelected: Color { color(isDark ? "#F3F4F6" : "#17191D") }

  // Footer / badges
  var typePillBackground: Color { color(isDark ? "#23252A" : "#EDF0F4") }
  var typePillText: Color { color(isDark ? "#C9CDD3" : "#3C424B") }

  // Empty state
  var emptyTileBackground: Color { color(isDark ? "#1F2126" : "#FFFFFF") }
  var emptyTileBorder: Color { color(isDark ? "#2B2E35" : "#D3DAE3") }
  var emptyIcon: Color { color(isDark ? "#8B9099" : "#555C66") }
  var emptyTitle: Color { color(isDark ? "#C9CDD3" : "#17191D") }
  var emptySubtitle: Color { color(isDark ? "#8B9099" : "#515861") }
  var keycapBackground: Color { color(isDark ? "#24262B" : "#FFFFFF") }
  var keycapBorder: Color { color(isDark ? "#34373D" : "#D3DAE3") }
  var keycapText: Color { color(isDark ? "#A8ADB6" : "#4B515B") }
  var keycapLabel: Color { color(isDark ? "#8B9099" : "#515861") }

  // More menu
  var menuBackground: Color { color(isDark ? "#1F2126" : "#FFFFFF") }
  var menuBorder: Color { color(isDark ? "#34373D" : "#D3DAE3") }
  var menuText: Color { color(isDark ? "#F3F4F6" : "#17191D") }
  var menuIcon: Color { color(isDark ? "#C9CDD3" : "#4B515B") }
  var menuShortcut: Color { color(isDark ? "#8B9099" : "#515861") }
  var menuHover: Color { color(isDark ? "#2A2C32" : "#F0F3F7") }
  var menuSeparator: Color { color(isDark ? "#34373D" : "#DCE1E8") }

  // Helpers
  func cardTop(tintHex: String, selected: Bool) -> Color {
    let ratio = selected ? cardTintSelected : cardTintNormal
    return Color(hex: Self.mixedHex(tintHex, with: cardBaseHex, ratio: ratio))
  }

  func contrastText(on hex: String) -> Color {
    Self.luminance(hex) > 0.68
      ? Color(hex: "#17191D")
      : Color(hex: "#FFFFFF")
  }

  /// Solid chip behind the hex value on a color card.
  func contrastChip(on hex: String) -> Color {
    Self.luminance(hex) > 0.68
      ? Color(hex: "#FFFFFF")
      : Color(hex: "#111214")
  }

  private func color(_ hex: String) -> Color { Color(hex: hex) }

  static func mixedHex(_ hex: String, with base: String, ratio: Double) -> String {
    let (r1, g1, b1) = rgb(hex)
    let (r2, g2, b2) = rgb(base)
    let clamp = { (value: Double) in min(1, max(0, value)) }
    let mix = { (a: Double, b: Double) in
      Int((clamp(a) * ratio + clamp(b) * (1 - ratio)) * 255)
    }
    return String(format: "#%02X%02X%02X", mix(r1, r2), mix(g1, g2), mix(b1, b2))
  }

  static func luminance(_ hex: String) -> Double {
    let (r, g, b) = rgb(hex)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b
  }

  private static func rgb(_ value: String) -> (Double, Double, Double) {
    let cleaned = value.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var intValue: UInt64 = 0
    Scanner(string: cleaned).scanHexInt64(&intValue)

    switch cleaned.count {
    case 3:
      return (
        Double((intValue >> 8) * 17) / 255,
        Double((intValue >> 4 & 0xF) * 17) / 255,
        Double((intValue & 0xF) * 17) / 255
      )
    case 6, 8:
      return (
        Double(intValue >> 16 & 0xFF) / 255,
        Double(intValue >> 8 & 0xFF) / 255,
        Double(intValue & 0xFF) / 255
      )
    default:
      return (1, 1, 1)
    }
  }
}
