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
/// - 패딩은 기존 시트 헤더(AddIngredientSheet)와 동일: 가로 `ReffiGrid.margin` · 위 `s5` · 아래 `s3`.
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
        .padding(.horizontal, ReffiGrid.margin)
        .padding(.top, ReffiSpace.s5)
        .padding(.bottom, ReffiSpace.s3)
    }
}
