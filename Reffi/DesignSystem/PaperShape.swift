import SwiftUI

/// 손으로 자른 종이(Hand-cut Paper) 셰이프 — 새 비주얼 언어의 핵심(§13).
/// 완벽한 원·사각 금지: 변·코너를 고정 시드로 미세하게 흩뜨려 손으로 오린 종이 느낌을 낸다.
/// 시드(seed)가 같으면 항상 같은 모양 → 레이아웃이 흔들리지 않는다(애니메이션 안정).

/// 종이 둥근 사각 — 버튼·뱃지·카드 면. 변은 살짝 휘고 코너 반지름은 변마다 다르다.
struct PaperRect: Shape {
    var cornerRadius: CGFloat = 14
    var seed: Int = 0

    // 코너 반지름 배율(0=TL,1=TR,2=BR,3=BL) · 변 휘는 정도(±, 0=top,1=right,2=bottom,3=left).
    private static let cornerJit: [[CGFloat]] = [
        [1.00, 0.84, 1.10, 0.90],
        [0.90, 1.08, 0.86, 1.04],
        [1.06, 0.92, 1.02, 0.88],
        [0.88, 1.04, 0.94, 1.10],
    ]
    private static let edgeBow: [[CGFloat]] = [
        [ 0.7, -0.5,  0.5, -0.6],
        [-0.5,  0.7, -0.4,  0.6],
        [ 0.5, -0.6,  0.7, -0.4],
        [-0.6,  0.5, -0.5,  0.7],
    ]

    private func pick<T>(_ a: [[T]]) -> [T] { a[((seed % a.count) + a.count) % a.count] }

    /// 네 코너가 전부 `min(w,h)/2`로 클램프되는가 = 이 크기에서 캡슐로 퇴화하는가(§13.1).
    /// 반지름 지터의 최솟값까지 클램프될 때만 참이라, 일부만 클램프되는 비대칭 손맛은 그대로 둔다.
    static func degeneratesToCapsule(cornerRadius: CGFloat, in rect: CGRect, seed: Int) -> Bool {
        let cj = cornerJit[((seed % cornerJit.count) + cornerJit.count) % cornerJit.count]
        let maxR = min(rect.width, rect.height) / 2
        guard maxR > 0, let lowest = cj.min() else { return false }
        return cornerRadius * lowest >= maxR
    }

