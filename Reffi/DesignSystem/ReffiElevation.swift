import SwiftUI

/// 엘리베이션(§6). 평소엔 그림자 금지 — 떠 있는 요소와 카드 스택만 예외.
/// 이중 그림자(낮은 블러 10% + 높은 블러 5%), 색은 `shadowTint`(라이트=ink 틴트, 다크=순검정).
/// ink는 다크에서 크림으로 뒤집혀 그림자가 밝은 글로우가 되므로 그림자엔 절대 쓰지 않는다.
extension View {

    /// 떠 있는 요소(§6.2) — 부유 카드·시트. CSS `--shadow-1` 근사.
    func reffiShadow1() -> some View {
        self
            .shadow(color: ReffiColor.shadowTint.opacity(0.10), radius: 1.5, x: 0, y: 1)
            .shadow(color: ReffiColor.shadowTint.opacity(0.05), radius: 10, x: 0, y: 8)
    }

    /// 오린 영수증 한 장(§6.4) — 크림 캔버스에서 종이가 살짝 들린 만큼의 단일 그림자.
    /// 떠 있는 요소(`reffiShadow1`)보다 얕고, 스택 그림자와 달리 아래로 드리운다.
    /// 카드마다 손으로 적으면 같은 종이가 파일마다 다른 radius로 갈린다(실제로 5/4/3으로 갈렸다).
    func reffiShadowCard() -> some View {
        self.shadow(color: ReffiColor.shadowTint.opacity(0.06), radius: 5, x: 0, y: 2)
    }

    /// 촘촘한 면용 얕은 변형(§6.4) — 카드 스택처럼 종이가 겹쳐 있거나, 목록 행처럼
    /// 한 화면에 여러 장이 반복될 때. 같은 잉크 농도에서 blur만 한 단 낮춘다.
    func reffiShadowCardCompact() -> some View {
        self.shadow(color: ReffiColor.shadowTint.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    /// 카드 스택(§6.3) — 위쪽으로 드리워 파스텔 카드 경계를 만든다. CSS `--shadow-stack` 근사.
    func reffiShadowStack() -> some View {
        self
            .shadow(color: ReffiColor.shadowTint.opacity(0.10), radius: 3, x: 0, y: -2)
            .shadow(color: ReffiColor.shadowTint.opacity(0.05), radius: 10, x: 0, y: -6)
    }

    /// 슬램 임팩트(§6.2 예외·42차) — 도장이 내려앉는 **순간**에만 쓰는 깊은 단일 그림자.
    /// §6.2 상한(10%)을 넘는 유일한 값이라 무명 리터럴로 두지 않고 토큰으로 세운다 —
    /// 0.75초 조명이지 상시 엘리베이션이 아니다(`scrimFlash`와 같은 성격). 온보딩 완료 도장 전용.
    func reffiShadowSlam() -> some View {
        self.shadow(color: ReffiColor.shadowTint.opacity(0.18), radius: 14, x: 0, y: 8)
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
