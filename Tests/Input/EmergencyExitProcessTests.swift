import Foundation
import Darwin

// Isolated child processes test the real watchdog without capturing input or opening windows.
@main
struct EmergencyExitProcessTests {
    static func main() throws {
        if CommandLine.arguments.count == 1 {
            let children = try ["responsive", "stalled", "cancelled", "restarted"].map { scenario in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
                process.arguments = [scenario]
                try process.run()
                return (scenario, process)
            }
            for (scenario, process) in children {
                process.waitUntilExit()
                if scenario == "stalled" {
                    assert(process.terminationReason == .uncaughtSignal && process.terminationStatus == SIGTERM)
                } else {
                    assert(process.terminationReason == .exit && process.terminationStatus == 0, scenario)
                }
            }
            print("Emergency exit checks passed: responsive, stalled, cancelled and restarted sessions")
            return
        }

        let blocker = InputBlocker()
        switch CommandLine.arguments[1] {
        case "stalled":
            blocker.startEmergencyExitWatchdog(isEscapePressed: { true })
            Thread.sleep(forTimeInterval: 6)
            exit(2) // The background watchdog must terminate this unresponsive process first.
        case "cancelled":
            blocker.startEmergencyExitWatchdog(isEscapePressed: { true })
            blocker.stop()
            Thread.sleep(forTimeInterval: 5)
            exit(0)
        case "restarted":
            blocker.onEmergencyExit = {
                blocker.stop()
                blocker.startEmergencyExitWatchdog(isEscapePressed: { false })
                DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                    blocker.stop()
                    exit(0) // The previous session's fallback must not kill the new one.
                }
            }
        default:
            blocker.onEmergencyExit = { blocker.stop(); exit(0) }
        }
        blocker.startEmergencyExitWatchdog(isEscapePressed: { true })
        DispatchQueue.global().asyncAfter(deadline: .now() + 6) { exit(2) }
        dispatchMain()
    }
}
