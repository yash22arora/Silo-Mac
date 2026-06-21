import SwiftUI
import SwiftData

/// Shown in the floating panel while a timer is live.
///
/// Two phases share this glass bubble:
/// - **Counting** → label + mm:ss remaining + a Cancel button.
/// - **Ringing** → label + "Time's up" + Snooze / Done buttons.
///
/// (In Increment 6 the ringing phase also gets a dedicated banner panel; this
/// inline version keeps the app fully usable now.)
struct RunningTimerView: View {
    let glassNamespace: Namespace.ID

    // Read the shared engine from the environment. Because it's `@Observable`,
    // reading `remaining` / `isRinging` here makes this view re-render on tick.
    @Environment(TimerEngine.self) private var engine

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(engine.activeTask?.label ?? "Timer")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(engine.isRinging ? "Time's up" : timeString)
                    .font(.system(size: engine.isRinging ? 13 : 22,
                                  weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(engine.isRinging ? .secondary : .primary)
            }

            Spacer(minLength: 8)

            if engine.isRinging {
                Button("Snooze 5") { engine.snooze(minutes: 5) }
                    .buttonStyle(.glass)
                Button("Done") { engine.markDone() }
                    .buttonStyle(.glassProminent)
            } else {
                Button {
                    engine.cancel()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.glass)
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 56)
        .frame(minWidth: 260)
        .glassEffect(.regular, in: .capsule)
        .glassEffectID("create", in: glassNamespace) // reuse id → morph from create bubble
        .glassEffectTransition(.matchedGeometry)
        // Animate the count/ring swap so layout changes glide.
        .animation(.snappy, value: engine.isRinging)
        .animation(.default, value: Int(engine.remaining))
    }

    private var timeString: String {
        let total = Int(engine.remaining.rounded())
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

#Preview {
    RunningPreview()
        .frame(width: 360, height: 120)
        .padding()
}

private struct RunningPreview: View {
    @Namespace var ns
    private let engine: TimerEngine
    private let container: ModelContainer

    init() {
        container = try! ModelContainer(
            for: TimerTask.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        engine = TimerEngine(context: container.mainContext)
        engine.start(label: "Write report", minutes: 1)
    }

    var body: some View {
        GlassEffectContainer { RunningTimerView(glassNamespace: ns) }
            .modelContainer(container)
            .environment(engine)
    }
}
