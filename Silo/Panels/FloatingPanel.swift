import AppKit

/// A borderless, non-activating panel that hosts SwiftUI glass content and
/// floats *below* the menu bar.
///
/// Why a custom `NSPanel` (and not `MenuBarExtra` or a popover)?
/// - `MenuBarExtra`'s window is glued directly under its icon — it can't float
///   "at a distance" or morph freely.
/// - A *non-activating* panel can show without stealing key-window focus from
///   whatever app you're in, so the menu bar stays "live" and the experience
///   feels like a lightweight overlay rather than a full app switch.
final class FloatingPanel: NSPanel {

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            // `.nonactivatingPanel` = showing us won't deactivate the user's app.
            // `.borderless` = no title bar / chrome; the glass provides the shape.
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating                 // sits above normal windows
        backgroundColor = .clear          // let the SwiftUI glass show through
        isOpaque = false
        hasShadow = false                 // glass renders its own depth
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationBehavior = .utilityWindow
    }

    // Borderless panels return `false` here by default, which would block them
    // from ever becoming key. We override so the embedded text field (added in
    // a later increment) can receive keyboard input when needed.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
