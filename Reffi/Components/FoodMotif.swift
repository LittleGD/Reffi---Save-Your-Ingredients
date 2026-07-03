import SwiftUI

/// 음식 모티프용 색 — 전부 OKLCH로 정의(시스템 일관). 따뜻한 파스텔, 네온 금지.
/// 음식은 "콘텐츠"라 신선도 3색 밖의 톤도 쓰되, 브랜드 팔레트의 명도·채도 규율을 따른다.
enum FoodPalette {
    static let cream   = ReffiColor.oklch(0.97, 0.014, 92)
    static let creamHi = ReffiColor.oklch(0.99, 0.008, 92)
    static let creamLo = ReffiColor.oklch(0.92, 0.020, 92)
    static let yolk    = ReffiColor.oklch(0.84, 0.150, 80)
    static let green   = ReffiColor.oklch(0.82, 0.130, 138)
    static let greenHi = ReffiColor.oklch(0.88, 0.110, 138)
    static let greenDk = ReffiColor.oklch(0.50, 0.110, 140)
    static let squash  = ReffiColor.oklch(0.78, 0.125, 142)
    static let carrot  = ReffiColor.oklch(0.74, 0.150, 52)
    static let carrotDk = ReffiColor.oklch(0.62, 0.150, 48)
    static let apple   = ReffiColor.oklch(0.66, 0.160, 26)
    static let appleHi = ReffiColor.oklch(0.80, 0.120, 28)
    static let citrus  = ReffiColor.oklch(0.88, 0.140, 96)
    static let citrusHi = ReffiColor.oklch(0.94, 0.100, 98)
    static let stem    = ReffiColor.oklch(0.46, 0.080, 120)
    static let bowl    = ReffiColor.oklch(0.90, 0.030, 250)
    static let bowlHi  = ReffiColor.oklch(0.95, 0.020, 250)
    static let steam   = ReffiColor.oklch(0.80, 0.012, 90)

    /// 레시피 카드 배경 틴트 — 글리프별 옅은 색면(신선도 의미와 섞이지 않게 옅게).
    static func heroTint(_ g: FoodGlyph) -> Color {
        switch g {
        case .squash:  ReffiColor.oklch(0.95, 0.045, 178)
        case .leaf:    ReffiColor.oklch(0.95, 0.045, 156)
        case .root:    ReffiColor.oklch(0.95, 0.050, 66)
        case .apple:   ReffiColor.oklch(0.95, 0.040, 8)
        case .egg:     ReffiColor.oklch(0.96, 0.035, 96)
        case .citrus:  ReffiColor.oklch(0.96, 0.055, 104)
        case .tofu:    ReffiColor.oklch(0.96, 0.030, 250)
        default:       ReffiColor.oklch(0.95, 0.020, 90)
        }
    }
}

