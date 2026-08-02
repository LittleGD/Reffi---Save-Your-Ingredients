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

    /// 카드 스택(§6.3) — 위쪽으로 드리워 파스텔 카드 경계를 만든다. CSS `--shadow-stack` 근사.
    func reffiShadowStack() -> some View {
        self
            .shadow(color: ReffiColor.shadowTint.opacity(0.10), radius: 3, x: 0, y: -2)
            .shadow(color: ReffiColor.shadowTint.opacity(0.05), radius: 10, x: 0, y: -6)
    }
}

/// z-레이어 스케일(§6.4).
enum ReffiZ {
    static let base: Double = 0
    static let sticky: Double = 100   // 스티키 헤더·하단 액션바·＋ 버튼
    static let dropdown: Double = 1000
    static let modal: Double = 2000
    static let toast: Double = 3000
}
