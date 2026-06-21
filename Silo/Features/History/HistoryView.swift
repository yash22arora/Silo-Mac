import SwiftUI
import SwiftData

/// The main window's content: every timer the user has created, with any
/// ongoing one pinned at the top and completed ones below.
///
/// `@Query` is SwiftData's live-fetch property wrapper — the view re-renders
/// automatically whenever the store changes (a timer starts, finishes, etc.),
/// no manual reloading. We fetch newest-first and split into "ongoing" vs
/// "history" in Swift, which keeps the predicate simple and the volume here is
/// tiny.
struct HistoryView: View {
    @Query(sort: \TimerTask.createdAt, order: .reverse) private var tasks: [TimerTask]

    private var ongoing: [TimerTask] { tasks.filter(\.isActive) }
    private var finished: [TimerTask] { tasks.filter { !$0.isActive } }

    var body: some View {
        List {
            if !ongoing.isEmpty {
                Section("Ongoing") {
                    ForEach(ongoing) { TaskRow(task: $0) }
                }
            }

            Section("History") {
                if finished.isEmpty {
                    Text("No completed timers yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(finished) { TaskRow(task: $0) }
                }
            }
        }
        .listStyle(.inset)
        .frame(minWidth: 380, minHeight: 440)
    }
}

/// One row in the history list.
private struct TaskRow: View {
    let task: TimerTask

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.system(size: 16))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.label)
                    .font(.system(size: 14, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(task.durationMinutes) min")
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var icon: String {
        switch task.state {
        case .running, .snoozed: return "timer"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }

    private var tint: Color {
        switch task.state {
        case .running, .snoozed: return .accentColor
        case .completed: return .green
        case .cancelled: return .secondary
        }
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
    let container = try! ModelContainer(
        for: TimerTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let ctx = container.mainContext
    let done = TimerTask(label: "Write report", durationMinutes: 30)
    done.completedAt = .now; done.state = .completed
    ctx.insert(done)
    ctx.insert(TimerTask(label: "Focus block", durationMinutes: 45))
    return HistoryView().modelContainer(container)
}
