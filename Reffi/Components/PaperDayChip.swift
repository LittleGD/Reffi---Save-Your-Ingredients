import SwiftUI

/// 하루를 오려 낸 **종이 칩 한 조각** — History 히어로의 주간 칩 행이 쓰는 칸(§13.10).
///
/// **왜 칩인가**: 히어로는 두 가지를 동시에 말해야 한다 — 이번 주 한 개의 비율과 7일 각각의 값.
/// 연속 호(고리)는 앞의 하나만 담을 수 있어 뒤의 일곱을 위해 둘째 그래픽을 붙여야 했다. 하루는
/// 셀 수 있는 **낱개 사건**이라 낱개 마크가 개념과 맞고(congruence), 낱개가 일곱뿐일 때는 마크
/// 하나짜리 유닛 차트가 회상률에서도 유리하다. 무엇보다 이 앱의 재질이 이미 오려 낸 종이라,
/// "하루 = 종이 한 조각"은 은유가 아니라 그냥 사실로 읽힌다.
///
/// **채널이 셋이라 한 칸이 세 가지를 말한다**:
/// - **면색** = 먹었는가(신선 초록) / 아무 일도 없었는가(그냥 종이) / 아직 오지 않았는가(점선, 면 없음)
/// - **안의 숫자 + 체크 도장** = 그날 먹은 개수
/// - **모서리의 빨간 조각** = 그날 버린 개수(먹은 날에도 붙는다 — 하루는 둘 다일 수 있다)
///
/// **면색과 배지가 서로 다른 채널인 것이 요점**이다: 버림을 면색으로 표현하면 먹고 버린 날에
/// 두 값 중 하나를 버려야 한다.
///
/// 접근성 라벨은 **호출부가** 요일 이름과 함께 붙인다(칩 혼자서는 "무슨 요일"인지 모른다).
/// 이 뷰는 그리기만 하고 라벨·트레잇을 스스로 두지 않는다.
struct PaperDayChip: View {
    /// 그날 먹은 개수. 0이면 숫자도 체크도 서지 않는다 — 일곱 칸에 0이 늘어서면 노이즈다.
    let eaten: Int
    /// 그날 버린 개수. 0보다 크면 모서리에 빨간 조각이 붙는다.
    let tossed: Int
    /// 아직 오지 않은 날 — 자리는 지키되 판정이 없다(0은 "안 먹었다"는 판정이라 쓰지 않는다).
    /// **아직 오려 내지 않은 종이**로 그린다(점선 외곽선, 면 없음) — 근거는 아래 `face` 참고.
    var isFuture: Bool = false
    /// 윤곽·질감 시드. **칸마다 달라야** 일곱 조각이 찍어 낸 패턴이 아니라 손으로 오린 종이가 된다.
    var seed: Int = 0
    var width: CGFloat = 38
    var height: CGFloat = 44

    /// 짧은 변 — 안쪽 글자·배지 치수를 전부 여기서 뽑아 칩 크기를 바꿔도 비율이 유지된다.
    private var side: CGFloat { min(width, height) }

    var body: some View {
        face
            .frame(width: width, height: height)
            // 배지는 칩 **밖으로 조금 걸친다** — 위에 얹으면 종이 한 장에 인쇄된 무늬로 읽히고,
            // 걸쳐야 나중에 덧붙인 두 번째 조각으로 읽힌다.
            .overlay(alignment: .topTrailing) {
                if !isFuture, tossed > 0 {
                    tossedBadge.offset(x: side * 0.10, y: -side * 0.10)
                }
            }
    }

