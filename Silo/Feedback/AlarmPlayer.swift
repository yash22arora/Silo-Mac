import AppKit

/// Plays the looping alert sound while a timer is ringing.
///
/// Kept separate from the engine's logic so the countdown/state machine stays
/// pure and testable — the engine just says "start"/"stop". Uses a single
/// looping `NSSound`; `loops = true` repeats it until the user acts.
final class AlarmPlayer {
    private var sound: NSSound?

    func start() {
        stop()
        // "Glass" is a built-in system alert sound. Looping turns the single
        // chime into a gentle, repeating alarm.
        let s = NSSound(named: "Glass")
        s?.loops = true
        s?.play()
        sound = s
    }

    func stop() {
        sound?.stop()
        sound = nil
    }
}
