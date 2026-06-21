# Silo — Technical Requirements Document (TRD)

**Status:** Approved for v1
**Date:** 2026-06-21
**Targets:** macOS 26.0+, Swift 5 mode (Swift 6.2 compiler), Xcode 26.3

---

## 1. Technology Choices

| Concern | Choice | Rationale |
|---|---|---|
| UI framework | SwiftUI + targeted AppKit | SwiftUI for views; AppKit where SwiftUI can't reach (status item, floating non-activating panel). |
| Design system | Liquid Glass (`glassEffect`, `GlassEffectContainer`, glass morphing) | Native macOS 26 API; the product's reason for being. |
| Menu bar | `NSStatusItem` | Needed for a freely-positioned, custom floating panel (not anchored like `MenuBarExtra`). |
| Floating surfaces | `NSPanel` (borderless, non-activating, `.floating` level) hosting SwiftUI via `NSHostingView` | Lets glass UI float "at a distance" from the menu bar and not steal focus. |
| Persistence | SwiftData | Modern, declarative, integrates with SwiftUI `@Query`. |
| Timer firing | In-process async countdown + `UNUserNotificationCenter` local notification as safety net | Reliable completion even if app loses focus. |
| Custom squeeze | Custom `Shape` + `Animatable` (`animatableData`) | Per design decision: no Metal; learn SwiftUI animation internals. |
| Tests | Swift Testing | Pure-logic tests for engine + shape. |

## 2. App Lifecycle

- `@main struct SiloApp: App` with:
  - An `NSApplicationDelegateAdaptor` (`AppDelegate`) owning the `NSStatusItem`
    and the floating panels.
  - A SwiftUI `Window` scene for the History window.
- `LSUIElement = YES` (accessory app — lives in the menu bar, no Dock icon by
  default). Activation policy is raised to `.regular` only while the History
  window is shown, then lowered again. *(Implemented in a later increment.)*

## 3. Module / File Layout

```
Silo/
├── SiloApp.swift                 # @main; App scene + History Window
├── App/
│   └── AppDelegate.swift         # NSStatusItem, panel lifecycle, app activation
├── Panels/
│   ├── FloatingPanel.swift       # NSPanel subclass (borderless, non-activating)
│   └── PanelPresenter.swift      # show/hide/position helpers
├── Features/
│   ├── Create/
│   │   ├── CreateBubbleView.swift     # + bubble + emerging timer bubble (morph)
│   │   ├── DragHandle.swift           # drag-to-increase + squeeze driver
│   │   └── TimerDraftModel.swift      # label + duration draft state
│   ├── Running/
│   │   └── RunningTimerView.swift     # active countdown UI
│   ├── History/
│   │   └── HistoryView.swift          # main window list (ongoing + completed)
│   └── Banner/
│       └── CompletionBannerView.swift # snooze / done
├── Shapes/
│   └── SqueezeCapsule.swift      # custom animatable Shape
├── Engine/
│   └── TimerEngine.swift         # single-active-timer state machine
└── Model/
    └── TimerTask.swift           # SwiftData @Model
```

## 4. Data Model

```swift
enum TimerState: String, Codable {
    case running, snoozed, completed, cancelled
}

@Model
final class TimerTask {
    var id: UUID
    var label: String
    var durationMinutes: Int
    var createdAt: Date
    var completedAt: Date?
    var stateRaw: String        // backing for TimerState

    // Convenience computed accessor for state.
}
```

- History query: `@Query` sorted by `(state == running/snoozed) first`, then
  `completedAt` descending.

## 5. TimerEngine (state machine)

States: `idle → running → (snoozed → running)* → completed | cancelled`.

Responsibilities:
- Enforce **one active timer**. Starting a new one while active is rejected or
  replaces, per UI.
- Drive the countdown (async `Task` with `Date`-based remaining calc — never
  trust tick accumulation; compute from `endDate`).
- Schedule the local notification at start; cancel/reschedule on snooze/cancel.
- Publish `remaining`, `state`, and a `didComplete` event the AppDelegate
  observes to show the banner.

Snooze math: `endDate = now + 5*60`; state `snoozed`; reschedule notification.

## 6. Liquid Glass Interaction (Create flow)

- A single `GlassEffectContainer` wraps the "+" bubble and the create bubble.
- Each bubble has `.glassEffect(...)` and `.glassEffectID(_, in: namespace)`.
- A `@State isExpanded` toggles layout; SwiftUI animates the layout change inside
  `withAnimation`, and Liquid Glass morphs the glass between IDs automatically.

## 7. Custom Squeeze Shape

```swift
struct SqueezeCapsule: Shape {
    var squeeze: CGFloat            // 0 = capsule, 1 = max pinch
    var animatableData: CGFloat {
        get { squeeze }
        set { squeeze = newValue }
    }
    func path(in rect: CGRect) -> Path { /* bezier: bulged ends, pinched middle */ }
}
```

- Drive `squeeze` from the drag handle's horizontal translation.
- On drag end: `withAnimation(.spring)` set `squeeze = 0`; `durationMinutes`
  persists from the same translation mapping.

## 8. Floating Panel Requirements

- `NSPanel` with `styleMask: [.borderless, .nonactivatingPanel]`,
  `isFloatingPanel = true`, `level = .floating`, `backgroundColor = .clear`,
  `hasShadow = false` (glass provides its own depth).
- Positioned a fixed offset below the menu bar, horizontally aligned to the
  status item.
- Content = `NSHostingView(rootView:)` with the SwiftUI tree, injecting the
  SwiftData `ModelContainer` and the shared `TimerEngine`.

## 9. Concurrency & Safety

- `SWIFT_VERSION = 5.0`, approachable concurrency, default actor isolation
  `MainActor` (UI-centric app). Engine is `@MainActor`.
- All SwiftData access on the main context for v1 (single timer, low volume).

## 10. Build Settings (key)

- `GENERATE_INFOPLIST_FILE = YES`
- `INFOPLIST_KEY_LSUIElement = YES`
- `MACOSX_DEPLOYMENT_TARGET = 26.0`
- `SWIFT_VERSION = 5.0`
- `PRODUCT_BUNDLE_IDENTIFIER = com.yasharora.Silo`

## 11. Testing Strategy

- `TimerEngineTests`: single-active enforcement; snooze adds 5 min; completion
  sets `completedAt`; remaining computed from `endDate`.
- `SqueezeCapsuleTests`: path bounding box at `squeeze = 0` equals capsule;
  `squeeze = 1` pinches the midpoint inward (assert control-point geometry).

## 12. Implementation Increments (teaching plan)

1. **Shell** — `NSStatusItem` + floating `NSPanel` + empty History `Window`.
2. **Glass + morph** — "+" → create-bubble morphing in `GlassEffectContainer`.
3. **Squeeze shape** — custom `Shape` + drag-to-increase duration.
4. **Engine + persistence** — `TimerEngine` + SwiftData model + start/run.
5. **History window** — `@Query` list, ongoing-first ordering, activation policy.
6. **Banner** — completion banner + notification safety net + snooze/done.

Each increment ends with an explanation and a knowledge check.

## 13. Risks

- **Squeeze fidelity:** bezier-only pinch may look less "physical" than a shader.
  Mitigation: accepted trade-off for v1; revisit with Metal later.
- **Glass morphing edge cases:** morphing between very different sizes can pop.
  Mitigation: tune sizes/animation curves.
- **Notification permission denied:** banner still shows in-app while running;
  the notification is only the out-of-focus safety net.
