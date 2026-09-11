// Uygulama ikonunu (gece mavisi zemin + altın hilal + yıldız) çizip bir .iconset klasörüne yazar.
// Kullanım: swift Scripts/make_icon.swift <çıktı.iconset>
import AppKit

let outDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1)
}

func starPath(center: NSPoint, outer: CGFloat, inner: CGFloat) -> NSBezierPath {
    let p = NSBezierPath()
    for i in 0..<10 {
        let r = i.isMultiple(of: 2) ? outer : inner
        let a = CGFloat.pi / 2 + CGFloat(i) * .pi / 5
        let pt = NSPoint(x: center.x + r * cos(a), y: center.y + r * sin(a))
        i == 0 ? p.move(to: pt) : p.line(to: pt)
    }
    p.close()
    return p
}

/// 1024'lük tuval üzerinde çizer, istenen piksel boyutuna ölçekler.
func render(px: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current!.cgContext.scaleBy(x: CGFloat(px) / 1024, y: CGFloat(px) / 1024)

    // Zemin: macOS ikon ızgarasındaki 824'lük yuvarlatılmış kare
    let bg = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    NSGradient(colors: [color(44, 56, 120), color(12, 16, 44)])!.draw(in: bg, angle: -90)

    // Hilal: dolu daireden kaydırılmış bir daireyi kırparak
    NSGraphicsContext.saveGraphicsState()
    let cut = NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024))
    cut.append(NSBezierPath(ovalIn: NSRect(x: 390, y: 360, width: 400, height: 400)))
    cut.windingRule = .evenOdd
    cut.addClip()
    let moon = NSBezierPath(ovalIn: NSRect(x: 240, y: 282, width: 460, height: 460))
    NSGradient(colors: [color(255, 224, 150), color(232, 168, 70)])!.draw(in: moon, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // Yıldız
    color(255, 224, 150).setFill()
    starPath(center: NSPoint(x: 648, y: 548), outer: 64, inner: 27).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try render(px: size * scale).write(to: outDir.appendingPathComponent(name))
    }
}
