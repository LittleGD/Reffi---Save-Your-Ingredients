import SwiftUI

/// 엘리베이션(§6). 평소엔 그림자 금지 — 떠 있는 요소와 카드 스택만 예외.
/// 이중 그림자(낮은 블러 10% + 높은 블러 5%), 색은 `shadowTint`(라이트=ink 틴트, 다크=순검정).
/// ink는 다크에서 크림으로 뒤집혀 그림자가 밝은 글로우가 되므로 그림자엔 절대 쓰지 않는다.
///
/// **모든 그림자는 합성 그룹 뒤에 온다 — 그 규칙을 콜사이트가 아니라 토큰이 진다.**
/// SwiftUI의 `.shadow`는 붙인 뷰를 하나로 합쳐서 드리우지 않고 **자식 프리미티브마다 따로**
/// 드리운다. 그룹 없이 컨테이너에 그림자를 걸면 카드 안의 행·글자·도장·실루엣이 저마다 어두운
/// 번짐을 얻고, 그 번짐이 **형제의 불투명 면 위에서 끊겨** 카드 안에 없는 경계를 만든다
/// (실측 근거는 `ReceiptShape`의 `ReceiptSurface` 주석 — 같은 픽셀색 행 아래에 폭 ≈9pt의
/// 249 → 241 띠). "그림자가 컨테이너 밖에서 뚝 끊겨 층이 생긴다"고 읽히던 것이 이 현상이다.
///
/// **왜 콜사이트 스윕이 아니라 토큰 안인가.** 이 결함은 그림자 콜사이트 스무 곳 남짓에 흩어져
/// 있었고 그중 여덟 곳만 손으로 `.compositingGroup()`을 달아 고쳐 둔 상태였다 — 규칙을 콜사이트에
/// 맡기면 "빠뜨릴 수 있는 규칙"이 되고, 실제로 절반 넘게 빠져 있었다. 여기서 묶으면 새로 생기는
/// 카드는 아무것도 하지 않아도 옳다. **`reffiShadow*` 밖에서 `.shadow`를 직접 부르지 마라** —
/// 그 순간 이 보증이 사라진다. 이미 손으로 달아 둔 `.compositingGroup()`은 중복이 되지만 무해하다
/// (평평한 레이어를 한 번 더 묶을 뿐이다).
///
/// **값은 그대로 둔다.** 자식마다 겹쳐 드리우던 그림자가 한 장으로 줄면 같은 α라도 지금까지보다
/// **옅게 보인다** — 그건 값이 얕아진 게 아니라 여태 진해 보이던 쪽이 버그였다는 뜻이다. 배경이
/// 단색 크림(`PaperCanvasBackground`)으로 평탄해진 것도 같은 방향이다: 블롭 얼룩이 그림자를
/// 삼키거나 부풀리던 자리가 없어져 바탕이 균일해진다. 그래도 얕게 느껴지면 눈이 아니라 **3x 캡처
/// 실측**으로 판단해서 α를 올린다(§2.6 "대비 수치는 측정값으로"와 같은 규율).
extension View {

    /// 떠 있는 요소(§6.2) — 부유 카드·시트. CSS `--shadow-1` 근사.
    func reffiShadow1() -> some View {
        modifier(GroupedShadow(near: ShadowLayer(alpha: 0.10, radius: 1.5, y: 1),
                               far:  ShadowLayer(alpha: 0.05, radius: 10,  y: 8)))
    }

    /// 오린 영수증 한 장(§6.4) — 크림 캔버스에서 종이가 살짝 들린 만큼의 단일 그림자.
    /// 떠 있는 요소(`reffiShadow1`)보다 얕고, 스택 그림자와 달리 아래로 드리운다.
    /// 카드마다 손으로 적으면 같은 종이가 파일마다 다른 radius로 갈린다(실제로 5/4/3으로 갈렸다).
    func reffiShadowCard() -> some View {
        modifier(GroupedShadow(near: ShadowLayer(alpha: 0.06, radius: 5, y: 2)))
    }

    /// 촘촘한 면용 얕은 변형(§6.4) — 카드 스택처럼 종이가 겹쳐 있거나, 목록 행처럼
    /// 한 화면에 여러 장이 반복될 때. 같은 잉크 농도에서 blur만 한 단 낮춘다.
    func reffiShadowCardCompact() -> some View {
        modifier(GroupedShadow(near: ShadowLayer(alpha: 0.06, radius: 4, y: 2)))
    }

