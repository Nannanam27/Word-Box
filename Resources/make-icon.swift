// Draws the Word Box app icon (1024x1024 PNG): a flat ink tile with two index cards.
// Usage: swift make-icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(deviceRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

// macOS icon grid: ~824pt tile centered in 1024 canvas
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
NSGraphicsContext.current?.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = rgb(0, 0, 0, 0.25)
shadow.shadowBlurRadius = 20
shadow.shadowOffset = NSSize(width: 0, height: -8)
shadow.set()
rgb(30, 28, 25).setFill()
NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185).fill()
NSGraphicsContext.current?.restoreGraphicsState()

// back card, tilted outline
NSGraphicsContext.current?.saveGraphicsState()
let t = NSAffineTransform()
t.translateX(by: 560, yBy: 600)
t.rotate(byDegrees: 9)
t.concat()
let back = NSBezierPath(roundedRect: NSRect(x: -230, y: -140, width: 460, height: 290), xRadius: 18, yRadius: 18)
back.lineWidth = 16
rgb(243, 240, 232, 0.45).setStroke()
back.stroke()
NSGraphicsContext.current?.restoreGraphicsState()

// front card
let front = NSRect(x: 230, y: 260, width: 540, height: 340)
rgb(255, 254, 250).setFill()
NSBezierPath(roundedRect: front, xRadius: 18, yRadius: 18).fill()

// red header rule + ruled lines
rgb(217, 80, 59).setFill()
NSBezierPath(rect: NSRect(x: 230, y: 520, width: 540, height: 8)).fill()
for (i, w) in [CGFloat(380), 260].enumerated() {
    rgb(42, 71, 160, 0.35).setFill()
    NSBezierPath(rect: NSRect(x: 290, y: 430 - CGFloat(i) * 80, width: w, height: 8)).fill()
}

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
