import SwiftUI

/// 영수증/티켓 셰이프 — 상·하 톱니(절취) 엣지. 좌우는 곧다.
///
/// 앱의 시그니처 종이 어휘라 피처가 아니라 디자인 시스템에 산다(`PaperShape` 옆).
/// 톱니 크기는 눈대중 리터럴 대신 `ReffiTooth`(chip/card/ticket)를 경유한다.
///
/// `seed`는 톱니의 **위상**을 어긋나게 한다 — 한 화면에 영수증이 여러 장 겹칠 때 절취선이 자로 잰 듯
/// 같은 자리에서 시작하면 오려 낸 종이가 아니라 찍어 낸 패턴으로 읽힌다. `PaperRect`·`PaperBlob`의
/// 시드 규약과 같다: 시드가 같으면 항상 같은 모양이라 레이아웃이 흔들리지 않는다. `seed: 0`은 위상 0
/// (= 시드를 쓰지 않던 시절과 완전히 같은 그림)이다.
struct ReceiptShape: Shape {
    var tooth: CGFloat = ReffiTooth.ticket
    var seed: Int = 0

    /// 톱니 한 칸을 4등분한 위상표 — 위·아래가 같은 자리에서 시작하지 않게 한 칸 밀어 쓴다.
    private static let phaseStep: [CGFloat] = [0, 0.5, 0.25, 0.75]

    private func phase(_ i: Int, _ t: CGFloat) -> CGFloat {
        guard seed != 0 else { return 0 }   // 시드 미지정 = 위상 0(종전 그림 그대로)
        let table = Self.phaseStep
        return t * table[((seed + i) % table.count + table.count) % table.count]
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let t = max(4, tooth)
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + t))
        // 상단 톱니 (좌→우) — 첫 칸만 위상만큼 짧게 시작해 리듬 전체를 민다.
        var x = rect.minX
        var up = true
        var lead = phase(0, t)
        while x < rect.maxX {
            let nx = min(x + (lead > 0 ? lead : t), rect.maxX)
            lead = 0
            p.addLine(to: CGPoint(x: nx, y: rect.minY + (up ? 0 : t)))
            x = nx; up.toggle()
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - t))
        // 하단 톱니 (우→좌) — 위상표에서 한 칸 밀어 상·하가 대칭으로 보이지 않게.
        up = true
        x = rect.maxX
        lead = phase(1, t)
        while x > rect.minX {
            let nx = max(x - (lead > 0 ? lead : t), rect.minX)
            lead = 0
            p.addLine(to: CGPoint(x: nx, y: rect.maxY - (up ? 0 : t)))
            x = nx; up.toggle()
        }
        p.closeSubpath()
        return p
    }
}

/// 영수증 면이 얼마나 들려 있나(§6.4) — 카드 그림자 토큰과 1:1.
enum ReffiPaperLift {
    /// 캔버스에 붙은 종이 — 빈 상태·검색 결과 없음처럼 조용한 안내 면.
    case flat
    /// 오린 영수증 한 장(`reffiShadowCard`).
    case card
    /// 떠 있는 요소(`reffiShadow1`) — 온보딩 질문 카드·로그인 카드처럼 화면에 한 장만 뜨는 면.
    case floating
}

extension View {

    /// 흰 영수증 카드 한 장(§13.8) — 톱니 면 + 종이 헤어라인 + 엘리베이션을 한 번에 얹는다.
    ///
    /// **세로 패딩을 톱니에서 계산하는 게 이 모디파이어의 핵심**이다. 톱니는 면 안쪽으로 파고들어
    /// 그만큼 콘텐츠 여백을 먹는데, 그 보정을 호출부가 손으로 적어 온 결과 같은 카드가 s5+7 / s5+3 /
    /// s5로 갈렸다(=톱니를 7로 정해 놓고 보정은 3만 준 카드가 셋). 여기서 `s5 + tooth`로 한 번만
    /// 계산하면 톱니를 바꿔도 여백이 따라온다.
    ///
    /// 헤더 행이 따로 있는 카드(`ReceiptCard`·`FridgeCard`)는 위·아래 보정이 비대칭이라 자체
    /// 프리셋으로 남는다 — 그 프리셋도 톱니와 엘리베이션은 이 토큰들을 쓴다.
    /// `seed`는 톱니 위상 변주다 — 한 화면에 영수증이 여러 장 겹칠 때만 의미가 있고, 기본 0은
    /// 위상 0(종전 그림 그대로)이다.
    func receiptSurface(tooth: CGFloat = ReffiTooth.card,
                        seed: Int = 0,
                        alignment: Alignment = .leading,
                        elevated: ReffiPaperLift = .card) -> some View {
        modifier(ReceiptSurface(tooth: tooth, seed: seed, alignment: alignment, lift: elevated))
    }
}

private struct ReceiptSurface: ViewModifier {
    let tooth: CGFloat
    let seed: Int
    let alignment: Alignment
    let lift: ReffiPaperLift

    func body(content: Content) -> some View {
        let shape = ReceiptShape(tooth: tooth, seed: seed)
        let surface = content
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s5 + tooth)   // 톱니 인셋 보정
            .frame(maxWidth: .infinity, alignment: alignment)
            .background(ReffiColor.receipt, in: shape)
            .paperEdge(shape)
            // **영수증 한 장은 그림자도 한 장 몫만 드리운다.**
            //
            // SwiftUI의 `.shadow`는 붙인 뷰를 하나로 합쳐서 드리우는 게 아니라 **자식 프리미티브마다
            // 따로** 드리운다(합쳐서 한 번 드리우게 하려면 그 전에 합성 그룹으로 묶어야 한다).
            // 그래서 아래 `lift`의 그림자가 카드 윤곽뿐 아니라 **카드 안에서 면을 가진 자식 전부**에
            // 각자 그림자를 달아 주고 있었다. To buy 메모 행이 그 값을 정면으로 받았다: 행 얼굴은
            // 밀기용 불투명 면이라(21차 `1834785`, 뒤의 빨간 조각을 가리는 유일한 수단) 카드와 **같은
            // `receipt` 토큰**인데도, 자기 그림자를 얻는 순간 영수증 위에 뜬 흰 카드로 읽혔다
            // (사용자 제보 "리스트에 쉐도우가 있어서 어색해"). 실측: 행 얼굴과 카드 얼굴의 픽셀은
            // 같은 (251,250,247)인데 행 아래로 폭 ≈9pt의 어두운 띠(249 → 241)가 깔려 있었다.
            //
            // 여기서 묶으면 그림자는 **영수증 윤곽 한 번**만 그려진다. 덤으로 긴 카드(타임라인)에서
            // 자식 수만큼 돌던 그림자 필터가 한 번으로 줄어든다.
            .compositingGroup()

        switch lift {
        case .flat:     surface
        case .card:     surface.reffiShadowCard()
        case .floating: surface.reffiShadow1()
        }
    }
}

/// 가로 점선/구분선용 1px 라인.
struct HLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
