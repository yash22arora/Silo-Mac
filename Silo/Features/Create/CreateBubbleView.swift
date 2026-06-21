import SwiftUI

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

    // Minutes committed before the current drag began.
    @State private var baseMinutes: Int = 30
    // Minutes reflecting the in-progress drag (what we display).
    @State private var currentMinutes: Int = 30
    // 0 = capsule, 1 = full pinch. Driven by the drag, sprung back on release.
    @State private var squeeze: CGFloat = 0
    @State private var label: String = ""

    // Tuning constants for the drag feel.
    private let pointsPerMinute: CGFloat = 6     // smaller = faster ramp
    private let pointsForFullSqueeze: CGFloat = 130
    private let minMinutes = 5
    private let maxMinutes = 180

    var body: some View {
        HStack(spacing: 12) {
            durationReadout

            Divider().frame(height: 22)

            TextField("Label…", text: $label)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .frame(minWidth: 70)

            dragHandle
        }
        .padding(.horizontal, 18)
        .frame(height: 52)
        .frame(minWidth: 190)
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
                .contentTransition(.numericText())   // digits roll, not snap
            Text("min")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
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
            }
            .onEnded { _ in
                // Commit the new duration; spring the bubble back to a capsule.
                baseMinutes = currentMinutes
                withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                    squeeze = 0
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
    var body: some View {
        GlassEffectContainer { CreateBubbleView(glassNamespace: ns) }
    }
}