    func path(in rect: CGRect) -> Path {
        // §13.1 "완벽한 캡슐 금지" — pill 스케일 반지름이 들어오면 좌우가 정확한 반원인 캡슐이 된다.
        // 그 크기의 정본은 모서리를 잘라낸 8각(`PaperCutRect`)이므로 셰입 자체를 그쪽으로 라우팅한다.
        if Self.degeneratesToCapsule(cornerRadius: cornerRadius, in: rect, seed: seed) {
            return PaperCutRect(seed: seed).path(in: rect)
        }
        let cj = pick(Self.cornerJit)
        let eb = pick(Self.edgeBow)
        let maxR = min(rect.width, rect.height) / 2
        func r(_ i: Int) -> CGFloat { min(maxR, max(0, cornerRadius * cj[i])) }
        let (r0, r1, r2, r3) = (r(0), r(1), r(2), r(3))
        // 변 휨은 **그 변의 직선 구간 길이**에 비례한다 — 가위질이 길수록 선이 더 흔들린다.
        // 반환값은 컨트롤 오프셋이라 목표 편차의 2배다(2차 베지어는 컨트롤 오프셋의 절반만 부푼다).
        // 예전 값(하한 1.5를 오프셋에 그대로 적용)은 44pt 컨트롤에서 편차 0.5pt라 3x 렌더에서도
        // 지각되지 않았다. 하한 1.4·상한 4 = 편차 1.4~4pt로, 45pt 컨트롤에서도 손맛이 보인다.
        //
        // **상한은 짧은 변에도 걸린다.** 긴 변 기준만 두면 폭은 넓고 높이는 낮은 면(재료 뱃지 ≈150×40)의
        // 위·아래 변이 상한 4pt를 그대로 받아, 높이의 10%가 출렁이고 위아래가 반대로 휘면 실루엣이
        // 20%까지 일그러진다("자연스럽던 왜곡이 과해졌다"는 실사용 피드백이 이 구간이다).
        // 손으로 자른 종이도 **얇은 조각의 가장자리는 그만큼 크게 흔들리지 않는다** — 흔들림의 폭은
        // 가위질 길이뿐 아니라 조각의 두께에도 매인다. 큰 카드(짧은 변 ≥ 80pt)는 상한 4pt 그대로다.
        let bowCap = min(4, min(rect.width, rect.height) * 0.05)
        func ctl(_ span: CGFloat) -> CGFloat { min(bowCap, max(1.4, span * 0.05)) * 2 }
        let (ctlTop, ctlRight) = (ctl(rect.width - r0 - r1), ctl(rect.height - r1 - r2))
        let (ctlBottom, ctlLeft) = (ctl(rect.width - r3 - r2), ctl(rect.height - r0 - r3))
        let (minX, maxX, minY, maxY) = (rect.minX, rect.maxX, rect.minY, rect.maxY)

        var p = Path()
        p.move(to: CGPoint(x: minX + r0, y: minY))
        // top edge → TR corner
        p.addQuadCurve(to: CGPoint(x: maxX - r1, y: minY),
                       control: CGPoint(x: rect.midX, y: minY + eb[0] * ctlTop))
        p.addQuadCurve(to: CGPoint(x: maxX, y: minY + r1), control: CGPoint(x: maxX, y: minY))
        // right edge → BR corner
        p.addQuadCurve(to: CGPoint(x: maxX, y: maxY - r2),
                       control: CGPoint(x: maxX - eb[1] * ctlRight, y: rect.midY))
        p.addQuadCurve(to: CGPoint(x: maxX - r2, y: maxY), control: CGPoint(x: maxX, y: maxY))
        // bottom edge → BL corner
        p.addQuadCurve(to: CGPoint(x: minX + r3, y: maxY),
                       control: CGPoint(x: rect.midX, y: maxY - eb[2] * ctlBottom))
        p.addQuadCurve(to: CGPoint(x: minX, y: maxY - r3), control: CGPoint(x: minX, y: maxY))
        // left edge → TL corner
        p.addQuadCurve(to: CGPoint(x: minX, y: minY + r0),
                       control: CGPoint(x: minX + eb[3] * ctlLeft, y: rect.midY))
        p.addQuadCurve(to: CGPoint(x: minX + r0, y: minY), control: CGPoint(x: minX, y: minY))
        p.closeSubpath()
        return p
    }
}

/// 종이 다각 블롭 — 직선 변의 불규칙 다각형(스탬프·실루엣 백킹·재료 없는 칩 폴백).
/// `app/ScallopedCircle`의 고정-지터 기법을 루트 트리로 일반화.
struct PaperBlob: Shape {
    var sides: Int = 9
    var seed: Int = 0

    private static let radiusFactors: [CGFloat] = [1.00, 0.95, 1.00, 0.93, 0.99, 0.95, 1.00, 0.94, 0.98, 0.96]
    private static let angleJitter:   [CGFloat] = [0.00, 0.07, -0.05, 0.06, -0.04, 0.05, -0.06, 0.04, -0.03, 0.05]

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseR = min(rect.width, rect.height) / 2
        let n = max(3, sides)
        let start = -CGFloat.pi / 2 + CGFloat(seed) * 0.21
        var path = Path()
        for i in 0..<n {
            let rf = Self.radiusFactors[(i + seed) % Self.radiusFactors.count]
            let jit = Self.angleJitter[(i + seed) % Self.angleJitter.count]
            let angle = start + (CGFloat(i) / CGFloat(n)) * 2 * .pi + jit
            let pt = CGPoint(x: center.x + baseR * rf * cos(angle),
                             y: center.y + baseR * rf * sin(angle))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}

/// 와이드 종이컷 — 네 모서리를 비스듬히 **잘라낸**(chamfer) 길쭉한 8각형. `PaperBlob`(아이콘 버튼 9각형)과
/// 같은 "손으로 자른 종이" 계열. 정점에 미세 지터로 손맛. 와이드 CTA 버튼·면에 쓴다(직선 변 = octagon 일치).
struct PaperCutRect: Shape {
    var seed: Int = 0

