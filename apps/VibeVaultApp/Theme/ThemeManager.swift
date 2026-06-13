import SwiftUI
import Combine

/// Manages app theme (light/dark/system) with persistence
@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    enum Theme: String, CaseIterable, Identifiable {
        case system = "system"
        case light = "light"
        case dark = "dark"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
        
        var icon: String {
            switch self {
            case .system: return "circle.lefthalf.filled"
            case .light: return "sun.max.fill"
            case .dark: return "moon.fill"
            }
        }
    }
    
    @Published var currentTheme: Theme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "app_theme")
            applyTheme()
        }
    }
    
    var colorScheme: ColorScheme? {
        switch currentTheme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: "app_theme") ?? "system"
        self.currentTheme = Theme(rawValue: saved) ?? .system
    }
    
    func applyTheme() {
        // Theme is applied via .preferredColorScheme in view hierarchy
    }
}
