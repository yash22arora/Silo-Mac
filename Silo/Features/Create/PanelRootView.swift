import SwiftUI
import SwiftData

/// The floating panel's content (Increment 2).
///
/// This is where Liquid Glass earns its name. Tapping the "+" bubble morphs a
/// second "create" bubble into existence and slides the "+" to the left — and
/// the glass *flows* between the two shapes instead of one fading out and
/// another fading in. Three pieces make that happen:
///
/// 1. `GlassEffectContainer` — groups nearby glass shapes so they can blend and
///    morph as a single fluid material rather than independent panes.
/// 2. `@Namespace` + `.glassEffectID(_:in:)` — gives each glass shape a stable
///    identity inside that container, so the system knows "this glass became
///    that glass" and animates the transition.
/// 3. `withAnimation` around the state change — drives both the layout change
///    (the "+" moving left) and the glass morph on the same timeline.
struct PanelRootView: View {
    @State private var isExpanded = false

    /// The identity space the glass shapes live in. Matched IDs across a state
    /// change tell Liquid Glass to morph rather than cross-fade.
    @Namespace private var glassNamespace

    @Environment(TimerEngine.self) private var engine

    /// Drives the label field's focus. Owned here so we can focus it the instant
    /// the panel opens, then passed down into `CreateBubbleView`.
    @FocusState private var labelFocused: Bool

    // We can't filter on `state`/`isActive` in a #Predicate (they're computed,
    // not stored columns SwiftData can query). So fetch all and check in Swift —
    // trivial at this volume, and it reuses the same `isActive` logic.
    @Query private var allTasks: [TimerTask]
    private var hasPastTasks: Bool { allTasks.contains { !$0.isActive } }

    var body: some View {
        VStack(spacing: 16) {
            // The bubble row sits at the top, near the menu bar. Its own
            // GlassEffectContainer keeps the +/create/running morph isolated.
            GlassEffectContainer(spacing: 32) {
                HStack(spacing: 8) {
                    if engine.activeTask != nil {
                        // A timer is live → the create flow yields to the
                        // countdown, reusing a glassEffectID so it morphs in.
                        RunningTimerView(glassNamespace: glassNamespace)
                    } else {
                        plusBubble

                        if isExpanded {
                            CreateBubbleView(
                                glassNamespace: glassNamespace,
                                labelFocused: $labelFocused
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            // The history card floats below the bubbles — only once there's at
            // least one past (completed/cancelled) timer to show.
            if hasPastTasks {
                HistoryView(glassNamespace: glassNamespace)
            }
        }
        // Fill the panel width but take only the natural height of the content,
        // so the host can measure it and resize the panel to fit.
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(20)
        // When the active timer clears (Done/Cancel), collapse back to just "+".
        .onChange(of: engine.activeTask == nil) { _, idle in
            if idle { isExpanded = false }
        }
        // When the panel opens (menu-bar click), reveal the create bubble and
        // drop the cursor straight into the label field — type-to-fill.
        .onReceive(NotificationCenter.default.publisher(for: .siloPanelDidOpen)) { _ in
            guard engine.activeTask == nil else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                isExpanded = true
            }
            focusLabelSoon()
        }
        // Also focus when the bubble is expanded by tapping "+".
        .onChange(of: isExpanded) { _, expanded in
            if expanded { focusLabelSoon() }
        }
    }

    /// Move focus to the label on the next runloop tick, after the field has
    /// actually been inserted into the view tree by the expand animation.
    private func focusLabelSoon() {
        DispatchQueue.main.async { labelFocused = true }
    }

    // MARK: - The "+" bubble

    private var plusBubble: some View {
        Image(systemName: isExpanded ? "xmark" : "plus")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 52, height: 52)
            .glassEffect()
            // Stable identity for this glass shape within the container.
            .glassEffectID("plus", in: glassNamespace)
            // The "+" is the morph *target* on collapse, so it must also opt
            // into matched-geometry morphing — otherwise the create bubble has
            // nothing to flow back into and just pops out of existence.
            .glassEffectTransition(.matchedGeometry)
            .contentShape(.circle)
            .onTapGesture {
                // One spring drives BOTH the layout (HStack reflow → "+" slides
                // left) and the Liquid Glass morph of the new bubble.
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                    isExpanded.toggle()
                }
            }
    }

}

#Preview {
    let container = try! ModelContainer(
        for: TimerTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return PanelRootView()
        .frame(width: 500, height: 500)
        .modelContainer(container)
        .environment(TimerEngine(context: container.mainContext))
}
