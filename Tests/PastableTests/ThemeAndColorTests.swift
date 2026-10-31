import XCTest
import SwiftUI
@testable import Pastable

/// Theme token math and hex color parsing/round-tripping.
final class ThemeAndColorTests: XCTestCase {
  func testThemeSelectionFollowsColorScheme() {
    XCTAssertTrue(AppTheme.theme(for: .dark).isDark)
    XCTAssertFalse(AppTheme.theme(for: .light).isDark)
    XCTAssertEqual(AppTheme.theme(for: .dark).scheme, .dark)
    XCTAssertEqual(AppTheme.theme(for: .light).scheme, .light)
  }

  func testMixedHexEndpointsAndMidpoint() {
    XCTAssertEqual(AppTheme.mixedHex("#FF0000", with: "#000000", ratio: 0), "#000000")
    XCTAssertEqual(AppTheme.mixedHex("#FF0000", with: "#000000", ratio: 1), "#FF0000")
    XCTAssertEqual(AppTheme.mixedHex("#FF0000", with: "#000000", ratio: 0.5), "#7F0000")
  }

  func testLuminanceOfBlackAndWhite() {
    XCTAssertEqual(AppTheme.luminance("#FFFFFF"), 1, accuracy: 0.001)
    XCTAssertEqual(AppTheme.luminance("#000000"), 0, accuracy: 0.001)
    XCTAssertEqual(AppTheme.luminance("#808080"), 0.5019, accuracy: 0.01)
  }

  func testContrastTextAndChipFlipOnLightBackgrounds() {
    let theme = AppTheme.light
    XCTAssertEqual(theme.contrastText(on: "#FFFFFF").toHex(), "#17191D")
    XCTAssertEqual(theme.contrastText(on: "#000000").toHex(), "#FFFFFF")
    XCTAssertEqual(theme.contrastChip(on: "#FFFFFF").toHex(), "#FFFDFB")
    XCTAssertEqual(theme.contrastChip(on: "#000000").toHex(), "#14110F")
  }

  func testCardTintMixesTowardTheCardBase() {
    let theme = AppTheme.dark
    let top = theme.cardTop(tintHex: "#FFFFFF", selected: false)
    XCTAssertNotNil(top.toHex())
    XCTAssertNotEqual(top.toHex(), "#FFFFFF", "the tint is mixed with the card base")
  }

  func testHexColorParsingRoundTripsSixDigitValues() {
    for hex in ["#C8402E", "#4E8F7C", "#4A7DB2", "#9A72A8", "#C46F88", "#D9824B"] {
      XCTAssertEqual(Color(hex: hex).toHex(), hex, "failed round-trip for \(hex)")
    }
  }

  func testThreeDigitHexExpands() {
    XCTAssertEqual(Color(hex: "#F00").toHex(), "#FF0000")
    XCTAssertEqual(Color(hex: "#0f0").toHex(), "#00FF00")
    XCTAssertEqual(Color(hex: "#00F").toHex(), "#0000FF")
  }

  func testEightDigitHexUsesAlphaAndKeepsRGB() {
    XCTAssertEqual(Color(hex: "#80FF0000").toHex(), "#FF0000")
    XCTAssertEqual(Color(hex: "#00112233").toHex(), "#112233")
  }

  func testPaletteAccentSurvivesConversion() {
    XCTAssertEqual(Color.pastableAccent.toHex(), AppPalette.accentLight)
  }

  func testCategoryPaletteIsDistinct() {
    let values = [
      AppPalette.categoryAll,
      AppPalette.categoryText,
      AppPalette.categoryCode,
      AppPalette.categoryLink,
      AppPalette.categoryMedia,
      AppPalette.categoryColor
    ]
    XCTAssertEqual(Set(values).count, values.count)
  }

  func testColorMemoReturnsTheSameValueForTheSameKey() {
    let memo = ColorMemo()
    let first = memo.color(key: "accent") { Color(hex: "#C8402E") }
    let second = memo.color(key: "accent") { Color(hex: "#000000") }

    XCTAssertEqual(first.toHex(), second.toHex())
    XCTAssertEqual(first.toHex(), "#C8402E")
  }
}
