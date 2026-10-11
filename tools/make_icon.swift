import AppKit

// Renders the app icon at every size macOS needs into an .iconset directory.
// Usage: swiftc -o /tmp/make_icon tools/make_icon.swift && /tmp/make_icon build/AppIcon.iconset

func render(size: Int) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // macOS icon grid: the artwork covers 80% of the canvas, leaving room for the shadow.
    let inset = s * 0.1
    let body = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let radius = body.width * 0.225
    let path = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = s * 0.02
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)
    shadow.set()
    NSColor.black.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [NSColor(red: 0.25, green: 0.55, blue: 1.0, alpha: 1),
                        NSColor(red: 0.40, green: 0.25, blue: 0.90, alpha: 1)])!
        .draw(in: path, angle: -60)

    // Two overlapping speech bubbles: "A" (white) and "文" (translucent white).
    func bubble(_ rect: NSRect, tailLeft: Bool, fill: NSColor) {
        let p = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.22, yRadius: rect.width * 0.22)
        let tail = NSBezierPath()
        let tx = tailLeft ? rect.minX + rect.width * 0.18 : rect.maxX - rect.width * 0.18
        let dir: CGFloat = tailLeft ? 1 : -1
        tail.move(to: NSPoint(x: tx, y: rect.minY + 1))
        tail.line(to: NSPoint(x: tx - dir * rect.width * 0.08, y: rect.minY - rect.height * 0.16))
        tail.line(to: NSPoint(x: tx + dir * rect.width * 0.22, y: rect.minY + 1))
        tail.close()
        fill.setFill()
        p.fill()
        tail.fill()
    }
    func glyph(_ text: String, in rect: NSRect, color: NSColor, weight: NSFont.Weight) {
        let font = NSFont.systemFont(ofSize: rect.height * 0.62, weight: weight)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let str = NSAttributedString(string: text, attributes: attrs)
        let sz = str.size()
        str.draw(at: NSPoint(x: rect.midX - sz.width / 2, y: rect.midY - sz.height / 2))
    }

    let bw = s * 0.40, bh = s * 0.33
    let back = NSRect(x: s * 0.22, y: s * 0.48, width: bw, height: bh)
    let front = NSRect(x: s * 0.38, y: s * 0.24, width: bw, height: bh)

    bubble(back, tailLeft: true, fill: .white)
    glyph("A", in: back, color: NSColor(red: 0.30, green: 0.40, blue: 0.95, alpha: 1), weight: .bold)

    bubble(front, tailLeft: false, fill: NSColor(white: 1, alpha: 0.92))
    glyph("文", in: front, color: NSColor(red: 0.40, green: 0.25, blue: 0.90, alpha: 1), weight: .semibold)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try render(size: base).write(to: URL(fileURLWithPath: "\(outDir)/icon_\(base)x\(base).png"))
    try render(size: base * 2).write(to: URL(fileURLWithPath: "\(outDir)/icon_\(base)x\(base)@2x.png"))
}
