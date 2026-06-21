import SwiftUI

/// The gentle completion banner shown near the menu bar when a timer finishes.
///
/// Deliberately *not* a full-screen takeover (per the product decision) — a
/// small glass capsule with the label and the two actions. It lives in its own
/// non-activating panel, so it appears without stealing focus from whatever the
/// user is doing.
struct CompletionBannerView: View {
    @Environment(TimerEngine.self) private var engine

    /// Called after the user picks an action, so AppKit can dismiss the panel.
    let onResolve: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "bell.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.orange)
                .symbolEffect(.bounce, options: .repeat(.periodic(delay: 1.2)))

            VStack(alignment: .leading, spacing: 2) {
                Text(engine.activeTask?.label ?? "Timer")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text("Time's up")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            Button("Snooze 5") {
                engine.snooze(minutes: 5)
                onResolve()
            }
            .buttonStyle(.glass)

            Button("Done") {
                engine.markDone()
                onResolve()
            }
            .buttonStyle(.glassProminent)
        }
        .padding(.horizontal, 20)
        .frame(height: 64)
        .frame(minWidth: 340)
        .glassEffect(.regular, in: .capsule)
    }
}
