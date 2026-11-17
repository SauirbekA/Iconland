import AppKit

/// A borderless, click-through window at the desktop window level: above the system wallpaper,
/// below Finder's desktop icons. Shown on every Space of the main display.
final class WallpaperWindow {
    let window: NSWindow
    let web: HostWeb

    init() {
        web = HostWeb(label: "wallpaper")
        web.keepRenderingWhenOccluded()
        let frame = WallpaperWindow.mainScreen.frame
        window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        window.ignoresMouseEvents = true
        window.isOpaque = true
        window.hasShadow = false
        window.backgroundColor = .black
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.contentView = web.view
        fit()
        window.orderFront(nil)
    }

    /// The screen with the menu bar; Finder's desktop coordinates are relative to its top-left corner.
    static var mainScreen: NSScreen { NSScreen.screens.first ?? NSScreen.main! }

    func fit() {
        window.setFrame(WallpaperWindow.mainScreen.frame, display: true)
    }

    func close() {
        window.orderOut(nil)
        window.contentView = nil
    }
}

/// Decides when to pause the animation: a window fills the main screen (full-screen app or a maximized window),
/// the display sleeps, the screen is locked, or the user switched to another login session.
final class PauseMonitor {
    var onChange: ((Bool) -> Void)?
    var manual = false { didSet { evaluate() } }
    var steering = false { didSet { evaluate() } }   // the user is sailing a ship on the desktop
    private(set) var paused = false

    private var asleep = false
    private var locked = false
    private var inactiveSession = false
    private var timer: Timer?

    init() {
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.asleep = true; self?.evaluate() }
        ws.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.asleep = false; self?.evaluate() }
        ws.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.inactiveSession = true; self?.evaluate() }
        ws.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.inactiveSession = false; self?.evaluate() }
        ws.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in self?.evaluate() }
        ws.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self?.evaluate() }
        }
        let dn = DistributedNotificationCenter.default()
        dn.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in self?.locked = true; self?.evaluate() }
        dn.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in self?.locked = false; self?.evaluate() }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.evaluate() }
        timer?.tolerance = 0.3
    }

    func evaluate() {
        var reason = ""
        if manual { reason = "manual" }
        else if asleep { reason = "display asleep" }
        else if locked { reason = "screen locked" }
        else if inactiveSession { reason = "session inactive" }
        // Finder in front means the user is on the desktop (dragging icons, "Show Desktop", click-to-reveal):
        // windows may still report full-screen bounds while they're slid away, so don't trust them then.
        else if !Self.finderIsFrontmost && !steering, let owner = Self.windowCoveringMainScreen() { reason = "covered by \(owner)" }
        let p = !reason.isEmpty
        if p != paused {
            paused = p
            Log.write(p ? "pause: \(reason)" : "resume")
            onChange?(p)
        }
    }

    static var finderIsFrontmost: Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder"
    }

    /// Owner of another app's normal-level window that covers (almost) the whole usable area of the main screen.
    static func windowCoveringMainScreen() -> String? {
        let screen = WallpaperWindow.mainScreen
        let full = CGRect(origin: .zero, size: screen.frame.size)        // CG coordinates: main screen at (0,0), y down
        let usable = screen.visibleFrame
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return nil }
        let me = ProcessInfo.processInfo.processIdentifier
        for w in list {
            guard (w[kCGWindowLayer as String] as? Int) == 0,
                  (w[kCGWindowOwnerPID as String] as? Int32) != me,
                  (w[kCGWindowAlpha as String] as? Double ?? 1) > 0.5,
                  let b = w[kCGWindowBounds as String] as? NSDictionary,
                  let r = CGRect(dictionaryRepresentation: b) else { continue }
            let i = r.intersection(full)
            if i.width >= usable.width - 4 && i.height >= usable.height - 4 {
                return (w[kCGWindowOwnerName as String] as? String) ?? "?"
            }
        }
        return nil
    }
}
