import SwiftUI

/// 종이 드롭다운 — 앱 최초 커스텀 드롭다운(§13). 스톡 `Menu`/`Picker` 팝업(흰 시스템 라운드 렉트)을
/// 대체한다. 팝업 면은 냉장고 카드·영수증 어휘와 같은 종이 문법: `PaperRect` 면 + `paperEdge` 헤어라인 +
/// 옅은 `PaperGrain` + `--shadow-1`. 행은 라벨(좌) + 선택 행에만 체크 글리프(우, `blue-dark`),
/// 최소 44pt 히트, `paperPress` 통통 프레스, 행 사이는 `DashedRule`(절취선 어휘, 보더 금지 §6).
///
/// 이 뷰는 **순수 팝업 면**이다 — 트리거 칩 아래 앵커링·바깥 탭 닫기·zIndex(`ReffiZ.dropdown`)·진입/이탈
/// 애니메이션은 호출부가 `DropdownAnchorKey` + `overlayPreferenceValue`로 붙인다(ScrollView에 클리핑되지
/// 않게 루트 오버레이에 띄운다). `FridgeView` 정렬 드롭다운이 첫 사용처 — 재사용을 전제로 제네릭.
struct PaperDropdown<Value: Hashable>: View {
    let options: [Value]
    let selected: Value
    /// 표시 라벨(로컬라이즈된 문자열). 저장값 라우팅은 호출부 책임(`onSelect`).
    let label: (Value) -> String
    var seed: Int = 5
    /// 선택 콜백 — 트레일링 클로저로 바인딩되게 마지막에 둔다(`seed`는 기본값).
    let onSelect: (Value) -> Void

    var body: some View {
        let shape = PaperRect(cornerRadius: ReffiRadius.md, seed: seed)
        VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button { onSelect(option) } label: {
                    HStack(spacing: ReffiSpace.s3) {
                        Text(label(option))
                            .reffiType(.checklistItem)
                            .foregroundStyle(ReffiColor.ink)
                            .lineLimit(1)
                        Spacer(minLength: ReffiSpace.s4)
                        // 선택 행에만 체크(§선택 표시는 체크 하나 — 배경 강조 금지, 종이 위 조용히).
                        ReffiIcon.check.reffi(14, .bold)
                            .foregroundStyle(ReffiColor.blueDark)
                            .opacity(option == selected ? 1 : 0)
                    }
                    .padding(.horizontal, ReffiSpace.s4)
                    .frame(minHeight: 44)               // §7.3 터치 타깃
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.paperPress)
                .accessibilityLabel(label(option))
                .accessibilityAddTraits(option == selected ? [.isButton, .isSelected] : .isButton)

                if index < options.count - 1 {
                    DashedRule().padding(.horizontal, ReffiSpace.s3)   // 절취선 구분(보더 아님)
                }
            }
        }
        .padding(.vertical, ReffiSpace.s1)
        .background {
            shape.fill(ReffiColor.paper)
                .overlay(PaperGrain(seed: UInt64(seed) &+ 11, strength: 0.6).clipShape(shape))   // 옅은 질감
                .paperEdge(shape, tint: ReffiColor.ink.opacity(0.08))
                .compositingGroup()
                .reffiShadow1()
        }
    }
}

/// 트리거 칩의 바운드를 루트 오버레이로 전달하는 앵커 키 — 드롭다운을 칩 바로 아래에 위치시킨다.
/// 화면당 한 개 열림을 전제(마지막 non-nil 우선). ScrollView 밖 루트에서 읽어 클리핑을 피한다.
struct DropdownAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}
