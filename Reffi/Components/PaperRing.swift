import SwiftUI

/// 종이로 오려 낸 고리 한 도막 — 12시에서 시계방향으로 도는 **각진**(직선 변) 띠.
/// `PaperBlob`(9각 블롭)의 문법을 원형 띠로 옮긴 것이다(§13.1): 정점 반지름을 고정 표로 미세하게
/// 흩뜨려 손으로 오린 가장자리를 만들고, 시드가 같으면 항상 같은 윤곽이 나온다.
///
/// **곡선이 아니다.** 매끈한 `Circle().trim()` 링은 iOS 스톡 진행 링의 얼굴이라, 같은 화면의 영수증·
/// 알약·블롭과 재질이 갈린다. 한 바퀴를 `facets`번 자른 폴리라인이라 확대해도 가위 자국이 남는다.
struct PaperRingArc: Shape {
    /// 시작 지점(0...1, 0 = 12시). 시계방향.
    var start: Double = 0
    /// 끝 지점(0...1). `end <= start`면 빈 패스(0%는 종이 조각을 만들지 않는다).
    var end: Double = 1
    /// 띠 두께(바깥 반지름에서 안쪽으로).
    var thickness: CGFloat = 18
    var seed: Int = 0
    /// 한 바퀴의 가위질 수 — 값이 클수록 원에 가깝고, 작을수록 다각형으로 읽힌다.
    /// 18이면 20°마다 꺾여 지름 156pt에서 변 하나가 27pt, 원 대비 처짐이 1.2pt다(눈에 보이는 직선).
    var facets: Int = 18

    /// 정점 반지름 배율 — 바깥/안쪽 가장자리가 **다른 표**를 써야 두 선이 나란히 출렁이지 않는다
    /// (같은 표를 쓰면 띠 두께가 일정해져 기계로 뽑은 링으로 되돌아간다).
    ///
    /// 표는 **한 바퀴에 정확히 맞물리는 저주파 파형**이다(사인 3개의 합). 이웃 칸끼리 값이 튀는
    /// 표(±2%가 매 칸 교대)를 쓰면 정점마다 뾰족한 톱니가 서서 "손으로 자른 종이"가 아니라 톱날이
    /// 된다 — 실제로 첫 캡처의 12시 정점이 이웃보다 2.7% 튀어나와 뿔처럼 보였다. 지금은 전체 진폭
    /// 4.1pt(R=78 기준)에 이웃 간 최대 단차 1.4pt다: 윤곽은 확실히 흔들리되 각 변은 서로 이어진다.
    private static let outerJit: [CGFloat] = [
        1.0167, 1.0135, 1.0119, 1.0131, 1.0143, 1.0125, 1.0084, 1.0054, 1.0050,
        1.0042, 0.9979, 0.9848, 0.9703, 0.9637, 0.9704, 0.9873, 1.0052, 1.0155,
    ]
    private static let innerJit: [CGFloat] = [
        1.0102, 1.0119, 1.0114, 1.0031, 0.9869, 0.9701, 0.9632, 0.9714, 0.9896,
        1.0066, 1.0137, 1.0111, 1.0057, 1.0042, 1.0074, 1.0112, 1.0119, 1.0104,
    ]

    /// 각도(0...1 회전) → 지터. **회전 비율로 인덱싱**하므로 `facets`를 바꿔도 표가 한 바퀴에
    /// 그대로 맞물리고(끊김 없음), 같은 각도는 언제나 같은 지터를 받는다 — 비율이 바뀌어도
    /// 가위 자국이 링을 따라 기어가지 않는다. `seed`는 그 파형을 통째로 돌린다.
    private static func jit(_ table: [CGFloat], turn: Double, seed: Int) -> CGFloat {
        let n = table.count
        let step = Int((turn * Double(n)).rounded()) &+ seed
        return table[((step % n) + n) % n]
    }

