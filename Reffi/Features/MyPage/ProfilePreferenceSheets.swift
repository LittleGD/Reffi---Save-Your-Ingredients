import SwiftUI

/// 시트 공통 셸 — 크림 캔버스 + `SheetHeader`(좌측 타이틀 + 종이 X) + 콘텐츠. 편집 시트를 통일한다.
/// 헤더는 인터랙션 커먼 룰 ②③의 단일 공급원 `SheetHeader`에 위임 — 인라인 종이 X 조립을 제거했다.
///
/// **핸들도 셸이 보증한다(§14.3 / 룰④)** — `SheetHeader`는 "프레젠테이션 측에서 dragIndicator를 켠다"를
/// 전제하는데, 호출부(ProfileView)마다 붙이면 같은 누락이 재발한다. 여기서 한 번 선언해 이 셸을 쓰는
/// 프로필 시트 6종이 함께 정렬되게 한다. 단일 고정 detent(.height) 시트는 automatic으로 그래버가
/// 뜨지 않으므로 이 선언이 곧 핸들 유무를 가른다.
private struct SheetShell<Content: View>: View {
    let title: LocalizedStringKey
    let onClose: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: title, showsClose: true, onClose: onClose)
            content
                .padding(.horizontal, ReffiGrid.margin)
            Spacer(minLength: 0)
        }
        .padding(.bottom, ReffiSpace.s5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ReffiColor.canvas.ignoresSafeArea())
        .presentationDragIndicator(.visible)   // §14.3 — 핸들 없는 시트를 두지 않는다(룰④)
    }
}

/// 닉네임 편집(§5.1.1).
///
/// **미저장 보호(§14.6 / 룰⑨)** — 명시적 Save를 가진 편집 시트라 §14.4의 "편집·생성 = 도킹 커밋"
/// 버킷에 속한다. 타이핑한 뒤 스와이프로 닫으면 경고 없이 사라지던 구멍을 `IngredientEditView`의
/// `requestClose()` 패턴 그대로 막는다(자동저장 버킷인 Cuisines·태그·알림시간 시트는 해당 없음).
struct NicknameEditSheet: View {
    @Environment(ProfileStore.self) private var profile
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""
    @State private var showDiscardConfirm = false

    /// 초안이 저장값과 다르면 미저장 변경이다. 앞뒤 공백만 다른 경우는 커밋 결과가 같아 dirty로 보지 않는다.
    private var isDirty: Bool {
        draft.trimmingCharacters(in: .whitespacesAndNewlines) != profile.nickname
    }

    var body: some View {
        SheetShell(title: "Nickname", onClose: { requestClose() }) {
            VStack(alignment: .leading, spacing: ReffiSpace.s4) {
                TextField("Nickname", text: $draft)
                    .reffiType(.body)
                    .foregroundStyle(ReffiColor.ink)
                    .fieldSurface(seed: 2)   // §13.8 필드 한 칸 — 캔버스 시트 위 독립 필드
                    .submitLabel(.done)
                    .onSubmit(commit)

                PaperButton(title: "Save", seed: 1, action: commit)
            }
        }
        .onAppear { draft = profile.nickname }
        .interactiveDismissDisabled(isDirty)   // 룰⑨ — 변경 있으면 스와이프 실수로 닫히지 않는다
        // 40차 — 팝업 전수 종이화(§14.7 개정).
        .paperDialog(isPresented: $showDiscardConfirm, title: "Discard changes?",
                    message: "Your changes won't be saved.",
                    seed: 1, backdropDismisses: true,
                    primary: PaperDialogAction("Discard", role: .destructive) { dismiss() },
                    secondary: PaperDialogAction("Cancel", role: .cancel) {})
    }

    /// 미저장 변경이 있으면 즉시 닫지 않고 Discard 확인을 띄운다(룰⑨).
    private func requestClose() {
        if isDirty { showDiscardConfirm = true } else { dismiss() }
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { profile.nickname = trimmed }
        dismiss()
    }
}

