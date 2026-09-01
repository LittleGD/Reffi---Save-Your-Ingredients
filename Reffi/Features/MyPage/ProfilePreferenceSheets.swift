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
/// **종이컷 체크 리스트(51차) → 종이컷 다이얼(56차, 오너 판정 — "종이컷 스타일은 유지하되 시간
/// 선택은 다이얼로")**. `.wheel`의 시스템 룩을 걷어낸다는 51차의 원칙은 그대로 두고 형태만 되돌아온다 —
/// 06~21시 16행을 훑는 세로 스크롤에 가운데 고정 **선택 밴드**(`PaperRect` sub 톤 + 위아래
/// `ReffiRule(.ticket)`)를 얹어 종이 문법을 지키고, 중심에서 먼 행일수록 옅고 작아지는 **원근**
/// (`dialPerspective`, 리듀스모션에선 페이드만 남고 스케일은 꺼진다)이 시스템 휠의 페이드를 대신한다.
/// 스냅 물리는 iOS 17+ `scrollTargetLayout`/`scrollTargetBehavior(.viewAligned)`가 지고(프로젝트
/// 최소 배포 타깃 18.0 확인 — GeometryReader 수동 스냅 폴백은 불필요), 어느 행이 지금 중심인지는
/// 뷰 렌더 없이 잠기는 순수 함수(`snapIndex`)가 판정해 `alertHour`를 갱신하고 선택 틱 햅틱을 낸다 —
/// **51차가 유지한 저장·재스케줄 로직은 그대로다**: 여전히 같은 `@AppStorage` 키에 쓰고, ProfileView의
/// `.onChange(of: alertHour)`가 그대로 `ExpiryNotifier.reschedule`을 편다.
///
/// **`.selection` 햅틱은 §7.6 판정·성공·파괴 3종 표 밖의 새 결이다.** 순수 정보성 스크롤(§7.6 "탭
/// 전환·스크롤 등에는 햅틱을 쓰지 않는다")과 달리, 이 스크롤 자체가 곧 커밋되는 값이라 시스템
/// `Picker(.wheel)`처럼 칸을 지날 때마다 틱이 울려야 "값을 고르고 있다"는 게 손끝으로 느껴진다 —
/// 표 밖의 예외라 여기 이름과 이유를 남긴다(§7.6을 고치는 대신 이 시트에 적어 둔다, 파급을 이 다이얼로 좁힌다).
///
/// **접근성은 51차의 "행별 버튼 + `.isSelected`" 모델을 완전히 대체한다.** 낱개 행은 트리에서
/// 지워지고(`accessibilityElement(children: .ignore)`) 다이얼 전체가 **요소 하나**로 묶여
/// `accessibilityValue`가 현재 시각을 말하며, 위/아래 스와이프(`accessibilityAdjustableAction`)가
/// 한 칸씩 시간을 옮긴다 — 시스템 `Picker(.wheel)`·`Stepper`가 VoiceOver에 보이는 것과 같은 문법이다.
struct NotifyTimeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(ExpiryNotifier.hourKey) private var alertHour = ExpiryNotifier.defaultHour

    static let hours = Array(6..<22)
    /// 다이얼 행 높이 — §7.3 최소 터치 타깃(44)을 새 숫자 없이 그대로 쓴다. 51차의 "행 전체가 탭
    /// 타깃"이라는 계약을, 이번엔 스크롤 스냅 격자 한 칸의 크기로 옮긴다.
    static let rowHeight: CGFloat = ReffiChrome.tapMin

    /// 연속 스크롤 오프셋 — `dialPerspective` 계산 전용(매 프레임 필요). 커밋 경로(`alertHour`·햅틱)는
    /// `committedIndex`가 따로 진다 — 원근은 부드러운 연속값이 필요하고 커밋은 "새 행이 중심에
    /// 왔다"는 이산 사건이라 세밀도가 다르다.
    @State private var scrollOffsetY: CGFloat
    /// 마지막으로 커밋한 행 인덱스 — 이 값이 바뀔 때만 `alertHour`를 쓰고 햅틱을 낸다.
    @State private var committedIndex: Int
    /// 시트가 뜨며 하는 초기 센터링 스크롤과, 사용자가 실제로 다이얼을 굴리는 것을 가른다.
    /// 이게 없으면 `.task`의 초기 `scrollTo`가 만드는 지오메트리 콜백이 "행이 바뀌었다"로 오판되어
    /// 아무것도 만지지 않았는데 스퓨리어스 햅틱이 한 번 운다.
    @State private var isInteractive = false

    init() {
        let hour = ExpiryNotifier.alertHour
        let idx = Self.index(ofHour: hour) ?? 0
        _scrollOffsetY = State(initialValue: CGFloat(idx) * Self.rowHeight)
        _committedIndex = State(initialValue: idx)
    }

    var body: some View {
        SheetShell(title: "Alert time", onClose: { dismiss() }) {
            ScrollViewReader { proxy in
                GeometryReader { geo in
                    let bandHeight = geo.size.height
                    ZStack {
                        selectionBand
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(Self.hours, id: \.self) { hour in
                                    dialRow(hour).id(hour)
                                }
                            }
                            .scrollTargetLayout()
                        }
                        // 첫·마지막 행도 밴드 중앙까지 올 수 있게 위아래를 행 반 폭만큼 비운다
                        // (§ safeAreaPadding 트릭 — `.viewAligned`가 재는 "정렬 경계"가 이 여백의
                        // 안쪽 가장자리라, 콘텐츠 오프셋 0 = 0번 행이 밴드 중앙에 오는 자리가 된다).
                        .safeAreaPadding(.vertical, max(0, (bandHeight - Self.rowHeight) / 2))
                        .scrollTargetBehavior(.viewAligned)
                        .scrollBounceBehavior(.basedOnSize)
                        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, newOffset in
                            scrollOffsetY = newOffset
                            guard isInteractive else { return }
                            let newIndex = Self.snapIndex(forOffset: newOffset, rowHeight: Self.rowHeight,
                                                          count: Self.hours.count)
                            guard newIndex != committedIndex else { return }
                            committedIndex = newIndex
                            alertHour = Self.hours[newIndex]
                        }
                    }
                }
                // `.onAppear`가 아니라 `.task`인 이유는 51차와 같다(42차 — 요소 등록 전에 실행되면
                // 이동이 유실되는 창이 있다). `isInteractive`는 이 초기 스크롤이 끝난 뒤에 켠다.
                .task {
                    proxy.scrollTo(alertHour, anchor: .center)
                    isInteractive = true
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Alert time")
                .accessibilityValue(Text(verbatim: Self.hourLabel(alertHour)))
                .accessibilityAdjustableAction { direction in
                    let newHour = Self.steppedHour(from: alertHour, direction: direction)
                    guard newHour != alertHour, let idx = Self.index(ofHour: newHour) else { return }
                    alertHour = newHour
                    committedIndex = idx
                    scrollOffsetY = CGFloat(idx) * Self.rowHeight
                    withAnimation(ReffiMotion.gated(ReffiMotion.standard, reduce: reduceMotion)) {
                        proxy.scrollTo(newHour, anchor: .center)
                    }
                }
            }
            .reffiFeedback(.selection, trigger: committedIndex)
        }
    }

    /// 가운데 고정 선택 밴드 — 종이 면(`sub` 톤, 캔버스 위 전용 서브 면이라 시트 배경과 짝이 맞는다) +
    /// 위아래 `ReffiRule(.ticket)`. 스크롤 콘텐츠 **뒤에** 깔리는 장식층이라 제스처를 먹지 않는다.
    private var selectionBand: some View {
        let shape = PaperRect(cornerRadius: ReffiRadius.sm, seed: 3)
        return VStack(spacing: 0) {
            ReffiRule(.ticket)
            Spacer(minLength: 0)
            ReffiRule(.ticket)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.rowHeight)
        .background { shape.fill(ReffiColor.sub) }
        .allowsHitTesting(false)
    }

    /// 다이얼 한 칸 — 더는 버튼이 아니다(선택은 탭이 아니라 다이얼 위치가 말한다). 중심에서의
    /// 연속 거리(`distance`)로 원근을 매겨 시스템 휠의 페이드를 종이 문법으로 옮긴다.
    private func dialRow(_ hour: Int) -> some View {
        let label = Self.hourLabel(hour)
        let index = Self.index(ofHour: hour) ?? 0
        let distance = Double(index) - Double(scrollOffsetY / Self.rowHeight)
        let perspective = Self.dialPerspective(distance: distance)
        return Text(verbatim: label)
            .font(.reffiNum(.body, for: label))
            .foregroundStyle(ReffiColor.ink)
            .frame(maxWidth: .infinity)
            .frame(height: Self.rowHeight)
            .opacity(perspective.opacity)
            .scaleEffect(reduceMotion ? 1 : perspective.scale)
    }

    // MARK: - 순수 로직(뷰 렌더 없이 `NotifyTimeSheetTests`가 잠근다 — 56차)

    /// `hours` 안에서 이 시각의 위치. 다이얼이 06~21시 연속 구간이라 `hour - 6`과 같지만, 그 사실에
    /// 기대지 않고 목록에서 직접 찾는다 — `hours`가 나중에 비연속으로 바뀌어도 원근·스냅 계산이 안 깨진다.
    static func index(ofHour hour: Int) -> Int? { hours.firstIndex(of: hour) }

    /// 연속 스크롤 오프셋 → 가장 가까운 행 인덱스(0-based, `hours` 범위로 clamp). 실제 스냅 물리는
    /// `.scrollTargetBehavior(.viewAligned)`가 지지만, 몇 번째 행이 지금 중심에 왔는지는 이 순수
    /// 계산이 판정한다 — `alertHour` 갱신·선택 햅틱이 이 값의 변화를 트리거로 쓴다.
    static func snapIndex(forOffset offset: CGFloat, rowHeight: CGFloat, count: Int) -> Int {
        guard count > 0, rowHeight > 0 else { return 0 }
        let raw = Int((offset / rowHeight).rounded())
        return min(max(raw, 0), count - 1)
    }

    /// 원근 감쇠 상수 — 몇 행 떨어지면 바닥에 닿는지(range)와 그 바닥값. §3.4류 타이포 스케일이
    /// 아니라 이 다이얼 전용의 새 시각 효과라 재사용할 기존 토큰이 없다(§4의 스페이싱·곡률과
    /// 다른 축 — "몇 pt인가"가 아니라 "몇 행 떨어지면 얼마나 옅어지는가"다).
    private static let perspectiveRange: Double = 2.5
    private static let perspectiveOpacityFloor: Double = 0.25
    private static let perspectiveScaleFloor: Double = 0.8

    /// 다이얼 원근 — 중심(거리 0)은 완전 불투명·원래 크기, 멀어질수록 옅고 작아지되 바닥 아래로는
    /// 안 내려간다. `distance`는 "행 몇 칸 떨어졌는가"(연속값 — 스크롤 중엔 정수 사이를 매끄럽게
    /// 지난다). 순수 함수라 스크롤·뷰 없이 잠글 수 있다.
    static func dialPerspective(distance: Double) -> (opacity: Double, scale: CGFloat) {
        let clamped = min(abs(distance), perspectiveRange)
        let opacity = 1 - clamped * ((1 - perspectiveOpacityFloor) / perspectiveRange)
        let scale = 1 - clamped * ((1 - perspectiveScaleFloor) / perspectiveRange)
        return (opacity, CGFloat(scale))
    }

    /// 접근성 adjustable 스텝 — 위/아래 스와이프 한 번 = 한 시간 칸. 경계(06·21시)에서 랩어라운드
    /// 하지 않는다 — 다이얼의 물리적 끝과 같다.
    static func steppedHour(from hour: Int, direction: AccessibilityAdjustmentDirection) -> Int {
        guard let idx = index(ofHour: hour) else { return hour }
        switch direction {
        case .increment: return hours[min(hours.count - 1, idx + 1)]
        case .decrement: return hours[max(0, idx - 1)]
        @unknown default: return hour
        }
    }

    /// 정시 라벨 — "8:00 AM" 형식(로케일 자동).
    static func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}
