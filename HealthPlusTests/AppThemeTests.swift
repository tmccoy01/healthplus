import SwiftUI
import XCTest
@testable import HealthPlus

@MainActor
final class AppThemeTests: XCTestCase {
    func testColorTokenHexPaletteMatchesDesignContract() {
        XCTAssertEqual(AppTheme.hex(for: .bgCanvas), "0B0E11")
        XCTAssertEqual(AppTheme.hex(for: .bgSurface), "11161C")
        XCTAssertEqual(AppTheme.hex(for: .bgSurfaceElevated), "1A2330")
        XCTAssertEqual(AppTheme.hex(for: .accentPrimary), "27C0D9")
        XCTAssertEqual(AppTheme.hex(for: .stateSuccess), "44D07D")
        XCTAssertEqual(AppTheme.hex(for: .stateWarning), "F4C257")
        XCTAssertEqual(AppTheme.hex(for: .stateError), "F06A5F")
    }

    func testAllColorTokensResolveToValidHexColor() {
        for token in AppTheme.ColorToken.allCases {
            let hex = AppTheme.hex(for: token)
            XCTAssertNotNil(Color(hex: hex), "Expected a valid hex color for token \(token)")
        }
    }

    func testLegacyAliasesMapToExpectedSemanticTokens() {
        XCTAssertEqual(AppTheme.token(for: .background), .bgCanvas)
        XCTAssertEqual(AppTheme.token(for: .surface), .bgSurface)
        XCTAssertEqual(AppTheme.token(for: .surfaceMuted), .bgSurfaceElevated)
        XCTAssertEqual(AppTheme.token(for: .accent), .accentPrimary)
        XCTAssertEqual(AppTheme.token(for: .trendUp), .stateSuccess)
        XCTAssertEqual(AppTheme.token(for: .trendFlat), .stateWarning)
        XCTAssertEqual(AppTheme.token(for: .trendDown), .stateError)
    }
}
