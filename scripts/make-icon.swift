import AppKit

// Render the same simple crescent mark as the website, using native drawing only.
let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let size = points * scale
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let transform = NSAffineTransform()
        transform.scale(by: CGFloat(size) / 64)
        transform.concat()
        let background = NSColor(srgbRed: 23/255, green: 25/255, blue: 23/255, alpha: 1)
        background.setFill()
        NSBezierPath(roundedRect: NSRect(x: 4, y: 4, width: 56, height: 56), xRadius: 13, yRadius: 13).fill()
        NSColor(srgbRed: 243/255, green: 240/255, blue: 231/255, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 16, y: 16, width: 32, height: 32)).fill()
        background.setFill()
        NSBezierPath(ovalIn: NSRect(x: 21, y: 21, width: 30, height: 30)).fill()
        NSColor(srgbRed: 185/255, green: 218/255, blue: 131/255, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 43, y: 43, width: 7, height: 7)).fill()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!
            .write(to: folder.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}
