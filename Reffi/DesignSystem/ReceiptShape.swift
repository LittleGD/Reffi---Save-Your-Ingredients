import SwiftUI

/// 영수증/티켓 셰이프 — 상·하 톱니(절취) 엣지. 좌우는 곧다.
///
/// 앱의 시그니처 종이 어휘라 피처가 아니라 디자인 시스템에 산다(`PaperShape` 옆).
/// 톱니 크기는 눈대중 리터럴 대신 `ReffiTooth`(chip/card/ticket)를 경유한다.
struct ReceiptShape: Shape {
    var tooth: CGFloat = ReffiTooth.ticket

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let t = max(4, tooth)
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + t))
        // 상단 톱니 (좌→우)
        var x = rect.minX
        var up = true
        while x < rect.maxX {
            let nx = min(x + t, rect.maxX)
            p.addLine(to: CGPoint(x: nx, y: rect.minY + (up ? 0 : t)))
            x = nx; up.toggle()
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - t))
        // 하단 톱니 (우→좌)
        up = true
        x = rect.maxX
        while x > rect.minX {
            let nx = max(x - t, rect.minX)
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
    func receiptSurface(tooth: CGFloat = ReffiTooth.card,
                        alignment: Alignment = .leading,
                        elevated: ReffiPaperLift = .card) -> some View {
        modifier(ReceiptSurface(tooth: tooth, alignment: alignment, lift: elevated))
    }
}

private struct ReceiptSurface: ViewModifier {
    let tooth: CGFloat
    let alignment: Alignment
    let lift: ReffiPaperLift

    func body(content: Content) -> some View {
        let shape = ReceiptShape(tooth: tooth)
        let surface = content
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s5 + tooth)   // 톱니 인셋 보정
            .frame(maxWidth: .infinity, alignment: alignment)
            .background(ReffiColor.receipt, in: shape)
            .paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))

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
