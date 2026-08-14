import SwiftUI

/// 하단 시트 헤더의 **단일 공급원**(인터랙션 커먼 룰 ②③) — 화면마다 손으로 조립하던 시트 헤더를 통일한다.
///
/// - **좌측** 타이틀(`.heading`) + Spacer + (선택)`PaperCloseButton`.
///   커버 헤더(`CoverHeader`)가 **중앙** 타이틀인 것과 의도적으로 대비된다(룰 ③: 시트=좌측 / 커버=중앙).
/// - 하단 시트는 dragIndicator(핸들)가 **주** 닫기 신호이므로 X는 선택이다(룰 ④, `showsClose`).
///   시트 프레젠테이션 측에서 `.presentationDragIndicator(.visible)`를 전제로 한다(호출부 책임).
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
