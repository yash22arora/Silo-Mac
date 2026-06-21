import SwiftUI

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

    var body: some View {
        GlassEffectContainer(spacing: 32) {
            HStack(spacing: 8) {
                plusBubble

                if isExpanded {
                    createBubble
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
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

    // MARK: - The create bubble (placeholder for Increment 3)

    private var createBubble: some View {
        HStack(spacing: 12) {
            // Duration readout — becomes a live, drag-adjustable value in
            // Increment 3. Defaults to the 30-minute spec value.
            Text("30")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text("min")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Divider().frame(height: 24)

            // Label placeholder — becomes an editable NSTextField-backed field
            // (via NSViewRepresentable) in Increment 3.
            Text("Label…")
                .font(.system(size: 15))
                .foregroundStyle(.tertiary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(height: 52)
        .frame(minWidth: 180)
        .glassEffect()
        .glassEffectID("create", in: glassNamespace)
        // Morph the glass out of (and back into) the neighboring "+" glass
        // instead of cross-fading as a separate pane.
        .glassEffectTransition(.matchedGeometry)
    }
}

#Preview {
    PanelRootView()
        .frame(width: 340, height: 120)
}
