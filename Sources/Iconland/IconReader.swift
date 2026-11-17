import AppKit

/// Reads desktop icon positions from Finder via Apple Events.
///
/// Finder reports each item's `desktop position` as the center of its icon image, in points, with the origin at the
/// top-left of the main screen. We turn that into a rectangle that covers the icon and its label, like the
/// Windows host does with LVM_GETITEMRECT.
final class IconReader {
    struct Snapshot: Equatable {
        var visible: Bool
        var rects: [CGRect]      // points, top-left origin, relative to the main screen
    }

    enum Failure: Equatable {
        case notAuthorized       // user denied Automation access to Finder
        case other(String)
    }

    private let queue = DispatchQueue(label: "icon-reader", qos: .utility)
    private var script: NSAppleScript?
    private var busy = false

    private static let source = """
    tell application "Finder"
        set o to icon view options of window of desktop
        set ps to {}
        try
            set ps to desktop position of every item of desktop
        end try
        return {icon size of o, text size of o, (label position of o) as text, ps}
    end tell
    """

    /// Reads asynchronously; the completion runs on the main queue. Overlapping calls are skipped.
    func read(_ done: @escaping (Result<Snapshot, IconReaderError>) -> Void) {
        if busy { return }
        busy = true
        queue.async { [self] in
            let result = readNow()
            DispatchQueue.main.async {
                self.busy = false
                done(result)
            }
        }
    }

    private func readNow() -> Result<Snapshot, IconReaderError> {
        if !Self.desktopIconsShown() { return .success(Snapshot(visible: false, rects: [])) }
        if script == nil {
            script = NSAppleScript(source: Self.source)
            script?.compileAndReturnError(nil)
        }
        var err: NSDictionary?
        guard let out = script?.executeAndReturnError(&err) else {
            let code = err?[NSAppleScript.errorNumber] as? Int ?? 0
            let msg = err?[NSAppleScript.errorMessage] as? String ?? "unknown error"
            if code == -1743 || code == -10004 { return .failure(.init(failure: .notAuthorized)) }
            return .failure(.init(failure: .other("\(code): \(msg)")))
        }
        guard out.numberOfItems == 4 else { return .failure(.init(failure: .other("unexpected Finder reply"))) }
        let iconSize = CGFloat(out.atIndex(1)?.int32Value ?? 64)
        let textSize = CGFloat(out.atIndex(2)?.int32Value ?? 12)
        let labelRight = (out.atIndex(3)?.stringValue ?? "bottom").lowercased().contains("right")
        var rects: [CGRect] = []
        if let list = out.atIndex(4), list.numberOfItems > 0 {
            for i in 1...list.numberOfItems {
                guard let p = list.atIndex(i), p.numberOfItems == 2,
                      let x = p.atIndex(1)?.int32Value, let y = p.atIndex(2)?.int32Value else { continue }
                rects.append(Self.rect(center: CGPoint(x: CGFloat(x), y: CGFloat(y)),
                                       icon: iconSize, text: textSize, labelRight: labelRight))
            }
        }
        return .success(Snapshot(visible: true, rects: rects))
    }

    /// Icon image + label box, approximating Finder's layout.
    static func rect(center c: CGPoint, icon s: CGFloat, text t: CGFloat, labelRight: Bool) -> CGRect {
        let lineH = ceil(t * 1.25)
        if labelRight {
            let labelW = max(80, t * 10)
            return CGRect(x: c.x - s / 2 - 2, y: c.y - s / 2 - 2, width: s + 6 + labelW, height: s + 4)
        }
        let w = max(s + 24, t * 7)
        let top = c.y - s / 2 - 3
        let bottom = c.y + s / 2 + 5 + 2 * lineH
        return CGRect(x: c.x - w / 2, y: top, width: w, height: bottom - top)
    }

    /// "Show items on desktop" off (Finder CreateDesktop=false, or Sonoma+ "Show Desktop Items" off).
    static func desktopIconsShown() -> Bool {
        if let finder = UserDefaults(suiteName: "com.apple.finder"),
           finder.object(forKey: "CreateDesktop") != nil, !finder.bool(forKey: "CreateDesktop") { return false }
        if let wm = UserDefaults(suiteName: "com.apple.WindowManager"),
           wm.bool(forKey: "StandardHideDesktopIcons") { return false }
        return true
    }
}

struct IconReaderError: Error, Equatable {
    let failure: IconReader.Failure
}
