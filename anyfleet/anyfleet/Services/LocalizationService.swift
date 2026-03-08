import SwiftUI
import Observation

/// Manages runtime language switching only.
/// For all static string access, use the generated `L10n` enum.
@Observable
final class LocalizationService {
    /// Current language override (nil = follow system)
    var currentLanguage: AppLanguage? {
        didSet { saveLanguagePreference() }
    }
    
    /// Effective language considering system fallback.
    var effectiveLanguage: AppLanguage {
        currentLanguage ?? systemLanguage
    }
    
    private var systemLanguage: AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("ru") { return .russian }
        if preferred.hasPrefix("en") { return .english }
        return .english
    }
    
    init() {
        self.currentLanguage = loadLanguagePreference()
    }
    
    // MARK: - Public API
    func setLanguage(_ language: AppLanguage?) {
        currentLanguage = language
    }
    
    func useSystemLanguage() {
        currentLanguage = nil
    }
    
    // MARK: - Persistence
    private func saveLanguagePreference() {
        if let language = currentLanguage {
            UserDefaults.standard.set(language.code, forKey: "app_language")
        } else {
            UserDefaults.standard.removeObject(forKey: "app_language")
        }
    }
    
    private func loadLanguagePreference() -> AppLanguage? {
        guard let code = UserDefaults.standard.string(forKey: "app_language") else {
            return nil
        }
        return AppLanguage(rawValue: code)
    }
}

// MARK: - AppLanguage

enum AppLanguage: String, CaseIterable, Identifiable {
    case russian = "ru"
    case english = "en"
    
    var id: String { rawValue }
    
    var code: String { rawValue }
    
    var displayName: String {
        switch self {
        case .russian: return "Русский"
        case .english: return "English"
        }
    }
}

// MARK: - SwiftUI Environment

private struct LocalizationServiceKey: EnvironmentKey {
    static var defaultValue: LocalizationService { LocalizationService() }
}

extension EnvironmentValues {
    var localization: LocalizationService {
        get { self[LocalizationServiceKey.self] }
        set { self[LocalizationServiceKey.self] = newValue }
    }
}
