import SwiftUI
import SwiftData

/// The history card that floats *below* the bubble row inside the panel.
///
/// Shows only **past** timers (completed / cancelled). The ongoing one is always
/// visible up in the bubble row, so repeating it here would be redundant.
///
/// `@Query` is SwiftData's live-fetch wrapper — the card re-renders whenever the
/// store changes. We use a `List` (not a ScrollView) specifically because
/// `.swipeActions` — the swipe-to-rerun affordance — is only available on list
/// rows. `.scrollContentBackground(.hidden)` strips the List's default backing
/// so our Liquid Glass card shows through.
struct HistoryView: View {
    @Query(sort: \TimerTask.createdAt, order: .reverse) private var tasks: [TimerTask]
    @Environment(TimerEngine.self) private var engine
    let glassNamespace: Namespace.ID
    @Namespace private var historyNameSpace

    /// Past timers only — exclude the live (running/snoozed) one.
    private var past: [TimerTask] { tasks.filter { !$0.isActive } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Past timers")
                .font(.system(size: 12, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 4)

            if past.isEmpty {
                Text("No past timers yet")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                List {
                    ForEach(past) { task in
                        TaskRow(task: task)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .glassEffect(.regular, in: .rect(cornerRadius: 26, style: .circular))
                            // Swipe left on a row to rerun that timer. On macOS
                            // this is a two-finger trackpad swipe.
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    rerun(task)
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                        .padding(8)
                                        .glassEffect(.regular, in: .circle)
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)   // let the glass show through
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
        .glassEffectID("history", in: glassNamespace)
        .glassEffectTransition(.matchedGeometry)
    }

    /// Start a fresh timer from a past one's label + duration. The engine's
    /// single-active rule means this is a no-op if a timer is already running.
    private func rerun(_ task: TimerTask) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            _ = engine.start(label: task.label, minutes: task.durationMinutes)
        }
    }
}

/// One row in the history card.
private struct TaskRow: View {
    let task: TimerTask

    var body: some View {
        HStack(alignment: .center, spacing: 12) {

            VStack(alignment: .leading, spacing: 2) {
                Text(task.label)
                    .font(.system(size: 14, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text("\(task.durationMinutes) min")
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 20)
    }

    private var subtitle: String {
        switch task.state {
        case .running, .snoozed:
            return "Started \(task.createdAt.formatted(date: .omitted, time: .shortened))"
        case .completed:
            let when = task.completedAt ?? task.createdAt
            return "Completed \(when.formatted(date: .abbreviated, time: .shortened))"
        case .cancelled:
            return "Cancelled"
        }
    }
}

#Preview {
    @Previewable @Namespace var ns
    let container = try! ModelContainer(
        for: TimerTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let ctx = container.mainContext
    let done = TimerTask(label: "Write report", durationMinutes: 30)
    done.completedAt = .now; done.state = .completed
    ctx.insert(done)
    let cancelled = TimerTask(label: "Standup", durationMinutes: 15)
    cancelled.state = .cancelled; cancelled.completedAt = .now
    ctx.insert(cancelled)
    return HistoryView(glassNamespace: ns)
        .frame(width: 420)
        .padding()
        .modelContainer(container)
        .environment(TimerEngine(context: ctx))
}
