import Foundation
import CoreGraphics
import ApplicationServices
import Darwin
import AppKit

struct EmergencyExitHold {
    private var beganAt: TimeInterval?
    private var fired = false

    mutating func update(pressed: Bool, uptime: TimeInterval) -> Bool {
        guard pressed else { beganAt = nil; fired = false; return false }
        guard let beganAt else { self.beganAt = uptime; return false }
        guard !fired, uptime - beganAt >= 3 else { return false }
        fired = true
        return true
    }
}

final class InputBlocker {
    enum Route { case pass, discard, wake, deliverToBlackout, switchInputSource }

    struct MouseTarget {
        let windowNumber: Int
        let frame: CGRect
        let desktopTop: CGFloat

        func event(from event: CGEvent) -> NSEvent? {
            switch event.type {
            case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
                 .otherMouseDown, .otherMouseUp, .mouseMoved,
                 .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
                break
            default: return nil
            }
            // Quartz uses the main display's upper-left origin; AppKit uses its
            // lower-left origin. Keep out-of-window drags/releases for native tracking.
            let point = NSPoint(x: event.location.x - frame.minX,
                                y: desktopTop - event.location.y - frame.minY)
            return NSEvent.mouseEvent(
                with: NSEvent.EventType(rawValue: UInt(event.type.rawValue))!, location: point,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue)),
                timestamp: TimeInterval(event.timestamp) / 1_000_000_000,
                windowNumber: windowNumber, context: nil,
                eventNumber: Int(event.getIntegerValueField(.mouseEventNumber)),
                clickCount: Int(event.getIntegerValueField(.mouseEventClickState)),
                pressure: Float(event.getDoubleValueField(.mouseEventPressure))
            )
        }
    }

    private let lock = NSLock()
    private var active = false
    private var prompting = false
    private var acceptingInput = false
    private var mouseTarget: MouseTarget?
    private var wakePending = false
    private var tap: CFMachPort?
    private var runLoop: CFRunLoop?
    private var emergencyTimer: DispatchSourceTimer?
    private var generation: UInt64 = 0
    private final class TapContext {
        weak var owner: InputBlocker?
        let generation: UInt64
        init(owner: InputBlocker, generation: UInt64) {
            self.owner = owner
            self.generation = generation
        }
    }
    var onWake: (() -> Void)?
    var onFailure: (() -> Void)?
    var onInputSourceChange: (() -> Void)?
    var onEmergencyExit: (() -> Void)?

    var isRunning: Bool {
        guard let currentTap = lock.withLock({ active ? tap : nil }) else { return false }
        return CGEvent.tapIsEnabled(tap: currentTap)
    }

    func start() -> Bool {
        stop()
        guard AXIsProcessTrusted() else { return false }
        let context = TapContext(owner: self, generation: lock.withLock { generation })
        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: CGEventMask.max,
            callback: { _, type, event, pointer in
                guard let pointer else { return nil }
                let context = Unmanaged<TapContext>.fromOpaque(pointer).takeUnretainedValue()
                return context.owner?.filter(type: type, event: event, generation: context.generation)
            }, userInfo: Unmanaged.passUnretained(context).toOpaque()
        ), let source = CFMachPortCreateRunLoopSource(nil, newTap, 0) else { return false }

        lock.withLock { tap = newTap; active = true; prompting = false }
        let ready = DispatchSemaphore(value: 0)
        let thread = Thread { [self, context] in
            let loop = CFRunLoopGetCurrent()!
            let current = lock.withLock { () -> Bool in
                guard generation == context.generation, active else { return false }
                runLoop = loop
                return true
            }
            guard current else { ready.signal(); return }
            CFRunLoopAddSource(loop, source, .commonModes)
            ready.signal()
            withExtendedLifetime(context) { CFRunLoopRun() }
            CFRunLoopRemoveSource(loop, source, .commonModes)
            let failed = lock.withLock { () -> Bool in
                guard generation == context.generation, active else { return false }
                active = false
                runLoop = nil
                return true
            }
            if failed { deliver(for: context.generation) { $0.onFailure?() } }
        }
        thread.name = "Blackout input blocker"
        thread.qualityOfService = .userInteractive
        thread.start()
        guard ready.wait(timeout: .now() + 1) == .success, isRunning else {
            stop()
            return false
        }
        startEmergencyExitWatchdog()
        return true
    }

    func startEmergencyExitWatchdog(isEscapePressed: @escaping () -> Bool = {
        CGEventSource.keyState(.hidSystemState, key: 53)
    }) {
        // Read physical key state independently of AppKit and event-tap delivery.
        // A secure text field or an unresponsive main thread must not disable the exit gesture.
        let queue = DispatchQueue(label: "Blackout emergency exit", qos: .userInteractive)
        let generation = lock.withLock { self.generation }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        var hold = EmergencyExitHold()
        timer.schedule(deadline: .now(), repeating: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            guard let self, self.lock.withLock({ self.generation == generation }) else { return }
            guard hold.update(pressed: isEscapePressed(),
                              uptime: ProcessInfo.processInfo.systemUptime) else { return }
            self.deliver(for: generation) { $0.onEmergencyExit?() }
            // Usually the main queue ends blackout and invalidates this generation.
            // If it is stuck, process termination releases its windows and event tap.
            queue.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let self else { return }
                self.lock.withLock {
                    guard self.generation == generation else { return }
                    kill(getpid(), SIGTERM)
                }
            }
        }
        lock.withLock { emergencyTimer = timer }
        timer.resume()
    }

    func setPrompting(_ value: Bool, acceptingInput: Bool = true, mouseTarget: MouseTarget? = nil) {
        lock.withLock {
            prompting = value
            self.acceptingInput = acceptingInput
            self.mouseTarget = mouseTarget
        }
    }

    func stop() {
        let resources = lock.withLock { () -> (CFMachPort?, CFRunLoop?, DispatchSourceTimer?) in
            active = false
            generation &+= 1
            prompting = false
            acceptingInput = false
            mouseTarget = nil
            wakePending = false
            let resources = (tap, runLoop, emergencyTimer)
            tap = nil
            runLoop = nil
            emergencyTimer = nil
            return resources
        }
        resources.2?.cancel()
        if let tap = resources.0 { CFMachPortInvalidate(tap) }
        if let loop = resources.1 {
            CFRunLoopPerformBlock(loop, CFRunLoopMode.commonModes.rawValue) { CFRunLoopStop(loop) }
            CFRunLoopWakeUp(loop)
        }
    }

    private func deliver(for generation: UInt64, action: @escaping (InputBlocker) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.lock.withLock({ self.generation == generation }) else { return }
            action(self)
        }
    }

    private func filter(type: CGEventType, event: CGEvent, generation: UInt64) -> Unmanaged<CGEvent>? {
        guard lock.withLock({ self.generation == generation }) else { return nil }
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // Never leave a covered desktop with a disabled input filter.
            deliver(for: generation) { $0.onFailure?() }
            return nil
        }
        let route = lock.withLock { () -> Route in
            guard self.generation == generation, active else { return .discard }
            let route = Self.route(type: type, event: event, active: active,
                                   prompting: prompting, acceptingInput: acceptingInput)
            if route == .wake {
                guard !wakePending else { return .discard }
                wakePending = true
            }
            return route
        }
        switch route {
        case .pass: return Unmanaged.passUnretained(event)
        case .discard: return nil
        case .deliverToBlackout:
            if type == .keyDown || type == .keyUp || type == .flagsChanged {
                // Direct keyboard delivery bypasses global shortcuts.
                event.postToPid(getpid())
            } else {
                lock.withLock {
                    guard self.generation == generation, active, prompting, acceptingInput,
                          let mouseTarget else { return }
                    // Session-tap mouse events have no AppKit window mapping. Post an
                    // explicitly targeted event; never return the original to another app.
                    // postEvent is thread-safe and reaches native control tracking loops.
                    autoreleasepool {
                        if let mouseEvent = mouseTarget.event(from: event) {
                            NSApp.postEvent(mouseEvent, atStart: false)
                        }
                    }
                }
            }
            return nil
        case .switchInputSource:
            deliver(for: generation) { $0.onInputSourceChange?() }
            return nil
        case .wake:
            deliver(for: generation) { blocker in
                blocker.lock.withLock { blocker.wakePending = false }
                blocker.onWake?()
            }
            return nil
        }
    }

    static func route(type: CGEventType, event: CGEvent, active: Bool, prompting: Bool, acceptingInput: Bool = true) -> Route {
        guard active else { return .pass }
        let keyboard = type == .keyDown || type == .keyUp || type == .flagsChanged
        let mouse: Set<CGEventType> = [
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp, .mouseMoved,
            .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .scrollWheel
        ]
        guard keyboard || mouse.contains(type) else { return .discard }
        guard prompting, acceptingInput else {
            return type == .keyDown || mouse.contains(type) ? .wake : .discard
        }
        if keyboard {
            let flags = event.flags
            if type == .keyDown, flags.contains(.maskControl),
               !flags.contains(.maskCommand), !flags.contains(.maskAlternate),
               event.getIntegerValueField(.keyboardEventKeycode) == 49 {
                return .switchInputSource
            }
            if flags.contains(.maskControl) { return .discard }
            if flags.contains(.maskCommand) {
                let code = event.getIntegerValueField(.keyboardEventKeycode)
                guard [0, 7, 8, 9].contains(code), !flags.contains(.maskAlternate) else { return .discard }
            }
        }
        return .deliverToBlackout
    }
}
