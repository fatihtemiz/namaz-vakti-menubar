import Foundation

/// Uygulama arayüz dili. Ayarlardan seçilir, UserDefaults'ta "appLanguage" olarak saklanır.
enum AppLanguage: String, CaseIterable, Identifiable {
    case tr, en

    static let storageKey = "appLanguage"

    var id: String { rawValue }

    /// Seçicide her dil kendi adıyla görünür.
    var label: String {
        switch self {
        case .tr: return "Türkçe"
        case .en: return "English"
        }
    }

    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .tr
    }
}

/// Seçili dile göre Türkçe ya da İngilizce metni döndürür.
func loc(_ tr: String, _ en: String) -> String {
    AppLanguage.current == .en ? en : tr
}
