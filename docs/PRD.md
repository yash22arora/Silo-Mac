# Silo — Product Requirements Document (PRD)

**Status:** Approved for v1
**Date:** 2026-06-21
**Owner:** Yash Arora
**Platform:** macOS 26 (Tahoe), native, Liquid Glass

---

## 1. Summary

Silo is a native macOS menu-bar timer built around Apple's Liquid Glass design
language. It lets a user spawn a single, focused countdown timer from the menu
bar through a playful, fluid "glass bubble" interaction, and keeps a history of
completed and ongoing tasks in a dedicated window.

The product's differentiator is **interaction feel**: glass morphing, a custom
"squeeze" drag animation, and a calm completion banner — not feature breadth.

## 2. Goals

- Start a labelled timer in under 5 seconds from the menu bar.
- Make the core interaction feel delightful via Liquid Glass + custom animation.
- Persist a clear history of what the user worked on.
- Serve as a deep, hands-on first-macOS-app learning project for the author.

## 3. Non-Goals (v1)

- No multiple concurrent timers (exactly **one active timer** at a time).
- No full-screen takeover overlay (a **gentle banner** instead).
- No sync, accounts, sharing, or cloud.
- No iOS/iPad companion.
- No notifications scheduling beyond a single safety-net local notification.

## 4. Personas

- **The Focused Maker** (primary): wants a frictionless, beautiful way to time a
  single task ("Write the report — 30 min") without app-switching.

## 5. User Stories & Acceptance Criteria

### US-1 — Menu bar presence
- **As a** user, **I want** a Silo icon in the menu bar **so that** the timer is
  always one click away.
- **Accept:** Icon visible after launch; clicking it toggles the floating panel;
  icon reflects whether a timer is running.

### US-2 — Spawn the create bubble
- **As a** user, **I click "+"** and a timer-creation bubble emerges, pushing the
  "+" to the left with a smooth Liquid Glass morph.
- **Accept:** Tapping "+" animates the "+" leftward and morphs a new glass bubble
  into existence; reversible.

### US-3 — Configure the timer
- The create bubble shows a **default 30-minute** value and a **text field** for a
  label. A **drag handle** at the right increases the duration as it's pulled
  right; pulling also **squeezes the bubble from the center while the ends stay
  bulged**, springing back on release.
- **Accept:** Drag right increases minutes (clamped to a sane min/max); the
  squeeze shape animates with the drag and releases smoothly; label is editable.

### US-4 — Start the timer
- Pressing **Enter** starts the countdown.
- **Accept:** Timer transitions to a running state; only one timer can run; the
  menu bar reflects the running state.

### US-5 — Completion banner
- When the timer ends, a **gentle glass banner** appears near the menu bar showing
  the label, with **"Snooze 5 min"** and **"Mark as done"** actions.
- **Accept:** Banner appears reliably even if focus changed (local-notification
  safety net); Snooze re-arms +5 min; Done records completion.

### US-6 — History window
- Opening the app's main window shows **ongoing tasks at the top** and a list of
  **past completed tasks** below.
- **Accept:** List is persisted across launches; ordering is ongoing-first then
  completed by most-recent.

## 6. UX Principles

- **Calm, not noisy.** Motion is smooth and purposeful; the completion is a nudge,
  not an alarm takeover.
- **One thing at a time.** A single active timer keeps the user (and the app)
  focused.
- **Glass everywhere.** All floating surfaces use Liquid Glass consistently.

## 7. Success Metrics (qualitative for v1)

- Time-to-start a timer < 5s.
- The author can explain every subsystem they built (learning goal).

## 8. Open Questions / Future

- Optional full-screen "focus" completion mode.
- Multiple/queued timers.
- Menu-bar live countdown text.
