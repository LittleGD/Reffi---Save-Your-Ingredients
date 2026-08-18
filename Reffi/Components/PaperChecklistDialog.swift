import SwiftUI

/// 종이 체크리스트 다이얼로그(§14.7) — **무엇을 담을지 고르는** 팝업.
///
/// `PaperDialog`(알림·질문)와 **같은 문법**이다: `scrim` 딤 + `PaperRect` 크림 카드 + 종이컷 버튼 +
/// `.isModal` + 제목 포커스. 다른 것은 셋뿐이고, 셋 다 "고르기"라는 목적에서 나온다.
/// ① **우상단 X**(`PaperCloseButton`, 룰 ①) — 아무것도 담지 않고 닫는 길이 있어야 한다.
///    알림·질문은 버튼이 곧 결론이라 X가 필요 없지만, 고르기는 "역시 안 담을래"가 정당한 결말이다.
/// ② **체크 행 목록** — 한 줄이 한 재료다. 체크가 **왼쪽**에 서는 것은 목록을 세로로 훑을 때
///    상태가 한 열에 정렬돼 읽히기 때문이다(오른쪽에 두면 이름 길이만큼 체크가 들쭉날쭉해진다).
/// ③ **하단 전폭 1차 CTA** — 담기는 이 팝업의 유일한 확정이라 커버·시트의 하단 도킹 CTA 관례를 따른다.
///
/// **`ReceiptShape`(톱니)를 쓰지 않는 것은 `PaperDialog`와 같은 이유**다 — 티켓 덱 위에 뜨는 팝업이
/// 톱니를 두르면 "티켓이 한 장 더 나온 것"으로 읽힌다. 다이얼로그는 티켓이 아니라 **묻는 종이**다.
struct PaperChecklistDialog: View {
    /// 한 줄 — 실루엣 + 이름. `id`는 **원본 배열의 인덱스**다: 선택 집합이 표기나 캐논 키에 매이면
    /// 같은 키로 정리되는 두 줄(예: "pork (or beef)"와 "beef")이 하나의 체크를 공유해 버린다.
    struct Row: Identifiable, Equatable {
        let id: Int
        let name: String
        let glyph: FoodGlyph
    }

    let title: LocalizedStringKey
    var message: LocalizedStringKey?
    let rows: [Row]
    /// 체크된 행의 `id` 집합 — 호출부가 소유한다(팝업이 닫혀도 결과를 읽어야 한다).
    @Binding var checked: Set<Int>
    let confirmTitle: LocalizedStringKey
    /// 종이 삐뚤빼뚤함의 시드 — 이어 뜨는 다이얼로그들과 다른 종이로 보이게.
    var seed: Int = 0
    let onConfirm: () -> Void
    /// X·딤 탭·이스케이프가 모두 이 한 곳으로 모인다 — **닫는 길은 결과가 하나여야 한다**(아무것도 안 담김).
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @AccessibilityFocusState private var titleFocused: Bool

    /// 목록이 길어도 카드가 화면을 넘지 않게 하는 상한. 부족 재료는 보통 1~2줄이지만
    /// (`RecipeRecommender.maxMissingForRecommendation`), 큰 글씨에서는 두 줄이 그 자체로 길어진다.
    private static let listMaxHeight: CGFloat = 260
    /// 행 묶음의 실측 높이 — 캡보다 짧으면 카드가 내용에 딱 맞게 줄어야 한다.
    /// `ScrollView`는 제안된 높이를 다 차지하므로 실측 없이 캡만 주면 빈 종이가 남는다
    /// (`PaperDropdown`이 같은 함정을 같은 방법으로 푼다).
    @State private var listHeight: CGFloat = 0

