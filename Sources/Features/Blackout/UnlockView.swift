import AppKit

final class UnlockView: NSView {
    let passwordField = NSSecureTextField()
    let messageLabel = NSTextField(wrappingLabelWithString: "")

    init(target: AnyObject, unlockAction: Selector, cancelAction: Selector) {
        super.init(frame: .zero)
        appearance = NSAppearance(named: .darkAqua)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        let body = NSView()
        let surface: NSView
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = 28
            glass.contentView = body
            surface = glass
        } else {
            let card = NSView()
            card.wantsLayer = true
            card.layer?.backgroundColor = NSColor(white: 0.12, alpha: 1).cgColor
            card.layer?.cornerRadius = 28
            card.layer?.borderWidth = 1
            card.layer?.borderColor = NSColor(white: 1, alpha: 0.15).cgColor
            card.addSubview(body)
            surface = card
        }
        addSubview(surface)

        let moon = NSImageView(image: NSImage(systemSymbolName: "moon.fill", accessibilityDescription: "Blackout")!)
        moon.contentTintColor = .labelColor
        moon.imageScaling = .scaleProportionallyUpOrDown
        moon.setAccessibilityElement(false)
        let title = NSTextField(wrappingLabelWithString: L("Unlock Blackout"))
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        title.alignment = .center
        passwordField.placeholderString = L("Password")
        passwordField.setAccessibilityLabel(L("Unlock password"))
        passwordField.font = .systemFont(ofSize: 16)
        passwordField.controlSize = .large
        passwordField.isBezeled = true
        passwordField.bezelStyle = .roundedBezel
        passwordField.target = target
        passwordField.action = unlockAction
        messageLabel.stringValue = L("Enter your password to restore the screen.")
        messageLabel.font = .systemFont(ofSize: 13)
        messageLabel.textColor = NSColor(white: 0.8, alpha: 1)
        messageLabel.alignment = .center
        let cancel = NSButton(title: L("Cancel"), target: target, action: cancelAction)
        let unlock = NSButton(title: L("Unlock"), target: target, action: unlockAction)
        cancel.keyEquivalent = "\u{1b}"
        unlock.keyEquivalent = "\r"
        for button in [cancel, unlock] {
            button.bezelStyle = .rounded
            button.controlSize = .large
            button.font = .systemFont(ofSize: 14)
            button.cell?.wraps = true
            button.cell?.isScrollable = false
            button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        let buttons = NSStackView(views: [cancel, unlock])
        buttons.spacing = 12
        buttons.distribution = .fillEqually
        let stack = NSStackView(views: [moon, title, messageLabel, passwordField, buttons])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 16
        body.addSubview(stack)
        let direction: NSUserInterfaceLayoutDirection = ["ar", "he"].contains(AppLanguage.currentCode)
            ? .rightToLeft : .leftToRight
        for view in [self, surface, body, stack, title, messageLabel, passwordField, buttons, cancel, unlock] {
            view.userInterfaceLayoutDirection = direction
        }
        passwordField.alignment = direction == .rightToLeft ? .right : .left
        for view in [surface, body, stack] { view.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 380),
            surface.leadingAnchor.constraint(equalTo: leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: trailingAnchor),
            surface.topAnchor.constraint(equalTo: topAnchor),
            surface.bottomAnchor.constraint(equalTo: bottomAnchor),
            body.leadingAnchor.constraint(equalTo: surface.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: surface.trailingAnchor),
            body.topAnchor.constraint(equalTo: surface.topAnchor),
            body.bottomAnchor.constraint(equalTo: surface.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: body.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: body.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: body.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: body.bottomAnchor, constant: -28),
            moon.widthAnchor.constraint(equalToConstant: 32),
            moon.heightAnchor.constraint(equalToConstant: 32),
            cancel.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),
            unlock.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
        ])
        for view in [title, messageLabel, passwordField, buttons] {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
