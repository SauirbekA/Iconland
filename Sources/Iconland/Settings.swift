import Foundation

/// Persistent user settings (~/Library/Application Support/Iconland/settings.json).
final class Settings {
    var theme = "beach"
    var params: [String: [String: Any]] = [:]   // theme id → { key: value }
    var lang = "auto"                            // "auto" | "en" | "ru"

    private let url = Paths.support.appendingPathComponent("settings.json")
    private var pending: DispatchWorkItem?

    init() {
        guard let root = JSON.read(url) as? [String: Any] else { return }
        if let t = root["theme"] as? String { theme = t }
        if let p = root["params"] as? [String: [String: Any]] { params = p }
        if let l = root["lang"] as? String { lang = l }
    }

    func values(for theme: String) -> [String: Any] { params[theme] ?? [:] }

    func set(theme: String, key: String, value: Any) {
        var v = params[theme] ?? [:]
        v[key] = value
        params[theme] = v
        saveSoon()
    }

    func reset(theme: String) {
        params.removeValue(forKey: theme)
        saveSoon()
    }

    func saveSoon() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    func saveNow() {
        pending?.cancel(); pending = nil
        let root: [String: Any] = ["theme": theme, "params": params, "lang": lang]
        if let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

/// Free, ready themes from web/themes.json, plus localized names from web/i18n/<lang>.json.
struct ThemeInfo {
    let id: String
    let page: String
    let name: String
}

enum ThemeRegistry {
    static func load(lang: String) -> [ThemeInfo] {
        guard let root = JSON.read(Paths.web.appendingPathComponent("themes.json")) as? [String: Any],
              let list = root["themes"] as? [[String: Any]] else { return [] }
        let i18n = (JSON.read(Paths.web.appendingPathComponent("i18n/\(lang).json")) as? [String: Any])?["themes"] as? [String: Any]
        return list.compactMap { t in
            guard let id = t["id"] as? String, let page = t["page"] as? String,
                  t["status"] as? String == "ready", t["product"] as? String == "free" else { return nil }
            let localized = (i18n?[id] as? [String: Any])?["name"] as? String
            return ThemeInfo(id: id, page: page, name: localized ?? (t["name"] as? String) ?? id)
        }
    }
}

/// UI language: the settings page supports these; "auto" follows the system.
enum Lang {
    static let supported = ["en", "ru"]

    static var system: String {
        for l in Locale.preferredLanguages {
            let code = l.lowercased()
            if code.hasPrefix("ru") && hasFile("ru") { return "ru" }
            if code.hasPrefix("en") { return "en" }
        }
        return "en"
    }

    static func effective(_ setting: String) -> String {
        if setting != "auto", supported.contains(setting), hasFile(setting) { return setting }
        return system
    }

    static func hasFile(_ code: String) -> Bool {
        FileManager.default.fileExists(atPath: Paths.web.appendingPathComponent("i18n/\(code).json").path)
    }

    /// Strings for the menu bar menu.
    static func menu(_ key: String, _ lang: String) -> String {
        let table: [String: [String: String]] = [
            "settings":  ["en": "Settings…", "ru": "Настройки…"],
            "themes":    ["en": "Theme", "ru": "Тема"],
            "pause":     ["en": "Pause animation", "ru": "Приостановить анимацию"],
            "reload":    ["en": "Reload", "ru": "Перезагрузить"],
            "autostart": ["en": "Start with Mac", "ru": "Запускать вместе с Mac"],
            "quit":      ["en": "Quit \(appName)", "ru": "Выйти из \(appName)"],
            "noAccess":  ["en": "Allow access to Finder…", "ru": "Разрешить доступ к Finder…"],
        ]
        return table[key]?[lang] ?? table[key]?["en"] ?? key
    }
}
