import XCTest
import SwiftUI
import AppKit
@testable import music

final class ThemeManagerTests: XCTestCase {
    func testAppThemeProperties() {
        XCTAssertNil(AppTheme.system.colorScheme)
        XCTAssertNil(AppTheme.system.nsAppearance)
        
        XCTAssertEqual(AppTheme.light.colorScheme, .light)
        XCTAssertEqual(AppTheme.light.nsAppearance?.name, .aqua)
        
        XCTAssertEqual(AppTheme.dark.colorScheme, .dark)
        XCTAssertEqual(AppTheme.dark.nsAppearance?.name, .darkAqua)
    }
    
    func testThemePersistence() {
        let original = ThemeManager.shared.currentTheme
        
        ThemeManager.shared.currentTheme = .dark
        XCTAssertEqual(ThemeManager.shared.currentTheme, .dark)
        let savedDark = UserDefaults.standard.string(forKey: ThemeManager.themeStorageKey)
        XCTAssertEqual(savedDark, "dark")
        
        ThemeManager.shared.currentTheme = .light
        XCTAssertEqual(ThemeManager.shared.currentTheme, .light)
        let savedLight = UserDefaults.standard.string(forKey: ThemeManager.themeStorageKey)
        XCTAssertEqual(savedLight, "light")
        
        ThemeManager.shared.currentTheme = .system
        XCTAssertEqual(ThemeManager.shared.currentTheme, .system)
        let savedSystem = UserDefaults.standard.string(forKey: ThemeManager.themeStorageKey)
        XCTAssertEqual(savedSystem, "system")
        
        // Restore
        ThemeManager.shared.currentTheme = original
    }
    
    func testEffectiveColorScheme() {
        let original = ThemeManager.shared.currentTheme
        
        ThemeManager.shared.currentTheme = .light
        XCTAssertEqual(ThemeManager.shared.effectiveColorScheme, .light)
        
        ThemeManager.shared.currentTheme = .dark
        XCTAssertEqual(ThemeManager.shared.effectiveColorScheme, .dark)
        
        ThemeManager.shared.currentTheme = .system
        let expectedSystemScheme: ColorScheme = ThemeManager.shared.isSystemInDarkMode ? .dark : .light
        XCTAssertEqual(ThemeManager.shared.effectiveColorScheme, expectedSystemScheme)
        
        // Restore
        ThemeManager.shared.currentTheme = original
    }
    
    func testApplyAppearanceSafety() {
        let manager = ThemeManager.shared
        manager.apply()
        XCTAssertNotNil(manager.effectiveColorScheme)
    }
}