    var body: some View {
        ZStack {
            ReffiColor.scrim.ignoresSafeArea()
                .opacity(shown ? 1 : 0)
                .contentShape(Rectangle())
                .onTapGesture { onClose() }
                // 딤은 시각 요소다 — 라벨을 달면 VoiceOver에 정체불명의 요소가 하나 늘어난다.
                .accessibilityHidden(true)
            card
                .scaleEffect(shown ? 1 : 0.85)
                .opacity(shown ? 1 : 0)
        }
        // 뜬 동안 뒤 화면(티켓 덱)을 VoiceOver에서 가린다 — 훑을 수 있으면 모달이 아니다.
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { onClose() }
        .onAppear {
            if reduceMotion { shown = true } else { withAnimation(ReffiMotion.pop) { shown = true } }
            titleFocused = true
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s4) {
            header
            list
            // 하나도 체크되지 않으면 **누를 수 없다**(§7.2 disabled = opacity만). 눌리게 두고 0건을
            // 담았다고 알리면 팝업 두 장이 "아무 일도 없었다"를 말하려고 뜨는 셈이다.
            PaperButton(title: confirmTitle, seed: seed &+ 2, action: onConfirm)
                .disabled(checked.isEmpty)
        }
        .padding(ReffiSpace.s5)
        .background {
            let shape = PaperRect(cornerRadius: ReffiRadius.xl, seed: seed)
            shape.fill(ReffiColor.paper).paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
        }
        .reffiShadow1()
        .padding(.horizontal, ReffiSpace.s6)
        .frame(maxWidth: 420)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: ReffiSpace.s3) {
            VStack(alignment: .leading, spacing: ReffiSpace.s2) {
                Text(title)
                    .reffiType(.heading).foregroundStyle(ReffiColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($titleFocused)
                if let message {
                    Text(message)
                        .reffiType(.body).foregroundStyle(ReffiColor.ink2)   // §2.6 소형 텍스트는 불투명 토큰
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: ReffiSpace.s2)
            // X는 카드 안 우상단이다(§14.3 커버 규칙의 자리) — 카드 밖에 두면 딤 위에 뜬 조각이 되어
            // 무엇을 닫는 X인지가 흐려진다. 제목과 같은 줄에 두어 시선의 시작·끝이 한 행에 모인다.
            PaperCloseButton(seed: seed &+ 3, action: onClose)
                .padding(.top, -ReffiSpace.s2)      // 40pt 면의 시각 중심을 제목 첫 줄에 맞춘다
                .padding(.trailing, -ReffiSpace.s2)
                // UI 테스트 훅 — 덱 커버의 닫기 X와 **라벨이 같아**("Close") 조회로 가를 수 없다.
                // 라벨은 그대로 두고 식별자만 붙인다(`ticket.menuName` 선례).
                .accessibilityIdentifier("dialog.close")
        }
    }

    /// 체크 행 목록 — 실측 높이와 상한 중 작은 값을 쓴다(짧으면 스크롤이 없는 것처럼 보인다).
    private var list: some View {
        ScrollView {
            VStack(spacing: ReffiSpace.s1) {
                ForEach(rows) { row($0) }
            }
            .background {
                GeometryReader { g in
                    Color.clear.preference(key: ChecklistContentHeightKey.self, value: g.size.height)
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)   // 다 들어가면 바운스도 없다(스크롤 아닌 척)
        .frame(height: min(listHeight > 0 ? listHeight : Self.listMaxHeight, Self.listMaxHeight))
        .onPreferenceChange(ChecklistContentHeightKey.self) { listHeight = $0 }
        .accessibilityElement(children: .contain)
    }

    private func row(_ item: Row) -> some View {
        let on = checked.contains(item.id)
        return Button {
            if on { checked.remove(item.id) } else { checked.insert(item.id) }
        } label: {
            HStack(spacing: ReffiSpace.s3) {
                checkbox(on: on, seed: seed &+ item.id)
                PaperSilhouette(glyph: item.glyph, fresh: .fresh)
                    .frame(width: ReffiFoodIcon.rowMini, height: ReffiFoodIcon.rowMini)
                Text(verbatim: item.name)
                    .reffiType(.body).foregroundStyle(ReffiColor.ink)
                    .lineLimit(2).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.vertical, ReffiSpace.s1)
            .frame(minHeight: 44)          // §7.3 — 행 전체가 타깃이다(작은 상자만 노리게 하지 않는다)
            .contentShape(Rectangle())
        }
        .buttonStyle(.reffiPress)
        .accessibilityLabel(Text(verbatim: item.name))
        .accessibilityValue(on ? Text("Checked") : Text("Not checked"))
        .accessibilityHint(Text("Toggles whether this goes on the list"))
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }

    /// 체크 상자 — 종이 문법 그대로다(새 컨트롤 어휘를 만들지 않는다).
    /// 켜짐 = blue 솔리드 + `PaperGrain` + `paperEdgeOnFill` + 크림 체크, 꺼짐 = `paper` 면 + 헤어라인.
    /// 조리 완료 시트의 상태 알약(`CookingStepsView.leftoverRow`)이 쓰던 "종이 면으로 상태를 말한다"는
    /// 축을 그대로 잇되, 그 알약은 **상태 보고**(다 씀/조금 남음)라 라벨을 달고 오른쪽에 서는 반면
    /// 여기는 **고르기**라 라벨 없는 상자로 왼쪽에 선다.
    @ViewBuilder
    private func checkbox(on: Bool, seed: Int) -> some View {
        let shape = PaperRect(cornerRadius: ReffiRadius.xs, seed: seed)
        ZStack {
            if on {
                shape.fill(ReffiColor.blue)
                    .overlay(PaperGrain(seed: UInt64(max(0, seed)) &+ 11, strength: 0.9).clipShape(shape))
                    .paperEdge(shape, tint: ReffiColor.paperEdgeOnFill)
                    .compositingGroup()
                // blue 면 위의 콘텐츠는 흰색이다 — `PaperButtonLabel`의 primary와 같은 규약
                // (ink 면이 아니므로 `onInk`가 아니다: 그건 다크에서 뒤집히는 잉크 면 전용이다).
                ReffiIcon.check.reffi(13, .bold).foregroundStyle(.white)
            } else {
                shape.fill(ReffiColor.paper).paperEdge(shape, tint: ReffiColor.ink.opacity(0.18))
            }
        }
        .frame(width: 22, height: 22)
        .animation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion), value: on)
    }
}

/// 행 묶음 실측 높이 전달용 — `PaperDropdown`의 같은 이름 키와 **별개**다(그쪽은 파일 private).
private struct ChecklistContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

extension PaperChecklistDialog {
    /// 체크된 것만 **원본 순서 그대로** 골라낸다 — 담기는 화면의 체크 상태와 정확히 일치해야 한다.
    /// 순수 함수라 유닛 테스트가 이 계약을 직접 잠근다(뷰 렌더 없이).
    static func selected<T>(_ items: [T], checked: Set<Int>) -> [T] {
        items.indices.filter { checked.contains($0) }.map { items[$0] }
    }
}

extension View {
    /// 체크리스트 다이얼로그를 이 뷰 위에 얹는다 — `paperDialog`와 같은 자리·같은 모양으로 쓴다.
    /// 확정·닫기 모두 **먼저 내리고 그 다음 행동**한다(시스템 알림과 같은 순서, `PaperDialog` 참고).
    func paperChecklistDialog(isPresented: Binding<Bool>,
                              title: LocalizedStringKey,
                              message: LocalizedStringKey? = nil,
                              rows: [PaperChecklistDialog.Row],
                              checked: Binding<Set<Int>>,
                              confirmTitle: LocalizedStringKey,
                              seed: Int = 0,
                              onConfirm: @escaping () -> Void,
                              onClose: @escaping () -> Void) -> some View {
        modifier(PaperChecklistDialogModifier(isPresented: isPresented,
                                              title: title,
                                              message: message,
                                              rows: rows,
                                              checked: checked,
                                              confirmTitle: confirmTitle,
                                              seed: seed,
                                              onConfirm: onConfirm,
                                              onClose: onClose))
    }
}

private struct PaperChecklistDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: LocalizedStringKey
    let message: LocalizedStringKey?
    let rows: [PaperChecklistDialog.Row]
    @Binding var checked: Set<Int>
    let confirmTitle: LocalizedStringKey
    let seed: Int
    let onConfirm: () -> Void
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    PaperChecklistDialog(title: title,
                                         message: message,
                                         rows: rows,
                                         checked: $checked,
                                         confirmTitle: confirmTitle,
                                         seed: seed,
                                         onConfirm: { close(then: onConfirm) },
                                         onClose: { close(then: onClose) })
                        .transition(.opacity)
                }
            }
            .animation(ReffiMotion.gated(.easeOut(duration: ReffiMotion.dur2), reduce: reduceMotion),
                       value: isPresented)
    }

    private func close(then handler: @escaping () -> Void) {
        isPresented = false
        handler()
    }
}
