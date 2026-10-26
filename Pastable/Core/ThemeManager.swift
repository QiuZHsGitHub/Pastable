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

  // Accent (mode-aware: light vermilion on dark, deep cinnabar on light)
  let accent: Color
  let accentGlow: Double

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

    accent = Color(hex: isDark ? AppPalette.accentDark : AppPalette.accentLight)
    accentGlow = isDark ? 0.24 : 0.16

    panelTop = Color(hex: isDark ? "#2C2A29" : "#F5F0E9")
    panelMid = Color(hex: isDark ? "#252322" : "#EBE4DA")
    panelBottom = Color(hex: isDark ? "#141211" : "#DDD2C4")
    panelBorder = Color(hex: isDark ? "#3A3634" : "#CFC4B5")

    cardBaseHex = isDark ? "#131110" : "#FFFDFB"
    cardBase = Color(hex: cardBaseHex)
    cardBorder = Color(hex: isDark ? "#302C2A" : "#DED5C8")
    imageBorder = Color(hex: isDark ? "#383330" : "#D8CEC0")
    cardTintNormal = isDark ? 0.18 : 0.12
    cardTintSelected = isDark ? 0.24 : 0.20

    textPrimary = Color(hex: isDark ? "#F6F1EA" : "#1B1816")
    textBody = Color(hex: isDark ? "#DCD5CC" : "#35302B")
    textSecondary = Color(hex: isDark ? "#ACA49B" : "#4A443D")
    textTertiary = Color(hex: isDark ? "#8E867D" : "#5C554C")
    textPlaceholder = Color(hex: isDark ? "#80786F" : "#6E665B")

    searchBackground = Color(hex: isDark ? "#1B1918" : "#FFFDFB")
    searchBorder = Color(hex: isDark ? "#332F2D" : "#CFC4B5")
    searchDivider = Color(hex: isDark ? "#3A3532" : "#E2D9CC")

    tabBackground = Color(hex: isDark ? "#1E1B1A" : "#FFFDFB")
    tabBorder = Color(hex: isDark ? "#2F2B29" : "#D8CEC0")
    tabHoverBackground = Color(hex: isDark ? "#262221" : "#F3EDE5")
    tabSelectedBackground = Color(hex: isDark ? "#3B201B" : "#FBE3DC")
    tabText = Color(hex: isDark ? "#BDB5AC" : "#433D36")
    tabTextSelected = Color(hex: isDark ? "#F6F1EA" : "#1B1816")

    typePillBackground = Color(hex: isDark ? "#242120" : "#F1EBE2")
    typePillText = Color(hex: isDark ? "#CCC4BB" : "#433D36")

    emptyTileBackground = Color(hex: isDark ? "#201D1C" : "#FFFDFB")
    emptyTileBorder = Color(hex: isDark ? "#2D2927" : "#D8CEC0")
    emptyIcon = Color(hex: isDark ? "#8E867D" : "#5C554C")
    emptyTitle = Color(hex: isDark ? "#CCC4BB" : "#1B1816")
    emptySubtitle = Color(hex: isDark ? "#8E867D" : "#5C554C")
    keycapBackground = Color(hex: isDark ? "#252221" : "#FFFDFB")
    keycapBorder = Color(hex: isDark ? "#383330" : "#D8CEC0")
    keycapText = Color(hex: isDark ? "#ACA49B" : "#4E473F")
    keycapLabel = Color(hex: isDark ? "#8E867D" : "#5C554C")

    menuBackground = Color(hex: isDark ? "#201D1C" : "#FFFDFB")
    menuBorder = Color(hex: isDark ? "#383330" : "#D8CEC0")
    menuText = Color(hex: isDark ? "#F6F1EA" : "#1B1816")
    menuIcon = Color(hex: isDark ? "#CCC4BB" : "#4E473F")
    menuShortcut = Color(hex: isDark ? "#8E867D" : "#5C554C")
    menuHover = Color(hex: isDark ? "#2B2725" : "#F3EDE5")
    menuSeparator = Color(hex: isDark ? "#3A3532" : "#E2D9CC")
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
      ? Color(hex: "#FFFDFB")
      : Color(hex: "#14110F")
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
