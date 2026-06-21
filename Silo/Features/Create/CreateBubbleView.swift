import SwiftUI
import SwiftData

/// The timer-creation bubble (Increment 3).
///
/// Responsibilities:
/// - Show the editable label + a live duration (default 30 min).
/// - A drag handle on the right that **increases the duration as you pull right**
///   and **squeezes the bubble** (mid-section pinches, ends stay bulged) via the
///   custom `SqueezeCapsule` shape.
/// - On release, the squeeze springs back to a capsule while the new duration
///   sticks.
///
/// The glass material is clipped to `SqueezeCapsule(squeeze:)`, so the *glass
/// itself* deforms — not just an outline.
struct CreateBubbleView: View {
    /// Shared identity space so this bubble can morph out of the "+".
    let glassNamespace: Namespace.ID

    @Environment(TimerEngine.self) private var engine

    // Minutes committed before the current drag began.
    @State private var baseMinutes: Int = 30
    // Minutes reflecting the in-progress drag (what we display).
    @State private var currentMinutes: Int = 30
    // 0 = capsule, 1 = full pinch. Driven by the drag, sprung back on release.
    @State private var squeeze: CGFloat = 0
    @State private var label: String = ""
    // Delta width
    @State private var deltaWidth: CGFloat = 0
    // Last whole width-point we fired feedback on, so we tick once per point
    // instead of on every (very frequent) drag callback.
    @State private var lastWidthStep: Int = 0

    private let feedback = RatchetFeedback()

    // Tuning constants for the drag feel.
    private let pointsPerMinute: CGFloat = 10     // smaller = faster ramp
    private let pointsForFullSqueeze: CGFloat = 150
    private let minMinutes = 5
    private let maxMinutes = 180
    private let maxDeltaWidth: CGFloat = 60

    var body: some View {
        HStack(spacing: 12) {
            durationReadout

            Divider().frame(height: 22)

            TextField("Label…", text: $label)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .frame(minWidth: 70)
                // Enter starts the timer. The engine flips `activeTask`, and
                // PanelRootView morphs this bubble into the running view — we
                // animate so that swap glides instead of snapping.
                .onSubmit {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                        _ = engine.start(label: label, minutes: currentMinutes)
                    }
                }

            dragHandle
        }
        .padding(.horizontal, 18)
        .frame(height: 52)
        // Use an explicit `width` (not `minWidth`): the flexible TextField would
        // otherwise already fill more than any minimum, so a min has no effect.
        // A concrete width is the only thing `deltaWidth` can actually move.
        .frame(width: 300 + deltaWidth)
        // The glass is clipped to the *animated* squeeze shape, so pulling the
        // handle physically deforms the material.
        .glassEffect(.regular, in: SqueezeCapsule(squeeze: squeeze))
        .glassEffectID("create", in: glassNamespace)
        .glassEffectTransition(.matchedGeometry)
    }

    // MARK: - Pieces

    private var durationReadout: some View {
        HStack(spacing: 4) {
            Text("\(currentMinutes)")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(currentMinutes)))   // digits roll, not snap
            Text("min")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        // Scope an animation to ONLY the minutes value. This gives the
        // numericText content transition a transaction to ride on (so the
        // digits roll) without animating `squeeze`/`deltaWidth`, which must keep
        // tracking the drag instantly.
        .animation(.snappy(duration: 0.18), value: currentMinutes)
    }

    private var dragHandle: some View {
        Image(systemName: "line.3.horizontal")
            .rotationEffect(.degrees(90))            // vertical grip lines
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 52)
            .contentShape(.rect)                     // whole area is draggable
            .gesture(resizeDrag)
    }

    // MARK: - The resize gesture

    private var resizeDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let dx = value.translation.width

                // Minutes follow the signed drag (pull right to add, left to
                // remove), clamped to a sane range.
                let deltaMinutes = Int((dx / pointsPerMinute).rounded())
                currentMinutes = min(max(baseMinutes + deltaMinutes, minMinutes), maxMinutes)

                // Squeeze responds only to the rightward pull, 0...1.
                squeeze = min(max(dx, 0) / pointsForFullSqueeze, 1)
                deltaWidth = squeeze * maxDeltaWidth

                // Fire a haptic + sound each time we cross a whole width point.
                // `.onChanged` runs far more often than once per point, so we
                // only tick when the integer step actually changes.
                let step = Int(deltaWidth)
                if step != lastWidthStep {
                    lastWidthStep = step
                    feedback.tick()
                }
            }
            .onEnded { _ in
                // Commit the new duration; spring the bubble back to a capsule.
                baseMinutes = currentMinutes
                lastWidthStep = 0
                withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                    squeeze = 0
                    deltaWidth = 0
                }
            }
    }
}

#Preview {
    PreviewWrapper()
        .frame(width: 360, height: 120)
        .padding()
}

private struct PreviewWrapper: View {
    @Namespace var ns
    private let container = try! ModelContainer(
        for: TimerTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    var body: some View {
        GlassEffectContainer { CreateBubbleView(glassNamespace: ns) }
            .modelContainer(container)
            .environment(TimerEngine(context: container.mainContext))
    }
}
