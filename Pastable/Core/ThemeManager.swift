import SwiftUI
import AppKit

// MARK: - Tokens

/// Solid semantic tokens for the two appearances. Every value is an opaque
/// six-digit hex string; text never relies on white/black alpha.
///
/// Tokens are stored properties resolved once per appearance. Views recreate
/// the theme many times per frame, so parsing hex strings (and mixing card
/// tints) on every property access showed up as measurable render cost.
struct AppTheme {
  static let dark = AppTheme(.dark)
  static let light = AppTheme(.light)

  /// Cached theme instance for the given appearance.
  static func theme(for scheme: ColorScheme) -> AppTheme {
    scheme == .dark ? dark : light
  }

  let scheme: ColorScheme
  let isDark: Bool

  // Panel
  let panelTop: Color
  let panelMid: Color
  let panelBottom: Color
  let panelBorder: Color

  // Cards
  let cardBaseHex: String
  let cardBase: Color
  let cardBorder: Color
  let imageBorder: Color
  let cardTintNormal: Double
  let cardTintSelected: Double

  // Text — solid only
  let textPrimary: Color
  let textBody: Color
  let textSecondary: Color
  let textTertiary: Color
  let textPlaceholder: Color

  // Search
  let searchBackground: Color
  let searchBorder: Color
  let searchDivider: Color

  // Category tabs
  let tabBackground: Color
  let tabBorder: Color
  let tabHoverBackground: Color
  let tabSelectedBackground: Color
  let tabText: Color
  let tabTextSelected: Color

  // Footer / badges
  let typePillBackground: Color
  let typePillText: Color

  // Empty state
  let emptyTileBackground: Color
  let emptyTileBorder: Color
  let emptyIcon: Color
  let emptyTitle: Color
  let emptySubtitle: Color
  let keycapBackground: Color
  let keycapBorder: Color
  let keycapText: Color
  let keycapLabel: Color

  // More menu
  let menuBackground: Color
  let menuBorder: Color
  let menuText: Color
  let menuIcon: Color
  let menuShortcut: Color
  let menuHover: Color
  let menuSeparator: Color

  init(_ scheme: ColorScheme) {
    self.scheme = scheme
    self.isDark = scheme == .dark

    panelTop = Color(hex: isDark ? "#2B2C31" : "#EDF0F4")
    panelMid = Color(hex: isDark ? "#26272C" : "#E4E8EE")
    panelBottom = Color(hex: isDark ? "#151619" : "#D7DCE4")
    panelBorder = Color(hex: isDark ? "#363941" : "#C9D1DB")

    cardBaseHex = isDark ? "#111214" : "#FFFFFF"
    cardBase = Color(hex: cardBaseHex)
    cardBorder = Color(hex: isDark ? "#2D3036" : "#D8DEE7")
    imageBorder = Color(hex: isDark ? "#34373D" : "#D3DAE3")
    cardTintNormal = isDark ? 0.18 : 0.12
    cardTintSelected = isDark ? 0.24 : 0.20

    textPrimary = Color(hex: isDark ? "#F3F4F6" : "#101216")
    textBody = Color(hex: isDark ? "#D9DCE1" : "#2B3037")
    textSecondary = Color(hex: isDark ? "#A8ADB6" : "#414750")
    textTertiary = Color(hex: isDark ? "#8B9099" : "#515861")
    textPlaceholder = Color(hex: isDark ? "#7E838C" : "#656D78")

    searchBackground = Color(hex: isDark ? "#1A1C21" : "#FFFFFF")
    searchBorder = Color(hex: isDark ? "#30333A" : "#C9D1DB")
    searchDivider = Color(hex: isDark ? "#34373D" : "#DCE1E8")

    tabBackground = Color(hex: isDark ? "#1D1F24" : "#FFFFFF")
    tabBorder = Color(hex: isDark ? "#2C2F36" : "#D3DAE3")
    tabHoverBackground = Color(hex: isDark ? "#24262C" : "#F0F3F7")
    tabSelectedBackground = Color(hex: isDark ? "#3A2418" : "#FFE8D6")
    tabText = Color(hex: isDark ? "#B9BDC4" : "#3C424B")
    tabTextSelected = Color(hex: isDark ? "#F3F4F6" : "#17191D")

    typePillBackground = Color(hex: isDark ? "#23252A" : "#EDF0F4")
    typePillText = Color(hex: isDark ? "#C9CDD3" : "#3C424B")

    emptyTileBackground = Color(hex: isDark ? "#1F2126" : "#FFFFFF")
    emptyTileBorder = Color(hex: isDark ? "#2B2E35" : "#D3DAE3")
    emptyIcon = Color(hex: isDark ? "#8B9099" : "#555C66")
    emptyTitle = Color(hex: isDark ? "#C9CDD3" : "#17191D")
    emptySubtitle = Color(hex: isDark ? "#8B9099" : "#515861")
    keycapBackground = Color(hex: isDark ? "#24262B" : "#FFFFFF")
    keycapBorder = Color(hex: isDark ? "#34373D" : "#D3DAE3")
    keycapText = Color(hex: isDark ? "#A8ADB6" : "#4B515B")
    keycapLabel = Color(hex: isDark ? "#8B9099" : "#515861")

    menuBackground = Color(hex: isDark ? "#1F2126" : "#FFFFFF")
    menuBorder = Color(hex: isDark ? "#34373D" : "#D3DAE3")
    menuText = Color(hex: isDark ? "#F3F4F6" : "#17191D")
    menuIcon = Color(hex: isDark ? "#C9CDD3" : "#4B515B")
    menuShortcut = Color(hex: isDark ? "#8B9099" : "#515861")
    menuHover = Color(hex: isDark ? "#2A2C32" : "#F0F3F7")
    menuSeparator = Color(hex: isDark ? "#34373D" : "#DCE1E8")
  }

  // Helpers
  func cardTop(tintHex: String, selected: Bool) -> Color {
    let ratio = selected ? cardTintSelected : cardTintNormal
    return Self.mixedColor(tintHex, with: cardBaseHex, ratio: ratio)
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

  /// Mixed tint colors are requested on every card render; memoize them.
  static func mixedColor(_ hex: String, with base: String, ratio: Double) -> Color {
    mixCache.color(key: "\(hex)|\(base)|\(ratio)") {
      Color(hex: mixedHex(hex, with: base, ratio: ratio))
    }
  }

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

  private static let mixCache = ColorMemo()

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

/// Small thread-safe memo used for repeatedly parsed color values.
final class ColorMemo: @unchecked Sendable {
  private let lock = NSLock()
  private var storage: [String: Color] = [:]

  func color(key: String, make: () -> Color) -> Color {
    lock.lock()
    defer { lock.unlock() }
    if let cached = storage[key] { return cached }
    let value = make()
    storage[key] = value
    return value
  }
}
