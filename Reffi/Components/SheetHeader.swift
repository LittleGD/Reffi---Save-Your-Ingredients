import SwiftUI

/// 하단 시트 헤더의 **단일 공급원**(인터랙션 커먼 룰 ②③) — 화면마다 손으로 조립하던 시트 헤더를 통일한다.
///
/// - **좌측** 타이틀(`.heading`) + Spacer + (선택)`PaperCloseButton`.
///   49차에 커버 헤더도 좌측으로 옮겨져(오너 지시) 시트·커버·팝업이 **한 축**으로 정렬된다 —
///   옛 룰 ③("시트=좌측 / 커버=중앙")의 대비는 더 이상 없다. 여기서 중앙으로 되돌리지 마라.
/// - 하단 시트는 dragIndicator(핸들)가 **주** 닫기 신호이므로 X는 선택이다(룰 ④, `showsClose`).
///   시트 프레젠테이션 측에서 `.presentationDragIndicator(.visible)`를 전제로 한다(호출부 책임).
/// - X는 50차에 무면화됐다(시각 18 글리프 · `ink2` · 면·그림자 없음, 히트는 44 그대로) —
///   **우측 엣지 광학 보정을 `PaperCloseButton`이 스스로 지므로** 여기서 음수 패딩을 덧대지 마라.
///   행 높이는 여전히 X의 히트 44로 바닥이 잡혀 시트마다 헤더 높이가 같다.
/// - 패딩은 시트 컴포지션 토큰(§14.8 · 61차)이다: 가로 `ReffiSheet.inset`(24) · 위 `ReffiSheet.top`(32) ·
///   아래 `ReffiSheet.headerGap`(24). 옛 값(16 · s5 · s3)은 페이지 마진을 시트에 그대로 상속한 것이라 시트가
///   좁게 읽혔고, 아래 12는 본문마다 제 상단 패딩을 덧대게 만들어 헤더→본문 간격이 시트마다 갈렸다.
///   **본문은 상단 패딩을 갖지 않는다** — 이 헤더가 첫 콘텐츠까지의 간격을 전부 진다.
/// - **타이틀은 한 줄·말줄임**이다. 재료명처럼 동적으로 들어오는 타이틀이 길어도 헤더가 깨지지 않고
///   X 버튼이 자리를 지킨다 — 이 보호를 호출부가 각자 하면(예전 `IngredientEditView`) 커스텀 HStack이
///   남아 시트 간 헤더 높이가 어긋나므로, 컴포넌트가 흡수해 모든 시트가 함께 안전해진다.
struct SheetHeader: View {
    let title: LocalizedStringKey
    var showsClose: Bool = false
    var onClose: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .reffiType(.heading)
                .foregroundStyle(ReffiColor.ink)
                .lineLimit(1)
                .truncationMode(.tail)
                // 시각 위계(.heading)에 의미 위계를 짝지운다(42차) — 이게 없으면 이 헤더를 쓰는
                // 시트 일곱 곳의 제목이 전부 VoiceOver 로터의 "제목" 탐색에서 사라진다.
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: ReffiSpace.s2)
            if showsClose {
                PaperCloseButton { onClose?() }
            }
        }
        // 행 높이 44는 X가 있을 때만 히트 프레임이 주던 것이라, `showsClose: false`(남은 재료 확인)에서는
        // 제목이 한 단 위로 올라가 시트 간 기준선이 어긋났다(61차 리뷰). 바닥을 명시해 X 유무와 무관하게 같다.
        .frame(minHeight: ReffiChrome.tapMin)
        .padding(.horizontal, ReffiSheet.inset)
        .padding(.top, ReffiSheet.top)
        .padding(.bottom, ReffiSheet.headerGap)
    }
}
