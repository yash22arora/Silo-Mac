import Foundation
import SwiftData

/// The lifecycle of a timer. Stored as a raw string so SwiftData can persist it
/// (SwiftData stores primitive types; we map the enum on top).
enum TimerState: String, Codable {
    case running     // counting down
    case snoozed     // re-armed after a snooze (still counts down)
    case completed   // finished and acknowledged ("Done")
    case cancelled   // dismissed before finishing
}

/// One timer the user created — both the live one and every past one.
///
/// `@Model` is SwiftData's macro that turns a plain class into a persisted
/// entity: each stored property becomes a column, and instances are tracked by
/// a `ModelContext`. It's the spiritual successor to Core Data's `NSManagedObject`,
/// but expressed in pure Swift.
///
/// Design note — we store an absolute `endDate`, not a "seconds remaining"
/// counter. Remaining time is always computed as `endDate - now`. That means
/// the countdown stays correct even if the app is busy, backgrounded, or a tick
/// is dropped: we never accumulate drift from counting ticks.
@Model
final class TimerTask {
    /// Stable identity (handy for diffing / the History list).
    var id: UUID
    var label: String
    var durationMinutes: Int
    /// When this timer was started.
    var createdAt: Date
    /// The absolute moment the countdown reaches zero.
    var endDate: Date
    /// Set when the user marks it Done (or it's cancelled).
    var completedAt: Date?

    /// Backing storage for `state`. SwiftData persists this `String`.
    private var stateRaw: String

    /// Typed accessor over `stateRaw`.
    var state: TimerState {
        get { TimerState(rawValue: stateRaw) ?? .completed }
        set { stateRaw = newValue.rawValue }
    }

    /// Is this the live timer (counting or snoozed)?
    var isActive: Bool { state == .running || state == .snoozed }

    init(label: String, durationMinutes: Int, startedAt: Date = .now) {
        self.id = UUID()
        self.label = label.isEmpty ? "Timer" : label
        self.durationMinutes = durationMinutes
        self.createdAt = startedAt
        self.endDate = startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
        self.completedAt = nil
        self.stateRaw = TimerState.running.rawValue
    }
}
