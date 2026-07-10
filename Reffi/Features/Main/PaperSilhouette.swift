import SwiftUI

/// 재료 일러스트(§13.3) — **각진 면분할 컷페이퍼**(faceted cut-paper) 풍. 곡선 대신 5~9각 직선 면,
/// 몸통 2~3톤 면분할, 아웃라인 없음, 잘라 붙인 종이 조각 디테일, 장난기 있는 오프컬러 액센트
/// (양파 뿌리 보라 등). 색은 재료의 실제 색(신선도색 아님 — 신선도는 뱃지·라벨).
struct PaperSilhouette: View {
    let glyph: FoodGlyph
    let fresh: Freshness   // 시그니처 유지(색엔 미사용; 신선도는 뱃지·라벨)
    /// false면 외곽 그림자 필터를 끈다 — 물리 바디용 텍스처는 알파 임계로 모양을 뜨므로
    /// 그림자가 실제 글리프보다 큰 충돌체를 만든다(재료 사이 빈틈). 표시용은 기본값 그대로.
    var shadowed: Bool = true

    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.1, dy: size.height * 0.1)
            // 배경 분리 — 실루엣 전체를 한 겹으로 합성해 **단일 외곽 그림자**를 준다.
            // 흰색 계열(달걀·버섯 기둥·우유)이 크림 배경에 묻히지 않게 가장자리에 옅은 헤일로.
            var shaded = ctx
            if shadowed {
                shaded.addFilter(.shadow(color: .black.opacity(0.20),
                                         radius: size.width * 0.04, x: 0, y: size.height * 0.015))
            }
            shaded.drawLayer { layer in
                Self.draw(glyph, in: r, ctx: &layer)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Palette (자연색 · 각 몸통마다 base/shade/highlight 3톤으로 면분할)
    private enum C {
        // 초록 계열(잎·줄기·봉오리)
        static let dGreen  = ReffiColor.oklch(0.43, 0.11, 150)
        static let mGreen  = ReffiColor.oklch(0.55, 0.13, 148)
        static let lGreen  = ReffiColor.oklch(0.78, 0.13, 142)
        static let leafHi  = ReffiColor.oklch(0.70, 0.13, 145)
        // 당근·오렌지
        static let carrot  = ReffiColor.oklch(0.70, 0.16, 56)
        static let carrotSh = ReffiColor.oklch(0.60, 0.15, 52)
        static let carrotHi = ReffiColor.oklch(0.79, 0.14, 64)
        // 토마토·빨강
        static let tomato  = ReffiColor.oklch(0.62, 0.18, 32)
        static let tomatoSh = ReffiColor.oklch(0.53, 0.17, 30)
        static let tomatoHi = ReffiColor.oklch(0.71, 0.15, 40)
        // 노랑(레몬·파프리카·옥수수)
        static let yellow  = ReffiColor.oklch(0.85, 0.15, 96)
        static let yellowSh = ReffiColor.oklch(0.77, 0.15, 92)
        static let yellowHi = ReffiColor.oklch(0.91, 0.11, 100)
        // 크림·베이지·갈색
        static let cream   = ReffiColor.oklch(0.95, 0.012, 90)
        static let creamLo = ReffiColor.oklch(0.90, 0.02, 80)
        static let creamHi = ReffiColor.oklch(0.98, 0.008, 90)
        static let onion   = ReffiColor.oklch(0.93, 0.022, 70)
        static let onionSh = ReffiColor.oklch(0.85, 0.03, 66)
        static let tan     = ReffiColor.oklch(0.74, 0.05, 64)
        static let tanSh   = ReffiColor.oklch(0.64, 0.055, 60)
        static let tanDk   = ReffiColor.oklch(0.5, 0.055, 58)
        static let brown   = ReffiColor.oklch(0.44, 0.06, 60)
        // 오프컬러 액센트
        static let purple  = ReffiColor.oklch(0.46, 0.10, 330)
        static let pink    = ReffiColor.oklch(0.72, 0.16, 350)
        // 과일
        static let apple   = ReffiColor.oklch(0.60, 0.17, 30)
        static let appleSh = ReffiColor.oklch(0.51, 0.16, 28)
        static let appleHi = ReffiColor.oklch(0.70, 0.15, 36)
        static let berry   = ReffiColor.oklch(0.60, 0.18, 25)
        static let berrySh = ReffiColor.oklch(0.51, 0.17, 24)
        // 단백질
        static let meat    = ReffiColor.oklch(0.54, 0.14, 22)
        static let meatSh  = ReffiColor.oklch(0.46, 0.13, 20)
        static let fat     = ReffiColor.oklch(0.91, 0.025, 48)
        static let poultry = ReffiColor.oklch(0.78, 0.07, 62)
        static let poultrySh = ReffiColor.oklch(0.68, 0.08, 58)
        static let fish    = ReffiColor.oklch(0.64, 0.07, 240)
        static let fishDk  = ReffiColor.oklch(0.5, 0.08, 244)
        static let fishHi  = ReffiColor.oklch(0.74, 0.06, 238)
        static let shrimp  = ReffiColor.oklch(0.72, 0.15, 38)
        static let shrimpSh = ReffiColor.oklch(0.63, 0.15, 36)
        // 유제품
        static let milkLbl = ReffiColor.oklch(0.55, 0.13, 250)
        static let cheese  = ReffiColor.oklch(0.83, 0.13, 92)
        static let cheeseHl = ReffiColor.oklch(0.72, 0.12, 90)
        // 빵
        static let bread   = ReffiColor.oklch(0.76, 0.07, 66)
        static let breadSh = ReffiColor.oklch(0.68, 0.07, 62)
        static let crust   = ReffiColor.oklch(0.6, 0.08, 56)
        static let neutral = ReffiColor.oklch(0.8, 0.03, 80)
        static let neutralSh = ReffiColor.oklch(0.72, 0.03, 80)
        // 신규 12종 전용
        static let flesh   = ReffiColor.oklch(0.90, 0.05, 138)   // 오이 단면 속살
        static let avoFlesh = ReffiColor.oklch(0.86, 0.10, 110)  // 아보카도 과육(황록)
        static let avoRim  = ReffiColor.oklch(0.74, 0.12, 128)   // 과육 테두리 초록
        static let avoSkin = ReffiColor.oklch(0.36, 0.07, 148)   // 아보카도 껍질(짙은 녹)
        static let pit     = ReffiColor.oklch(0.50, 0.075, 58)   // 씨(밤색)
        static let banana  = ReffiColor.oklch(0.84, 0.15, 92)
        static let bananaSh = ReffiColor.oklch(0.75, 0.14, 88)
        static let bananaTip = ReffiColor.oklch(0.42, 0.06, 64)
        static let bowlB   = ReffiColor.oklch(0.72, 0.06, 246)   // 국수 그릇(도기 블루)
        static let bowlBHi = ReffiColor.oklch(0.81, 0.05, 248)
        static let bowlW   = ReffiColor.oklch(0.72, 0.045, 60)   // 밥그릇(나무결)
        static let bowlWHi = ReffiColor.oklch(0.80, 0.04, 62)
        static let noodle  = ReffiColor.oklch(0.86, 0.10, 86)    // 면 가닥(밀색)
        static let noodleSh = ReffiColor.oklch(0.78, 0.11, 84)
        static let rice    = ReffiColor.oklch(0.965, 0.006, 96)  // 흰 밥
        static let riceSh  = ReffiColor.oklch(0.90, 0.01, 90)
        static let bottle  = ReffiColor.oklch(0.40, 0.055, 44)   // 소스병(간장/굴소스 갈색)
        static let bottleHi = ReffiColor.oklch(0.50, 0.06, 46)
        static let cap     = ReffiColor.oklch(0.55, 0.14, 30)    // 병뚜껑(레드 액센트)
        static let metal   = ReffiColor.oklch(0.82, 0.008, 250)  // 캔 금속
        static let metalSh = ReffiColor.oklch(0.70, 0.012, 250)
        static let metalHi = ReffiColor.oklch(0.91, 0.006, 250)
        static let canBand = ReffiColor.oklch(0.58, 0.16, 28)    // 캔 라벨 띠(레드)
        static let cabbage = ReffiColor.oklch(0.87, 0.07, 138)   // 양배추 연녹
        static let cabbageDk = ReffiColor.oklch(0.66, 0.10, 140)
        static let cabbageVein = ReffiColor.oklch(0.94, 0.04, 130)
        static let chili   = ReffiColor.oklch(0.55, 0.19, 32)
        static let chiliSh = ReffiColor.oklch(0.46, 0.17, 30)
        static let pumpkin = ReffiColor.oklch(0.66, 0.15, 62)
        static let pumpkinSh = ReffiColor.oklch(0.56, 0.14, 58)
        static let pea     = ReffiColor.oklch(0.60, 0.14, 142)   // 완두 꼬투리
        static let peaBean = ReffiColor.oklch(0.80, 0.13, 138)   // 콩알
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

    /// 닫힌 다각형(직선 면).
    private static func poly(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard let f = pts.first else { return p }
        p.move(to: f)
        for pt in pts.dropFirst() { p.addLine(to: pt) }
        p.closeSubpath()
        return p
    }

    /// 각진 N각형(타원 근사) — 곡선 대신 직선 면으로 종이 컷 느낌. phase로 첫 정점 각도 조절.
    private static func facet(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat,
                              _ sides: Int, phase: CGFloat = -.pi / 2) -> Path {
        var pts: [CGPoint] = []
        for i in 0..<sides {
            let a = phase + CGFloat(i) / CGFloat(sides) * 2 * .pi
            pts.append(CGPoint(x: cx + cos(a) * w / 2, y: cy + sin(a) * h / 2))
        }
        return poly(pts)
    }

    /// 각진 잎/칼날 한 장(base→tip, 가운데가 가장 넓은 다이아 블레이드) — 어느 각도든 동작.
    private static func angularLeaf(_ base: CGPoint, _ tip: CGPoint, _ halfW: CGFloat) -> Path {
        let mid = CGPoint(x: (base.x + tip.x) / 2, y: (base.y + tip.y) / 2)
        let dx = tip.y - base.y, dy = -(tip.x - base.x)     // 진행방향의 수직
        let len = max(hypot(dx, dy), 0.0001)
        let nx = dx / len * halfW, ny = dy / len * halfW
        return poly([base,
                     CGPoint(x: mid.x + nx, y: mid.y + ny),
                     tip,
                     CGPoint(x: mid.x - nx, y: mid.y - ny)])
    }

    /// 몸통 면분할(2~3톤) — body로 클립하고 우하 어두운 면 + 좌상 밝은 면을 얹는다.
    /// 대각선 직선 경계라 "잘라 붙인 면" 느낌이 난다.
    private static func shadeBody(_ ctx: inout GraphicsContext, _ body: Path,
                                  dark: Color, light: Color? = nil, split: CGFloat = 0.42) {
        let b = body.boundingRect
        guard b.width > 0, b.height > 0 else { return }
        var c = ctx
        c.clip(to: body)
        let d = poly([CGPoint(x: b.minX - 2, y: b.maxY + 2),
                      CGPoint(x: b.maxX + 2, y: b.minY + b.height * split),
                      CGPoint(x: b.maxX + 2, y: b.maxY + 2)])
        c.fill(d, with: .color(dark))
        if let light {
            let l = poly([CGPoint(x: b.minX - 2, y: b.minY - 2),
                          CGPoint(x: b.minX + b.width * 0.6, y: b.minY - 2),
                          CGPoint(x: b.minX - 2, y: b.minY + b.height * 0.64)])
            c.fill(l, with: .color(light))
        }
    }

    private static func roundRect(_ rect: CGRect, _ rad: CGFloat) -> Path {
        Path(roundedRect: rect, cornerRadius: rad, style: .continuous)
    }

    // MARK: Dispatch
    static func draw(_ glyph: FoodGlyph, in r: CGRect, ctx: inout GraphicsContext) {
        switch glyph {
        // 채소
        case .root:      carrot(r, &ctx)
        case .tomato:    tomato(r, &ctx)
        case .pepper:    pepper(r, &ctx)
        case .squash:    zucchini(r, &ctx)
        case .leaf:      greens(r, &ctx)
        case .onion:     onion(r, &ctx)
        case .mushroom:  mushroom(r, &ctx)
        case .broccoli:  broccoli(r, &ctx)
        case .potato:    potato(r, &ctx)
        case .garlic:    garlic(r, &ctx)
        case .cucumber:  cucumber(r, &ctx)
        case .pea:       pea(r, &ctx)
        case .cabbage:   cabbage(r, &ctx)
        case .chili:     chili(r, &ctx)
        case .pumpkin:   pumpkin(r, &ctx)
        case .corn:      corn(r, &ctx)
        // 과일
        case .apple:     apple(r, &ctx)
        case .citrus:    lemon(r, &ctx)
        case .berry:     berry(r, &ctx)
        case .avocado:   avocado(r, &ctx)
        case .banana:    banana(r, &ctx)
        // 단백질
        case .egg:       egg(r, &ctx)
        case .tofu:      tofu(r, &ctx)
        case .meat:      meat(r, &ctx)
        case .poultry:   drumstick(r, &ctx)
        case .fish:      fish(r, &ctx)
        case .shrimp:    shrimp(r, &ctx)
        // 유제품·곡류·저장식품
        case .milk:      milk(r, &ctx)
        case .cheese:    cheese(r, &ctx)
        case .bread:     bread(r, &ctx)
        case .rice:      rice(r, &ctx)
        case .noodles:   noodles(r, &ctx)
        case .sauceBottle: sauceBottle(r, &ctx)
        case .can:       can(r, &ctx)
        case .generic:   blob(r, &ctx)
        }
    }

    // MARK: - Vegetables

    /// 당근 — 각진 오렌지 원뿔 + 초록 잎 프린지.
    private static func carrot(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, topY = r.minY + r.height * 0.36, hw = r.width * 0.19, bot = r.maxY - r.height * 0.02
        let body = poly([
            CGPoint(x: cx - hw, y: topY),
            CGPoint(x: cx + hw, y: topY),
            CGPoint(x: cx + hw * 0.62, y: topY + r.height * 0.28),
            CGPoint(x: cx + hw * 0.22, y: bot),
            CGPoint(x: cx - hw * 0.5, y: topY + r.height * 0.40),
        ])
        // 잎 3장(각진)
        let leafBase = CGPoint(x: cx, y: topY + r.height * 0.02)
        for (dx, len, col) in [(-0.16, 0.26, C.dGreen), (0.0, 0.32, C.mGreen), (0.16, 0.26, C.dGreen)] as [(CGFloat, CGFloat, Color)] {
            let leaf = angularLeaf(leafBase, CGPoint(x: cx + r.width * dx, y: topY - r.height * len), r.width * 0.075)
            fill(&ctx, leaf, col)
        }
        shadow(&ctx, body, r)
        fill(&ctx, body, C.carrot)
        shadeBody(&ctx, body, dark: C.carrotSh, light: C.carrotHi, split: 0.30)
        // 결 한 줄(각진 밝은 면)
        var c = ctx; c.clip(to: body)
        let groove = poly([CGPoint(x: cx - hw * 0.28, y: topY + r.height * 0.12),
                           CGPoint(x: cx - hw * 0.06, y: topY + r.height * 0.12),
                           CGPoint(x: cx + hw * 0.02, y: bot - r.height * 0.06),
                           CGPoint(x: cx - hw * 0.12, y: bot - r.height * 0.06)])
        c.fill(groove, with: .color(C.carrotHi.opacity(0.85)))
    }

    /// 토마토 — 각진(8각) 빨강 몸 + 초록 별 꼭지 + 줄기.
    private static func tomato(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cy = r.midY + r.height * 0.06, w = r.width * 0.84, h = r.height * 0.76
        let body = facet(r.midX, cy, w, h, 8, phase: -.pi / 2 + .pi / 8)
        shadow(&ctx, body, r)
        fill(&ctx, body, C.tomato)
        shadeBody(&ctx, body, dark: C.tomatoSh, light: C.tomatoHi, split: 0.40)
        // 초록 별 꼭지(5갈래 각진)
        let top = cy - h * 0.44
        var star = Path()
        let pts = 5
        for i in 0..<pts {
            let ang = -CGFloat.pi / 2 + CGFloat(i) / CGFloat(pts) * 2 * .pi
            let outer = CGPoint(x: r.midX + cos(ang) * w * 0.22, y: top + sin(ang) * h * 0.20)
            let ia = ang + .pi / CGFloat(pts)
            let inner = CGPoint(x: r.midX + cos(ia) * w * 0.08, y: top + sin(ia) * h * 0.08)
            if i == 0 { star.move(to: outer) } else { star.addLine(to: outer) }
            star.addLine(to: inner)
        }
        star.closeSubpath()
        fill(&ctx, star, C.mGreen)
        fill(&ctx, poly([CGPoint(x: r.midX - w * 0.04, y: top - h * 0.02),
                         CGPoint(x: r.midX + w * 0.04, y: top - h * 0.02),
                         CGPoint(x: r.midX + w * 0.015, y: top - h * 0.18),
                         CGPoint(x: r.midX - w * 0.02, y: top - h * 0.18)]), C.dGreen)
    }

    /// 파프리카 — 각진 노랑 몸(하부 두 로브) + 올리브 꼭지.
    private static func pepper(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY + r.height * 0.06, w = r.width * 0.76, h = r.height * 0.78
        let top = cy - h / 2, bot = cy + h / 2
        let body = poly([
            CGPoint(x: cx - w * 0.10, y: top),
            CGPoint(x: cx + w * 0.16, y: top + h * 0.04),
            CGPoint(x: cx + w * 0.5, y: cy - h * 0.14),
            CGPoint(x: cx + w * 0.42, y: bot - h * 0.10),
            CGPoint(x: cx + w * 0.14, y: bot),
            CGPoint(x: cx, y: bot - h * 0.12),
            CGPoint(x: cx - w * 0.16, y: bot),
            CGPoint(x: cx - w * 0.42, y: bot - h * 0.12),
            CGPoint(x: cx - w * 0.5, y: cy - h * 0.14),
        ])
        shadow(&ctx, body, r)
        fill(&ctx, body, C.yellow)
        shadeBody(&ctx, body, dark: C.yellowSh, light: C.yellowHi, split: 0.42)
        // 올리브 꼭지
        fill(&ctx, poly([CGPoint(x: cx - w * 0.06, y: top + h * 0.04),
                         CGPoint(x: cx + w * 0.06, y: top + h * 0.02),
                         CGPoint(x: cx + w * 0.11, y: top - h * 0.14),
                         CGPoint(x: cx - w * 0.02, y: top - h * 0.10)]), C.mGreen)
    }

    /// 애호박 — 각진 초록 원기둥(기울임) + 꼭지.
    private static func zucchini(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY, w = r.width * 0.34, h = r.height * 0.80
        let body = poly([
            CGPoint(x: cx - w / 2, y: cy - h * 0.36),
            CGPoint(x: cx - w * 0.32, y: cy - h / 2),
            CGPoint(x: cx + w * 0.36, y: cy - h * 0.44),
            CGPoint(x: cx + w / 2, y: cy - h * 0.30),
            CGPoint(x: cx + w * 0.42, y: cy + h * 0.42),
            CGPoint(x: cx + w * 0.10, y: cy + h / 2),
            CGPoint(x: cx - w * 0.42, y: cy + h * 0.40),
            CGPoint(x: cx - w / 2, y: cy + h * 0.20),
        ]).applying(rot(-0.32, CGPoint(x: cx, y: cy)))
        shadow(&ctx, body, r)
        fill(&ctx, body, ReffiColor.oklch(0.62, 0.13, 142))
        shadeBody(&ctx, body, dark: C.dGreen, light: C.lGreen.opacity(0.7), split: 0.5)
        // 꼭지
        let stem = poly([CGPoint(x: cx - w * 0.12, y: cy - h * 0.42),
                         CGPoint(x: cx + w * 0.12, y: cy - h * 0.46),
                         CGPoint(x: cx + w * 0.08, y: cy - h * 0.58),
                         CGPoint(x: cx - w * 0.08, y: cy - h * 0.55)]).applying(rot(-0.32, CGPoint(x: cx, y: cy)))
        fill(&ctx, stem, C.dGreen)
    }

    /// 잎채소 — 각진 초록 잎 두 장 + 잎맥.
    private static func greens(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX
        let bigBase = CGPoint(x: cx, y: r.maxY - r.height * 0.04)
        let big = angularLeaf(bigBase, CGPoint(x: cx - r.width * 0.06, y: r.minY + r.height * 0.02), r.width * 0.34)
        let small = angularLeaf(CGPoint(x: cx + r.width * 0.04, y: r.maxY - r.height * 0.06),
                                CGPoint(x: cx + r.width * 0.30, y: r.minY + r.height * 0.16), r.width * 0.20)
        shadow(&ctx, big, r)
        fill(&ctx, small, C.dGreen)
        fill(&ctx, big, C.mGreen)
        shadeBody(&ctx, big, dark: C.dGreen, light: C.leafHi, split: 0.5)
        // 잎맥(각진 밝은 면)
        var c = ctx; c.clip(to: big)
        let vein = poly([CGPoint(x: cx - r.width * 0.02, y: r.minY + r.height * 0.10),
                         CGPoint(x: cx + r.width * 0.03, y: r.minY + r.height * 0.12),
                         CGPoint(x: cx + r.width * 0.02, y: r.maxY - r.height * 0.08),
                         CGPoint(x: cx - r.width * 0.04, y: r.maxY - r.height * 0.08)])
        c.fill(vein, with: .color(C.leafHi))
    }

    /// 양파 — 각진 크림 알뿌리 + 초록 싹 + **보라 뿌리 액센트**.
    private static func onion(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY + r.height * 0.10, w = r.width * 0.72, h = r.height * 0.66
        let top = cy - h / 2, bot = cy + h / 2
        let body = poly([
            CGPoint(x: cx, y: top - r.height * 0.02),
            CGPoint(x: cx + w * 0.34, y: top + h * 0.12),
            CGPoint(x: cx + w * 0.5, y: cy),
            CGPoint(x: cx + w * 0.30, y: bot - h * 0.04),
            CGPoint(x: cx, y: bot),
            CGPoint(x: cx - w * 0.30, y: bot - h * 0.04),
            CGPoint(x: cx - w * 0.5, y: cy),
            CGPoint(x: cx - w * 0.34, y: top + h * 0.12),
        ])
        // 보라 뿌리 술(아래 삼각 프린지)
        for dx in [-0.12, 0.0, 0.12] as [CGFloat] {
            fill(&ctx, poly([CGPoint(x: cx + w * dx - w * 0.05, y: bot - h * 0.04),
                             CGPoint(x: cx + w * dx + w * 0.05, y: bot - h * 0.04),
                             CGPoint(x: cx + w * dx, y: bot + h * 0.14)]), C.purple)
        }
        shadow(&ctx, body, r)
        fill(&ctx, body, C.onion)
        shadeBody(&ctx, body, dark: C.onionSh, light: C.creamHi, split: 0.44)
        // 결 두 줄(각진)
        var c = ctx; c.clip(to: body)
        for s in [-1.0, 1.0] as [CGFloat] {
            let line = poly([CGPoint(x: cx + s * w * 0.06, y: top + h * 0.10),
                             CGPoint(x: cx + s * w * 0.12, y: top + h * 0.10),
                             CGPoint(x: cx + s * w * 0.30, y: bot - h * 0.10),
                             CGPoint(x: cx + s * w * 0.22, y: bot - h * 0.10)])
            c.fill(line, with: .color(C.onionSh.opacity(0.7)))
        }
        // 초록 싹
        for (dx, len) in [(-0.05, 0.16), (0.06, 0.12)] as [(CGFloat, CGFloat)] {
            let sprout = angularLeaf(CGPoint(x: cx + w * dx, y: top + h * 0.02),
                                     CGPoint(x: cx + w * dx * 2, y: top - r.height * len), r.width * 0.035)
            fill(&ctx, sprout, C.dGreen)
        }
    }

    /// 버섯 — 각진 탄 갓 + 점 + 크림 기둥.
    private static func mushroom(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY, w = r.width * 0.82, h = r.height * 0.72
        let capBot = cy - h * 0.02, stemW = w * 0.36
        // 기둥(크림, 각진)
        let stem = poly([CGPoint(x: cx - stemW / 2, y: capBot),
                         CGPoint(x: cx + stemW / 2, y: capBot),
                         CGPoint(x: cx + stemW * 0.42, y: cy + h * 0.48),
                         CGPoint(x: cx - stemW * 0.42, y: cy + h * 0.48)])
        shadow(&ctx, stem, r)
        fill(&ctx, stem, C.cream)
        shadeBody(&ctx, stem, dark: C.creamLo, split: 0.5)
        // 갓(각진 반원)
        let cap = poly([CGPoint(x: cx - w / 2, y: capBot),
                        CGPoint(x: cx - w * 0.38, y: cy - h * 0.36),
                        CGPoint(x: cx - w * 0.12, y: cy - h * 0.56),
                        CGPoint(x: cx + w * 0.14, y: cy - h * 0.56),
                        CGPoint(x: cx + w * 0.38, y: cy - h * 0.36),
                        CGPoint(x: cx + w / 2, y: capBot)])
        fill(&ctx, cap, C.tan)
        shadeBody(&ctx, cap, dark: C.tanSh, light: C.tan.opacity(0.5), split: 0.5)
        // 점 3개(각진 마름모)
        for (dx, dy, s) in [(-0.20, -0.30, 0.09), (0.14, -0.40, 0.07), (0.26, -0.16, 0.06)] as [(CGFloat, CGFloat, CGFloat)] {
            fill(&ctx, facet(cx + w * dx, cy + h * dy, w * s * 2, w * s * 2, 4), C.tanDk)
        }
    }

    /// 브로콜리 — 각진 초록 봉오리 클러스터(줄기에 맞닿게) + 연두 줄기.
    private static func broccoli(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY, w = r.width * 0.82, h = r.height * 0.82
        let stalkTop = cy + h * 0.06, stalkW = w * 0.28
        // 줄기(연두, 각진) — 봉오리 클러스터 밑동과 겹치게 위로 올린다.
        let stalk = poly([CGPoint(x: cx - stalkW / 2, y: cy + h / 2),
                          CGPoint(x: cx - stalkW * 0.72, y: stalkTop),
                          CGPoint(x: cx + stalkW * 0.72, y: stalkTop),
                          CGPoint(x: cx + stalkW / 2, y: cy + h / 2)])
        shadow(&ctx, stalk, r)
        fill(&ctx, stalk, ReffiColor.oklch(0.72, 0.1, 138))
        shadeBody(&ctx, stalk, dark: ReffiColor.oklch(0.60, 0.10, 138), split: 0.5)
        // 봉오리 클러스터(각진 다각형 — 돔을 이루며 줄기 밑동까지 내려와 맞닿는다). y는 cy 기준 절대 오프셋.
        let buds: [(CGFloat, CGFloat, CGFloat)] = [
            (0.0, -0.34, 0.42), (-0.30, -0.18, 0.36), (0.30, -0.18, 0.36),
            (-0.16, 0.00, 0.34), (0.16, 0.00, 0.34), (0.0, 0.12, 0.30),
        ]
        for (dx, dy, s) in buds {
            let bud = facet(cx + w * dx, cy + h * dy, w * s, w * s, 7, phase: dx * 3)
            fill(&ctx, bud, C.dGreen)
            shadeBody(&ctx, bud, dark: ReffiColor.oklch(0.37, 0.10, 150), light: C.mGreen, split: 0.5)
        }
    }

    /// 감자 — 각진 탄 덩이 + 눈.
    private static func potato(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY, w = r.width * 0.84, h = r.height * 0.66
        let body = poly([
            CGPoint(x: cx - w * 0.46, y: cy - h * 0.20),
            CGPoint(x: cx - w * 0.16, y: cy - h * 0.48),
            CGPoint(x: cx + w * 0.28, y: cy - h * 0.44),
            CGPoint(x: cx + w * 0.5, y: cy - h * 0.06),
            CGPoint(x: cx + w * 0.44, y: cy + h * 0.34),
            CGPoint(x: cx + w * 0.10, y: cy + h * 0.5),
            CGPoint(x: cx - w * 0.34, y: cy + h * 0.42),
            CGPoint(x: cx - w * 0.5, y: cy + h * 0.08),
        ]).applying(rot(-0.12, CGPoint(x: cx, y: cy)))
        shadow(&ctx, body, r)
        fill(&ctx, body, C.tan)
        shadeBody(&ctx, body, dark: C.tanSh, light: C.tan.opacity(0.45), split: 0.46)
        for (dx, dy) in [(-0.18, -0.06), (0.12, 0.10), (0.26, -0.16)] as [(CGFloat, CGFloat)] {
            fill(&ctx, facet(cx + w * dx, cy + h * dy, w * 0.10, w * 0.08, 4), C.tanDk)
        }
    }

    /// 마늘 — 각진 크림 알뿌리 + 클로브 결.
    private static func garlic(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY + r.height * 0.06, w = r.width * 0.64, h = r.height * 0.74
        let top = cy - h / 2, bot = cy + h / 2
        let body = poly([
            CGPoint(x: cx, y: top - r.height * 0.06),
            CGPoint(x: cx + w * 0.22, y: top + h * 0.16),
            CGPoint(x: cx + w * 0.5, y: cy + h * 0.10),
            CGPoint(x: cx + w * 0.30, y: bot),
            CGPoint(x: cx, y: bot - h * 0.06),
            CGPoint(x: cx - w * 0.30, y: bot),
            CGPoint(x: cx - w * 0.5, y: cy + h * 0.10),
            CGPoint(x: cx - w * 0.22, y: top + h * 0.16),
        ])
        shadow(&ctx, body, r)
        fill(&ctx, body, C.cream)
        shadeBody(&ctx, body, dark: C.onionSh, light: C.creamHi, split: 0.44)
        // 클로브 결(각진 밝은 면 두 줄)
        var c = ctx; c.clip(to: body)
        for s in [-1.0, 1.0] as [CGFloat] {
            let line = poly([CGPoint(x: cx + s * w * 0.04, y: cy - h * 0.14),
                             CGPoint(x: cx + s * w * 0.10, y: cy - h * 0.14),
                             CGPoint(x: cx + s * w * 0.28, y: bot - h * 0.08),
                             CGPoint(x: cx + s * w * 0.18, y: bot - h * 0.08)])
            c.fill(line, with: .color(C.creamLo))
        }
    }

    /// 오이 단면 — 연두 원 + 진초록 씨앗 별무늬.
    private static func cucumber(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY, R = min(r.width, r.height) * 0.42
        let rind = facet(cx, cy, R * 2, R * 2, 9)
        shadow(&ctx, rind, r)
        fill(&ctx, rind, C.mGreen)
        // 속살
        let flesh = facet(cx, cy, R * 1.56, R * 1.56, 9, phase: -.pi / 2 + .pi / 9)
        fill(&ctx, flesh, C.flesh)
        shadeBody(&ctx, flesh, dark: ReffiColor.oklch(0.83, 0.05, 138), split: 0.5)
        // 씨앗 별무늬(진초록 마름모, 중심 방사)
        for i in 0..<6 {
            let a = -CGFloat.pi / 2 + CGFloat(i) / 6 * 2 * .pi
            let p = CGPoint(x: cx + cos(a) * R * 0.42, y: cy + sin(a) * R * 0.42)
            fill(&ctx, facet(p.x, p.y, R * 0.20, R * 0.34, 4, phase: a), C.dGreen)
        }
        fill(&ctx, facet(cx, cy, R * 0.24, R * 0.24, 4), C.dGreen)
    }

    /// 완두 꼬투리 — 진초록 포드 + 연두 콩알.
    private static func pea(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY
        // 꼬투리(기울인 각진 반달)
        let pod = poly([
            CGPoint(x: cx - r.width * 0.34, y: cy - r.height * 0.06),
            CGPoint(x: cx - r.width * 0.10, y: cy - r.height * 0.30),
            CGPoint(x: cx + r.width * 0.24, y: cy - r.height * 0.30),
            CGPoint(x: cx + r.width * 0.40, y: cy - r.height * 0.04),
            CGPoint(x: cx + r.width * 0.30, y: cy + r.height * 0.14),
            CGPoint(x: cx - r.width * 0.06, y: cy + r.height * 0.10),
            CGPoint(x: cx - r.width * 0.30, y: cy + r.height * 0.12),
        ]).applying(rot(-0.18, CGPoint(x: cx, y: cy)))
        shadow(&ctx, pod, r)
        fill(&ctx, pod, C.pea)
        shadeBody(&ctx, pod, dark: C.dGreen, light: C.lGreen.opacity(0.6), split: 0.5)
        // 콩알 3개(각진 원)
        for dx in [-0.16, 0.02, 0.20] as [CGFloat] {
            let p = CGPoint(x: cx + r.width * dx, y: cy - r.height * 0.06 + r.height * dx * 0.2)
            fill(&ctx, facet(p.x, p.y, r.width * 0.17, r.width * 0.17, 7), C.peaBean)
        }
        // 꼭지 덩굴
        fill(&ctx, angularLeaf(CGPoint(x: cx - r.width * 0.30, y: cy - r.height * 0.04),
                               CGPoint(x: cx - r.width * 0.44, y: cy - r.height * 0.24), r.width * 0.03), C.dGreen)
    }

    /// 양배추 — 연녹 각진 머리 + 짙은 겉잎 + 잎맥.
    private static func cabbage(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY + r.height * 0.02, w = r.width * 0.86, h = r.height * 0.82
        // 겉잎(짙은 초록, 조금 큰 각진 원)
        let outer = facet(cx, cy, w, h, 8)
        shadow(&ctx, outer, r)
        fill(&ctx, outer, C.cabbageDk)
        // 속 머리(연녹)
        let head = facet(cx, cy + h * 0.04, w * 0.78, h * 0.78, 8, phase: -.pi / 2 + .pi / 8)
        fill(&ctx, head, C.cabbage)
        shadeBody(&ctx, head, dark: ReffiColor.oklch(0.78, 0.08, 138), split: 0.5)
        // 잎맥(각진 밝은 곡면 두 줄)
        var c = ctx; c.clip(to: head)
        for s in [-1.0, 1.0] as [CGFloat] {
            let vein = poly([CGPoint(x: cx, y: cy - h * 0.30),
                             CGPoint(x: cx + s * w * 0.30, y: cy - h * 0.06),
                             CGPoint(x: cx + s * w * 0.24, y: cy + h * 0.20),
                             CGPoint(x: cx + s * w * 0.06, y: cy + h * 0.02),
                             CGPoint(x: cx, y: cy - h * 0.14)])
            c.fill(vein, with: .color(C.cabbageVein))
        }
    }

    /// 고추 — 각진 붉은 뿔 + 초록 꼭지.
    private static func chili(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, top = r.minY + r.height * 0.14
        let body = poly([
            CGPoint(x: cx - r.width * 0.14, y: top),
            CGPoint(x: cx + r.width * 0.06, y: top + r.height * 0.06),
            CGPoint(x: cx + r.width * 0.24, y: r.midY),
            CGPoint(x: cx + r.width * 0.12, y: r.maxY - r.height * 0.14),
            CGPoint(x: cx - r.width * 0.16, y: r.maxY - r.height * 0.02),
            CGPoint(x: cx - r.width * 0.06, y: r.maxY - r.height * 0.22),
            CGPoint(x: cx - r.width * 0.06, y: r.midY),
            CGPoint(x: cx - r.width * 0.18, y: top + r.height * 0.10),
        ])
        shadow(&ctx, body, r)
        fill(&ctx, body, C.chili)
        shadeBody(&ctx, body, dark: C.chiliSh, light: C.tomatoHi.opacity(0.7), split: 0.4)
        // 초록 꼭지(각진)
        fill(&ctx, poly([CGPoint(x: cx - r.width * 0.14, y: top),
                         CGPoint(x: cx - r.width * 0.02, y: top + r.height * 0.02),
                         CGPoint(x: cx + r.width * 0.02, y: top - r.height * 0.14),
                         CGPoint(x: cx - r.width * 0.06, y: top - r.height * 0.10),
                         CGPoint(x: cx - r.width * 0.16, y: top - r.height * 0.04)]), C.mGreen)
    }

    /// 호박(단호박/늙은호박) — 각진 오렌지 몸 + 세로 리브 + 초록 꼭지.
    private static func pumpkin(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY + r.height * 0.06, w = r.width * 0.9, h = r.height * 0.72
        let body = facet(cx, cy, w, h, 8, phase: -.pi / 2 + .pi / 8)
        shadow(&ctx, body, r)
        fill(&ctx, body, C.pumpkin)
        shadeBody(&ctx, body, dark: C.pumpkinSh, light: C.carrotHi.opacity(0.7), split: 0.44)
        // 세로 리브(각진 어두운 면 두 줄)
        var c = ctx; c.clip(to: body)
        for s in [-1.0, 1.0] as [CGFloat] {
            let rib = poly([CGPoint(x: cx + s * w * 0.14, y: cy - h * 0.40),
                            CGPoint(x: cx + s * w * 0.22, y: cy - h * 0.36),
                            CGPoint(x: cx + s * w * 0.30, y: cy + h * 0.34),
                            CGPoint(x: cx + s * w * 0.20, y: cy + h * 0.40)])
            c.fill(rib, with: .color(C.pumpkinSh.opacity(0.8)))
        }
        // 꼭지(초록-갈색 각진)
        fill(&ctx, poly([CGPoint(x: cx - w * 0.06, y: cy - h * 0.42),
                         CGPoint(x: cx + w * 0.06, y: cy - h * 0.42),
                         CGPoint(x: cx + w * 0.05, y: cy - h * 0.58),
                         CGPoint(x: cx - w * 0.05, y: cy - h * 0.56)]), ReffiColor.oklch(0.50, 0.09, 120))
    }

    /// 옥수수 — 각진 노랑 자루(알갱이 격자) + 초록 껍질.
    private static func corn(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY - r.height * 0.02, w = r.width * 0.44, h = r.height * 0.82
        let top = cy - h / 2, bot = cy + h / 2
        // 껍질 두 장(초록, 하부)
        for s in [-1.0, 1.0] as [CGFloat] {
            let husk = angularLeaf(CGPoint(x: cx + s * w * 0.30, y: bot - h * 0.02),
                                   CGPoint(x: cx + s * w * 0.72, y: cy + h * 0.14), w * 0.22)
            fill(&ctx, husk, s < 0 ? C.dGreen : C.mGreen)
        }
        // 자루(각진 캡슐)
        let cob = poly([CGPoint(x: cx - w / 2, y: top + h * 0.10),
                        CGPoint(x: cx - w * 0.28, y: top),
                        CGPoint(x: cx + w * 0.28, y: top),
                        CGPoint(x: cx + w / 2, y: top + h * 0.10),
                        CGPoint(x: cx + w / 2, y: bot - h * 0.06),
                        CGPoint(x: cx + w * 0.24, y: bot),
                        CGPoint(x: cx - w * 0.24, y: bot),
                        CGPoint(x: cx - w / 2, y: bot - h * 0.06)])
        shadow(&ctx, cob, r)
        fill(&ctx, cob, C.yellow)
        shadeBody(&ctx, cob, dark: C.yellowSh, light: C.yellowHi, split: 0.46)
        // 알갱이 격자(마름모, 두 톤 교차)
        var c = ctx; c.clip(to: cob)
        let cols = 3, rows = 6
        for row in 0..<rows {
            for col in 0..<cols {
                let px = cx + (CGFloat(col) - 1) * w * 0.30 + (row % 2 == 0 ? 0 : w * 0.15)
                let py = top + h * 0.14 + CGFloat(row) * h * 0.13
                c.fill(facet(px, py, w * 0.24, h * 0.12, 4), with: .color((row + col) % 2 == 0 ? C.yellowSh.opacity(0.7) : C.yellowHi.opacity(0.6)))
            }
        }
    }

    // MARK: - Fruit

    /// 사과 — 각진 빨강 몸(윗 노치) + 갈색 줄기 + 초록 잎.
    private static func apple(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY + r.height * 0.05, w = r.width * 0.84, h = r.height * 0.78
        let top = cy - h / 2, bot = cy + h / 2
        let body = poly([
            CGPoint(x: cx, y: top + h * 0.10),
            CGPoint(x: cx + w * 0.20, y: top),
            CGPoint(x: cx + w * 0.44, y: top + h * 0.16),
            CGPoint(x: cx + w * 0.5, y: cy + h * 0.06),
            CGPoint(x: cx + w * 0.28, y: bot),
            CGPoint(x: cx, y: bot - h * 0.10),
            CGPoint(x: cx - w * 0.28, y: bot),
            CGPoint(x: cx - w * 0.5, y: cy + h * 0.06),
            CGPoint(x: cx - w * 0.44, y: top + h * 0.16),
            CGPoint(x: cx - w * 0.20, y: top),
        ])
        shadow(&ctx, body, r)
        fill(&ctx, body, C.apple)
        shadeBody(&ctx, body, dark: C.appleSh, light: C.appleHi, split: 0.40)
        // 줄기 + 잎
        fill(&ctx, poly([CGPoint(x: cx - w * 0.03, y: top + h * 0.08),
                         CGPoint(x: cx + w * 0.03, y: top + h * 0.08),
                         CGPoint(x: cx + w * 0.02, y: top - h * 0.14),
                         CGPoint(x: cx - w * 0.02, y: top - h * 0.14)]), C.brown)
        fill(&ctx, angularLeaf(CGPoint(x: cx + w * 0.02, y: top - h * 0.06),
                               CGPoint(x: cx + w * 0.24, y: top - h * 0.16), w * 0.08), C.mGreen)
    }

    /// 레몬 — 각진 노랑 타원(양끝 뾰족).
    private static func lemon(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY, w = r.width * 0.84, h = r.height * 0.60
        let body = poly([
            CGPoint(x: cx - w / 2, y: cy + h * 0.04),
            CGPoint(x: cx - w * 0.30, y: cy - h * 0.36),
            CGPoint(x: cx + w * 0.14, y: cy - h * 0.5),
            CGPoint(x: cx + w * 0.44, y: cy - h * 0.24),
            CGPoint(x: cx + w / 2, y: cy + h * 0.06),
            CGPoint(x: cx + w * 0.28, y: cy + h * 0.42),
            CGPoint(x: cx - w * 0.18, y: cy + h * 0.5),
            CGPoint(x: cx - w * 0.44, y: cy + h * 0.26),
        ]).applying(rot(-0.16, CGPoint(x: cx, y: cy)))
        shadow(&ctx, body, r)
        fill(&ctx, body, C.yellow)
        shadeBody(&ctx, body, dark: C.yellowSh, light: C.yellowHi, split: 0.46)
        // 꼭지 젖꼭지(각진)
        fill(&ctx, facet(cx + w * 0.40, cy - h * 0.16, w * 0.1, w * 0.1, 4), C.yellowSh)
    }

    /// 딸기 — 각진 빨강 몸 + 초록 꼭지 + 씨.
    private static func berry(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY + r.height * 0.06, w = r.width * 0.66, h = r.height * 0.76
        let top = cy - h / 2, bot = cy + h / 2
        let body = poly([
            CGPoint(x: cx - w * 0.48, y: top + h * 0.14),
            CGPoint(x: cx - w * 0.12, y: top + h * 0.02),
            CGPoint(x: cx + w * 0.20, y: top),
            CGPoint(x: cx + w * 0.48, y: top + h * 0.16),
            CGPoint(x: cx + w * 0.30, y: cy + h * 0.20),
            CGPoint(x: cx, y: bot),
            CGPoint(x: cx - w * 0.30, y: cy + h * 0.20),
        ])
        shadow(&ctx, body, r)
        fill(&ctx, body, C.berry)
        shadeBody(&ctx, body, dark: C.berrySh, light: C.apple.opacity(0.6), split: 0.42)
        // 꼭지 잎(각진 3장)
        for dx in [-0.22, 0.0, 0.22] as [CGFloat] {
            fill(&ctx, angularLeaf(CGPoint(x: cx + w * dx * 0.4, y: top + h * 0.08),
                                   CGPoint(x: cx + w * dx, y: top - h * 0.12), w * 0.10), C.mGreen)
        }
        // 씨(작은 마름모)
        for (dx, dy) in [(-0.16, 0.14), (0.16, 0.14), (0.0, 0.30), (-0.18, 0.36), (0.18, 0.36)] as [(CGFloat, CGFloat)] {
            fill(&ctx, facet(cx + w * dx, cy + h * dy, w * 0.07, w * 0.11, 4), C.yellowHi)
        }
    }

    /// 아보카도 반쪽 — 짙은 껍질 + 황록 과육 + 밤색 씨.
    private static func avocado(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY, w = r.width * 0.62, h = r.height * 0.86
        // 서양배 모양(각진) — 위 좁고 아래 넓게
        func pear(_ sw: CGFloat, _ sh: CGFloat) -> Path {
            poly([
                CGPoint(x: cx, y: cy - sh / 2),
                CGPoint(x: cx + sw * 0.24, y: cy - sh * 0.30),
                CGPoint(x: cx + sw * 0.5, y: cy + sh * 0.10),
                CGPoint(x: cx + sw * 0.34, y: cy + sh * 0.44),
                CGPoint(x: cx, y: cy + sh / 2),
                CGPoint(x: cx - sw * 0.34, y: cy + sh * 0.44),
                CGPoint(x: cx - sw * 0.5, y: cy + sh * 0.10),
                CGPoint(x: cx - sw * 0.24, y: cy - sh * 0.30),
            ])
        }
        let skin = pear(w, h)
        shadow(&ctx, skin, r)
        fill(&ctx, skin, C.avoSkin)
        // 과육 테두리 + 과육
        fill(&ctx, pear(w * 0.82, h * 0.82), C.avoRim)
        fill(&ctx, pear(w * 0.64, h * 0.64), C.avoFlesh)
        shadeBody(&ctx, pear(w * 0.64, h * 0.64), dark: ReffiColor.oklch(0.80, 0.10, 108), split: 0.5)
        // 씨(밤색 각진 원, 하부)
        fill(&ctx, facet(cx, cy + h * 0.18, w * 0.34, w * 0.34, 7), C.pit)
        fill(&ctx, facet(cx - w * 0.05, cy + h * 0.13, w * 0.14, w * 0.14, 6), C.pit.opacity(0.0))
        fill(&ctx, facet(cx - w * 0.05, cy + h * 0.13, w * 0.12, w * 0.12, 6), ReffiColor.oklch(0.60, 0.07, 58))
    }

    /// 바나나 — 각진 노랑 초승달 두 개(다발) + 갈색 팁·꼭지.
    private static func banana(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY, w = r.width * 0.82, h = r.height * 0.52
        // 굵은 각진 초승달(벨리가 아래, 양끝 위) — 자체 중심 기준 회전.
        func crescent(_ c: CGPoint, _ sw: CGFloat, _ sh: CGFloat, _ a: CGFloat) -> Path {
            poly([
                CGPoint(x: c.x - sw / 2, y: c.y + sh * 0.08),    // 왼 팁
                CGPoint(x: c.x - sw * 0.30, y: c.y - sh * 0.34),
                CGPoint(x: c.x + sw * 0.12, y: c.y - sh * 0.46), // 능선 정점
                CGPoint(x: c.x + sw * 0.44, y: c.y - sh * 0.18),
                CGPoint(x: c.x + sw / 2, y: c.y + sh * 0.16),    // 오른 팁
                CGPoint(x: c.x + sw * 0.24, y: c.y + sh * 0.02), // 안쪽(밑면)
                CGPoint(x: c.x - sw * 0.16, y: c.y - sh * 0.06),
            ]).applying(rot(a, c))
        }
        let back = crescent(CGPoint(x: cx + w * 0.06, y: cy + h * 0.16), w * 0.94, h * 0.94, -0.14)
        let front = crescent(CGPoint(x: cx, y: cy - h * 0.02), w, h, 0.03)
        shadow(&ctx, back, r)
        fill(&ctx, back, C.bananaSh)
        fill(&ctx, front, C.banana)
        shadeBody(&ctx, front, dark: C.bananaSh, light: C.yellowHi.opacity(0.6), split: 0.5)
        // 갈색 팁(양끝) + 꼭지
        fill(&ctx, facet(cx - w * 0.42, cy + h * 0.06, w * 0.10, h * 0.16, 4), C.bananaTip)
        fill(&ctx, facet(cx + w * 0.50, cy + h * 0.12, w * 0.09, h * 0.15, 4), C.bananaTip)
        fill(&ctx, poly([CGPoint(x: cx + w * 0.08, y: cy - h * 0.46),
                         CGPoint(x: cx + w * 0.18, y: cy - h * 0.44),
                         CGPoint(x: cx + w * 0.15, y: cy - h * 0.60),
                         CGPoint(x: cx + w * 0.05, y: cy - h * 0.56)]), C.bananaTip)
    }

    // MARK: - Protein

    /// 계란 — 각진 흰자 + 노른자(각진 원) + 하이라이트.
    private static func egg(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY, w = r.width * 0.76, h = r.height * 0.84
        let white = facet(cx, cy, w, h, 9)
        shadow(&ctx, white, r)
        fill(&ctx, white, C.cream)
        shadeBody(&ctx, white, dark: C.creamLo, split: 0.5)
        let yr = w * 0.46
        fill(&ctx, facet(cx, cy + h * 0.02, yr, yr, 7), ReffiColor.oklch(0.82, 0.155, 82))
        fill(&ctx, facet(cx - yr * 0.20, cy - yr * 0.18, yr * 0.36, yr * 0.36, 5), ReffiColor.oklch(0.90, 0.10, 92))
    }

    /// 두부 — 각진 크림 블록(윗면 밝게 · 옆면 어둡게).
    private static func tofu(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let w = r.width * 0.82, h = r.height * 0.62, cx = r.midX, cy = r.midY
        let front = CGRect(x: cx - w / 2, y: cy - h * 0.28, width: w, height: h * 0.78)
        let off = w * 0.16
        var topF = Path()
        topF.move(to: CGPoint(x: front.minX, y: front.minY))
        topF.addLine(to: CGPoint(x: front.minX + off, y: front.minY - off * 0.7))
        topF.addLine(to: CGPoint(x: front.maxX + off, y: front.minY - off * 0.7))
        topF.addLine(to: CGPoint(x: front.maxX, y: front.minY)); topF.closeSubpath()
        var side = Path()
        side.move(to: CGPoint(x: front.maxX, y: front.minY))
        side.addLine(to: CGPoint(x: front.maxX + off, y: front.minY - off * 0.7))
        side.addLine(to: CGPoint(x: front.maxX + off, y: front.maxY - off * 0.7))
        side.addLine(to: CGPoint(x: front.maxX, y: front.maxY)); side.closeSubpath()
        let f = Path(front)
        shadow(&ctx, f, r)
        fill(&ctx, side, C.creamLo)
        fill(&ctx, topF, C.creamHi)
        fill(&ctx, f, C.cream)
    }

    /// 소/돼지고기 — 각진 빨강 살 + 크림 지방 가장자리.
    private static func meat(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY, w = r.width * 0.88, h = r.height * 0.62
        let l = cx - w / 2, rr = cx + w / 2, t = cy - h / 2, b = cy + h / 2
        let body = poly([
            CGPoint(x: l + w * 0.10, y: t + h * 0.06),
            CGPoint(x: cx - w * 0.06, y: t - h * 0.06),
            CGPoint(x: cx + w * 0.24, y: t + h * 0.02),
            CGPoint(x: rr, y: t + h * 0.20),
            CGPoint(x: rr - w * 0.04, y: b - h * 0.16),
            CGPoint(x: rr - w * 0.24, y: b),
            CGPoint(x: l + w * 0.18, y: b - h * 0.02),
            CGPoint(x: l, y: b - h * 0.34),
        ]).applying(rot(-0.05, CGPoint(x: cx, y: cy)))
        shadow(&ctx, body, r)
        fill(&ctx, body, C.meat)
        shadeBody(&ctx, body, dark: C.meatSh, light: C.meat.opacity(0.4), split: 0.5)
        // 지방 가장자리(윗변 크림 각진 띠)
        var c = ctx; c.clip(to: body)
        let fatBand = poly([CGPoint(x: l + w * 0.08, y: t + h * 0.08),
                            CGPoint(x: cx - w * 0.06, y: t - h * 0.04),
                            CGPoint(x: cx + w * 0.24, y: t + h * 0.04),
                            CGPoint(x: rr - w * 0.02, y: t + h * 0.22),
                            CGPoint(x: rr - w * 0.06, y: t + h * 0.40),
                            CGPoint(x: cx, y: t + h * 0.26),
                            CGPoint(x: l + w * 0.08, y: t + h * 0.34)]).applying(rot(-0.05, CGPoint(x: cx, y: cy)))
        c.fill(fatBand, with: .color(C.fat))
    }

    /// 닭다리 — 각진 탄 살 + 크림 뼈.
    private static func drumstick(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY, w = r.width * 0.58, h = r.height * 0.9
        let boneW = w * 0.14, boneTopY = cy - h * 0.44, meatTopY = cy - h * 0.06, meatBotY = cy + h * 0.44
        // 살(각진 물방울)
        let m = poly([
            CGPoint(x: cx + boneW, y: meatTopY),
            CGPoint(x: cx + w * 0.5, y: meatTopY + h * 0.14),
            CGPoint(x: cx + w * 0.44, y: meatBotY - h * 0.10),
            CGPoint(x: cx, y: meatBotY),
            CGPoint(x: cx - w * 0.44, y: meatBotY - h * 0.10),
            CGPoint(x: cx - w * 0.5, y: meatTopY + h * 0.14),
            CGPoint(x: cx - boneW, y: meatTopY),
        ])
        // 뼈(크림 각진)
        let bone = poly([
            CGPoint(x: cx - boneW * 2, y: boneTopY + h * 0.02),
            CGPoint(x: cx - boneW * 0.6, y: boneTopY - h * 0.04),
            CGPoint(x: cx + boneW * 0.6, y: boneTopY - h * 0.04),
            CGPoint(x: cx + boneW * 2, y: boneTopY + h * 0.02),
            CGPoint(x: cx + boneW, y: meatTopY + h * 0.04),
            CGPoint(x: cx - boneW, y: meatTopY + h * 0.04),
        ])
        let tr = rot(0.18, CGPoint(x: cx, y: cy))
        shadow(&ctx, m.applying(tr), r)
        fill(&ctx, bone.applying(tr), C.cream)
        let mm = m.applying(tr)
        fill(&ctx, mm, C.poultry)
        shadeBody(&ctx, mm, dark: C.poultrySh, light: C.poultry.opacity(0.4), split: 0.5)
    }

    /// 생선 — 각진 파랑 몸 + 갈라진 꼬리 + 눈.
    private static func fish(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY, w = r.width * 0.94, h = r.height * 0.56
        let bodyRight = cx + w * 0.26
        let body = poly([
            CGPoint(x: cx - w / 2, y: cy),
            CGPoint(x: cx - w * 0.22, y: cy - h * 0.44),
            CGPoint(x: cx + w * 0.14, y: cy - h * 0.42),
            CGPoint(x: bodyRight, y: cy - h * 0.30),
            CGPoint(x: cx + w / 2, y: cy - h * 0.5),
            CGPoint(x: bodyRight + w * 0.05, y: cy),
            CGPoint(x: cx + w / 2, y: cy + h * 0.5),
            CGPoint(x: bodyRight, y: cy + h * 0.30),
            CGPoint(x: cx + w * 0.14, y: cy + h * 0.42),
            CGPoint(x: cx - w * 0.22, y: cy + h * 0.44),
        ])
        shadow(&ctx, body, r)
        fill(&ctx, body, C.fish)
        shadeBody(&ctx, body, dark: C.fishDk, light: C.fishHi, split: 0.5)
        // 꼬리(진한 삼각)
        fill(&ctx, poly([CGPoint(x: bodyRight + w * 0.02, y: cy),
                         CGPoint(x: cx + w / 2, y: cy - h * 0.5),
                         CGPoint(x: bodyRight + w * 0.05, y: cy),
                         CGPoint(x: cx + w / 2, y: cy + h * 0.5)]), C.fishDk)
        // 눈
        fill(&ctx, facet(cx - w * 0.32, cy - h * 0.10, w * 0.08, w * 0.08, 6), .white)
        fill(&ctx, facet(cx - w * 0.32, cy - h * 0.10, w * 0.038, w * 0.038, 5), ReffiColor.ink)
    }

    /// 새우 — 각진 코랄 몸(분절) + 꼬리 부채.
    private static func shrimp(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let c = CGPoint(x: r.midX, y: r.midY), R = min(r.width, r.height) * 0.42
        // C자 각진 몸
        let body = poly([
            CGPoint(x: c.x - R * 0.10, y: c.y - R * 0.92),
            CGPoint(x: c.x + R * 0.6, y: c.y - R * 0.62),
            CGPoint(x: c.x + R * 0.86, y: c.y + R * 0.04),
            CGPoint(x: c.x + R * 0.5, y: c.y + R * 0.58),
            CGPoint(x: c.x - R * 0.30, y: c.y + R * 0.7),
            CGPoint(x: c.x - R * 0.74, y: c.y + R * 0.98),
            CGPoint(x: c.x - R * 0.5, y: c.y + R * 0.48),
            CGPoint(x: c.x + R * 0.34, y: c.y + R * 0.14),
            CGPoint(x: c.x + R * 0.42, y: c.y - R * 0.34),
            CGPoint(x: c.x - R * 0.02, y: c.y - R * 0.58),
        ])
        shadow(&ctx, body, r)
        fill(&ctx, body, C.shrimp)
        shadeBody(&ctx, body, dark: C.shrimpSh, light: C.yellow.opacity(0.4), split: 0.5)
        // 분절 3줄(각진 밝은 쐐기)
        var cc = ctx; cc.clip(to: body)
        for t in [0.28, 0.48, 0.68] as [CGFloat] {
            let a = CGPoint(x: c.x + R * (0.6 - t * 0.9), y: c.y - R * 0.5 + R * 1.2 * t)
            cc.fill(poly([a, CGPoint(x: a.x + R * 0.26, y: a.y + R * 0.06),
                          CGPoint(x: a.x + R * 0.22, y: a.y + R * 0.18),
                          CGPoint(x: a.x - R * 0.02, y: a.y + R * 0.12)]),
                    with: .color(C.shrimpSh.opacity(0.6)))
        }
    }

    // MARK: - Dairy / grain / pantry / other

    /// 우유 — 각진 흰 박공 카톤 + 라벨 띠.
    private static func milk(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, w = r.width * 0.56, h = r.height * 0.86
        let top = r.midY - h / 2, bot = r.midY + h / 2, bodyTop = top + h * 0.28
        let carton = poly([
            CGPoint(x: cx - w / 2, y: bot),
            CGPoint(x: cx - w / 2, y: bodyTop),
            CGPoint(x: cx - w * 0.16, y: top),
            CGPoint(x: cx + w * 0.16, y: top),
            CGPoint(x: cx + w / 2, y: bodyTop),
            CGPoint(x: cx + w / 2, y: bot),
        ])
        shadow(&ctx, carton, r)
        fill(&ctx, carton, C.creamHi)
        shadeBody(&ctx, carton, dark: C.creamLo, split: 0.5)
        // 지붕 접힌 면(밝은 삼각)
        fill(&ctx, poly([CGPoint(x: cx - w * 0.16, y: top),
                         CGPoint(x: cx + w * 0.16, y: top),
                         CGPoint(x: cx, y: top + h * 0.06)]), C.cream)
        // 라벨 띠
        fill(&ctx, Path(CGRect(x: cx - w / 2, y: bodyTop + h * 0.16, width: w, height: h * 0.18)), C.milkLbl)
    }

    /// 치즈 — 각진 노랑 쐐기 + 구멍.
    private static func cheese(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY + r.height * 0.04, w = r.width * 0.86, h = r.height * 0.62
        let wedge = poly([
            CGPoint(x: cx - w / 2, y: cy - h / 2),
            CGPoint(x: cx + w * 0.20, y: cy - h * 0.34),
            CGPoint(x: cx + w / 2, y: cy + h * 0.12),
            CGPoint(x: cx - w * 0.10, y: cy + h / 2),
            CGPoint(x: cx - w / 2, y: cy + h * 0.30),
        ])
        shadow(&ctx, wedge, r)
        fill(&ctx, wedge, C.cheese)
        shadeBody(&ctx, wedge, dark: C.cheeseHl, light: C.yellowHi.opacity(0.5), split: 0.5)
        for (dx, dy, s) in [(-0.24, 0.02, 0.10), (-0.02, 0.16, 0.08), (-0.10, -0.14, 0.06)] as [(CGFloat, CGFloat, CGFloat)] {
            fill(&ctx, facet(cx + w * dx, cy + h * dy, w * s * 2, w * s * 2, 6), C.cheeseHl)
        }
    }

    /// 빵 — 각진 식빵 + 진한 윗 크러스트.
    private static func bread(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY + r.height * 0.04, w = r.width * 0.78, h = r.height * 0.72
        let bot = cy + h / 2, sideTop = cy - h * 0.08
        let loaf = poly([
            CGPoint(x: cx - w / 2, y: bot - h * 0.06),
            CGPoint(x: cx - w * 0.34, y: bot),
            CGPoint(x: cx + w * 0.34, y: bot),
            CGPoint(x: cx + w / 2, y: bot - h * 0.06),
            CGPoint(x: cx + w / 2, y: sideTop),
            CGPoint(x: cx + w * 0.28, y: cy - h * 0.54),
            CGPoint(x: cx, y: cy - h / 2 - h * 0.04),
            CGPoint(x: cx - w * 0.28, y: cy - h * 0.54),
            CGPoint(x: cx - w / 2, y: sideTop),
        ])
        shadow(&ctx, loaf, r)
        fill(&ctx, loaf, C.bread)
        shadeBody(&ctx, loaf, dark: C.breadSh, split: 0.46)
        // 윗 크러스트(진한 각진 띠)
        var c = ctx; c.clip(to: loaf)
        let crust = poly([CGPoint(x: cx - w / 2, y: sideTop),
                          CGPoint(x: cx - w * 0.28, y: cy - h * 0.54),
                          CGPoint(x: cx, y: cy - h / 2 - h * 0.04),
                          CGPoint(x: cx + w * 0.28, y: cy - h * 0.54),
                          CGPoint(x: cx + w / 2, y: sideTop),
                          CGPoint(x: cx + w / 2, y: sideTop + h * 0.16),
                          CGPoint(x: cx - w / 2, y: sideTop + h * 0.16)])
        c.fill(crust, with: .color(C.crust))
    }

    /// 밥 — 각진 나무 밥공기 + 흰 밥 봉우리 + 밥알.
    private static func rice(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY + r.height * 0.06, w = r.width * 0.82
        let rim = cy - r.height * 0.06
        // 밥 봉우리(각진 돔)
        let mound = poly([
            CGPoint(x: cx - w * 0.42, y: rim),
            CGPoint(x: cx - w * 0.24, y: rim - r.height * 0.22),
            CGPoint(x: cx + w * 0.02, y: rim - r.height * 0.30),
            CGPoint(x: cx + w * 0.26, y: rim - r.height * 0.20),
            CGPoint(x: cx + w * 0.42, y: rim),
        ])
        shadow(&ctx, mound, r)
        fill(&ctx, mound, C.rice)
        shadeBody(&ctx, mound, dark: C.riceSh, split: 0.5)
        // 그릇(각진 사다리꼴)
        let bowl = poly([
            CGPoint(x: cx - w * 0.46, y: rim),
            CGPoint(x: cx + w * 0.46, y: rim),
            CGPoint(x: cx + w * 0.30, y: cy + r.height * 0.32),
            CGPoint(x: cx - w * 0.30, y: cy + r.height * 0.32),
        ])
        fill(&ctx, bowl, C.bowlW)
        shadeBody(&ctx, bowl, dark: ReffiColor.oklch(0.64, 0.05, 58), light: C.bowlWHi, split: 0.5)
        // 밥알 몇 개
        var c = ctx; c.clip(to: mound)
        for (dx, dy) in [(-0.12, -0.10), (0.10, -0.14), (0.0, -0.02)] as [(CGFloat, CGFloat)] {
            c.fill(facet(cx + w * dx, rim - r.height * (0.06 - dy), w * 0.08, w * 0.05, 4), with: .color(C.riceSh))
        }
    }

    /// 국수 — 각진 도기 그릇 + 밀색 면 봉우리(웨이브 가닥).
    private static func noodles(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, cy = r.midY + r.height * 0.06, w = r.width * 0.84
        let rim = cy - r.height * 0.04
        // 면 봉우리(각진)
        let mound = poly([
            CGPoint(x: cx - w * 0.40, y: rim),
            CGPoint(x: cx - w * 0.28, y: rim - r.height * 0.20),
            CGPoint(x: cx - w * 0.04, y: rim - r.height * 0.28),
            CGPoint(x: cx + w * 0.24, y: rim - r.height * 0.18),
            CGPoint(x: cx + w * 0.40, y: rim),
        ])
        shadow(&ctx, mound, r)
        fill(&ctx, mound, C.noodle)
        shadeBody(&ctx, mound, dark: C.noodleSh, split: 0.5)
        // 웨이브 가닥(각진 지그재그 두 줄)
        var c = ctx; c.clip(to: mound)
        for oy in [0.0, 0.10] as [CGFloat] {
            let wave = poly([
                CGPoint(x: cx - w * 0.32, y: rim - r.height * (0.10 + oy)),
                CGPoint(x: cx - w * 0.14, y: rim - r.height * (0.18 + oy)),
                CGPoint(x: cx + w * 0.04, y: rim - r.height * (0.10 + oy)),
                CGPoint(x: cx + w * 0.22, y: rim - r.height * (0.18 + oy)),
                CGPoint(x: cx + w * 0.30, y: rim - r.height * (0.10 + oy)),
                CGPoint(x: cx + w * 0.30, y: rim - r.height * (0.06 + oy)),
                CGPoint(x: cx - w * 0.32, y: rim - r.height * (0.06 + oy)),
            ])
            c.fill(wave, with: .color(C.noodleSh.opacity(0.7)))
        }
        // 그릇(각진 도기 블루)
        let bowl = poly([
            CGPoint(x: cx - w * 0.46, y: rim),
            CGPoint(x: cx + w * 0.46, y: rim),
            CGPoint(x: cx + w * 0.28, y: cy + r.height * 0.34),
            CGPoint(x: cx - w * 0.28, y: cy + r.height * 0.34),
        ])
        fill(&ctx, bowl, C.bowlB)
        shadeBody(&ctx, bowl, dark: ReffiColor.oklch(0.62, 0.06, 246), light: C.bowlBHi, split: 0.5)
    }

    /// 소스병 — 각진 병 실루엣 + 라벨 면 + 레드 뚜껑 액센트.
    private static func sauceBottle(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, w = r.width * 0.42
        let top = r.minY + r.height * 0.06, bot = r.maxY - r.height * 0.04
        let neckBot = top + r.height * 0.24, shoulder = top + r.height * 0.30
        // 뚜껑(레드 각진)
        fill(&ctx, Path(CGRect(x: cx - w * 0.24, y: top, width: w * 0.48, height: r.height * 0.08)), C.cap)
        // 병 몸(각진)
        let bottle = poly([
            CGPoint(x: cx - w * 0.16, y: top + r.height * 0.07),
            CGPoint(x: cx + w * 0.16, y: top + r.height * 0.07),
            CGPoint(x: cx + w * 0.16, y: neckBot),
            CGPoint(x: cx + w / 2, y: shoulder),
            CGPoint(x: cx + w / 2, y: bot - r.height * 0.04),
            CGPoint(x: cx + w * 0.34, y: bot),
            CGPoint(x: cx - w * 0.34, y: bot),
            CGPoint(x: cx - w / 2, y: bot - r.height * 0.04),
            CGPoint(x: cx - w / 2, y: shoulder),
            CGPoint(x: cx - w * 0.16, y: neckBot),
        ])
        shadow(&ctx, bottle, r)
        fill(&ctx, bottle, C.bottle)
        shadeBody(&ctx, bottle, dark: ReffiColor.oklch(0.34, 0.05, 42), light: C.bottleHi, split: 0.5)
        // 라벨 면(크림 각진)
        fill(&ctx, poly([CGPoint(x: cx - w * 0.42, y: shoulder + r.height * 0.10),
                         CGPoint(x: cx + w * 0.42, y: shoulder + r.height * 0.10),
                         CGPoint(x: cx + w * 0.42, y: bot - r.height * 0.14),
                         CGPoint(x: cx - w * 0.42, y: bot - r.height * 0.14)]), C.cream)
    }

    /// 통조림 캔 — 각진 금속 원기둥 + 라벨 띠.
    private static func can(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let cx = r.midX, w = r.width * 0.62, h = r.height * 0.66
        let top = r.midY - h / 2, bot = r.midY + h / 2, lip = top + h * 0.10
        // 몸(각진 원기둥)
        let bodyRect = CGRect(x: cx - w / 2, y: lip, width: w, height: bot - lip)
        let body = Path(bodyRect)
        shadow(&ctx, body, r)
        fill(&ctx, body, C.metal)
        shadeBody(&ctx, body, dark: C.metalSh, light: C.metalHi, split: 0.5)
        // 뚜껑(각진 타원 림)
        fill(&ctx, facet(cx, lip, w, h * 0.2, 8), C.metalHi)
        fill(&ctx, facet(cx, lip, w * 0.84, h * 0.14, 8), C.metalSh)
        // 라벨 띠(레드)
        fill(&ctx, Path(CGRect(x: cx - w / 2, y: top + h * 0.34, width: w, height: h * 0.40)), C.canBand)
        // 라벨 하이라이트(밝은 각진 면)
        var c = ctx; c.clip(to: Path(CGRect(x: cx - w / 2, y: top + h * 0.34, width: w, height: h * 0.40)))
        c.fill(poly([CGPoint(x: cx - w * 0.5, y: top + h * 0.34),
                     CGPoint(x: cx - w * 0.20, y: top + h * 0.34),
                     CGPoint(x: cx - w * 0.34, y: top + h * 0.74),
                     CGPoint(x: cx - w * 0.5, y: top + h * 0.74)]),
                with: .color(ReffiColor.oklch(0.68, 0.14, 28)))
    }

    /// 일반 — 각진 뉴트럴 블롭.
    private static func blob(_ r: CGRect, _ ctx: inout GraphicsContext) {
        let body = facet(r.midX, r.midY, r.width * 0.84, r.height * 0.80, 9)
        shadow(&ctx, body, r)
        fill(&ctx, body, C.neutral)
        shadeBody(&ctx, body, dark: C.neutralSh, split: 0.5)
    }
}
