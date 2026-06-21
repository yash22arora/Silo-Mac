import SwiftUI

/// Placeholder content for the floating panel (Increment 1).
///
/// For now this is just the resting "+" bubble rendered with Liquid Glass, so we
/// can confirm the panel + glass pipeline works end to end. In Increment 2 this
/// becomes a `GlassEffectContainer` where tapping "+" *morphs* a second bubble
/// into existence and pushes the "+" to the left.
struct PanelRootView: View {
    var body: some View {
        ZStack {
            // The "+" bubble. `.glassEffect` is the macOS 26 Liquid Glass
            // modifier: it gives the view a translucent, light-bending glass
            // material clipped to the supplied shape (a circle here).
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 56, height: 56)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }
}

#Preview {
    PanelRootView()
        .frame(width: 320, height: 120)
}
