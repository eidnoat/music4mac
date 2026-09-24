import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

public enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
    
    public var iconName: String {
        switch self {
        case .system:
            return "circle.righthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }
    
    public var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    #if os(macOS)
    public var nsAppearance: NSAppearance? {
        switch self {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }
    #endif
}

public final class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()
    
    public static let themeStorageKey = "music.settings.appTheme"
    
    @Published public var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: Self.themeStorageKey)
            apply()
        }
    }
    
    @Published public private(set) var isSystemInDarkMode: Bool = false
    
    public var effectiveColorScheme: ColorScheme {
        switch currentTheme {
        case .system:
            return isSystemInDarkMode ? .dark : .light
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    private init() {
        let savedRaw = UserDefaults.standard.string(forKey: Self.themeStorageKey)
            ?? UserDefaults.standard.string(forKey: "sylvakru.settings.appTheme")
            ?? AppTheme.system.rawValue
        let theme = AppTheme(rawValue: savedRaw) ?? .system
        self.currentTheme = theme
        
        #if os(macOS)
        let style = UserDefaults.standard.string(forKey: "AppleInterfaceStyle")
        self.isSystemInDarkMode = style?.caseInsensitiveCompare("dark") == .orderedSame
        setupSystemThemeObserver()
        #endif
        
        DispatchQueue.main.async { [weak self] in
            self?.apply()
        }
    }
    
    deinit {
        #if os(macOS)
        DistributedNotificationCenter.default().removeObserver(self)
        #endif
    }
    
    #if os(macOS)
    private func setupSystemThemeObserver() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleSystemThemeChanged),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
    }
    
    @objc private func handleSystemThemeChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.apply()
        }
    }
    #endif
    
    public func apply() {
        if Thread.isMainThread {
            self.performApply()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.performApply()
            }
        }
    }
    
    #if os(macOS)
    private func performApply() {
        let targetAppearance = currentTheme.nsAppearance
        NSApp?.appearance = targetAppearance
        
        for window in NSApplication.shared.windows {
            window.appearance = targetAppearance
            window.invalidateShadow()
        }
        
        updateSystemDarkMode()
    }
    
    private func updateSystemDarkMode() {
        let isDark: Bool
        if currentTheme == .system {
            if let match = NSApp?.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) {
                isDark = (match == .darkAqua)
            } else if let style = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") {
                isDark = style.caseInsensitiveCompare("dark") == .orderedSame
            } else {
                isDark = false
            }
        } else {
            let style = UserDefaults.standard.string(forKey: "AppleInterfaceStyle")
            isDark = style?.caseInsensitiveCompare("dark") == .orderedSame
        }
        
        if self.isSystemInDarkMode != isDark {
            self.isSystemInDarkMode = isDark
        }
    }
    #elseif os(iOS)
    private func performApply() {
        let style: UIUserInterfaceStyle
        switch currentTheme {
        case .system:
            style = .unspecified
        case .light:
            style = .light
        case .dark:
            style = .dark
        }
        
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                for window in windowScene.windows {
                    window.overrideUserInterfaceStyle = style
                }
            }
        }
    }
    #endif
}
