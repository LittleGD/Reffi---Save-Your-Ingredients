import SwiftUI

/// 종이 드롭다운 — 앱 최초 커스텀 드롭다운(§13). 스톡 `Menu`/`Picker` 팝업(흰 시스템 라운드 렉트)을
/// 대체한다. 팝업 면은 냉장고 카드·영수증 어휘와 같은 종이 문법: `PaperRect` 면 + `paperEdge` 헤어라인 +
/// 옅은 `PaperGrain` + `--shadow-1`. 행은 라벨(좌) + 선택 행에만 체크 글리프(우, `blue-dark`),
/// 최소 44pt 히트, `paperPress` 통통 프레스, 행 사이는 `ReffiRule(.ticket)`(절취선 어휘, 보더 금지 §6).
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
    /// 팝업이 차지할 수 있는 최대 높이. 시트 안처럼 세로 여유가 좁고 항목이 많을 때(단위 10종) 필요하다 —
    /// 넘치면 행이 **내부 스크롤**되고, 넉넉하면 내용 높이 그대로 뜬다(`ViewThatFits`가 고른다).
    /// `nil`이면 항상 내용 높이(항목이 적은 정렬 드롭다운의 기본 동작 — 기존 호출부는 그대로다).
    var maxHeight: CGFloat? = nil
    /// 바깥 탭 말고 **보조기술로** 닫는 길(escape 제스처). VoiceOver에는 "팝업 바깥"이 없다 —
    /// 투명 탭 캐처는 라벨도 없어 커서가 닿지 않으므로, 이 콜백이 없으면 고르는 것 말고는 나갈 수 없다.
    var onDismiss: (() -> Void)? = nil
    /// 선택 콜백 — 트레일링 클로저로 바인딩되게 마지막에 둔다(`seed`·`maxHeight`는 기본값).
    let onSelect: (Value) -> Void

    /// 행 묶음의 실측 높이 — 캡보다 짧으면 종이가 내용에 딱 맞게 줄어야 한다.
    /// `ScrollView`는 제안된 높이를 다 차지하므로 실측 없이 캡만 주면 빈 종이가 남는다.
    @State private var contentHeight: CGFloat = 0
    /// 열리는 순간 커서를 옮길 행 — 팝업은 루트 오버레이에 떠서 트리거의 이웃이 아니다.
    /// 옮겨 주지 않으면 종이가 화면을 덮은 채 커서만 뒤 화면에 남는다(§13 팝업은 뜨는 즉시 주인공이다).
    @AccessibilityFocusState private var focusedOption: Value?

    var body: some View {
        let shape = PaperRect(cornerRadius: ReffiRadius.md, seed: seed)
        Group {
            if let maxHeight {
                ScrollView {
                    rows.background {
                        GeometryReader { g in
                            Color.clear.preference(key: DropdownContentHeightKey.self, value: g.size.height)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)   // 다 들어가면 바운스도 없다(스크롤 아닌 척)
                .frame(height: min(contentHeight > 0 ? contentHeight : maxHeight, maxHeight))
                .onPreferenceChange(DropdownContentHeightKey.self) { contentHeight = $0 }
            } else {
                rows
            }
        }
        .padding(.vertical, ReffiSpace.s1)
        .background {
            shape.fill(ReffiColor.paper)
                .overlay(PaperGrain(seed: UInt64(seed) &+ 11, strength: 0.6).clipShape(shape))   // 옅은 질감
                .paperEdge(shape)
                .compositingGroup()
                .reffiShadow1()
        }
        // 팝업은 한 묶음으로 서고, 뜬 동안 뒤 화면은 없는 것으로 친다 — 바깥을 건드리면 어차피
        // 닫히는 면이라(투명 탭 캐처), 보조기술에서만 배경을 훑을 수 있는 상태가 오히려 어긋난
        // 모델이다(`PaperDialog`와 같은 태도).
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { onDismiss?() }
        .onAppear {
            // 지금 선택된 행이 있으면 거기서, 없으면 첫 행에서 시작한다 — 위아래로 훑을 기준점이 생긴다.
            focusedOption = options.contains(selected) ? selected : options.first
        }
    }

    private var rows: some View {
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
                    .frame(minHeight: ReffiChrome.tapMin)               // §7.3 터치 타깃
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.paperPress)
                .accessibilityLabel(label(option))
                .accessibilityAddTraits(option == selected ? [.isButton, .isSelected] : .isButton)
                .accessibilityFocused($focusedOption, equals: option)

                if index < options.count - 1 {
                    ReffiRule(.ticket).padding(.horizontal, ReffiSpace.s3)   // 절취선 구분(보더 아님)
                }
            }
        }
    }
}

/// 드롭다운 행 묶음의 실측 높이 — 캡 안에서 종이가 내용에 딱 맞게 줄도록 한다.
private struct DropdownContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// 트리거 칩의 바운드를 루트 오버레이로 전달하는 앵커 키 — 드롭다운을 칩 바로 아래에 위치시킨다.
/// 화면당 한 개 열림을 전제(마지막 non-nil 우선). ScrollView 밖 루트에서 읽어 클리핑을 피한다.
struct DropdownAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