    /// 칩 얼굴 — 세 상태 중 하나. 그라데이션·그림자 없이 평평한 토큰 면 + 그레인 + 헤어라인(§13.1).
    @ViewBuilder
    private var face: some View {
        let shape = PaperChipCut(seed: seed)
        if isFuture {
            // 아직 오지 않은 날 = **아직 오려 내지 않은 종이**. 자리는 지키되(빈 칸이면 주가 짧아
            // 보인다) 면을 채우지 않고 점선 재단선만 둔다.
            //
            // 20차의 연한 면(`sub` 0.55)을 물린 근거는 실측이다: 다크에서 `sub`(L .32)와
            // `paper`(L .33)가 사실상 같은 값이라, 밴드 위에 얹으면 조용한 날 칩과 앞으로 올 날 칩의
            // **면 대 면 대비가 1.02:1**이었다(라이트는 1.18). 두 칸이 구분되지 않으면 "어디가
            // 지금인가"까지 함께 사라진다 — 이 문법에서 오늘은 **오려 낸 마지막 칸**으로 읽히기 때문이다.
            // 밝기 차를 더 벌리는 대신 **범주를 바꿨다**: 채운 종이 vs 아직 안 자른 종이는 스킴과
            // 무관하게 갈리고, 재단선은 이 앱이 이미 쓰는 기호다(`ReffiRule(.receipt)`).
            shape.stroke(ReffiColor.ink.opacity(0.18),
                         style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        } else if eaten > 0 {
            ZStack {
                shape.fill(ReffiColor.fresh)
                    .overlay(PaperGrain(seed: UInt64(bitPattern: Int64(90 &+ seed)), strength: 0.8)
                        .clipShape(shape))
                    // 채도 면 위의 단면은 흰 톤이다(§13.1 `--paper-edge-onfill`).
                    .paperEdge(shape, tint: ReffiColor.paperEdgeOnFill)
                    .compositingGroup()
                eatenMark
            }
        } else {
            shape.fill(ReffiColor.paper).paperEdge(shape)
        }
    }

    /// 먹은 날의 각인 — 체크 도장 + 개수.
    ///
    /// 숫자만 두면 초록 면이 무슨 뜻인지 칩 안에서는 알 수 없고(캡션까지 내려가야 한다), 체크만
    /// 두면 "몇 개"가 사라진다. 잉크는 `ink` 한 색이다 — `freshDark`는 `fresh` 면 위에서 3.9:1로
    /// 4.5:1을 못 넘지만(실측), `ink`는 두 스킴 모두 `fresh` 면 위에서 10.8:1 / 6.7:1이다.
    /// 두 토큰이 라이트/다크에서 **함께 뒤집히기 때문에** 한 색으로 양쪽이 성립한다.
    private var eatenMark: some View {
        VStack(spacing: 1) {
            ReffiIcon.check.reffi(side * 0.24, .bold)
            Text(eaten.formatted()).font(.reffiNum(.body))
        }
        .foregroundStyle(ReffiColor.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, 2)
    }

    /// 버린 개수 — 모서리에 덧붙인 빨간 조각.
    ///
    /// 면이 `urgentLight`가 아니라 **`urgentDark`인 이유는 실측이다**: `urgentLight`는 `fresh` 칩
    /// 위에서 면 대 면 대비가 1.16:1(라이트) / 1.69:1(다크)이라 초록 칩에 얹으면 조각의 경계가
    /// 사라진다. `urgentDark`는 4.01 / 3.39로 확실히 갈리고, 그 위 글자(`onInk`)는 5.9 / 7.1이다.
    ///
    /// 그레인은 올리지 않는다 — 반점이 질감으로 읽히려면 면적이 필요한데(38pt 칩 ≈ 1,672pt² 대
    /// 배지 ≈ 280pt²) 이 크기에서는 무늬가 아니라 얼룩이 된다.
    private var tossedBadge: some View {
        let shape = PaperChipCut(seed: seed &+ 17)
        // `✕`(U+2715)가 아니라 `×`(U+00D7)다 — 후자는 Latin-1이라 Pretendard가 확실히 덮는다.
        // 폰트가 빠지면 시스템 폴백으로 글꼴이 이 조각에서만 갈린다.
        return Text(verbatim: "×\(tossed.formatted())")
            .font(.reffiStamp(side * 0.26, relativeTo: .caption2))
            .monospacedDigit()
            .foregroundStyle(ReffiColor.onInk)
            .lineLimit(1)
            .padding(.horizontal, side * 0.11)
            .padding(.vertical, side * 0.04)
            .background(shape.fill(ReffiColor.urgentDark))
            .paperEdge(shape, tint: ReffiColor.paperEdgeOnFill)
            .compositingGroup()
    }
}

/// 칩 윤곽 — 네 모서리를 비스듬히 **잘라낸** 8각형에 정점 지터. `PaperCutRect`(와이드 CTA)의 형제이고
/// 계수만 다르다: 그쪽은 `min(높이 32%, 폭 12%)`이라 정사각에 가까운 칩에서는 폭 쪽이 4pt대로 눌려
/// 8각이 아니라 그냥 사각으로 읽힌다. 여기서는 잘림을 **짧은 변에 비례**시켜 어떤 칩 크기에서도
/// 모서리가 같은 비중으로 잘린다.
///
/// 지터를 표가 아니라 `SeededGen`으로 뽑는 이유: 칩은 일곱 칸이 **서로 달라야** 하는데(같으면 찍어 낸
/// 패턴이 된다) 고정 표는 칸 수가 표 길이를 넘는 순간 조용히 되풀이된다. 시드 하나면 몇 칸이든 갈린다.
struct PaperChipCut: Shape {
    var seed: Int = 0

    /// 모서리 잘림 — 짧은 변의 26%. 38pt 칩에서 9.9pt라 손으로 자른 각이 확실히 읽힌다.
    private static let chamfer: CGFloat = 0.26
    /// 정점 지터 폭(±) — 짧은 변의 4.5%(하한 0.8pt). 38pt에서 ±1.7pt: 윤곽은 흔들리되 변은 이어진다.
    private static let jitter: CGFloat = 0.045

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let c = side * Self.chamfer
        let j = max(0.8, side * Self.jitter)
        let (minX, maxX, minY, maxY) = (rect.minX, rect.maxX, rect.minY, rect.maxY)
        let base: [CGPoint] = [
            CGPoint(x: minX + c, y: minY), CGPoint(x: maxX - c, y: minY),  // 윗변
            CGPoint(x: maxX, y: minY + c), CGPoint(x: maxX, y: maxY - c),  // 우변
            CGPoint(x: maxX - c, y: maxY), CGPoint(x: minX + c, y: maxY),  // 아랫변
            CGPoint(x: minX, y: maxY - c), CGPoint(x: minX, y: minY + c),  // 좌변
        ]
        // 시드는 홀수로 흩는다 — `SeededGen`은 LCG라 이웃한 짝수 시드가 첫 몇 값을 비슷하게 낸다.
        var rng = SeededGen(UInt64(bitPattern: Int64(seed &* 2 &+ 1)))
        var p = Path()
        for (i, pt) in base.enumerated() {
            let q = CGPoint(x: pt.x + CGFloat(rng.unit() - 0.5) * 2 * j,
                            y: pt.y + CGFloat(rng.unit() - 0.5) * 2 * j)
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        p.closeSubpath()
        return p
    }
}
