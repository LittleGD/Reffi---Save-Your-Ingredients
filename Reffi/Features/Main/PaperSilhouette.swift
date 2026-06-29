import SwiftUI

/// 재료 일러스트(§13) — **손으로 자른 종이(Matisse cut-paper)** 풍. 자연색 **멀티컬러**(몸 + 초록 잎/줄기 + 디테일),
/// 플랫 색면, 아웃라인 없음, 옅은 종이 그림자. 색은 재료의 실제 색(신선도색 아님 — 신선도는 뱃지/라벨로).
struct PaperSilhouette: View {
    let glyph: FoodGlyph
    let fresh: Freshness   // 시그니처 유지(색엔 미사용; 신선도는 뱃지·라벨)

    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.1, dy: size.height * 0.1)
            // 배경 분리 — 실루엣 전체를 한 겹으로 합성해 **단일 외곽 그림자**를 준다.
            // 흰색 계열(달걀·버섯 기둥·우유)이 크림 배경에 묻히지 않게 가장자리에 옅은 헤일로.
            var shaded = ctx
            shaded.addFilter(.shadow(color: .black.opacity(0.20),
                                     radius: size.width * 0.04, x: 0, y: size.height * 0.015))
            shaded.drawLayer { layer in
                Self.draw(glyph, in: r, ctx: &layer)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Palette (자연색, 따뜻하고 살짝 차분한 채도)
    private enum C {
        static let dGreen  = ReffiColor.oklch(0.43, 0.11, 150)
        static let mGreen  = ReffiColor.oklch(0.55, 0.13, 148)
        static let lGreen  = ReffiColor.oklch(0.78, 0.13, 142)
        static let carrot  = ReffiColor.oklch(0.70, 0.16, 56)
        static let tomato  = ReffiColor.oklch(0.62, 0.18, 32)
        static let yellow  = ReffiColor.oklch(0.85, 0.15, 96)
        static let cream   = ReffiColor.oklch(0.95, 0.012, 90)
        static let creamLo = ReffiColor.oklch(0.90, 0.02, 80)
        static let onion   = ReffiColor.oklch(0.93, 0.022, 70)
        static let tan     = ReffiColor.oklch(0.74, 0.05, 64)
        static let tanDk   = ReffiColor.oklch(0.5, 0.055, 58)
        static let brown   = ReffiColor.oklch(0.44, 0.06, 60)
        static let purple  = ReffiColor.oklch(0.46, 0.1, 330)
        static let pink    = ReffiColor.oklch(0.72, 0.16, 350)
        static let apple   = ReffiColor.oklch(0.6, 0.17, 30)
        static let berry   = ReffiColor.oklch(0.6, 0.18, 25)
        static let meat    = ReffiColor.oklch(0.54, 0.14, 22)
        static let fat     = ReffiColor.oklch(0.91, 0.025, 48)
        static let poultry = ReffiColor.oklch(0.78, 0.07, 62)
        static let fish    = ReffiColor.oklch(0.64, 0.07, 240)
        static let fishDk  = ReffiColor.oklch(0.5, 0.08, 244)
        static let shrimp  = ReffiColor.oklch(0.72, 0.15, 38)
        static let milkLbl = ReffiColor.oklch(0.55, 0.13, 250)
        static let cheese  = ReffiColor.oklch(0.83, 0.13, 92)
        static let cheeseHl = ReffiColor.oklch(0.72, 0.12, 90)
        static let bread   = ReffiColor.oklch(0.76, 0.07, 66)
        static let crust   = ReffiColor.oklch(0.6, 0.08, 56)
        static let neutral = ReffiColor.oklch(0.8, 0.03, 80)
    }

    // MARK: Helpers
    private static func fill(_ ctx: inout GraphicsContext, _ p: Path, _ color: Color) { ctx.fill(p, with: .color(color)) }
    /// 종이 그림자(아래로 옅게).
    private static func shadow(_ ctx: inout GraphicsContext, _ p: Path, _ r: CGRect) {
        ctx.fill(p.applying(.init(translationX: 0, y: r.height * 0.02)), with: .color(.black.opacity(0.08)))
    }
    private static func rot(_ a: CGFloat, _ c: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: c.x, y: c.y).rotated(by: a).translatedBy(x: -c.x, y: -c.y)
    }
    /// 잎/칼날 한 장(끝이 뾰족).
    private static func blade(_ cx: CGFloat, _ baseY: CGFloat, _ tipY: CGFloat, _ halfW: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: cx, y: baseY))
        p.addQuadCurve(to: CGPoint(x: cx, y: tipY), control: CGPoint(x: cx + halfW, y: (baseY + tipY) / 2))
        p.addQuadCurve(to: CGPoint(x: cx, y: baseY), control: CGPoint(x: cx - halfW, y: (baseY + tipY) / 2))
        p.closeSubpath()
        return p
    }
    private static func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h))
    }
    private static func roundRect(_ rect: CGRect, _ rad: CGFloat) -> Path {
        Path(roundedRect: rect, cornerRadius: rad, style: .continuous)
    }

    // MARK: Dispatch
    static func draw(_ glyph: FoodGlyph, in r: CGRect, ctx: inout GraphicsContext) {
        switch glyph {
        case .root:     carrot(r, &ctx)
        case .tomato:   tomato(r, &ctx)
        case .pepper:   pepper(r, &ctx)
        case .squash:   zucchini(r, &ctx)
        case .leaf:     greens(r, &ctx)
        case .onion:    onion(r, &ctx)
        case .mushroom: mushroom(r, &ctx)
        case .broccoli: broccoli(r, &ctx)
        case .potato:   potato(r, &ctx)
        case .garlic:   garlic(r, &ctx)
        case .apple:    apple(r, &ctx)
        case .citrus:   lemon(r, &ctx)
        case .berry:    berry(r, &ctx)
        case .egg:      egg(r, &ctx)
        case .tofu:     tofu(r, &ctx)
        case .meat:     meat(r, &ctx)
        case .poultry:  drumstick(r, &ctx)
        case .fish:     fish(r, &ctx)
        case .shrimp:   shrimp(r, &ctx)
        case .milk:     milk(r, &ctx)
        case .cheese:   cheese(r, &ctx)
        case .bread:    bread(r, &ctx)
        case .generic:  blob(r, &ctx)
        }
    }

    // MARK: - Vegetables

    /// 당근 — 오렌지 몸 + 초록 잎 3장.
    private static func carrot(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let topY = r.minY + r.height * 0.34, hw = r.width * 0.16
        let tip = CGPoint(x: r.midX, y: r.maxY - r.height * 0.02)
        var body = Path()
        body.move(to: tip)
        body.addQuadCurve(to: CGPoint(x: r.midX + hw, y: topY), control: CGPoint(x: r.midX + hw * 1.4, y: r.maxY - r.height * 0.34))
        body.addLine(to: CGPoint(x: r.midX - hw, y: topY))
        body.addQuadCurve(to: tip, control: CGPoint(x: r.midX - hw * 1.4, y: r.maxY - r.height * 0.34))
        body.closeSubpath()
        // 잎(초록 칼날 3장)
        for a in [-0.42, 0.0, 0.42] as [CGFloat] {
            let leaf = blade(r.midX, topY + r.height * 0.04, topY - r.height * 0.26, r.width * 0.06)
                .applying(rot(a, CGPoint(x: r.midX, y: topY)))
            fill(&ctx, leaf, C.dGreen)
        }
        shadow(&ctx, body, r)
        fill(&ctx, body, C.carrot)
        // 결 한두 줄(밝은 오렌지)
        var groove = Path()
        groove.move(to: CGPoint(x: r.midX - hw * 0.3, y: topY + r.height * 0.12))
        groove.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.16), control: CGPoint(x: r.midX - hw * 0.5, y: r.midY))
        ctx.stroke(groove, with: .color(ReffiColor.oklch(0.8, 0.13, 60)), style: StrokeStyle(lineWidth: max(1.5, r.width * 0.02), lineCap: .round))
    }

    /// 토마토 — 빨강 몸 + 초록 별 꼭지.
    private static func tomato(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cy = r.midY + r.height * 0.06, w = r.width * 0.82, h = r.height * 0.74
        let body = ellipse(r.midX, cy, w, h)
        shadow(&ctx, body, r)
        fill(&ctx, body, C.tomato)
        // 초록 별 꼭지(5갈래) — 가운데 위
        let top = cy - h * 0.42
        var star = Path()
        let pts = 5
        for i in 0..<pts {
            let ang = -CGFloat.pi / 2 + CGFloat(i) / CGFloat(pts) * 2 * .pi
            let outer = CGPoint(x: r.midX + cos(ang) * w * 0.2, y: top + sin(ang) * h * 0.2)
            let ia = ang + .pi / CGFloat(pts)
            let inner = CGPoint(x: r.midX + cos(ia) * w * 0.08, y: top + sin(ia) * h * 0.08)
            if i == 0 { star.move(to: outer) } else { star.addLine(to: outer) }
            star.addLine(to: inner)
        }
        star.closeSubpath()
        fill(&ctx, star, C.mGreen)
        // 작은 줄기
        fill(&ctx, roundRect(CGRect(x: r.midX - w * 0.03, y: top - h * 0.16, width: w * 0.06, height: h * 0.16), w * 0.03), C.dGreen)
    }

    /// 파프리카 — 노랑 몸(아래 두 갈래) + 초록 꼭지.
    private static func pepper(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY + r.height * 0.06, w = r.width * 0.74, h = r.height * 0.76
        let top = cy - h / 2, bot = cy + h / 2
        var body = Path()
        body.move(to: CGPoint(x: cx, y: top))
        body.addCurve(to: CGPoint(x: cx + w / 2, y: cy), control1: CGPoint(x: cx + w * 0.42, y: top), control2: CGPoint(x: cx + w / 2, y: cy - h * 0.2))
        body.addCurve(to: CGPoint(x: cx + w * 0.16, y: bot), control1: CGPoint(x: cx + w / 2, y: bot - h * 0.06), control2: CGPoint(x: cx + w * 0.34, y: bot))
        body.addQuadCurve(to: CGPoint(x: cx - w * 0.16, y: bot), control: CGPoint(x: cx, y: bot - h * 0.18))
        body.addCurve(to: CGPoint(x: cx - w / 2, y: cy), control1: CGPoint(x: cx - w * 0.34, y: bot), control2: CGPoint(x: cx - w / 2, y: bot - h * 0.06))
        body.addCurve(to: CGPoint(x: cx, y: top), control1: CGPoint(x: cx - w / 2, y: cy - h * 0.2), control2: CGPoint(x: cx - w * 0.42, y: top))
        body.closeSubpath()
        shadow(&ctx, body, r)
        fill(&ctx, body, C.yellow)
        // 초록 꼭지
        var stem = Path()
        stem.move(to: CGPoint(x: cx - w * 0.05, y: top + h * 0.04))
        stem.addLine(to: CGPoint(x: cx - w * 0.02, y: top - h * 0.16))
        stem.addQuadCurve(to: CGPoint(x: cx + w * 0.1, y: top - h * 0.06), control: CGPoint(x: cx + w * 0.02, y: top - h * 0.18))
        stem.addLine(to: CGPoint(x: cx + w * 0.06, y: top + h * 0.05))
        stem.closeSubpath()
        fill(&ctx, stem, C.mGreen)
    }

    /// 애호박 — 초록 원기둥 + 작은 꼭지.
    private static func zucchini(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let w = r.width * 0.36, h = r.height * 0.82, cx = r.midX
        let top = r.midY - h / 2, bot = r.midY + h / 2, hw = w / 2
        let body = roundRect(CGRect(x: cx - hw, y: top + h * 0.08, width: w, height: h * 0.92), hw)
            .applying(rot(-0.3, CGPoint(x: cx, y: r.midY)))
        shadow(&ctx, body, r)
        fill(&ctx, body, ReffiColor.oklch(0.62, 0.13, 142))
        let stem = roundRect(CGRect(x: cx - w * 0.12, y: top, width: w * 0.24, height: h * 0.12), w * 0.1)
            .applying(rot(-0.3, CGPoint(x: cx, y: r.midY)))
        _ = bot
        fill(&ctx, stem, C.dGreen)
    }

    /// 잎채소 — 초록 잎 + 줄기.
    private static func greens(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let lr = r.insetBy(dx: r.width * 0.16, dy: r.height * 0.04)
        let cx = lr.midX
        let leaf = blade(cx, lr.maxY, lr.minY, lr.width * 0.62).applying(rot(0.12, CGPoint(x: cx, y: lr.midY)))
        shadow(&ctx, leaf, r)
        fill(&ctx, leaf, C.mGreen)
        // 줄기/잎맥
        var vein = Path()
        vein.move(to: CGPoint(x: cx, y: lr.minY + lr.height * 0.18))
        vein.addLine(to: CGPoint(x: cx, y: lr.maxY))
        ctx.stroke(vein.applying(rot(0.12, CGPoint(x: cx, y: lr.midY))), with: .color(C.dGreen),
                   style: StrokeStyle(lineWidth: max(2, r.width * 0.03), lineCap: .round))
    }

    /// 양파 — 크림 알뿌리 + 초록 싹.
    private static func onion(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let w = r.width * 0.7, h = r.height * 0.68, cx = r.midX, cy = r.midY + r.height * 0.1
        let top = cy - h / 2, bot = cy + h / 2
        var body = Path()
        body.move(to: CGPoint(x: cx, y: top - r.height * 0.04))
        body.addCurve(to: CGPoint(x: cx, y: bot), control1: CGPoint(x: cx + w * 0.66, y: top + h * 0.2), control2: CGPoint(x: cx + w * 0.5, y: bot))
        body.addCurve(to: CGPoint(x: cx, y: top - r.height * 0.04), control1: CGPoint(x: cx - w * 0.5, y: bot), control2: CGPoint(x: cx - w * 0.66, y: top + h * 0.2))
        body.closeSubpath()
        shadow(&ctx, body, r)
        fill(&ctx, body, C.onion)
        // 결 두 줄
        for dx in [-w * 0.16, w * 0.16] {
            var line = Path()
            line.move(to: CGPoint(x: cx + dx * 0.5, y: top + h * 0.1))
            line.addQuadCurve(to: CGPoint(x: cx + dx, y: bot - h * 0.12), control: CGPoint(x: cx + dx * 1.3, y: cy))
            ctx.stroke(line, with: .color(ReffiColor.oklch(0.82, 0.05, 60)), lineWidth: max(1, r.width * 0.012))
        }
        // 초록 싹
        for a in [-0.18, 0.12] as [CGFloat] {
            let sprout = blade(cx, top, top - r.height * 0.16, r.width * 0.03).applying(rot(a, CGPoint(x: cx, y: top)))
            fill(&ctx, sprout, C.dGreen)
        }
    }

    /// 버섯 — 탄 갓 + 점 + 크림 기둥.
    private static func mushroom(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let w = r.width * 0.8, h = r.height * 0.7, cx = r.midX, cy = r.midY
        let capBot = cy - h * 0.04, stemW = w * 0.34
        // 기둥(크림)
        let stem = roundRect(CGRect(x: cx - stemW / 2, y: capBot - h * 0.02, width: stemW, height: h * 0.5), stemW * 0.4)
        shadow(&ctx, stem, r)
        fill(&ctx, stem, C.cream)
        // 갓(탄)
        var cap = Path()
        cap.move(to: CGPoint(x: cx - w / 2, y: capBot))
        cap.addCurve(to: CGPoint(x: cx + w / 2, y: capBot), control1: CGPoint(x: cx - w * 0.46, y: cy - h * 0.72), control2: CGPoint(x: cx + w * 0.46, y: cy - h * 0.72))
        cap.closeSubpath()
        fill(&ctx, cap, C.tan)
        // 점 3개
        for (dx, dy, s) in [(-0.2, -0.34, 0.1), (0.16, -0.42, 0.08), (0.26, -0.2, 0.07)] as [(CGFloat, CGFloat, CGFloat)] {
            fill(&ctx, ellipse(cx + w * dx, cy + h * dy, w * s, w * s), C.tanDk)
        }
    }

    /// 브로콜리 — 초록 봉오리 구름 + 줄기.
    private static func broccoli(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let w = r.width * 0.82, h = r.height * 0.8, cx = r.midX, cy = r.midY
        let stalkTop = cy + h * 0.06, stalkW = w * 0.28, ft = cy - h / 2
        // 줄기(연두)
        var stalk = Path()
        stalk.move(to: CGPoint(x: cx - stalkW / 2, y: cy + h / 2))
        stalk.addLine(to: CGPoint(x: cx - stalkW * 0.7, y: stalkTop))
        stalk.addLine(to: CGPoint(x: cx + stalkW * 0.7, y: stalkTop))
        stalk.addLine(to: CGPoint(x: cx + stalkW / 2, y: cy + h / 2))
        stalk.closeSubpath()
        shadow(&ctx, stalk, r)
        fill(&ctx, stalk, ReffiColor.oklch(0.72, 0.1, 138))
        // 봉오리 구름(진초록 원 여러 개)
        let buds: [(CGFloat, CGFloat, CGFloat)] = [(-0.3, 0.04, 0.34), (0.0, -0.08, 0.4), (0.3, 0.04, 0.34), (-0.15, 0.16, 0.28), (0.15, 0.16, 0.28)]
        for (dx, dy, s) in buds {
            fill(&ctx, ellipse(cx + w * dx, ft + h * (0.18 + dy), w * s, w * s), C.dGreen)
        }
    }

    /// 감자 — 탄 타원 + 작은 눈.
    private static func potato(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let w = r.width * 0.84, h = r.height * 0.64, c = CGPoint(x: r.midX, y: r.midY)
        let body = ellipse(c.x, c.y, w, h).applying(rot(-0.14, c))
        shadow(&ctx, body, r)
        fill(&ctx, body, C.tan)
        for (dx, dy) in [(-0.18, -0.06), (0.12, 0.1), (0.24, -0.14)] as [(CGFloat, CGFloat)] {
            fill(&ctx, ellipse(c.x + w * dx, c.y + h * dy, w * 0.06, w * 0.045), C.tanDk)
        }
    }

    /// 마늘 — 크림 알뿌리 + 클로브 결.
    private static func garlic(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let w = r.width * 0.62, h = r.height * 0.72, cx = r.midX, cy = r.midY + r.height * 0.06
        let top = cy - h / 2, bot = cy + h / 2
        var body = Path()
        body.move(to: CGPoint(x: cx, y: top - r.height * 0.1))
        body.addCurve(to: CGPoint(x: cx + w / 2, y: cy + h * 0.04), control1: CGPoint(x: cx + w * 0.12, y: top + h * 0.06), control2: CGPoint(x: cx + w / 2, y: cy - h * 0.32))
        body.addQuadCurve(to: CGPoint(x: cx + w * 0.2, y: bot), control: CGPoint(x: cx + w * 0.46, y: bot))
        body.addQuadCurve(to: CGPoint(x: cx, y: bot - h * 0.02), control: CGPoint(x: cx + w * 0.1, y: bot - h * 0.04))
        body.addQuadCurve(to: CGPoint(x: cx - w * 0.2, y: bot), control: CGPoint(x: cx - w * 0.1, y: bot - h * 0.04))
        body.addQuadCurve(to: CGPoint(x: cx - w / 2, y: cy + h * 0.04), control: CGPoint(x: cx - w * 0.46, y: bot))
        body.addCurve(to: CGPoint(x: cx, y: top - r.height * 0.1), control1: CGPoint(x: cx - w / 2, y: cy - h * 0.32), control2: CGPoint(x: cx - w * 0.12, y: top + h * 0.06))
        body.closeSubpath()
        shadow(&ctx, body, r)
        fill(&ctx, body, C.cream)
        for dx in [-w * 0.2, 0, w * 0.2] {
            var line = Path()
            line.move(to: CGPoint(x: cx + dx, y: cy - h * 0.1))
            line.addLine(to: CGPoint(x: cx + dx * 1.4, y: bot - h * 0.1))
            ctx.stroke(line, with: .color(C.creamLo), lineWidth: max(1, r.width * 0.014))
        }
    }

    // MARK: - Fruit

    /// 사과 — 빨강 몸 + 갈색 줄기 + 초록 잎.
    private static func apple(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let s = min(r.width, r.height), c = CGPoint(x: r.midX, y: r.midY + s * 0.05)
        var body = Path()
        body.move(to: CGPoint(x: c.x, y: c.y + s * 0.4))
        body.addCurve(to: CGPoint(x: c.x + s * 0.45, y: c.y - s * 0.02), control1: CGPoint(x: c.x + s * 0.32, y: c.y + s * 0.44), control2: CGPoint(x: c.x + s * 0.45, y: c.y + s * 0.22))
        body.addCurve(to: CGPoint(x: c.x + s * 0.04, y: c.y - s * 0.28), control1: CGPoint(x: c.x + s * 0.45, y: c.y - s * 0.26), control2: CGPoint(x: c.x + s * 0.2, y: c.y - s * 0.24))
        body.addCurve(to: CGPoint(x: c.x - s * 0.04, y: c.y - s * 0.28), control1: CGPoint(x: c.x + s * 0.0, y: c.y - s * 0.2), control2: CGPoint(x: c.x - s * 0.0, y: c.y - s * 0.2))
        body.addCurve(to: CGPoint(x: c.x - s * 0.45, y: c.y - s * 0.02), control1: CGPoint(x: c.x - s * 0.2, y: c.y - s * 0.24), control2: CGPoint(x: c.x - s * 0.45, y: c.y - s * 0.26))
        body.addCurve(to: CGPoint(x: c.x, y: c.y + s * 0.4), control1: CGPoint(x: c.x - s * 0.45, y: c.y + s * 0.22), control2: CGPoint(x: c.x - s * 0.32, y: c.y + s * 0.44))
        body.closeSubpath()
        shadow(&ctx, body, r)
        fill(&ctx, body, C.apple)
        // 줄기 + 잎
        fill(&ctx, roundRect(CGRect(x: c.x - s * 0.02, y: c.y - s * 0.46, width: s * 0.04, height: s * 0.2), s * 0.02), C.brown)
        let leaf = blade(c.x + s * 0.12, c.y - s * 0.3, c.y - s * 0.46, s * 0.08).applying(rot(0.5, CGPoint(x: c.x + s * 0.06, y: c.y - s * 0.34)))
        fill(&ctx, leaf, C.mGreen)
    }

    /// 레몬 — 노랑 통통 타원(양끝 뾰족).
    private static func lemon(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let w = r.width * 0.82, h = r.height * 0.6, c = CGPoint(x: r.midX, y: r.midY)
        var body = Path()
        body.move(to: CGPoint(x: c.x - w / 2, y: c.y))
        body.addCurve(to: CGPoint(x: c.x + w / 2, y: c.y), control1: CGPoint(x: c.x - w * 0.28, y: c.y - h * 0.6), control2: CGPoint(x: c.x + w * 0.28, y: c.y - h * 0.6))
        body.addCurve(to: CGPoint(x: c.x - w / 2, y: c.y), control1: CGPoint(x: c.x + w * 0.28, y: c.y + h * 0.6), control2: CGPoint(x: c.x - w * 0.28, y: c.y + h * 0.6))
        body.closeSubpath()
        let p = body.applying(rot(-0.16, c))
        shadow(&ctx, p, r)
        fill(&ctx, p, C.yellow)
    }

    /// 딸기 — 빨강 몸 + 초록 꼭지 + 씨.
    private static func berry(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let w = r.width * 0.64, h = r.height * 0.74, cx = r.midX, cy = r.midY + r.height * 0.06
        let top = cy - h / 2, bot = cy + h / 2
        var body = Path()
        body.move(to: CGPoint(x: cx, y: bot))
        body.addCurve(to: CGPoint(x: cx + w / 2, y: top + h * 0.12), control1: CGPoint(x: cx + w * 0.36, y: bot - h * 0.04), control2: CGPoint(x: cx + w / 2, y: top + h * 0.46))
        body.addQuadCurve(to: CGPoint(x: cx - w / 2, y: top + h * 0.12), control: CGPoint(x: cx, y: top - h * 0.06))
        body.addCurve(to: CGPoint(x: cx, y: bot), control1: CGPoint(x: cx - w / 2, y: top + h * 0.46), control2: CGPoint(x: cx - w * 0.36, y: bot - h * 0.04))
        body.closeSubpath()
        shadow(&ctx, body, r)
        fill(&ctx, body, C.berry)
        // 꼭지 잎(3장)
        for a in [-0.5, 0.0, 0.5] as [CGFloat] {
            let leaf = blade(cx, top + h * 0.08, top - h * 0.14, w * 0.1).applying(rot(a, CGPoint(x: cx, y: top + h * 0.08)))
            fill(&ctx, leaf, C.mGreen)
        }
        // 씨
        for (dx, dy) in [(-0.16, 0.1), (0.16, 0.1), (0.0, 0.28), (-0.2, 0.34), (0.2, 0.34)] as [(CGFloat, CGFloat)] {
            fill(&ctx, ellipse(cx + w * dx, cy + h * dy, w * 0.06, w * 0.09), ReffiColor.oklch(0.92, 0.07, 95))
        }
    }

    // MARK: - Protein

    /// 계란 — 반 잘린 삶은 달걀(흰자 타원 + 가운데 노른자). 흰 면 위에서도 노른자로 식별.
    private static func egg(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let w = r.width * 0.74, h = r.height * 0.82, c = CGPoint(x: r.midX, y: r.midY)
        let white = ellipse(c.x, c.y, w, h)
        shadow(&ctx, white, r)
        fill(&ctx, white, C.cream)
        // 노른자
        let yr = w * 0.46
        fill(&ctx, ellipse(c.x, c.y, yr, yr), ReffiColor.oklch(0.82, 0.155, 82))
        // 노른자 하이라이트(살짝)
        fill(&ctx, ellipse(c.x - yr * 0.22, c.y - yr * 0.22, yr * 0.34, yr * 0.34), ReffiColor.oklch(0.90, 0.10, 92))
    }

    /// 두부 — 크림 블록 + 윗면.
    private static func tofu(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let w = r.width * 0.82, h = r.height * 0.62, cx = r.midX, cy = r.midY
        let front = CGRect(x: cx - w / 2, y: cy - h * 0.28, width: w, height: h * 0.78)
        let off = w * 0.16
        // 윗면(밝게)
        var topF = Path()
        topF.move(to: CGPoint(x: front.minX, y: front.minY))
        topF.addLine(to: CGPoint(x: front.minX + off, y: front.minY - off * 0.7))
        topF.addLine(to: CGPoint(x: front.maxX + off, y: front.minY - off * 0.7))
        topF.addLine(to: CGPoint(x: front.maxX, y: front.minY)); topF.closeSubpath()
        // 옆면(어둡게)
        var side = Path()
        side.move(to: CGPoint(x: front.maxX, y: front.minY))
        side.addLine(to: CGPoint(x: front.maxX + off, y: front.minY - off * 0.7))
        side.addLine(to: CGPoint(x: front.maxX + off, y: front.maxY - off * 0.7))
        side.addLine(to: CGPoint(x: front.maxX, y: front.maxY)); side.closeSubpath()
        let f = roundRect(front, w * 0.08)
        shadow(&ctx, f, r)
        fill(&ctx, side, C.creamLo)
        fill(&ctx, topF, ReffiColor.oklch(0.98, 0.008, 90))
        fill(&ctx, f, C.cream)
    }

    /// 소/돼지고기 — 빨강 살 + 크림 지방 가장자리.
    private static func meat(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let w = r.width * 0.88, h = r.height * 0.6, c = CGPoint(x: r.midX, y: r.midY)
        let l = c.x - w / 2, rr = c.x + w / 2, t = c.y - h / 2, b = c.y + h / 2, cr = h * 0.42
        var body = Path()
        body.move(to: CGPoint(x: l + cr, y: t))
        body.addQuadCurve(to: CGPoint(x: c.x - w * 0.04, y: t - h * 0.07), control: CGPoint(x: l + w * 0.26, y: t - h * 0.14))
        body.addQuadCurve(to: CGPoint(x: rr - cr, y: t), control: CGPoint(x: c.x + w * 0.26, y: t + h * 0.05))
        body.addQuadCurve(to: CGPoint(x: rr, y: t + cr), control: CGPoint(x: rr, y: t))
        body.addLine(to: CGPoint(x: rr, y: b - cr))
        body.addQuadCurve(to: CGPoint(x: rr - cr, y: b), control: CGPoint(x: rr, y: b))
        body.addLine(to: CGPoint(x: l + cr, y: b))
        body.addQuadCurve(to: CGPoint(x: l, y: b - cr), control: CGPoint(x: l, y: b))
        body.addLine(to: CGPoint(x: l, y: t + cr))
        body.addQuadCurve(to: CGPoint(x: l + cr, y: t), control: CGPoint(x: l, y: t))
        body.closeSubpath()
        let p = body.applying(rot(-0.06, c))
        shadow(&ctx, p, r)
        fill(&ctx, p, C.meat)
        // 지방 가장자리(윗변 크림 띠)
        var fatBand = Path()
        fatBand.move(to: CGPoint(x: l + cr, y: t))
        fatBand.addQuadCurve(to: CGPoint(x: c.x - w * 0.04, y: t - h * 0.07), control: CGPoint(x: l + w * 0.26, y: t - h * 0.14))
        fatBand.addQuadCurve(to: CGPoint(x: rr - cr, y: t), control: CGPoint(x: c.x + w * 0.26, y: t + h * 0.05))
        fatBand.addLine(to: CGPoint(x: rr - cr, y: t + h * 0.18))
        fatBand.addQuadCurve(to: CGPoint(x: l + cr, y: t + h * 0.18), control: CGPoint(x: c.x, y: t + h * 0.06))
        fatBand.closeSubpath()
        fill(&ctx, fatBand.applying(rot(-0.06, c)), C.fat)
    }

    /// 닭다리 — 탄 살 + 크림 뼈.
    private static func drumstick(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY, w = r.width * 0.56, h = r.height * 0.9
        let boneW = w * 0.12, boneTopY = cy - h * 0.46, meatTopY = cy - h * 0.06, meatR = w * 0.52, meatBotY = cy + h * 0.44
        // 살(탄)
        var m = Path()
        m.move(to: CGPoint(x: cx + boneW, y: meatTopY))
        m.addCurve(to: CGPoint(x: cx, y: meatBotY), control1: CGPoint(x: cx + meatR * 1.15, y: meatTopY + h * 0.05), control2: CGPoint(x: cx + meatR * 0.95, y: meatBotY))
        m.addCurve(to: CGPoint(x: cx - boneW, y: meatTopY), control1: CGPoint(x: cx - meatR * 0.95, y: meatBotY), control2: CGPoint(x: cx - meatR * 1.15, y: meatTopY + h * 0.05))
        m.closeSubpath()
        // 뼈(크림)
        var bone = Path()
        bone.move(to: CGPoint(x: cx - boneW * 2, y: boneTopY + h * 0.03))
        bone.addQuadCurve(to: CGPoint(x: cx - boneW * 0.5, y: boneTopY - h * 0.03), control: CGPoint(x: cx - boneW * 2, y: boneTopY - h * 0.07))
        bone.addQuadCurve(to: CGPoint(x: cx + boneW * 0.5, y: boneTopY - h * 0.03), control: CGPoint(x: cx, y: boneTopY + h * 0.02))
        bone.addQuadCurve(to: CGPoint(x: cx + boneW * 2, y: boneTopY + h * 0.03), control: CGPoint(x: cx + boneW * 2, y: boneTopY - h * 0.07))
        bone.addLine(to: CGPoint(x: cx + boneW, y: meatTopY + h * 0.04))
        bone.addLine(to: CGPoint(x: cx - boneW, y: meatTopY + h * 0.04))
        bone.closeSubpath()
        let tr = rot(0.2, CGPoint(x: cx, y: cy))
        shadow(&ctx, m.applying(tr), r)
        fill(&ctx, bone.applying(tr), C.cream)
        fill(&ctx, m.applying(tr), C.poultry)
    }

    /// 생선 — 파랑-회색 몸 + 갈라진 꼬리 + 눈.
    private static func fish(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let w = r.width * 0.94, h = r.height * 0.54, c = CGPoint(x: r.midX, y: r.midY), bodyRight = c.x + w * 0.26
        var body = Path()
        body.move(to: CGPoint(x: c.x - w / 2, y: c.y))
        body.addCurve(to: CGPoint(x: bodyRight, y: c.y - h / 2), control1: CGPoint(x: c.x - w * 0.3, y: c.y - h / 2), control2: CGPoint(x: c.x + w * 0.1, y: c.y - h / 2))
        body.addLine(to: CGPoint(x: c.x + w / 2, y: c.y - h * 0.5))
        body.addLine(to: CGPoint(x: bodyRight + w * 0.05, y: c.y))
        body.addLine(to: CGPoint(x: c.x + w / 2, y: c.y + h * 0.5))
        body.addLine(to: CGPoint(x: bodyRight, y: c.y + h / 2))
        body.addCurve(to: CGPoint(x: c.x - w / 2, y: c.y), control1: CGPoint(x: c.x + w * 0.1, y: c.y + h / 2), control2: CGPoint(x: c.x - w * 0.3, y: c.y + h / 2))
        body.closeSubpath()
        shadow(&ctx, body, r)
        fill(&ctx, body, C.fish)
        // 꼬리 음영
        var tail = Path()
        tail.move(to: CGPoint(x: bodyRight + w * 0.02, y: c.y))
        tail.addLine(to: CGPoint(x: c.x + w / 2, y: c.y - h * 0.5))
        tail.addLine(to: CGPoint(x: bodyRight + w * 0.05, y: c.y))
        tail.addLine(to: CGPoint(x: c.x + w / 2, y: c.y + h * 0.5))
        tail.closeSubpath()
        fill(&ctx, tail, C.fishDk)
        // 눈
        fill(&ctx, ellipse(c.x - w * 0.32, c.y - h * 0.08, w * 0.07, w * 0.07), .white)
        fill(&ctx, ellipse(c.x - w * 0.32, c.y - h * 0.08, w * 0.035, w * 0.035), ReffiColor.ink)
    }

    /// 새우 — 코랄 몸(분절) + 꼬리 부채.
    private static func shrimp(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let c = CGPoint(x: r.midX, y: r.midY), R = min(r.width, r.height) * 0.42
        var p = Path()
        p.move(to: CGPoint(x: c.x - R * 0.1, y: c.y - R * 0.95))
        p.addQuadCurve(to: CGPoint(x: c.x + R * 0.5, y: c.y + R * 0.55), control: CGPoint(x: c.x + R * 1.05, y: c.y - R * 0.5))
        p.addQuadCurve(to: CGPoint(x: c.x - R * 0.45, y: c.y + R * 0.7), control: CGPoint(x: c.x + R * 0.1, y: c.y + R * 0.98))
        p.addLine(to: CGPoint(x: c.x - R * 0.78, y: c.y + R * 1.0))
        p.addLine(to: CGPoint(x: c.x - R * 0.5, y: c.y + R * 0.5))
        p.addCurve(to: CGPoint(x: c.x - R * 0.1, y: c.y - R * 0.95), control1: CGPoint(x: c.x + R * 0.45, y: c.y + R * 0.08), control2: CGPoint(x: c.x + R * 0.32, y: c.y - R * 0.62))
        p.closeSubpath()
        shadow(&ctx, p, r)
        fill(&ctx, p, C.shrimp)
        // 분절 줄
        for t in [0.3, 0.5, 0.7] as [CGFloat] {
            var seg = Path()
            let a = CGPoint(x: c.x + R * (0.7 - t), y: c.y - R * 0.7 + R * 1.4 * t)
            seg.move(to: a)
            seg.addLine(to: CGPoint(x: a.x + R * 0.3, y: a.y + R * 0.12))
            ctx.stroke(seg, with: .color(ReffiColor.oklch(0.6, 0.16, 35)), lineWidth: max(1, r.width * 0.014))
        }
    }

    // MARK: - Dairy / other

    /// 우유 — 흰 박공 카톤 + 라벨 띠.
    private static func milk(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let w = r.width * 0.56, h = r.height * 0.86, cx = r.midX, top = r.midY - h / 2, bot = r.midY + h / 2, bodyTop = top + h * 0.28
        var p = Path()
        p.move(to: CGPoint(x: cx - w / 2, y: bot)); p.addLine(to: CGPoint(x: cx - w / 2, y: bodyTop))
        p.addLine(to: CGPoint(x: cx - w * 0.16, y: top)); p.addLine(to: CGPoint(x: cx + w * 0.16, y: top))
        p.addLine(to: CGPoint(x: cx + w / 2, y: bodyTop)); p.addLine(to: CGPoint(x: cx + w / 2, y: bot)); p.closeSubpath()
        shadow(&ctx, p, r)
        fill(&ctx, p, ReffiColor.oklch(0.97, 0.006, 90))
        // 라벨 띠
        fill(&ctx, Path(CGRect(x: cx - w / 2, y: bodyTop + h * 0.16, width: w, height: h * 0.18)), C.milkLbl)
    }

    /// 치즈 — 노랑 쐐기 + 구멍.
    private static func cheese(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let w = r.width * 0.86, h = r.height * 0.62, cx = r.midX, cy = r.midY + r.height * 0.04
        var wedge = Path()
        wedge.move(to: CGPoint(x: cx - w / 2, y: cy - h / 2))
        wedge.addLine(to: CGPoint(x: cx + w / 2, y: cy + h * 0.12))
        wedge.addLine(to: CGPoint(x: cx - w / 2, y: cy + h / 2))
        wedge.closeSubpath()
        let rr = wedge // (rounded enough by scale)
        shadow(&ctx, rr, r)
        fill(&ctx, rr, C.cheese)
        for (dx, dy, s) in [(-0.26, 0.0, 0.1), (-0.04, 0.16, 0.08), (-0.12, -0.18, 0.06)] as [(CGFloat, CGFloat, CGFloat)] {
            fill(&ctx, ellipse(cx + w * dx, cy + h * dy, w * s, w * s), C.cheeseHl)
        }
    }

    /// 빵 — 탄 식빵 + 진한 윗 크러스트.
    private static func bread(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let w = r.width * 0.78, h = r.height * 0.72, cx = r.midX, cy = r.midY + r.height * 0.04
        let bot = cy + h / 2, sideTop = cy - h * 0.08, rr = w * 0.12
        var p = Path()
        p.move(to: CGPoint(x: cx - w / 2, y: bot - rr))
        p.addQuadCurve(to: CGPoint(x: cx - w / 2 + rr, y: bot), control: CGPoint(x: cx - w / 2, y: bot))
        p.addLine(to: CGPoint(x: cx + w / 2 - rr, y: bot))
        p.addQuadCurve(to: CGPoint(x: cx + w / 2, y: bot - rr), control: CGPoint(x: cx + w / 2, y: bot))
        p.addLine(to: CGPoint(x: cx + w / 2, y: sideTop))
        p.addCurve(to: CGPoint(x: cx - w / 2, y: sideTop), control1: CGPoint(x: cx + w * 0.36, y: cy - h / 2 - h * 0.08), control2: CGPoint(x: cx - w * 0.36, y: cy - h / 2 - h * 0.08))
        p.closeSubpath()
        shadow(&ctx, p, r)
        fill(&ctx, p, C.bread)
        // 윗 크러스트(진한 띠)
        var crust = Path()
        crust.move(to: CGPoint(x: cx - w / 2, y: sideTop))
        crust.addCurve(to: CGPoint(x: cx + w / 2, y: sideTop), control1: CGPoint(x: cx - w * 0.36, y: cy - h / 2 - h * 0.08), control2: CGPoint(x: cx + w * 0.36, y: cy - h / 2 - h * 0.08))
        crust.addLine(to: CGPoint(x: cx + w / 2, y: sideTop + h * 0.16))
        crust.addCurve(to: CGPoint(x: cx - w / 2, y: sideTop + h * 0.16), control1: CGPoint(x: cx + w * 0.36, y: sideTop + h * 0.04), control2: CGPoint(x: cx - w * 0.36, y: sideTop + h * 0.04))
        crust.closeSubpath()
        fill(&ctx, crust, C.crust)
    }

    /// 일반 — 뉴트럴 블롭.
    private static func blob(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let body = ellipse(r.midX, r.midY, r.width * 0.84, r.height * 0.8)
        shadow(&ctx, body, r)
        fill(&ctx, body, C.neutral)
    }
}
