import SwiftUI
import PhosphorSwift

// 와이드 1차 CTA는 PaperButton(§13.5)으로 통일. 이전 ReffiButton(둥근 사각)은 제거됨.

/// 보조 액션 — 면 없는 텍스트+아이콘 버튼(캔버스 위 색은 dark, §2.6).
struct QuietButton: View {
    let title: LocalizedStringKey
    var icon: Ph?
    var tint: Color = ReffiColor.blueDark
    /// 조용한 텍스트 링크 신호(39차 부활 — 35차가 걷어낸 "캡션처럼 읽히는" 옛 텍스트 버튼과 다른 점이
    /// 바로 이 밑줄이다). 기본 false라 기존 호출부(파괴 성향 보조 액션 등)는 전부 그대로다 —
    /// 이 신호는 **정보를 더 보여주는** 링크에만 켠다(design_system.md 참고).
    var underline: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ReffiSpace.s1) {
                if let icon { icon.reffi(16, .bold) }
                // 버튼 라벨은 `pillLabel`(SemiBold 13)이다 — 알약·토스트와 같은 배정(§3.5).
                // caption(Medium 14)을 쓰던 동안 이 버튼은 같은 카드의 섹션 제목·안내문과 폰트·자간이
                // **완전히 같아서**, 색(blueDark·urgentDark)만이 "누를 수 있다"의 유일한 신호였다.
                // 색 하나에 기대는 신호는 색각 이상·저대비 환경·흑백 캡처에서 통째로 사라진다 —
                // 굵기(600)가 그 몫을 나눠 진다. 되돌리면 35차가 걷어낸 "캡션처럼 읽히는 텍스트 버튼"이
                // 그대로 돌아온다(위 `underline` 주석의 그 실패다).
                Text(title)
                    .reffiType(.pillLabel)
                    .underline(underline)
            }
            .foregroundStyle(tint)
            .padding(.vertical, ReffiSpace.s2)
            .padding(.horizontal, ReffiSpace.s2)
            .frame(minHeight: ReffiChrome.tapMin)   // §7.3 터치 타깃
            .contentShape(Rectangle())
        }
        .buttonStyle(.reffiPress)
    }
}
