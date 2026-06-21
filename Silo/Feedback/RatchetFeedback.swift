import AppKit

/// A "ratchet" tick: a trackpad haptic + a short click, meant to fire once per
/// discrete step while dragging (like notches on a dial).
///
/// macOS specifics worth remembering:
/// - Haptics come from `NSHapticFeedbackManager`, **not** anything like iOS's
///   `UIImpactFeedbackGenerator`. They only physically fire on a Force Touch
///   trackpad; on other input devices the call is a harmless no-op.
/// - `performanceTime: .drawCompleted` asks the system to align the haptic with
///   the next screen update, so the tick lands together with the visual change.
/// - Reusing one `NSSound` and restarting it is cheaper than allocating a new
///   sound per tick; `stop()` before `play()` lets rapid ticks retrigger.
struct RatchetFeedback {

    func tick() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .levelChange,
            performanceTime: .drawCompleted
        )
    }
}