/// 단일 재료 모티프 — 납작한 색면 일러스트. 카드 악센트·히어로 구성요소로 재사용.
struct FoodMotif: View {
    let glyph: FoodGlyph

    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size)
                .insetBy(dx: size.width * 0.10, dy: size.height * 0.10)
            Self.draw(glyph, in: r, ctx: &ctx)
        }
        .accessibilityHidden(true)
    }

    static func draw(_ glyph: FoodGlyph, in r: CGRect, ctx: inout GraphicsContext) {
        switch glyph {
        case .egg:     drawEgg(r, &ctx)
        case .tofu:    drawTofu(r, &ctx)
        case .leaf:    drawLeaf(r, &ctx)
        case .squash:  drawSquash(r, &ctx)
        case .root:    drawCarrot(r, &ctx)
        case .apple:   drawApple(r, &ctx)
        case .citrus:  drawCitrus(r, &ctx)
        default:       drawBowl(r, &ctx)
        }
    }

    // MARK: - Shapes

    static func leafPath(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY),
                       control: CGPoint(x: r.maxX, y: r.minY + r.height * 0.34))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY),
                       control: CGPoint(x: r.minX, y: r.minY + r.height * 0.34))
        p.closeSubpath()
        return p
    }

    static func blobPath(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.move(to: CGPoint(x: r.minX + w * 0.22, y: r.minY + h * 0.20))
        p.addCurve(to: CGPoint(x: r.maxX - w * 0.06, y: r.minY + h * 0.34),
                   control1: CGPoint(x: r.minX + w * 0.52, y: r.minY - h * 0.02),
                   control2: CGPoint(x: r.maxX - w * 0.04, y: r.minY + h * 0.04))
        p.addCurve(to: CGPoint(x: r.maxX - w * 0.20, y: r.maxY - h * 0.14),
                   control1: CGPoint(x: r.maxX + w * 0.02, y: r.minY + h * 0.64),
                   control2: CGPoint(x: r.maxX - w * 0.05, y: r.maxY - h * 0.02))
        p.addCurve(to: CGPoint(x: r.minX + w * 0.12, y: r.maxY - h * 0.20),
                   control1: CGPoint(x: r.midX, y: r.maxY + h * 0.05),
                   control2: CGPoint(x: r.minX + w * 0.22, y: r.maxY + h * 0.02))
        p.addCurve(to: CGPoint(x: r.minX + w * 0.22, y: r.minY + h * 0.20),
                   control1: CGPoint(x: r.minX - w * 0.05, y: r.maxY - h * 0.42),
                   control2: CGPoint(x: r.minX + w * 0.02, y: r.minY + h * 0.42))
        p.closeSubpath()
        return p
    }

    static func bowlPath(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY),
                       control: CGPoint(x: r.minX + r.width * 0.04, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY),
                       control: CGPoint(x: r.maxX - r.width * 0.04, y: r.maxY))
        p.closeSubpath()
        return p
    }

    // MARK: - Items

    static func drawEgg(_ r: CGRect, _ ctx: inout GraphicsContext) {
        ctx.fill(blobPath(in: r), with: .color(FoodPalette.cream))
        let d = min(r.width, r.height) * 0.44
        let yolk = CGRect(x: r.midX - d / 2 - r.width * 0.04,
                          y: r.midY - d / 2 - r.height * 0.02, width: d, height: d)
        ctx.fill(Circle().path(in: yolk), with: .color(FoodPalette.yolk))
        let hl = d * 0.26
        ctx.fill(Circle().path(in: CGRect(x: yolk.minX + hl * 0.5, y: yolk.minY + hl * 0.5,
                                          width: hl, height: hl)),
                 with: .color(FoodPalette.creamHi.opacity(0.75)))
    }

    static func drawTofu(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let b = min(r.width, r.height) * 0.5
        let lower = CGRect(x: r.midX - b * 0.58, y: r.midY - b * 0.05, width: b, height: b * 0.82)
        let upper = CGRect(x: r.midX - b * 0.16, y: r.midY - b * 0.70, width: b, height: b * 0.82)
        let rad = b * 0.16
        ctx.fill(RoundedRectangle(cornerRadius: rad).path(in: lower.offsetBy(dx: 3, dy: 4)),
                 with: .color(FoodPalette.creamLo))
        ctx.fill(RoundedRectangle(cornerRadius: rad).path(in: lower), with: .color(FoodPalette.cream))
        ctx.fill(RoundedRectangle(cornerRadius: rad).path(in: upper), with: .color(FoodPalette.creamHi))
        // 살짝 패인 윗면 그림자
        ctx.fill(RoundedRectangle(cornerRadius: rad).path(in:
            CGRect(x: upper.minX, y: upper.minY, width: upper.width, height: upper.height * 0.30)),
                 with: .color(FoodPalette.creamLo.opacity(0.35)))
    }

    static func drawLeaf(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let center = CGPoint(x: r.midX, y: r.maxY - r.height * 0.10)
        let lw = r.width * 0.36, lh = r.height * 0.74
        for (i, angle) in [-30.0, 0.0, 30.0].enumerated() {
            var c = ctx
            c.translateBy(x: center.x, y: center.y)
            c.rotate(by: .degrees(angle))
            let lr = CGRect(x: -lw / 2, y: -lh, width: lw, height: lh)
            c.fill(leafPath(in: lr), with: .color(i == 1 ? FoodPalette.green : FoodPalette.greenHi))
            var vein = Path()
            vein.move(to: CGPoint(x: 0, y: -lh * 0.06))
            vein.addLine(to: CGPoint(x: 0, y: -lh * 0.92))
            c.stroke(vein, with: .color(FoodPalette.greenDk.opacity(0.45)),
                     lineWidth: max(1, r.width * 0.012))
        }
    }

    static func drawSquash(_ r: CGRect, _ ctx: inout GraphicsContext) {
        var c = ctx
        c.translateBy(x: r.midX, y: r.midY)
        c.rotate(by: .degrees(-24))
        let w = r.width * 0.32, h = r.height * 0.78
        c.fill(Capsule().path(in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h)),
               with: .color(FoodPalette.squash))
        c.fill(Capsule().path(in: CGRect(x: -w / 2 + w * 0.20, y: -h / 2 + h * 0.10,
                                        width: w * 0.20, height: h * 0.66)),
               with: .color(FoodPalette.greenHi.opacity(0.65)))
        c.fill(RoundedRectangle(cornerRadius: w * 0.12).path(in:
            CGRect(x: -w * 0.10, y: -h / 2 - h * 0.12, width: w * 0.20, height: h * 0.16)),
               with: .color(FoodPalette.stem))
    }

    static func drawCarrot(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let topY = r.minY + r.height * 0.32
        let halfW = r.width * 0.19
        var body = Path()
        body.move(to: CGPoint(x: r.midX - halfW, y: topY))
        body.addLine(to: CGPoint(x: r.midX + halfW, y: topY))
        body.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.05),
                          control: CGPoint(x: r.midX + halfW * 0.5, y: r.maxY * 0.92))
        body.addQuadCurve(to: CGPoint(x: r.midX - halfW, y: topY),
                          control: CGPoint(x: r.midX - halfW * 0.5, y: r.maxY * 0.92))
        body.closeSubpath()
        ctx.fill(body, with: .color(FoodPalette.carrot))
        for t in [0.32, 0.56, 0.78] as [CGFloat] {
            var line = Path()
            let y = topY + (r.maxY - topY) * t
            let hw = halfW * (1 - t * 0.7)
            line.move(to: CGPoint(x: r.midX - hw, y: y))
            line.addLine(to: CGPoint(x: r.midX + hw, y: y))
            ctx.stroke(line, with: .color(FoodPalette.carrotDk.opacity(0.5)),
                       lineWidth: max(1, r.width * 0.011))
        }
        for angle in [-28.0, 0.0, 28.0] {
            var c = ctx
            c.translateBy(x: r.midX, y: topY)
            c.rotate(by: .degrees(angle))
            c.fill(leafPath(in: CGRect(x: -r.width * 0.055, y: -r.height * 0.32,
                                       width: r.width * 0.11, height: r.height * 0.32)),
                   with: .color(FoodPalette.green))
        }
    }

    static func drawApple(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let s = min(r.width, r.height) * 0.84
        let rect = CGRect(x: r.midX - s / 2, y: r.maxY - s, width: s, height: s)
        ctx.fill(Circle().path(in: rect), with: .color(FoodPalette.apple))
        ctx.fill(Ellipse().path(in: CGRect(x: rect.minX + s * 0.18, y: rect.minY + s * 0.16,
                                          width: s * 0.24, height: s * 0.18)),
                 with: .color(FoodPalette.appleHi.opacity(0.7)))
        ctx.fill(RoundedRectangle(cornerRadius: s * 0.03).path(in:
            CGRect(x: r.midX - s * 0.03, y: rect.minY - s * 0.15, width: s * 0.06, height: s * 0.20)),
                 with: .color(FoodPalette.stem))
        var c = ctx
        c.translateBy(x: r.midX + s * 0.11, y: rect.minY - s * 0.03)
        c.rotate(by: .degrees(40))
        c.fill(leafPath(in: CGRect(x: -s * 0.06, y: -s * 0.22, width: s * 0.12, height: s * 0.22)),
               with: .color(FoodPalette.green))
    }

    static func drawCitrus(_ r: CGRect, _ ctx: inout GraphicsContext) {
        var c = ctx
        c.translateBy(x: r.midX, y: r.midY)
        c.rotate(by: .degrees(-18))
        let w = r.width * 0.72, h = r.height * 0.48
        c.fill(Ellipse().path(in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h)),
               with: .color(FoodPalette.citrus))
        for dx in [-w / 2 - h * 0.02, w / 2 - h * 0.14] {
            c.fill(Capsule().path(in: CGRect(x: dx, y: -h * 0.09, width: h * 0.18, height: h * 0.18)),
                   with: .color(FoodPalette.citrusHi))
        }
        c.fill(Ellipse().path(in: CGRect(x: -w * 0.32, y: -h * 0.30,
                                        width: w * 0.30, height: h * 0.32)),
               with: .color(FoodPalette.citrusHi.opacity(0.8)))
    }

    static func drawBowl(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let bowl = CGRect(x: r.minX + r.width * 0.10, y: r.midY,
                          width: r.width * 0.80, height: r.height * 0.44)
        ctx.fill(Ellipse().path(in: CGRect(x: bowl.minX + bowl.width * 0.10,
                                          y: bowl.minY - bowl.height * 0.42,
                                          width: bowl.width * 0.80, height: bowl.height * 0.72)),
                 with: .color(FoodPalette.green))
        ctx.fill(bowlPath(in: bowl), with: .color(FoodPalette.bowl))
        ctx.fill(Ellipse().path(in: CGRect(x: bowl.minX, y: bowl.minY - bowl.height * 0.06,
                                          width: bowl.width, height: bowl.height * 0.22)),
                 with: .color(FoodPalette.bowlHi))
    }

    static func drawSteam(_ r: CGRect, _ ctx: inout GraphicsContext) {
        for i in 0..<3 {
            let x = r.minX + r.width * (0.22 + 0.28 * CGFloat(i))
            var p = Path()
            p.move(to: CGPoint(x: x, y: r.maxY))
            p.addCurve(to: CGPoint(x: x, y: r.minY),
                       control1: CGPoint(x: x + r.width * 0.18, y: r.maxY - r.height * 0.34),
                       control2: CGPoint(x: x - r.width * 0.18, y: r.minY + r.height * 0.34))
            ctx.stroke(p, with: .color(FoodPalette.steam.opacity(0.5)),
                       style: StrokeStyle(lineWidth: max(2, r.width * 0.05), lineCap: .round))
        }
    }
}