/// 요리 스타일 멀티 선택(§5.2) — 사용자 요청 핵심. 여러 스타일 동시 선택/해제.
struct CuisinePickerSheet: View {
    @Environment(ProfileStore.self) private var profile
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: ReffiSpace.s2)]

    var body: some View {
        SheetShell(title: "Cuisines", onClose: { dismiss() }) {
            VStack(alignment: .leading, spacing: ReffiSpace.s4) {
                Text("Pick as many as you like.\nRecipes will follow.")
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2)

                LazyVGrid(columns: columns, alignment: .leading, spacing: ReffiSpace.s2) {
                    ForEach(CuisineStyle.allCases) { c in
                        SelectableChip(text: c.labelKey, selected: profile.cuisines.contains(c),
                                       fullWidth: false) {
                            profile.toggleCuisine(c)
                        }
                    }
                }
            }
        }
    }
}

/// 문자열 태그 편집 시트 — 비선호 재료·알레르기(§5.2)에 공용. 추가/삭제.
struct TagEditorSheet: View {
    let title: LocalizedStringKey
    let placeholder: LocalizedStringKey
    @Binding var tags: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""

    var body: some View {
        SheetShell(title: title, onClose: { dismiss() }) {
            VStack(alignment: .leading, spacing: ReffiSpace.s4) {
                HStack(spacing: ReffiSpace.s2) {
                    TextField(placeholder, text: $draft)
                        .reffiType(.body)
                        .foregroundStyle(ReffiColor.ink)
                        .fieldSurface(seed: 2)   // §13.8 필드 한 칸
                        .submitLabel(.done)
                        .onSubmit(add)
                    QuietButton(title: "Add", icon: ReffiIcon.add, action: add)
                }

                if tags.isEmpty {
                    Text("None yet")
                        .reffiType(.caption).foregroundStyle(ReffiColor.muted)
                        .padding(.top, ReffiSpace.s1)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: ReffiSpace.s2)],
                              alignment: .leading, spacing: ReffiSpace.s2) {
                        ForEach(tags, id: \.self) { tag in
                            Button { remove(tag) } label: {
                                HStack(spacing: ReffiSpace.s1) {
                                    Text(tag)
                                        .font(ReffiTextRole.caption.font)
                                        .tracking(ReffiTextRole.caption.tracking)
                                        .foregroundStyle(ReffiColor.ink).lineLimit(1)
                                    ReffiIcon.close.reffi(11, .bold).foregroundStyle(ReffiColor.ink2)
                                }
                                .padding(.horizontal, ReffiSpace.s3)
                                .padding(.vertical, ReffiSpace.s2)
                                .background(ReffiColor.sub, in: PaperCutRect(seed: 4))   // §13.1 종이컷 8각형(캡슐 금지)
                                .frame(minHeight: ReffiChrome.tapMin)          // §7.3 터치 타깃
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.reffiPress)
                            .accessibilityLabel("Remove \(tag)")
                        }
                    }
                }
            }
        }
    }

    private func add() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { draft = ""; return }
        tags.append(trimmed)
        draft = ""
    }
    private func remove(_ tag: String) { tags.removeAll { $0 == tag } }
}