/// 드롭다운 트리거 칩 — 현재 값을 상시 노출하는 종이 칩(§13.5 정렬 칩과 같은 문법·같은 히트 44pt).
///
/// **자기가 열려 있을 때만 앵커를 올린다** — `DropdownAnchorKey`는 화면당 한 개 열림을 전제하므로,
/// 한 화면에 트리거가 둘 이상이면(편집 시트의 단위·보관) 상시 발행 시 마지막 것이 이겨 팝업이
/// 엉뚱한 칩 아래에 뜬다. 열린 것만 발행하면 non-nil이 항상 하나뿐이라 그 전제가 유지된다.
struct PaperDropdownTrigger: View {
    let label: String
    let isOpen: Bool
    var seed: Int = 5
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ReffiSpace.s1) {
                Text(verbatim: label)
                    .font(ReffiTextRole.caption.font)
                    .tracking(ReffiTextRole.caption.tracking)
                    .lineLimit(1)
                ReffiIcon.chevron.reffi(10, .bold)
                    .rotationEffect(.degrees(isOpen ? -90 : 90))   // 닫힘 ▼ / 열림 ▲
            }
            .foregroundStyle(ReffiColor.ink)
            .padding(.horizontal, ReffiSpace.s3)
            .padding(.vertical, ReffiSpace.s2)
            .background {
                let s = PaperRect(cornerRadius: ReffiRadius.sm, seed: seed)
                s.fill(ReffiColor.paper).paperEdge(s)
            }
            .frame(minHeight: ReffiChrome.tapMin)   // §7.3 터치 타깃
            .contentShape(Rectangle())
            .anchorPreference(key: DropdownAnchorKey.self, value: .bounds) { isOpen ? $0 : nil }
        }
        .buttonStyle(.paperPress)
        // 펼침/접힘을 **값**으로 말한다 — 셰브런 회전은 눈에만 보이고, SwiftUI에는 expanded 트레잇이
        // 없다(iOS 26 SDK 확인: `AccessibilityTraits`에 isToggle까지만 있다).
        // 무엇을 고르는 칩인지·지금 값이 무엇인지는 **호출부의 라벨**이 말한다(예: "Unit: g") —
        // 여기서 라벨까지 잡으면 안쪽이 이겨 호출부 문구가 조용히 사라진다.
        .accessibilityValue(isOpen ? Text("Expanded") : Text("Collapsed"))
    }
}

extension View {
    /// 시트 안 종이 드롭다운 오버레이 — `FridgeView` 루트 오버레이 패턴을 **세로 여유가 좁은 시트**용으로
    /// 일반화했다. 트리거 앵커 아래에 띄우되 **아래 공간이 더 좁으면 위로 뒤집고**, 남은 공간에 맞춰
    /// 팝업 높이를 캡한다(넘치면 `PaperDropdown`이 내부 스크롤 — 단위 10종이 그 경우다).
    /// 딤 없는 투명 탭 캐처가 바깥 탭을 받아 닫는다(가벼운 드롭다운, 모달 아님 — scrim 금지).
    ///
    /// 시트에는 시스템 팝오버처럼 뷰 밖으로 나갈 자유가 없으므로, 정렬 칩과 달리 높이 캡·뒤집기가 필요하다.
    func paperDropdownOverlay<Value: Hashable>(
        isPresented: Bool,
        options: [Value],
        selected: Value,
        label: @escaping (Value) -> String,
        width: CGFloat = 210,
        seed: Int = 5,
        onDismiss: @escaping () -> Void,
        onSelect: @escaping (Value) -> Void
    ) -> some View {
        // 열린 동안 트리거·배경은 보조기술에서 사라진다 — 오버레이는 **이 뒤에** 붙으므로 함께 가려지지
        // 않는다. `PaperDropdown`의 `.isModal`만으로는 부족하다: 팝업이 오버레이 안쪽 깊이 놓여
        // 모달 형제 관계가 화면 전체까지 닿는다고 보장할 수 없다.
        accessibilityHidden(isPresented)
        .overlayPreferenceValue(DropdownAnchorKey.self) { anchor in
            GeometryReader { proxy in
                if isPresented, let anchor {
                    let rect = proxy[anchor]
                    let gap = ReffiSpace.s1
                    let below = proxy.size.height - rect.maxY - gap - ReffiSpace.s4
                    let above = rect.minY - gap - ReffiSpace.s4
                    let placeBelow = below >= above
                    let cap = max(132, placeBelow ? below : above)
                    let x = min(max(ReffiGrid.margin, rect.maxX - width),
                                max(ReffiGrid.margin, proxy.size.width - width - ReffiGrid.margin))
                    let y = placeBelow ? rect.maxY + gap : max(0, rect.minY - gap - cap)
                    ZStack(alignment: .topLeading) {
                        Color.clear
                            .contentShape(Rectangle())
                            .ignoresSafeArea()
                            .onTapGesture { onDismiss() }
                            // 탭 캐처는 시각 요소도 아니고 이름도 없다 — 커서에 걸리면 정체불명의
                            // 요소가 하나 는다. 바깥 탭의 접근성 대응은 팝업의 escape 액션이 맡는다.
                            .accessibilityHidden(true)
                        PaperDropdown(options: options, selected: selected, label: label,
                                      seed: seed, maxHeight: cap,
                                      onDismiss: onDismiss) { value in
                            onSelect(value)
                            onDismiss()
                        }
                        // 캡 높이의 투명 상자에 정렬만 다르게 담는다 — 아래로 뜨면 위쪽 정렬,
                        // 위로 뒤집으면 아래쪽 정렬이라 팝업이 실제 높이만큼만 트리거에 붙는다.
                        .frame(width: width, height: cap, alignment: placeBelow ? .top : .bottom)
                        .offset(x: x, y: y)
                        .transition(.scale(scale: 0.92, anchor: placeBelow ? .topTrailing : .bottomTrailing)
                            .combined(with: .opacity))
                    }
                    .zIndex(ReffiZ.dropdown)
                }
            }
        }
    }
}
