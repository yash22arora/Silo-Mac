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

    /// Focus is owned by the parent (so it can focus the field the moment the
    /// panel opens); we just bind the TextField to it. A `FocusState.Binding`
    /// lets a child drive a parent's `@FocusState`.
    let labelFocused: FocusState<Bool>.Binding

    @Environment(TimerEngine.self) private var engine

    // Minutes committed before the current drag began.
    @State private var baseMinutes: Int = 30
    // Minutes reflecting the in-progress drag (what we display).
    @State private var currentMinutes: Int = 30
    // Signed deformation: >0 pinches the waist in (right drag), <0 bulges it out
    // (left drag). Sprung back to 0 on release.
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
    private let minMinutes = 1
    private let maxMinutes = 180
    private let maxDeltaWidth: CGFloat = 40   // gentler width travel so the pinch reads, not just the shrink
    // Transparent vertical room reserved around the capsule so the outward
    // bulge (negative squeeze) is visible instead of clipped. Must match the
    // value passed to `SqueezeCapsule`.
    private let bulgeRoom: CGFloat = 12

    var body: some View {
        HStack(spacing: 12) {
            durationReadout

            Divider().frame(height: 22)

            TextField("Label…", text: $label)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .frame(minWidth: 70)
                .focused(labelFocused)
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
        // Reserve transparent room above/below so the outward bulge isn't
        // clipped. The capsule stays visually 52pt tall; the glass rect is
        // 52 + 2*bulgeRoom, and SqueezeCapsule centers the caps within it.
        .padding(.vertical, bulgeRoom)
        // The glass is clipped to the *animated* squeeze shape, so pulling the
        // handle physically deforms the material in both directions.
        .glassEffect(.regular, in: SqueezeCapsule(squeeze: squeeze, bulgeRoom: bulgeRoom))
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

                // One signed value: right → pinch (+), left → bulge (−).
                squeeze = max(-1, min(dx / pointsForFullSqueeze, 1))
                // Volume-preserving width, signed BOTH ways: pinching the waist
                // widens the ends (+), bulging the waist narrows them (−). The
                // old `max(0, squeeze)` floored the bulge side to zero, which is
                // why a left drag changed nothing.
                deltaWidth = squeeze * maxDeltaWidth

                // Ratchet feedback both ways: a signed step that changes once
                // per unit of deformation, whether pinching or bulging.
                // `.onChanged` runs far more often than once per step.
                let step = Int(squeeze * maxDeltaWidth)
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
    @FocusState var focused: Bool
    private let container = try! ModelContainer(
        for: TimerTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    var body: some View {
        GlassEffectContainer {
            CreateBubbleView(glassNamespace: ns, labelFocused: $focused)
        }
        .modelContainer(container)
        .environment(TimerEngine(context: container.mainContext))
    }
}
