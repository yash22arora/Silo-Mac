# Silo

A native macOS **menu-bar timer** built around Apple's **Liquid Glass** design
language (macOS 26 / Tahoe). Open it from the menu bar, type a label, drag to set
a duration with a playful squeeze-and-bulge interaction, and get a gentle glass
banner when time's up. Past timers live in an in-panel history with swipe-to-rerun.

> Built as a hands-on, first-macOS-app learning project — see
> [Key Decisions & Learnings](#key-decisions--learnings).

---

## Requirements

- **macOS 26.0+** (Liquid Glass APIs)
- **Xcode 26.3+**, Swift 5 mode (Swift 6.2 toolchain)

## Run it

```bash
git clone https://github.com/yash22arora/Silo-Mac.git
cd Silo-Mac
open Silo.xcodeproj      # then press ⌘R in Xcode
```

Or from the command line:

```bash
xcodebuild -project Silo.xcodeproj -scheme Silo -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/Silo-*/Build/Products/Debug/Silo.app
```

Silo is an **accessory app** (`LSUIElement`) — it has no Dock icon. Look for the
**timer glyph in the menu bar**.

## How to use

| Action | What happens |
|---|---|
| Click the menu-bar icon | Panel opens, cursor lands in the label field — just type |
| Drag the grip handle **right** | Duration ↑, waist **pinches in**, ends widen (haptic ratchet) |
| Drag the grip handle **left** | Duration ↓, waist **bulges out**, ends narrow |
| Press **Return** | Timer starts; bubble morphs into a live countdown |
| Timer ends | Gentle glass banner near the menu bar: **Snooze 5** / **Done** |
| Swipe a history row left | **Rerun** that timer |
| **Esc** / click away | Panel dismisses |
| Right-click the icon | Quit |

---

## Architecture

Silo is an **AppKit spine hosting SwiftUI**. AppKit owns the menu bar and the
floating windows; SwiftUI renders everything inside them. There is no SwiftUI
`WindowGroup` — the app launches into the background as a menu-bar utility.

```
SiloApp (@main)
└── AppDelegate                     ← AppKit spine: status item + panels + lifecycle
    ├── NSStatusItem                ← the menu-bar icon (left = toggle, right = menu)
    ├── FloatingPanel  (main)       ← borderless, non-activating NSPanel
    │   └── NSHostingView
    │       └── PanelRootView       ← SwiftUI; injected ModelContainer + TimerEngine
    │           ├── plus / CreateBubbleView / RunningTimerView  (GlassEffectContainer)
    │           └── HistoryView     ← @Query past timers, swipe-to-rerun
    └── FloatingPanel  (banner)     ← CompletionBannerView (Snooze / Done)

TimerEngine  (@MainActor @Observable)   ← single-active state machine, drift-free ticking
TimerTask    (@Model)                   ← SwiftData persistence (stores endDate, not a counter)
SqueezeCapsule (Shape + Animatable)     ← the custom pinch/bulge geometry
```

### Folder layout

```
Silo/
├── SiloApp.swift               # @main; null Settings scene (no auto window)
├── App/AppDelegate.swift       # status item, panels, activation policy, Esc monitor
├── Panels/FloatingPanel.swift  # borderless non-activating NSPanel subclass
├── Features/
│   ├── Create/                 # PanelRootView, CreateBubbleView (drag + squeeze)
│   ├── Running/                # RunningTimerView (live countdown)
│   ├── History/                # HistoryView (glass card, swipe-to-rerun)
│   └── Banner/                 # CompletionBannerView
├── Shapes/SqueezeCapsule.swift # custom animatable Shape (pinch in / bulge out)
├── Engine/TimerEngine.swift    # single-active timer state machine
├── Feedback/                   # RatchetFeedback (haptics), AlarmPlayer (looping sound)
└── Model/TimerTask.swift       # SwiftData @Model
```

Design docs live in [`docs/`](docs/) (`PRD.md`, `TRD.md`).

---

## Key Decisions & Learnings

A running log of the non-obvious choices and the macOS-specific gotchas behind them.

### App shape
- **`NSStatusItem` + a custom `NSPanel`, not `MenuBarExtra`.** `MenuBarExtra`'s
  window is glued under its icon and can't float freely or morph. Dropping to
  AppKit and hosting SwiftUI via `NSHostingView` is the price of the desired UI.
- **`LSUIElement` (accessory) vs. the scene.** Two independent switches: the
  Info.plist key removes the Dock icon; using a `Settings` scene (not
  `WindowGroup`) prevents a window auto-opening at launch.
- **Manual dependency injection.** With no SwiftUI scene, the `ModelContainer` and
  `TimerEngine` are created once in `AppDelegate` and injected by hand onto each
  hosting view (`.modelContainer(...).environment(engine)`).

### Liquid Glass
- **Morphing needs three things together:** a `GlassEffectContainer`,
  matched `glassEffectID`s in a shared `@Namespace`, and the state change wrapped
  in `withAnimation`. An explicit SwiftUI `.transition` *overrides* the glass
  morph — removing it (and declaring `.glassEffectTransition(.matchedGeometry)` on
  **both** participants) is what makes the bubble flow back into the `+`.

### Animation internals
- **`Shape` + `animatableData` is the whole engine.** `SqueezeCapsule` exposes its
  signed `squeeze` through `animatableData`, so SwiftUI interpolates the geometry
  frame-by-frame instead of snapping.
- **Bulge without clipping:** the shape draws into a rect taller than the visible
  capsule (`bulgeRoom`), with cap radius = half the *visible* capsule, so the
  outward bulge expands into reserved transparent space instead of past the frame.
- **`contentTransition(.numericText)` needs a clock.** The rolling digits only
  animate when the value change rides an animation transaction — scoped here via
  `.animation(_, value:)` so the squeeze stays glued to the drag.
- **Direct manipulation vs. animation:** drag updates are applied *without*
  `withAnimation` (finger = clock); only the release springs back.

### Timing & reliability
- **Store `endDate`, never a countdown counter.** Remaining is always
  `endDate − now`, so the timer can't drift even if ticks are dropped.
- **Boundary-aligned ticking:** the async tick loop sleeps until the next whole
  second (recomputed from `endDate`), so the display flips on the beat and stays
  wall-clock accurate. (Known gap: if the Mac sleeps past `endDate`, the alarm
  fires late — a local notification is the planned fix.)
- **Invariants live in the engine.** Single-active enforcement is one guard in
  `TimerEngine.start()`; the UI (including swipe-to-rerun) inherits it for free.

### Focus, input & dismissal (the macOS-specific stuff)
- **Type-to-fill needs `NSApp.activate` *and* `makeKeyAndOrderFront`.** A text
  field only receives keys when the app is active *and* its window is key.
- **`FocusState.Binding`** lets the parent (`PanelRootView`) focus a field owned
  by a child (`CreateBubbleView`) the instant the panel opens.
- **Cross-boundary timing:** signalling SwiftUI from AppKit (a `NotificationCenter`
  post) and then focusing both need a hop to the next runloop tick, so the
  subscriber/field exists before they're used.
- **Esc via a local event monitor**, not a responder override — it intercepts the
  key before the text field's field editor can swallow it.
- **Click-away-to-hide keys off `applicationDidResignActive`, not
  `windowDidResignKey`** — the latter collides with the status-item click and
  causes a hide-then-reopen flicker.
- **Hiding UI ≠ resolving state:** the completion banner intentionally ignores Esc,
  because `orderOut` would hide it while leaving the looping alarm unstoppable.

### AppKit ↔ SwiftUI sizing
- The panel **auto-sizes to its content**: SwiftUI reports its height via
  `.onGeometryChange`, and AppKit resizes the panel (`setFrame`) to match,
  anchored under the menu bar — content tells the window how big to be, the
  inverse of the normal flow.
