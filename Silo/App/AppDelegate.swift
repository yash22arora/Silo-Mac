import AppKit
import SwiftUI
import SwiftData

/// Owns the menu-bar status item and the floating panel, and wires clicks
/// together. This is the "AppKit spine" of the app; SwiftUI lives *inside* the
/// panel via `NSHostingView`.
extension Notification.Name {
    /// Posted when the floating panel is shown, so the SwiftUI content can
    /// reveal the create bubble and focus the label field.
    static let siloPanelDidOpen = Notification.Name("siloPanelDidOpen")
}

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var panel: FloatingPanel?
    private var bannerPanel: FloatingPanel?
    private var escMonitor: Any?

    // The shared persistence stack and timer engine. Created once at launch and
    // injected into the SwiftUI tree (which lives inside the AppKit panel, so we
    // wire the environment by hand rather than via a SwiftUI scene modifier).
    private let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: TimerTask.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
    private lazy var engine = TimerEngine(context: modelContainer.mainContext)

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        // When a timer rings, make sure the panel is visible so the user sees
        // the Snooze/Done controls. (Increment 6 upgrades this to a banner.)
        engine.onRing = { [weak self] _ in
            self?.showBanner()
        }
        installEscapeMonitor()
    }

    /// Dismiss any visible Silo surface on the Escape key. A *local* event
    /// monitor sees the keystroke before it's routed to a responder, so it works
    /// even while the label TextField is focused (whose field editor would
    /// otherwise swallow Escape). Returning `nil` consumes the event.
    private func installEscapeMonitor() {
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.keyCode == 53 else { return event } // 53 = Esc
            // Only the main panel. The completion banner is intentionally NOT
            // Esc-dismissable: hiding it would leave the looping alarm playing
            // with no way to stop it — it requires an explicit Snooze/Done.
            if self.panel?.isVisible == true {
                self.panel?.orderOut(nil)
                return nil
            }
            return event
        }
    }

    /// Hide the panel when the user clicks away (the app loses active status) —
    /// the "Spotlight" dismissal. We key off app deactivation rather than the
    /// panel resigning key, because clicking our own status item keeps the app
    /// active and would otherwise hide-then-reopen the panel.
    func applicationDidResignActive(_ notification: Notification) {
        panel?.orderOut(nil)
    }

    // MARK: - Status item

    private func setUpStatusItem() {
        // `.variableLength` lets the item size to its content (an icon here).
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let icon = NSImage(named: "MenuIcon")
        icon?.isTemplate = true
        icon?.size = NSSize(width: 18, height: 18)
        icon?.accessibilityDescription = "Silo"

        if let button = item.button {
            button.image = icon
            button.image?.isTemplate = true   // adapts to light/dark menu bar
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            // Receive BOTH mouse buttons so we can distinguish left vs right.
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePanel()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(
            withTitle: "Quit Silo",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        // Attaching the menu and immediately popping it shows it for this click
        // only, without making it the permanent left-click behavior.
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    // MARK: - Floating panel

    private func togglePanel() {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
            return
        }
        showPanel()
    }

    private func showPanel() {
        let panel = panel ?? makePanel()
        self.panel = panel
        positionPanelUnderStatusItem(panel)
        // Activate the app and make the panel key so the label field can receive
        // keystrokes immediately (a text field needs an active app + key window).
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        // Tell the SwiftUI content to reveal the create bubble and focus it.
        // Async so a freshly-created hosting view has subscribed to the
        // notification before we post it (otherwise the first open misses it).
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .siloPanelDidOpen, object: nil)
        }
    }

    // MARK: - Completion banner

    /// Show the gentle completion banner near the menu bar. Non-activating, so
    /// it doesn't pull the user out of whatever they're doing; the looping alarm
    /// (started by the engine) keeps playing until they pick Snooze or Done.
    private func showBanner() {
        // Avoid a redundant second "ringing" surface if the main panel is open.
        panel?.orderOut(nil)

        let banner = bannerPanel ?? makeBanner()
        bannerPanel = banner
        let size = NSSize(width: 420, height: 96)
        banner.setFrame(frameForPanel(size: size), display: true)
        banner.orderFrontRegardless()
    }

    private func makeBanner() -> FloatingPanel {
        let size = NSSize(width: 420, height: 96)
        let banner = FloatingPanel(contentRect: NSRect(origin: .zero, size: size))
        let root = CompletionBannerView { [weak self] in self?.hideBanner() }
            .modelContainer(modelContainer)
            .environment(engine)
        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: size)
        host.autoresizingMask = [.width, .height]
        banner.contentView = host
        return banner
    }

    private func hideBanner() {
        bannerPanel?.orderOut(nil)
    }

    /// Fixed panel width; the height is driven by the SwiftUI content.
    private let panelWidth: CGFloat = 460

    private func makePanel() -> FloatingPanel {
        // Start short (just the bubble row); the first content measurement will
        // grow it to fit.
        let size = NSSize(width: panelWidth, height: 140)
        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: size)
        )
        // Embed the SwiftUI tree. `NSHostingView` is the bridge from SwiftUI
        // back into AppKit's view hierarchy. We inject the persistence stack and
        // the shared engine here, since there's no SwiftUI scene to do it for us.
        // The container reports its measured height back so we can resize the
        // panel to fit (compact when history is hidden, taller when shown).
        let root = PanelContainerView { [weak self] height in
            self?.resizePanel(toContentHeight: height)
        }
        .modelContainer(modelContainer)
        .environment(engine)

        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: size)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        return panel
    }

    private func positionPanelUnderStatusItem(_ panel: FloatingPanel) {
        panel.setFrame(frameForPanel(size: panel.frame.size), display: true)
    }

    /// The on-screen frame for a panel of `size`: horizontally centered under
    /// the status item, hanging a fixed gap below the menu bar, and clamped to
    /// stay fully on screen. The top edge stays put as the height changes, so
    /// the panel grows *downward*.
    private func frameForPanel(size: NSSize) -> NSRect {
        guard
            let button = statusItem?.button,
            let buttonWindow = button.window
        else { return NSRect(origin: .zero, size: size) }

        let buttonFrame = buttonWindow.convertToScreen(
            button.convert(button.bounds, to: nil)
        )
        let gap: CGFloat = 12
        var x = buttonFrame.midX - size.width / 2
        let y = buttonFrame.minY - gap - size.height

        if let visible = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame {
            let margin: CGFloat = 8
            x = min(max(x, visible.minX + margin), visible.maxX - size.width - margin)
        }
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    /// Resize the panel to the height SwiftUI reported for its content, keeping
    /// it anchored under the menu bar. Animated for a smooth grow/shrink.
    private func resizePanel(toContentHeight height: CGFloat) {
        guard let panel else { return }
        let maxHeight = (panel.screen ?? NSScreen.main)?.visibleFrame.height ?? 900
        let clamped = min(max(height, 80), maxHeight - 40)
        let newFrame = frameForPanel(size: NSSize(width: panelWidth, height: clamped))
        guard abs(newFrame.height - panel.frame.height) > 0.5 else { return }
        // Hop off the SwiftUI layout pass before driving an AppKit animation.
        DispatchQueue.main.async {
            panel.setFrame(newFrame, display: true, animate: true)
        }
    }
}

/// Wraps `PanelRootView` and reports its measured height back to AppKit so the
/// hosting panel can size itself to the content. `onGeometryChange` fires
/// whenever the reported value changes — here, when history appears/disappears.
private struct PanelContainerView: View {
    let onHeightChange: (CGFloat) -> Void

    init(onHeightChange: @escaping (CGFloat) -> Void) {
        self.onHeightChange = onHeightChange
    }

    var body: some View {
        PanelRootView()
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { newHeight in
                onHeightChange(newHeight)
            }
    }
}
