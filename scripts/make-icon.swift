// Draws assets/AppIcon.icns: a sunny island with a white "desktop icon" tile resting on the shore.
import AppKit
func draw(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let inset = s * 0.1, r = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let clip = NSBezierPath(roundedRect: r, xRadius: r.width * 0.225, yRadius: r.width * 0.225)
    clip.addClip()
    NSGradient(colors: [NSColor(calibratedRed: 0.05, green: 0.55, blue: 0.70, alpha: 1),
                        NSColor(calibratedRed: 0.35, green: 0.85, blue: 0.85, alpha: 1)])!.draw(in: r, angle: 90)
    func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: NSColor) {
        c.setFill(); NSBezierPath(ovalIn: NSRect(x: r.minX + r.width * (cx - w / 2), y: r.minY + r.height * (cy - h / 2),
                                                 width: r.width * w, height: r.height * h)).fill()
    }
    ellipse(0.5, 0.42, 0.86, 0.62, NSColor(calibratedRed: 0.98, green: 0.90, blue: 0.68, alpha: 1))   // sand
    ellipse(0.5, 0.43, 0.70, 0.48, NSColor(calibratedRed: 0.42, green: 0.70, blue: 0.30, alpha: 1))   // grass
    ellipse(0.80, 0.82, 0.16, 0.16, NSColor(calibratedRed: 1.0, green: 0.86, blue: 0.35, alpha: 1))   // sun
    let tile = NSRect(x: r.minX + r.width * 0.36, y: r.minY + r.height * 0.32, width: r.width * 0.28, height: r.width * 0.28)
    NSColor(calibratedWhite: 0, alpha: 0.18).setFill()
    NSBezierPath(roundedRect: tile.offsetBy(dx: 0, dy: -r.width * 0.025), xRadius: tile.width * 0.22, yRadius: tile.width * 0.22).fill()
    NSColor.white.setFill()
    NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.22, yRadius: tile.width * 0.22).fill()
    NSColor(calibratedRed: 0.05, green: 0.55, blue: 0.70, alpha: 1).setFill()
    NSBezierPath(roundedRect: tile.insetBy(dx: tile.width * 0.24, dy: tile.width * 0.24), xRadius: tile.width * 0.08, yRadius: tile.width * 0.08).fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}
let set = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! draw(base).write(to: set.appendingPathComponent("icon_\(base)x\(base).png"))
    try! draw(base * 2).write(to: set.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
