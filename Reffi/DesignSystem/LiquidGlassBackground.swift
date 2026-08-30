import SwiftUI

/// 리퀴드글래스 배경(§13.2) — 크림 캔버스 위 부드러운 컬러 블롭 + 글래스 프로스트.
/// Main·Fridge·History·쇼핑이 공유해 한 몸으로 보이게 한다. `accent`는 가장 임박한 재료의
/// 신선도색, `accentDeep`은 세 번째 블롭(기본은 accent 저강도).
///
/// **라이트/다크 분기를 뷰가 들지 않는다**(§2.8·42차) — 옛 구현은 앱에서 유일하게 뷰 안에서
/// `colorScheme`을 읽어 무명 알파 여섯을 삼항으로 갈랐고, 그 값들이 MD·HTML 어디에도 없어
/// 3자 대조의 사각지대였다(하단 시노는 문서에 존재 자체가 없었다). 알파는 전부
/// `ReffiColor.bgBlob*`·`bgSheen`·`bgSheenBottom` 적응 토큰이 쥔다 — 다크에서 블롭을 내리는
/// 이유(어두운 캔버스 위에선 같은 값이 네온처럼 타올라 종이 대비를 잡아먹는다)는 토큰 주석에.
struct LiquidGlassBackground: View {
    var accent: Color = ReffiColor.fresh
    var accentDeep: Color? = nil

    /// Reduce Transparency(42차·F59) — 프로스트는 시스템 재질이라 스스로 불투명해지지만
    /// 그 아래 블러 블롭 3벌은 손으로 그린 것이라 설정에 반응하지 않았다. 켜면 블롭·시노를
    /// 걷고 캔버스 단색만 남긴다(§7.4 모션 축소와 같은 태도의 투명도판).
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            ReffiColor.canvas
            if !reduceTransparency {
                Circle().fill(ReffiColor.bgBlobStrong(accent))
                    .frame(width: 300, height: 300).blur(radius: 80)
                    .offset(x: -130, y: -180)
                Circle().fill(ReffiColor.bgBlobMid(ReffiColor.blue))
                    .frame(width: 260, height: 260).blur(radius: 90)
                    .offset(x: 140, y: 60)
                Circle().fill(ReffiColor.bgBlobSoft(accentDeep ?? accent))
                    .frame(width: 220, height: 220).blur(radius: 80)
                    .offset(x: 70, y: 300)
                // 글래스 프로스트(.ultraThinMaterial·glassEffect)는 시스템이 스킴에 맞춰 자동 적응한다.
                glassFrost
                LinearGradient(colors: [ReffiColor.bgSheen, .clear, ReffiColor.bgSheenBottom],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder private var glassFrost: some View {
        if #available(iOS 26.0, *) {
            Rectangle().fill(.clear).glassEffect(.regular, in: Rectangle())
        } else {
            Rectangle().fill(.ultraThinMaterial)
        }
    }
}
