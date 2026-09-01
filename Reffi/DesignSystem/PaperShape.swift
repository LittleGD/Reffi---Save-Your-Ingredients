import SwiftUI

/// 손으로 자른 종이(Hand-cut Paper) 셰이프 — 새 비주얼 언어의 핵심(§13).
/// 완벽한 원·사각 금지: 변·코너를 고정 시드로 미세하게 흩뜨려 손으로 오린 종이 느낌을 낸다.
/// 시드(seed)가 같으면 항상 같은 모양 → 레이아웃이 흔들리지 않는다(애니메이션 안정).

/// 종이 둥근 사각 — **뱃지·카드·입력 칸·큰 다이얼로그 면**. 변은 살짝 휘고 코너 반지름은 변마다 다르다.
///
/// **역할로 고르는 셰이프다. 크기로 고르지 마라.** §13.1의 2계층은 이렇다 — 행동을 받는 소형 면
/// (칩·필·드롭다운 트리거·토글·와이드 CTA)의 정본은 `PaperCutRect`(정사각에 가까우면
/// `PaperChipCut`)이고, 여기 `PaperRect`는 **읽는 면**(뱃지·카드·`fieldSurface`·`PaperDialog`)이다.
/// 둘은 기하로 갈리지 않는다: 재료 뱃지(≈150×34)와 정렬 칩(≈100×32)은 크기가 사실상 같은데
/// 정본이 서로 다르다. 그래서 이 프리미티브는 **역할을 추론하지 않는다** — 콜사이트가 어느
/// 계층인지 이름으로 선언해야 하고, 아래 캡슐 라우팅은 그 선언이 기하와 정면으로 모순될 때
/// (= 저자가 적은 반지름으로는 둥근 사각이 애초에 그려질 수 없을 때) 도는 안전장치일 뿐이다.
/// 칩이 둥글게 보인다면 이 파일이 아니라 그 칩의 콜사이트를 고쳐라.
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

    /// 저자가 적은 반지름이 짧은 변의 절반을 넘는가 = 이 크기에서 캡슐로 퇴화하는가(§13.1).
    ///
    /// **판정은 시드와 무관하다 — 그것이 이 식의 요점이다.** 예전엔 반지름 지터의 최솟값까지
    /// 클램프될 때만 참이었는데(`cornerRadius * lowest >= maxR`), 그 최솟값이 시드마다 0.84~0.88로
    /// 갈리는 바람에 **크기도 반지름도 같은 두 면이 시드만 다르다고 종(種)이 갈렸다**: `md`(12)에서
    /// 짧은 변 20.5pt면 seed 0은 둥근 사각(임계 20.16), seed 2는 8각(임계 21.12)이다. 셰이프가
    /// 각지느냐 둥그냐가 손맛 난수에 걸리면 그건 규칙이 아니라 우연이고, 오너가 화면에서 본
    /// "규칙 없이 섞여 있다"가 프리미티브 안에서 그대로 재현된다. 이제 임계는 콜사이트에서 읽고
    /// 예측할 수 있는 한 줄뿐이다.
    ///
    /// `seed` 인자는 호출부·테스트 계약을 위해 남기지만 판정에 **쓰지 않는다**. 다시 쓰지 마라.
    static func degeneratesToCapsule(cornerRadius: CGFloat, in rect: CGRect, seed: Int) -> Bool {
        let maxR = min(rect.width, rect.height) / 2
        guard maxR > 0 else { return false }
        return cornerRadius >= maxR
    }

    func path(in rect: CGRect) -> Path {
        // §13.1 "완벽한 캡슐 금지" — pill 스케일 반지름이 들어오면 좌우가 정확한 반원인 캡슐이 된다.
        // 그 크기의 정본은 모서리를 잘라낸 8각(`PaperCutRect`)이므로 셰입 자체를 그쪽으로 라우팅한다.
        // 라우팅이 **정사각에 가까운 면에서 도로 사각을 만들던 구멍**은 `PaperCutRect` 안에서 막았다
        // (그쪽 `c` 주석) — 캡슐을 막고 사각을 내놓으면 규칙이 스스로를 무효로 만든다.
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
///
/// **소형 행동 면(칩·필·트리거·토글)의 정본이 여기다**(§13.1). 다만 잘림이 높이·폭 양쪽에
/// 매여 있어 정사각에 가까운 칩에서는 얕아지므로, 그런 자리는 잘림을 짧은 변에만 매단 형제
/// `PaperChipCut`(`PaperDayChip.swift`)을 쓴다. 도장(`DDayStamp`)도 폭이 라벨 길이를 따라 흔들려
/// 그쪽 형제를 쓴다 — 근거는 그 파일의 다이(die) 주석.
struct PaperCutRect: Shape {
    var seed: Int = 0

    private static let jit: [[CGFloat]] = [
        [ 0.6, -0.5,  0.7, -0.4,  0.5, -0.6,  0.4, -0.5],
        [-0.5,  0.6, -0.4,  0.5, -0.6,  0.4, -0.5,  0.6],
        [ 0.5, -0.4,  0.6, -0.5,  0.4, -0.6,  0.5, -0.4],
    ]

    func path(in rect: CGRect) -> Path {
        // 모서리 잘림. 폭 12% 항은 **윗변·아랫변의 직선 구간을 지키는 상한**이지 잘림의 정의가 아니다 —
        // 그 항이 없으면 세로로 긴 면에서 잘림이 폭을 다 먹어 8각이 마름모로 뭉갠다. 그런데 정사각에
        // 가까운 면에서는 상한이 잘림 **자체**를 삼킨다: 30×30이면 min(9.6, 3.6) = 3.6pt라 모서리가
        // 잘린 것으로 읽히지 않고 그냥 사각이 된다(`PaperDayChip`이 형제 프리미티브를 따로 세운
        // 이유가 정확히 이 눌림이다 — 그 파일의 `PaperChipCut` 주석).
        //
        // 이건 단순한 미감 문제가 아니라 **규칙의 구멍**이었다: `PaperRect`의 캡슐 금지 라우팅이
        // 이 셰이프로 보내는 면 중에 정사각에 가까운 것이 있어서(pill 반지름을 받은 40×40 아바타·
        // 토글 슬롯 등), 상한이 그대로면 라우팅이 캡슐을 막고 **사각을 만든다**. §13.1이 한 줄에
        // 나란히 금지한 두 형태 중 하나를 피하려다 다른 하나에 착지하는 자리다.
        //
        // 그래서 짧은 변의 20%를 하한으로 깐다. 20%인 근거는 레포의 실패 사례다 — 30pt 면에서
        // 3.6pt(12%)는 사각으로 읽혔고, 51×31 토글 슬롯의 6.1pt(19.7%)는 8각으로 읽힌다.
        // 하한은 짧은 변에만 걸리므로 어떤 비율에서도 두 직선 구간이 각각 60% 이상 남는다.
        // **폭 ≥ 높이 × 1.67인 면(와이드 CTA·칩·탭 알약 = 지금 콜사이트의 대부분)은 상한이 하한보다
        // 크므로 잘림이 예전과 완전히 동일하다** — 이 하한은 눌리던 구간만 들어 올린다.
        let short = min(rect.width, rect.height)
        let c = max(min(rect.height * 0.32, rect.width * 0.12), short * 0.20)
        let j = max(1.2, short * 0.025)                           // 손맛 지터(px)
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

    /// 입력 필드 한 칸(§13.8) — 면(`field`) + 필드 단면(`paperEdgeField`) + 패딩 + 터치 타깃을 한 번에.
    ///
    /// `receiptSurface`가 영수증 카드에 한 것을 필드에 한다. 손으로 재조립하던 시절 같은 역할이
    /// canvas / paper / receipt+그레인 / 면 없음 **네 갈래**로 갈렸고, 갈린 축이 부모 면이었다 —
    /// 시트 캔버스 위 필드와 영수증 카드 위 필드가 서로 다른 종이를 골랐다. 면은 `ReffiColor.field`가
    /// 두 부모 사이에 앉아 해결하고, 여기서는 그 면에 딸린 패딩·히트·그레인까지 한 곳에 묶는다.
    ///
    /// **그레인을 넣는 이유**: 이 앱에서 매끈한 면은 시스템 컨트롤이고 종이는 전부 결을 갖는다.
    /// 옆 타일이 결을 가진 화면에서 필드만 매끈하면 인풋만 다른 재질(플라스틱)로 읽힌다(장보기 검색 선례).
    ///
    /// **카드 안의 행(row) 필드에는 쓰지 않는다** — 영수증 카드가 이미 "쓰는 종이"라 그 위에 또 한 장을
    /// 얹으면 종이가 겹친다. 그쪽은 면 없이 절취선(`ReffiRule(.ticket)`)이 행을 나눈다(§13.1).
    func fieldSurface(seed: Int = 0) -> some View {
        let shape = PaperRect(cornerRadius: ReffiRadius.md, seed: seed)
        return self
            .padding(.horizontal, ReffiSpace.s4)
            .padding(.vertical, ReffiSpace.s3)
            .frame(minHeight: ReffiChrome.tapMin)   // §7.3 터치 타깃
            .background {
                shape.fill(ReffiColor.field)
                    .overlay(PaperGrain(seed: UInt64(max(0, seed)) &+ 11, strength: 0.5).clipShape(shape))
                    .paperEdge(shape, tint: ReffiColor.paperEdgeField)
                    .compositingGroup()
            }
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
            // 결 밀도는 면적에 비례해야 한 재질로 읽힌다(42차) — 옛 하한(반점 60·섬유 6)은 48×48
            // 아래에서 항상 물려, 22pt 체크박스가 사양의 4.7배 반점·17배 섬유를 뒤집어쓰고
            // 큰 영수증(잔털)과 다른 종이(긁힌 자국)로 갈라졌다. 큰 면은 하한이 안 물려 그대로다.
            let n = max(16, Int(size.width * size.height / 38))
            for _ in 0..<n {
                let x = CGFloat(rng.unit()) * size.width
                let y = CGFloat(rng.unit()) * size.height
                let s = 0.6 + CGFloat(rng.unit()) * 1.5
                let dark = rng.unit() > 0.46
                let a = (dark ? 0.1 : 0.11) * (0.5 + rng.unit()) * strength
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)),
                         with: .color((dark ? Color.black : Color.white).opacity(a)))
            }
            // 짧은 섬유 결 몇 가닥 — 길이는 짧은 변의 40%를 넘지 않는다(42차): 절대 길이 4~14는
            // 22pt 상자에서 한 가닥이 폭의 64%를 가로질러 결이 아니라 흠집으로 읽혔다.
            let fibers = max(2, Int(size.width * size.height / 1400))
            let maxLen = min(size.width, size.height) * 0.4
            for _ in 0..<fibers {
                let x = CGFloat(rng.unit()) * size.width
                let y = CGFloat(rng.unit()) * size.height
                let len = min(4 + CGFloat(rng.unit()) * 10, maxLen)
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
