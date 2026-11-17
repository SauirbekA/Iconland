// Draws the DMG window background with install instructions (Russian). Usage: swift make-dmg-background.swift <out.png>
import AppKit

let W: CGFloat = 640, H: CGFloat = 440, scale: CGFloat = 2
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W * scale), pixelsHigh: Int(H * scale), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: W, height: H)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

NSGradient(colors: [NSColor(calibratedRed: 0.86, green: 0.96, blue: 0.97, alpha: 1),
                    NSColor(calibratedRed: 1.0, green: 0.98, blue: 0.93, alpha: 1)])!.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: 90)

func text(_ s: String, y: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .init(white: 0.2, alpha: 1)) {
    let p = NSMutableParagraphStyle(); p.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: p]
    NSAttributedString(string: s, attributes: attrs).draw(in: NSRect(x: 20, y: y, width: W - 40, height: size * 3))
}

// Coordinates are bottom-up (Finder positions are top-down: y_here = 440 - y_finder).
text("Шаг 1. Дважды нажмите «Установить»", y: H - 60, size: 20, weight: .semibold)

// Arrow between the app and Applications (alternative: drag & drop)
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 250, y: 190)); arrow.line(to: NSPoint(x: 385, y: 190))
arrow.move(to: NSPoint(x: 370, y: 202)); arrow.line(to: NSPoint(x: 388, y: 190)); arrow.line(to: NSPoint(x: 370, y: 178))
arrow.lineWidth = 3; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
NSColor(calibratedRed: 0.05, green: 0.55, blue: 0.70, alpha: 0.7).setStroke(); arrow.stroke()
text("или перетащите Iconland в «Программы»", y: 70, size: 13, color: .init(white: 0.35, alpha: 1))

text("Если macOS пишет «не удалось проверить»: нажмите «Готово», затем откройте", y: 38, size: 12, color: .init(white: 0.35, alpha: 1))
text("Системные настройки → Конфиденциальность и безопасность → «Всё равно открыть»", y: 20, size: 12, weight: .medium, color: .init(white: 0.25, alpha: 1))

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
