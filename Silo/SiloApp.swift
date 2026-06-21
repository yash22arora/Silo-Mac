import SwiftUI

/// The app entry point.
///
/// Silo is a *menu-bar app*, so most of the interesting lifecycle work happens
/// in `AppDelegate` (creating the status item, owning the floating panel). The
/// SwiftUI `App` here intentionally has **no auto-opening window**: we use a
/// `Settings` scene as a "null" scene so launching the app does not pop a
/// window. Real windows (like History, in a later increment) are created on
/// demand from the delegate.
@main
struct SiloApp: App {
    // Bridges a classic AppKit delegate into the SwiftUI lifecycle.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // `Settings` only ever appears via the (currently empty) Settings menu,
        // so nothing shows on launch — exactly what a menu-bar app wants.
        Settings {
            EmptyView()
        }
    }
}
