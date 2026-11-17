import AppKit

/// "Take the helm": a click on the desktop is forwarded to the theme page ({t:'pick', x, y} in points from the
/// top-left of the main screen). If the page answers "steer|on" (a ship was hit), a transparent overlay just above
/// the desktop icons takes the keyboard and mouse: W/A/S/D or arrows steer, a click sets a destination,
/// Esc / right click / switching to another app hands the ship back.
final class Steering {
    var post: ((String) -> Void)?
    var onActiveChange: ((Bool) -> Void)?
    var lang = "en"
    private(set) var active = false
    private var monitor: Any?
    private var overlay: SteerWindow?
    private var resignObs: Any?

    func start() {
        guard monitor == nil else { return }
        // Global mouse monitors need no special permission (only key monitors do).
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] e in
            guard let self, !self.active, e.clickCount == 1 else { return }
            let p = NSEvent.mouseLocation
            let f = WallpaperWindow.mainScreen.frame
            guard f.contains(p) else { return }
            // Let the click land first: a click on the desktop brings Finder to the front.
            // Outside the usable area = on the Dock or the menu bar.
            guard WallpaperWindow.mainScreen.visibleFrame.contains(p) else { return }
            // Let the click land first: a click on the desktop brings Finder to the front (give it up to ~0.4 s).
            func check(_ tries: Int) {
                let finder = PauseMonitor.finderIsFrontmost
                if !finder && tries > 0 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { check(tries - 1) }; return }
                guard Self.desktopIsUnder(p, finderInFront: finder) else {
                    Log.write("click at \(Int(p.x - f.minX)),\(Int(f.maxY - p.y)): a window is there (finder front: \(finder))")
                    return
                }
                self.post?(JSON.string(["t": "pick", "x": p.x - f.minX, "y": f.maxY - p.y] as [String: Any]))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { check(3) }
        }
    }

    /// The page hit a ship: take keyboard and mouse.
    func begin() {
        guard !active else { return }
        active = true
        let w = SteerWindow(frame: WallpaperWindow.mainScreen.frame, lang: lang)
        w.view.onKey = { [weak self] k, down in self?.post?(JSON.string(["t": "key", "k": k, "v": down] as [String: Any])) }
        w.view.onClick = { [weak self] pt in self?.post?(JSON.string(["t": "goto", "x": pt.x, "y": pt.y] as [String: Any])) }
        w.view.onExit = { [weak self] in self?.end(tellPage: true) }
        overlay = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
        w.makeFirstResponder(w.view)
        resignObs = NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification,
                                                           object: nil, queue: .main) { [weak self] _ in self?.end(tellPage: true) }
        Log.write("steering: on")
        onActiveChange?(true)
    }

    /// Hand the ship back (Esc, another app, theme change) or the page let go of it ("steer|off").
    func end(tellPage: Bool) {
        guard active else { return }
        active = false
        if let o = resignObs { NotificationCenter.default.removeObserver(o); resignObs = nil }
        overlay?.orderOut(nil)
        overlay = nil
        if tellPage { post?(JSON.string(["t": "steer", "on": false] as [String: Any])) }
        Log.write("steering: off")
        onActiveChange?(false)
    }

    /// True when no app window, the Dock or the menu bar is under the point (Cocoa coordinates).
    /// With Finder in front the user is on the desktop: other apps' windows may be slid away (click-to-reveal,
    /// Show Desktop) while still reporting their old bounds, so only Finder's own windows count then.
    static func desktopIsUnder(_ p: NSPoint, finderInFront: Bool) -> Bool {
        let cg = CGPoint(x: p.x, y: (NSScreen.screens.first?.frame.maxY ?? 0) - p.y)
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return false }
        let me = ProcessInfo.processInfo.processIdentifier
        for w in list {
            let layer = w[kCGWindowLayer as String] as? Int ?? 0
            // Only normal app windows: the Dock owns an invisible full-screen window (layer 20), and the Dock
            // and menu bar strips are already excluded by the caller via visibleFrame.
            guard layer == 0,
                  (w[kCGWindowOwnerPID as String] as? Int32) != me,
                  (w[kCGWindowAlpha as String] as? Double ?? 1) > 0.05,
                  let b = w[kCGWindowBounds as String] as? NSDictionary,
                  let r = CGRect(dictionaryRepresentation: b) else { continue }
            if finderInFront && layer == 0 && (w[kCGWindowOwnerName as String] as? String) != "Finder" { continue }
            if r.contains(cg) { return false }
        }
        return true
    }
}

/// Transparent full-screen window just above the desktop icons (below every app window) that takes input.
final class SteerWindow: NSWindow {
    let view: SteerView

    init(frame: NSRect, lang: String) {
        view = SteerView(frame: NSRect(origin: .zero, size: frame.size), lang: lang)
        super.init(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false                      // set explicitly: catch clicks on the transparent area too
        isReleasedWhenClosed = false
        animationBehavior = .none
        contentView = view
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class SteerView: NSView {
    var onKey: ((String, Bool) -> Void)?
    var onClick: ((NSPoint) -> Void)?
    var onExit: (() -> Void)?

    init(frame: NSRect, lang: String) {
        super.init(frame: frame)
        let ru = lang == "ru"
        let text = ru ? "⚓︎  WASD или стрелки — плыть   ·   клик — плыть туда   ·   Esc — отпустить корабль"
                      : "⚓︎  WASD or arrows — sail   ·   click — sail there   ·   Esc — let the ship go"
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = NSColor(calibratedRed: 0.96, green: 0.92, blue: 0.82, alpha: 1)
        label.translatesAutoresizingMaskIntoConstraints = false
        let pill = NSView()
        pill.wantsLayer = true
        pill.layer?.backgroundColor = NSColor(calibratedRed: 0.23, green: 0.15, blue: 0.09, alpha: 0.82).cgColor
        pill.layer?.cornerRadius = 14
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)
        addSubview(pill)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: 7),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -7),
            pill.centerXAnchor.constraint(equalTo: centerXAnchor),
            pill.topAnchor.constraint(equalTo: topAnchor, constant: 40),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }                 // y down, like the page
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    // Physical key positions, so it works with any keyboard layout (e.g. Russian).
    private static let keys: [UInt16: String] = [13: "w", 0: "a", 1: "s", 2: "d", 126: "w", 123: "a", 125: "s", 124: "d"]

    override func keyDown(with e: NSEvent) {
        if e.keyCode == 53 { onExit?(); return }          // Esc
        if let k = Self.keys[e.keyCode] { if !e.isARepeat { onKey?(k, true) } }
        else { super.keyDown(with: e) }
    }
    override func keyUp(with e: NSEvent) {
        if let k = Self.keys[e.keyCode] { onKey?(k, false) }
    }
    override func mouseDown(with e: NSEvent) { onClick?(convert(e.locationInWindow, from: nil)) }
    override func rightMouseDown(with e: NSEvent) { onExit?() }
}
