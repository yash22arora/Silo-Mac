import AppKit
import SwiftUI
import SwiftData

/// Owns the menu-bar status item and the floating panel, and wires clicks
/// together. This is the "AppKit spine" of the app; SwiftUI lives *inside* the
/// panel via `NSHostingView`.
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var panel: FloatingPanel?

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
            self?.showPanel()
        }
    }

    // MARK: - Status item

    private func setUpStatusItem() {
        // `.variableLength` lets the item size to its content (an icon here).
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "timer",
                accessibilityDescription: "Silo"
            )
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
        panel.orderFrontRegardless()
    }

    private func makePanel() -> FloatingPanel {
        let size = NSSize(width: 320, height: 120)
        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: size)
        )
        // Embed the SwiftUI tree. `NSHostingView` is the bridge from SwiftUI
        // back into AppKit's view hierarchy. We inject the persistence stack and
        // the shared engine here, since there's no SwiftUI scene to do it for us.
        let root = PanelRootView()
            .modelContainer(modelContainer)
            .environment(engine)
        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: size)
        panel.contentView = host
        return panel
    }

    /// Centers the panel horizontally under the status item, a fixed gap below
    /// the menu bar.
    private func positionPanelUnderStatusItem(_ panel: FloatingPanel) {
        guard
            let button = statusItem?.button,
            let buttonWindow = button.window
        else { return }

        // The button's frame in screen coordinates.
        let buttonFrameInScreen = buttonWindow.convertToScreen(
            button.convert(button.bounds, to: nil)
        )

        let gap: CGFloat = 12
        let panelSize = panel.frame.size
        let x = buttonFrameInScreen.midX - panelSize.width / 2
        let y = buttonFrameInScreen.minY - gap - panelSize.height

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
