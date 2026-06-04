//  WatchHapticTestHandler.swift
//  Watch_Dream_Catcher Watch App
//
//  Handles "testHaptic" messages from iPhone's CueTestingView.
//  Plays different haptic patterns based on the "pattern" key.
//
//  Add to your Watch-side WCSession message handler:
//
//    case "testHaptic":
//        if let pattern = message["pattern"] as? String {
//            WatchHapticTestHandler.play(pattern: pattern)
//        }

import WatchKit

enum WatchHapticTestHandler {

    static func play(pattern: String) {
        let device = WKInterfaceDevice.current()

        switch pattern {

        // --- Single taps ---

        case "single_light":
            device.play(.click)

        case "single_strong":
            device.play(.notification)

        // --- Triple ascending (the TLR cue) ---

        case "triple_ascending":
            device.play(.click)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.225) {
                device.play(.directionUp)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.450) {
                device.play(.notification)
            }

        // --- Triple uniform (for comparison) ---

        case "triple_uniform":
            device.play(.directionUp)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.225) {
                device.play(.directionUp)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.450) {
                device.play(.directionUp)
            }

        // --- Double strong ---

        case "double_strong":
            device.play(.notification)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.300) {
                device.play(.notification)
            }

        default:
            // Unknown pattern -- play the default TLR cue
            WatchHapticCueEngine().playCue()
        }
    }
}
