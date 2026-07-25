import SwiftUI

/// 종이 X 닫기 버튼 — 커버 헤더·시트 헤더·doneBar 등 **모든 종이 X의 단일 공급원**(인터랙션 커먼 룰 ①).
/// 이전엔 34/40/44 · `paper`/`.white.opacity(0.9)`/`oklch(0.99)` · seed 1/4로 4갈래 파편화돼 있었다.
///
/// 확정 스펙(§F): **시각 40 / 히트 44 / 채움 `ReffiColor.paper` 단일 토큰**.
/// 시각과 히트를 분리한다(§7.3) — `PaperRect` 면은 40×40, 탭 영역은 `.frame(minWidth:44,minHeight:44)`
/// + `.contentShape(Rectangle())`로 44를 확보한다. 아이콘은 공용 `ReffiIcon.close`(xmark).
struct PaperCloseButton: View {
    var seed: Int = 4
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ReffiIcon.close.reffi(18, .bold)
                .foregroundStyle(ReffiColor.ink)
                .frame(width: 40, height: 40)                 // 시각 40
                .background {
                    let s = PaperRect(cornerRadius: ReffiRadius.md, seed: seed)
                    s.fill(ReffiColor.paper).paperEdge(s)
                }
                .reffiShadow1()
                .frame(minWidth: 44, minHeight: 44)           // 히트 44 (§7.3)
                .contentShape(Rectangle())
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel("Close")
    }
}
