import AppKit

func makeStatusIcon(passwordProtected: Bool, description: String) -> NSImage {
    let image = NSImage(size: NSSize(width: 22, height: 18), flipped: false) { _ in
        NSImage(systemSymbolName: "moon.fill", accessibilityDescription: nil)?
            .draw(in: NSRect(x: 1, y: 1, width: 16, height: 16))
        if passwordProtected {
            // Clear a small backing so the lock remains distinct in light and dark menu bars.
            NSRect(x: 12, y: 0, width: 10, height: 11).fill(using: .clear)
            NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)?
                .draw(in: NSRect(x: 13, y: 0, width: 8, height: 10))
        }
        return true
    }
    image.isTemplate = true
    image.accessibilityDescription = description
    return image
}
