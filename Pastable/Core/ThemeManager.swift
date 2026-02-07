import SwiftUI
import Combine

// 1. Define the Palette Structure
struct ThemePalette: Codable, Equatable {
  var text: String
  var code: String
  var link: String
  var other: String
  var all: String
  
  // Convert hex strings to SwiftUI Colors
  var textColor: Color { Color(hex: text) }
  var codeColor: Color { Color(hex: code) }
  var linkColor: Color { Color(hex: link) }
  var otherColor: Color { Color(hex: other) }
  var allColor: Color { Color(hex: all) }
  
  static let deepElegant = ThemePalette(
    text: "#334155", // Slate-700
    code: "#4C1D95", // Violet-900
    link: "#1E40AF", // Blue-800
    other: "#BE123C", // Rose-700
    all: "#1F2937"    // Gray-800
  )
  
  static let vibrant = ThemePalette(
    text: "#059669", // Emerald-600
    code: "#7C3AED", // Violet-600
    link: "#2563EB", // Blue-600
    other: "#DB2777", // Pink-600
    all: "#64748B"    // Slate-500
  )
  
  static let muted = ThemePalette(
    text: "#567C73", // Muted Pine
    code: "#8A819C", // Muted Purple
    link: "#6385A7", // Muted Blue
    other: "#B57E86", // Muted Rose
    all: "#6B7280"    // Muted Gray
  )
}

// 2. Define Theme Modes
enum ThemeMode: String, CaseIterable, Codable {
  case deepElegant = "Deep Elegant"
  case vibrant = "Vibrant"
  case muted = "Muted (Ya Se)"
  case adaptive = "Adaptive (App Color)"
  case custom = "Custom"
  
  var localizedName: LocalizedStringKey {
    LocalizedStringKey(self.rawValue)
  }
}

// 3. Theme Manager
class ThemeManager: ObservableObject {
  static let shared = ThemeManager()
  
  // lock to adaptive mode as per user request
  var currentMode: ThemeMode = .adaptive
  
  var activePalette: ThemePalette {
     // Always use Deep Elegant as the base palette, 
     // which Adaptive Mode uses for fallback/text colors.
     return .deepElegant
  }
}
