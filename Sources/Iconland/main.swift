import AppKit

// Developer tool: render a theme offscreen to a PNG (see Snapshot.swift).
if let snap = SnapshotRunner(args: CommandLine.arguments) {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    snap.run()
    app.run()
    exit(0)
}

// One instance per user: a second launch asks the running one to show its settings and exits.
if let id = Bundle.main.bundleIdentifier {
    let me = ProcessInfo.processInfo.processIdentifier
    if NSRunningApplication.runningApplications(withBundleIdentifier: id).contains(where: { $0.processIdentifier != me }) {
        DistributedNotificationCenter.default().postNotificationName(
            .init("local.iconland.showSettings"), object: nil, userInfo: nil, deliverImmediately: true)
        exit(0)
    }
}

let app = NSApplication.shared
let controller = AppController()
app.delegate = controller
app.setActivationPolicy(.accessory)
app.run()