    /// 카드 스택(§6.3) — 위쪽으로 드리워 파스텔 카드 경계를 만든다. CSS `--shadow-stack` 근사.
    ///
    /// **지금 호출부가 없다.** 겹쳐 쌓이는 냉장고 카드 더미는 아래로 드리우는
    /// `reffiShadowCardCompact`를 쓴다. 그래도 남기는 이유는 §6.3이 스케일에 이 단을 세워 두었고
    /// 위로 드리우는 그림자가 앱에서 여기 하나뿐이라서다 — 지우려면 §6.3과 `--shadow-stack`을
    /// 같이 지운다(코드만 지우면 MD·HTML이 없는 토큰을 가리킨다).
    func reffiShadowStack() -> some View {
        modifier(GroupedShadow(near: ShadowLayer(alpha: 0.10, radius: 3,  y: -2),
                               far:  ShadowLayer(alpha: 0.05, radius: 10, y: -6)))
    }

    /// 슬램 임팩트(§6.2 예외·42차) — 도장이 내려앉는 **순간**에만 쓰는 깊은 단일 그림자.
    /// §6.2 상한(10%)을 넘는 유일한 값이라 무명 리터럴로 두지 않고 토큰으로 세운다 —
    /// 0.75초 조명이지 상시 엘리베이션이 아니다(`scrimFlash`와 같은 성격). 온보딩 완료 도장 전용.
    /// 앱에서 가장 깊은 그림자라 자식 분리가 가장 잘 보이는 자리이기도 하다(도장은 면·글자·테두리가
    /// 겹친 조각이다) — 그룹을 지나는 것이 여기서 특히 중요하다.
    func reffiShadowSlam() -> some View {
        modifier(GroupedShadow(near: ShadowLayer(alpha: 0.18, radius: 14, y: 8)))
    }
}

/// 그림자 한 단의 값 — 색은 언제나 `shadowTint`라 여기 담지 않는다(§6: 그림자에 다른 색을 쓰지 않는다).
/// x는 항상 0이다 — 조명이 정면 위에서 온다는 것이 이 디자인의 전제라, 옆으로 미는 그림자는 없다.
private struct ShadowLayer {
    let alpha: Double
    let radius: CGFloat
    let y: CGFloat
}

/// **엘리베이션 토큰의 공통 토대** — 합성 그룹으로 묶은 뒤에만 그림자를 드리운다.
/// 위 `reffiShadow*`가 전부 여기를 지나므로, 그룹을 빠뜨린 그림자가 새로 생길 수 없다.
/// 단이 하나인 토큰(`far == nil`)은 두 번째 `.shadow`를 아예 붙이지 않는다 — α 0짜리 그림자도
/// 렌더 패스는 그대로 돈다.
private struct GroupedShadow: ViewModifier {
    let near: ShadowLayer
    var far: ShadowLayer? = nil

    @ViewBuilder func body(content: Content) -> some View {
        let lifted = content
            .compositingGroup()
            .shadow(color: ReffiColor.shadowTint.opacity(near.alpha),
                    radius: near.radius, x: 0, y: near.y)
        if let far = self.far {
            lifted.shadow(color: ReffiColor.shadowTint.opacity(far.alpha),
                          radius: far.radius, x: 0, y: far.y)
        } else {
            lifted
        }
    }
}

/// z-레이어 스케일(§6.5) 중 **iOS가 실제로 쓰는 한 단**.
///
/// CSS 쪽 5단(`--z-base`/`sticky`/`dropdown`/`modal`/`toast`)을 그대로 옮겨 왔지만, 네이티브에서
/// 쌓임 순서를 `zIndex`로 정하는 자리는 드롭다운 하나뿐이다 — modal·toast는 `sheet`/`fullScreenCover`
/// 같은 **프레젠테이션 계층**이, sticky는 `safeAreaInset`/`overlay`가 각각 자기 규칙으로 세운다.
/// 안 쓰는 상수를 남겨 두면 다음 사람이 `.zIndex(ReffiZ.modal)`로 시트를 세우려다 같은 계층 안에서만
/// 도는 숫자라는 걸 뒤늦게 알게 된다. **스케일 정본은 §6.5 문서**고, 여기는 실사용분만 둔다.
enum ReffiZ {
    /// 드롭다운·팝오버 — 루트 오버레이 안에서 스크롤 콘텐츠 위로 올린다(`PaperDropdown`).
    static let dropdown: Double = 1000
}
