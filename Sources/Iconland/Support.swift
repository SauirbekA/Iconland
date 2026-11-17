import AppKit

let appName = "Iconland"

enum Paths {
    /// ~/Library/Application Support/Iconland (settings.json, host.log)
    static let support: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent(appName, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    /// Theme pages: Contents/Resources/web inside the bundle, or ./web next to the package when run with `swift run`.
    static let web: URL = {
        if let env = ProcessInfo.processInfo.environment["ICONLAND_WEB"] {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        if let res = Bundle.main.resourceURL?.appendingPathComponent("web", isDirectory: true),
           FileManager.default.fileExists(atPath: res.appendingPathComponent("themes.json").path) {
            return res
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("web", isDirectory: true)
    }()

    /// ~/Pictures/Iconland — shared images and clips.
    static let share: URL = {
        let base = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(appName, isDirectory: true)
    }()
}

enum Log {
    private static let queue = DispatchQueue(label: "log")
    static let file = Paths.support.appendingPathComponent("host.log")

    static func write(_ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date()))  \(message)\n"
        queue.async {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
               let size = attrs[.size] as? Int, size > 1_000_000 {
                try? FileManager.default.removeItem(at: file)
            }
            if let h = try? FileHandle(forWritingTo: file) {
                h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close()
            } else {
                try? line.data(using: .utf8)!.write(to: file)
            }
        }
        #if DEBUG
        FileHandle.standardError.write(line.data(using: .utf8)!)
        #endif
    }
}

enum JSON {
    static func string(_ obj: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: [.fragmentsAllowed]) else { return "null" }
        return String(data: data, encoding: .utf8) ?? "null"
    }
    static func parse(_ s: String) -> Any? {
        guard let d = s.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: d, options: [.fragmentsAllowed])
    }
    static func read(_ url: URL) -> Any? {
        guard let d = try? Data(contentsOf: url) else { return nil }
        return try? JSONSerialization.jsonObject(with: d)
    }
}
