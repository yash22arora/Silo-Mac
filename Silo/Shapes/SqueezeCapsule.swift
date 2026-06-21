import SwiftUI

/// A capsule whose mid-section deforms while the **rounded ends stay fixed**.
///
/// The trick that makes an *outward* bulge possible without clipping: the shape
/// is drawn into a rect that's **taller than the visible capsule** by
/// `bulgeRoom` on each side. The end semicircles use a radius of
/// `rect.height/2 - bulgeRoom` (i.e. half the *visible* capsule, not half the
/// rect) and are centered vertically. So at rest the top/bottom edges sit at the
/// caps' tangents, leaving `bulgeRoom` of transparent space above and below for
/// the mid-edges to bulge into.
///
/// `squeeze` is **signed**:
///   - `> 0` → the waist pinches *inward* (concave).
///   - `0`   → a plain capsule.
///   - `< 0` → the waist bulges *outward* (convex), into the reserved room.
struct SqueezeCapsule: Shape {
    /// Signed deformation: positive pinches in, negative bulges out.
    var squeeze: CGFloat
    /// Reserved transparent space above and below the capsule for the bulge.
    var bulgeRoom: CGFloat = 12

    /// Only `squeeze` animates; `bulgeRoom` is a fixed layout constant.
    var animatableData: CGFloat {
        get { squeeze }
        set { squeeze = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let yCenter = rect.midY
        // Cap radius = half the VISIBLE capsule, independent of the padded rect.
        let r = max(1, rect.height / 2 - bulgeRoom)

        // Fallback for degenerate widths.
        guard w > 2 * r else {
            return Path(roundedRect: rect.insetBy(dx: 0, dy: bulgeRoom), cornerRadius: r)
        }

        let s = max(-1, min(1, squeeze))
        // The two directions have different limits:
        // - Inward pinch can go deep (bounded only by the radius), so the waist
        //   visibly squeezes — it isn't constrained by the bulge room.
        // - Outward bulge must stay within the reserved room so it never clips.
        let inwardMax = r * 0.5
        let outwardMax = min(bulgeRoom, r * 0.4)
        let travel = (s >= 0 ? inwardMax : outwardMax) * s   // +inward, -outward

        let leftCenter = CGPoint(x: r, y: yCenter)
        let rightCenter = CGPoint(x: w - r, y: yCenter)
        let topY = yCenter - r
        let bottomY = yCenter + r

        var p = Path()

        // Top edge: control point a quad's midpoint sits halfway to it, so a
        // control offset of `travel * 2` moves the waist by exactly `travel`.
        // travel > 0 pushes the edge down (toward center → pinch); travel < 0
        // pushes it up into the reserved room (bulge).
        p.move(to: CGPoint(x: r, y: topY))
        p.addQuadCurve(
            to: CGPoint(x: w - r, y: topY),
            control: CGPoint(x: w / 2, y: topY + travel * 2)
        )

        // Right cap (top → right → bottom).
        p.addArc(
            center: rightCenter, radius: r,
            startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false
        )

        // Bottom edge: mirror of the top.
        p.addQuadCurve(
            to: CGPoint(x: r, y: bottomY),
            control: CGPoint(x: w / 2, y: bottomY - travel * 2)
        )

        // Left cap (bottom → left → top).
        p.addArc(
            center: leftCenter, radius: r,
            startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false
        )

        p.closeSubpath()
        return p
    }
}

#Preview("Deform sweep") {
    VStack(spacing: 18) {
        ForEach([-1.0, -0.5, 0.0, 0.5, 1.0], id: \.self) { s in
            SqueezeCapsule(squeeze: s)
                .fill(.blue.opacity(0.25))
                .overlay(SqueezeCapsule(squeeze: s).stroke(.blue, lineWidth: 2))
                .frame(width: 240, height: 76) // 52 capsule + 12 room each side
        }
    }
    .padding()
}
