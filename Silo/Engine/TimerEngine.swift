import Foundation
import SwiftData
import Observation

/// The single source of truth for the one active timer.
///
/// Responsibilities:
/// - Enforce **one active timer at a time** (the product rule).
/// - Drive the countdown from the task's absolute `endDate` (no tick drift).
/// - Move through the state machine: `idle → running → ringing → completed`,
///   with `snoozed` looping back into the countdown.
/// - Persist via SwiftData's `ModelContext`.
///
/// `@Observable` (not the older `ObservableObject`) means SwiftUI views that
/// read `remaining`, `activeTask`, or `isRinging` re-render automatically when
/// those change — and *only* when the properties they actually read change.
/// The whole class is `@MainActor` because it touches UI state and the main
/// `ModelContext`.
@MainActor
@Observable
final class TimerEngine {

    /// The live timer, or `nil` when idle.
    private(set) var activeTask: TimerTask?
    /// Seconds left on the active timer (kept fresh by the ticking loop).
    private(set) var remaining: TimeInterval = 0
    /// True once the countdown hits zero and we're awaiting Snooze/Done.
    private(set) var isRinging = false

    /// Called when a timer reaches zero. The app uses this to surface the
    /// completion UI (and, later, a notification / banner).
    var onRing: ((TimerTask) -> Void)?

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private var tickLoop: Task<Void, Never>?

    init(context: ModelContext) {
        self.context = context
    }

    /// Is a timer currently counting down?
    var isCounting: Bool { activeTask != nil && !isRinging }

    // MARK: - Commands

    /// Start a new timer. Rejected if one is already active (single-active rule).
    @discardableResult
    func start(label: String, minutes: Int) -> Bool {
        guard activeTask == nil else { return false }
        let task = TimerTask(label: label, durationMinutes: minutes)
        context.insert(task)
        try? context.save()
        activeTask = task
        isRinging = false
        beginTicking()
        return true
    }

    /// Re-arm the ringing timer for `minutes` more.
    func snooze(minutes: Int = 5) {
        guard let task = activeTask else { return }
        task.endDate = Date.now.addingTimeInterval(TimeInterval(minutes * 60))
        task.state = .snoozed
        try? context.save()
        isRinging = false
        beginTicking()
    }

    /// Acknowledge the finished timer ("Done") and move it into history.
    func markDone() {
        guard let task = activeTask else { return }
        task.completedAt = .now
        task.state = .completed
        try? context.save()
        finish()
    }

    /// Cancel the active timer before it finishes.
    func cancel() {
        guard let task = activeTask else { return }
        task.completedAt = .now
        task.state = .cancelled
        try? context.save()
        finish()
    }

    // MARK: - Ticking

    private func beginTicking() {
        tickLoop?.cancel()
        // An async loop on the main actor — no Timer, no Sendable juggling.
        tickLoop = Task { @MainActor in
            while !Task.isCancelled {
                updateRemaining()
                if activeTask == nil || isRinging { break }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func updateRemaining() {
        guard let task = activeTask else { return }
        remaining = max(0, task.endDate.timeIntervalSinceNow)
        if remaining <= 0 { ring(task) }
    }

    private func ring(_ task: TimerTask) {
        isRinging = true
        remaining = 0
        tickLoop?.cancel()
        onRing?(task)
    }

    private func finish() {
        tickLoop?.cancel()
        tickLoop = nil
        activeTask = nil
        isRinging = false
        remaining = 0
    }
}
