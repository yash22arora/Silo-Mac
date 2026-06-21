import SwiftUI

/// A capsule whose **middle pinches inward while the two ends stay bulged** —
/// the "squeeze" you feel when pulling the drag handle.
///
/// This is the increment where you learn how SwiftUI animates *custom geometry*.
/// A `Shape` is just a function `(CGRect) -> Path`. To make that path
/// *animatable*, we expose the one value that changes — `squeeze` — through
/// `animatableData`. When SwiftUI interpolates between two states, it drives
/// `animatableData` frame by frame, calling `path(in:)` each time, so the curve
/// morphs smoothly instead of jumping.
///
/// `squeeze`:
///   - `0` → a plain capsule (rest state)
///   - `1` → maximum pinch (mid-section sucked in, ends still round)
struct SqueezeCapsule: Shape {
    /// 0 = capsule, 1 = maximum pinch.
    var squeeze: CGFloat

    /// The hook SwiftUI uses to animate this shape. By routing it to `squeeze`,
    /// any animated change to `squeeze` is interpolated for us.
    var animatableData: CGFloat {
        get { squeeze }
        set { squeeze = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let h = rect.height
        let w = rect.width
        let r = h / 2                       // end radius (full bulge)

        // How far the middle can collapse inward at squeeze == 1. Capped so the
        // waist never fully closes.
        let maxPinch = r * 0.40
        let pinch = maxPinch * max(0, min(1, squeeze))

        // Guard against degenerate sizes (very narrow bubbles).
        guard w > h else { return Path(roundedRect: rect, cornerRadius: r) }

        let leftCenter = CGPoint(x: r, y: r)
        let rightCenter = CGPoint(x: w - r, y: r)

        var p = Path()

        // Top edge: start at the top of the left bulge, curve DOWN toward the
        // center (y grows downward), ending at the top of the right bulge.
        // A quadratic curve's midpoint sits halfway to its control point, so a
        // control y of `pinch * 2` makes the waist dip exactly `pinch`.
        p.move(to: CGPoint(x: r, y: 0))
        p.addQuadCurve(
            to: CGPoint(x: w - r, y: 0),
            control: CGPoint(x: w / 2, y: pinch * 2)
        )

        // Right bulge: top → right → bottom (passes through the outer edge).
        p.addArc(
            center: rightCenter,
            radius: r,
            startAngle: .degrees(-90),
            endAngle: .degrees(90),
            clockwise: false
        )

        // Bottom edge: curve UP toward the center, mirroring the top.
        p.addQuadCurve(
            to: CGPoint(x: r, y: h),
            control: CGPoint(x: w / 2, y: h - pinch * 2)
        )

        // Left bulge: bottom → left → top, closing the shape.
        p.addArc(
            center: leftCenter,
            radius: r,
            startAngle: .degrees(90),
            endAngle: .degrees(270),
            clockwise: false
        )

        p.closeSubpath()
        return p
    }
}

#Preview("Squeeze sweep") {
    VStack(spacing: 16) {
        ForEach([0.0, 0.5, 1.0], id: \.self) { s in
            SqueezeCapsule(squeeze: s)
                .fill(.blue.opacity(0.25))
                .overlay(SqueezeCapsule(squeeze: s).stroke(.blue, lineWidth: 2))
                .frame(width: 240, height: 56)
        }
    }
    .padding()
}