    func path(in rect: CGRect) -> Path {
        let span = end - start
        guard span > 0.0005, thickness > 0 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerR = min(rect.width, rect.height) / 2
        let innerR = max(outerR * 0.15, outerR - thickness)
        let f = Double(max(6, facets))
        let closed = span >= 1 - 0.0005

        // 정점은 **절대 각도 칸**(0/f, 1/f, …)에 박고 양 끝만 정확한 값에 둔다.
        var stops: [Double] = [start]
        let firstCell = Int((start * f).rounded(.down)) + 1
        let lastCell = Int((end * f).rounded(.up)) - 1
        if firstCell <= lastCell {
            for cell in firstCell...lastCell {
                let t = Double(cell) / f
                if t > start + 0.0001, t < end - 0.0001 { stops.append(t) }
            }
        }
        // 꽉 찬 고리에서 마지막 점은 첫 점과 같은 각도다 — 넣으면 길이 0의 변이 하나 생긴다.
        if !closed { stops.append(end) }

        func point(_ t: Double, radius: CGFloat, table: [CGFloat]) -> CGPoint {
            let angle = (t - 0.25) * 2 * .pi                      // 0 = 12시
            let r = radius * Self.jit(table, turn: t, seed: seed)
            return CGPoint(x: center.x + r * CGFloat(cos(angle)),
                           y: center.y + r * CGFloat(sin(angle)))
        }

        func loop(_ path: inout Path, radius: CGFloat, table: [CGFloat], reversed: Bool) {
            let order = reversed ? Array(stops.reversed()) : stops
            for (i, t) in order.enumerated() {
                let p = point(t, radius: radius, table: table)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
        }

        var path = Path()
        if closed {
            // **닫힌 서브패스 두 개**(바깥 시계방향 · 안쪽 반시계방향)라 non-zero 규칙으로 가운데가 뚫린다.
            // 한 폴리곤으로 잇지 않는 이유: 그러면 12시에 폭 0의 반지름 슬릿이 윤곽에 남고,
            // `paperEdge` 스트로크가 **그 자리에 실선을 그린다**(첫 캡처에서 보인 세로 이음매).
            // 꽉 찬 고리에는 잘린 단면이 없다 — 윤곽도 그 사실을 그대로 말해야 한다.
            loop(&path, radius: outerR, table: Self.outerJit, reversed: false)
            loop(&path, radius: innerR, table: Self.innerJit, reversed: true)
        } else {
            // 부분 호 — 양 끝의 반지름 방향 변은 **진짜 잘린 단면**이라 윤곽에 있어야 한다.
            for (i, t) in stops.enumerated() {
                let p = point(t, radius: outerR, table: Self.outerJit)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            for t in stops.reversed() {
                path.addLine(to: point(t, radius: innerR, table: Self.innerJit))
            }
            path.closeSubpath()
        }
        return path
    }
}

/// 비율 고리 — 종이 두 장이다. 아래는 한 바퀴 **트랙**(연한 면), 위는 값만큼의 **띠**(강조 잉크).
/// 그라데이션·글로우·그림자 없이 평평한 토큰 면 + `PaperGrain` + `paperEdge`로 끝낸다(§13.1).
///
/// 가운데는 호출부가 채운다 — 숫자·라벨의 문구와 위계는 화면마다 다르고, 컴포넌트가 그것까지
/// 정하면 두 번째 호출부에서 곧바로 갈라진다.
struct PaperRing<Center: View>: View {
    /// 채울 비율(0...1). 범위 밖 값은 잘라 낸다 — 비율이 고리 밖으로 나갈 수는 없다.
    let fraction: Double
    /// 값 띠의 잉크. 트랙은 항상 `sub`(면 위계상 콘텐츠보다 가벼워야 한다).
    let tint: Color
    var thickness: CGFloat = 18
    var seed: Int = 0
    @ViewBuilder var center: () -> Center

    var body: some View {
        let value = min(max(fraction, 0), 1)
        ZStack {
            band(PaperRingArc(start: 0, end: 1, thickness: thickness, seed: seed),
                 fill: ReffiColor.sub,
                 edge: ReffiColor.paperEdge,
                 grain: seed &+ 1)
            if value > 0 {
                band(PaperRingArc(start: 0, end: value, thickness: thickness, seed: seed),
                     fill: tint,
                     // 채도 면 위의 단면은 흰 톤이다(§13.1 `--paper-edge-onfill`).
                     edge: ReffiColor.paperEdgeOnFill,
                     grain: seed &+ 2)
            }
            center()
        }
    }

    private func band(_ shape: PaperRingArc, fill: Color, edge: Color, grain: Int) -> some View {
        shape.fill(fill)
            // 질감은 종이 안쪽에만 — 클립하지 않으면 사각 캔버스 전체에 반점이 깔린다.
            .overlay(PaperGrain(seed: UInt64(bitPattern: Int64(grain)), strength: 0.8).clipShape(shape))
            .paperEdge(shape, tint: edge)
            .compositingGroup()
    }
}