    private static let jit: [[CGFloat]] = [
        [ 0.6, -0.5,  0.7, -0.4,  0.5, -0.6,  0.4, -0.5],
        [-0.5,  0.6, -0.4,  0.5, -0.6,  0.4, -0.5,  0.6],
        [ 0.5, -0.4,  0.6, -0.5,  0.4, -0.6,  0.5, -0.4],
    ]

    func path(in rect: CGRect) -> Path {
        let c = min(rect.height * 0.32, rect.width * 0.12)        // 모서리 잘림(끝 수직변 유지 = 깔끔한 8각형)
        let j = max(1.2, min(rect.width, rect.height) * 0.025)    // 손맛 지터(px)
        let js = Self.jit[((seed % Self.jit.count) + Self.jit.count) % Self.jit.count]
        let (minX, maxX, minY, maxY) = (rect.minX, rect.maxX, rect.minY, rect.maxY)
        let base: [CGPoint] = [
            CGPoint(x: minX + c, y: minY), CGPoint(x: maxX - c, y: minY),  // 윗변
            CGPoint(x: maxX, y: minY + c), CGPoint(x: maxX, y: maxY - c),  // 우변
            CGPoint(x: maxX - c, y: maxY), CGPoint(x: minX + c, y: maxY),  // 아랫변
            CGPoint(x: minX, y: maxY - c), CGPoint(x: minX, y: minY + c),  // 좌변
        ]
        var p = Path()
        for (i, pt) in base.enumerated() {
            let q = CGPoint(x: pt.x + js[i] * j, y: pt.y + js[(i + 3) % 8] * j)
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        p.closeSubpath()
        return p
    }
}

extension View {
    /// 종이 단면 — 얇은 외곽선(잘린 가장자리). 면 위에 겹쳐 종이 두께감을 준다.
    func paperEdge<S: Shape>(_ shape: S, tint: Color = ReffiColor.paperEdge, width: CGFloat = 1) -> some View {
        overlay(shape.stroke(tint, lineWidth: width))
    }
}

/// 결정적 의사난수(시드 LCG) — 종이 그레인이 매 프레임 바뀌지 않게 고정.
struct SeededGen {
    private var state: UInt64
    init(_ seed: UInt64) { state = seed &* 2862933555777941757 &+ 3037000493 }
    mutating func unit() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(UInt64(1) << 53)
    }
}

/// 종이 질감 — 결정적 미세 반점(밝음/어둠)을 옅게 흩뿌려 솔리드 면에 종이 그레인을 준다(그라데이션 아님).
/// 버튼·종이 면 위에 겹쳐서(클립 후) 사용. 색은 면색과 무관(overlay 블렌드).
struct PaperGrain: View {
    var seed: UInt64 = 7
    var strength: Double = 1.4

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededGen(seed)
            // 반점(그레인)
            let n = max(60, Int(size.width * size.height / 38))
            for _ in 0..<n {
                let x = CGFloat(rng.unit()) * size.width
                let y = CGFloat(rng.unit()) * size.height
                let s = 0.6 + CGFloat(rng.unit()) * 1.5
                let dark = rng.unit() > 0.46
                let a = (dark ? 0.1 : 0.11) * (0.5 + rng.unit()) * strength
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)),
                         with: .color((dark ? Color.black : Color.white).opacity(a)))
            }
            // 짧은 섬유 결 몇 가닥
            let fibers = max(6, Int(size.width * size.height / 1400))
            for _ in 0..<fibers {
                let x = CGFloat(rng.unit()) * size.width
                let y = CGFloat(rng.unit()) * size.height
                let len = 4 + CGFloat(rng.unit()) * 10
                let horiz = rng.unit() > 0.5
                var f = Path()
                f.move(to: CGPoint(x: x, y: y))
                f.addLine(to: CGPoint(x: x + (horiz ? len : len * 0.3), y: y + (horiz ? len * 0.2 : len)))
                ctx.stroke(f, with: .color((rng.unit() > 0.5 ? Color.black : Color.white).opacity(0.05 * strength)),
                           lineWidth: 0.6)
            }
        }
        .blendMode(.overlay)
        .allowsHitTesting(false)
    }
}