/// 알림 시간 선택(§2.1.2) — 아침 리마인더 시각(시 단위).
/// SSOT는 `ExpiryNotifier.hourKey`(ProfileView 토글과 같은 키). ExpiryNotifier는 정시(:00)에만
/// 발화하므로 시(hour) 단위로 선택한다 — 스케줄에 반영되지 않을 분(minute)은 UI에 노출하지 않는다.
///
/// **네이티브 휠 → 종이컷 리스트(51차, 오너 피드백 — "이것도 종이컷 스타일로 만들 수 있나?")**.
/// `.wheel`은 이 화면 유일의 시스템 룩이라 크림 캔버스·종이 시트 사이에서 홀로 튀었다. 새 컨트롤을
/// 짓지 않고 `PaperChecklistDialog`/`KitchenCopySheet`가 이미 쓰는 체크 상자 문법(§14.7)을 그대로
/// 가져온다 — 켜짐 = blue 솔리드 + `PaperGrain` + `paperEdgeOnFill` + onAccent 체크, 꺼짐 = paper
/// 면 + `paperEdgeState` 헤어라인. 다만 이 목록은 여럿을 담는 체크리스트가 아니라 **단일 선택**이라,
/// 접근성은 그 둘의 "담김 여부" 값 대신 `SelectableChip`·`PaperDropdown`과 같은 축의 `.isSelected`
/// 트레잇 하나로 말한다(상태 채널은 하나, §13.5). 16개 행(06시~21시)은 이 시트의 고정 높이(300)에
/// 다 들어가지 않아 자체 스크롤하고, 뜨는 순간 현재 선택 행으로 스크롤한다 — `.onAppear`가 아니라
/// `.task`에서 여는 것은 `PaperChecklistDialog`의 포커스 이동과 같은 이유다(42차, 요소 등록 전에
/// 실행되면 이동이 유실되는 창이 있다).
struct NotifyTimeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(ExpiryNotifier.hourKey) private var alertHour = ExpiryNotifier.defaultHour

    private static let hours = Array(6..<22)

    var body: some View {
        SheetShell(title: "Alert time", onClose: { dismiss() }) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(Self.hours.enumerated()), id: \.offset) { index, hour in
                            hourRow(hour)
                                .id(hour)
                            if index < Self.hours.count - 1 { ReffiRule(.ticket) }
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .task { proxy.scrollTo(alertHour, anchor: .center) }
            }
        }
    }

    private func hourRow(_ hour: Int) -> some View {
        let selected = hour == alertHour
        let label = Self.hourLabel(hour)
        return Button { alertHour = hour } label: {
            HStack(spacing: ReffiSpace.s3) {
                checkbox(on: selected, seed: hour)
                Text(verbatim: label)
                    .font(.reffiNum(.body, for: label))
                    .foregroundStyle(ReffiColor.ink)
                Spacer(minLength: 0)
            }
            .padding(.vertical, ReffiSpace.s2)
            .frame(minHeight: ReffiChrome.tapMin)   // §7.3 — 행 전체가 타깃
            .contentShape(Rectangle())
            .animation(ReffiMotion.gated(ReffiMotion.standard, reduce: reduceMotion), value: selected)
        }
        .buttonStyle(.reffiPress)
        .accessibilityLabel(Text(verbatim: label))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    /// 체크 상자 — `PaperChecklistDialog.checkbox`·`KitchenCopySheet.checkbox`와 같은 시각 문법(§14.7).
    /// 사설 함수를 공유하지 않는 이유도 그 둘과 같다 — 이 시트는 `Set` 없이 `Int` 하나만 비교하는
    /// 훨씬 얕은 계약이라, 파일을 가로지르는 의존보다 같은 그림을 다시 그리는 쪽이 더 작은 결합이다.
    @ViewBuilder
    private func checkbox(on: Bool, seed: Int) -> some View {
        let shape = PaperRect(cornerRadius: ReffiRadius.xs, seed: seed)
        ZStack {
            if on {
                shape.fill(ReffiColor.blue)
                    .overlay(PaperGrain(seed: UInt64(max(0, seed)) &+ 11, strength: 0.9).clipShape(shape))
                    .paperEdge(shape, tint: ReffiColor.paperEdgeOnFill)
                    .compositingGroup()
                ReffiIcon.check.reffi(13, .bold).foregroundStyle(ReffiColor.onAccent)
            } else {
                shape.fill(ReffiColor.paper).paperEdge(shape, tint: ReffiColor.paperEdgeState)
            }
        }
        .frame(width: 22, height: 22)
    }

    /// 정시 라벨 — "8:00 AM" 형식(로케일 자동).
    static func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}
