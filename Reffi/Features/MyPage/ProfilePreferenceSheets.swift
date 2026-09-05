import SwiftUI

// 프로필 취향 시트 4종(닉네임·요리 스타일·태그·알림 시간). 이 파일이 들고 있던 private 시트 셸은
// 61차에 앱 전역 `Components/SheetShell`(§14.8)로 올라갔다 — 헤더·핸들·캔버스 배경·도킹 CTA·바닥
// 여백을 셸이 지므로 여기 시트들은 본문 구성과 자기 detent만 적는다(호출부 ProfileView는 이제
// detent를 적지 않는다).

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
        // 61차 — 필드 한 칸 + Save뿐인 짧은 입력이라 콘텐츠 맞춤 높이(§14.5)다. 옛 `.height(260)`은
        // 호출부가 든 매직 넘버라 Dynamic Type에서 조용히 잘렸다. Save는 셸의 바 슬롯이 진다(§14.4 도킹 커밋).
        SheetShell(title: "Nickname", onClose: { requestClose() }, sizing: .fitted) {
            TextField("Nickname", text: $draft)
                .reffiType(.body)
                .foregroundStyle(ReffiColor.ink)
                .fieldSurface(seed: 2)   // §13.8 필드 한 칸 — 캔버스 시트 위 독립 필드
                .submitLabel(.done)
                .onSubmit(commit)
                .sheetInset()
        } bar: {
            PaperButton(title: "Save", seed: 1, action: commit)
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

    var body: some View {
        SheetShell(title: "Cuisines", onClose: { dismiss() }) {
            ScrollView {
                VStack(alignment: .leading, spacing: ReffiSheet.itemGap) {
                    Text("Pick the kinds of food you like.\nWe'll use them for recommendations.")
                        .reffiType(.caption).foregroundStyle(ReffiColor.ink2)

                    // 칩은 제 폭으로 흐른다(`ReffiFlowLayout`, 61차) — 고정 칸의 `LazyVGrid(.adaptive(minimum: 92))`는
                    // "Mediterranean"이 칸보다 길어 말줄임됐고 짧은 라벨 옆은 빈 칸으로 남았다.
                    ReffiFlowLayout(spacing: ReffiSpace.s2, lineSpacing: ReffiSpace.s2) {
                        ForEach(CuisineStyle.allCases) { c in
                            SelectableChip(text: c.labelKey, selected: profile.cuisines.contains(c),
                                           fullWidth: false) {
                                profile.toggleCuisine(c)
                            }
                        }
                    }
                }
                .sheetInset()
                // 바가 없는 `.fills` 시트라 바닥 여백은 스크롤 콘텐츠 끝이 진다(§14.8 바닥 계약).
                .padding(.bottom, ReffiSheet.bottom)
            }
        }
        // 61차 — detent는 시트 안에 산다(§14.5). 칩 그리드는 접근성 글자 크기에서 `.medium`을 넘치므로
        // 실제로 스크롤되는 목록이어야 한다: 진입은 절반, 끌어올리면 `.large`.
        .presentationDetents([.medium, .large])
    }
}

/// 문자열 태그 편집 시트 — 비선호 재료·알레르기(§5.2)에 공용. 추가/삭제.
struct TagEditorSheet: View {
    let title: LocalizedStringKey
    let placeholder: LocalizedStringKey
    @Binding var tags: [String]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var fieldFocused: Bool
    @State private var draft: String = ""
    /// 시트 높이를 코드에서 올리기 위한 바인딩 축(`ToBuySearchSheet`와 같은 처방) — 입력 포커스 시 `.large`.
    @State private var detent: PresentationDetent = .medium

    var body: some View {
        SheetShell(title: title, onClose: { dismiss() }) {
            ScrollView {
                VStack(alignment: .leading, spacing: ReffiSheet.itemGap) {
                    HStack(spacing: ReffiSpace.s2) {
                        TextField(placeholder, text: $draft)
                            .reffiType(.body)
                            .foregroundStyle(ReffiColor.ink)
                            .fieldSurface(seed: 2)   // §13.8 필드 한 칸
                            .focused($fieldFocused)
                            .submitLabel(.done)
                            .onSubmit(add)
                        QuietButton(title: "Add", icon: ReffiIcon.add, action: add)
                    }

                    if tags.isEmpty {
                        Text("None yet")
                            .reffiType(.caption).foregroundStyle(ReffiColor.muted)
                    } else {
                        // 요리 스타일 시트와 같은 흐름 배치(61차) — 태그 길이가 제각각이라 고정 칸이 더 자주 잘렸다.
                        ReffiFlowLayout(spacing: ReffiSpace.s2, lineSpacing: ReffiSpace.s2) {
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
                .sheetInset()
                // 바가 없는 `.fills` 시트라 바닥 여백은 스크롤 콘텐츠 끝이 진다(§14.8 바닥 계약).
                .padding(.bottom, ReffiSheet.bottom)
            }
        }
        // 61차 — detent는 시트 안에 산다(§14.5). 태그가 쌓이면 그리드가 `.medium`을 넘치므로 스크롤한다.
        .presentationDetents([.medium, .large], selection: $detent)
        // 입력 포커스 → 시트를 `.large`로. 키보드가 떠도 태그 그리드가 가리지 않는다(`ToBuySearchSheet` 선례).
        .onChange(of: fieldFocused) { _, focused in
            if focused, detent != .large {
                withAnimation(ReffiMotion.gated(ReffiMotion.enter, reduce: reduceMotion)) {
                    detent = .large
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
    /// 한 번에 보이는 행 수 — 선택 행 ± 2. 다이얼 높이를 이 격자에서 파생시킨다(61차, 아래 `body` 주석).
    static let visibleRows = 5
    /// 밴드 위아래 여백(`safeAreaPadding`) — 다이얼 높이가 고정되며(61차) 지오메트리 없이도 아는 값이 됐다:
    /// (220 − 44) / 2 = 88, 정확히 두 행. `scrollOffsetY`의 **초기값**이 이 값을 알아야 한다 — 이 상태는 원시
    /// `contentOffset.y` 좌표(정렬 좌표 − topInset)라, 행 인덱스 × 행 높이로만 씨를 뿌리면 첫 스크롤 콜백
    /// 전까지 원근의 정점이 두 행 위에 잡힌다(61차 리뷰 — 58차 보정을 초기값에도 같은 방향으로 적용).
    static let topInset: CGFloat = (rowHeight * CGFloat(visibleRows) - rowHeight) / 2

    /// 연속 스크롤 오프셋 — `dialPerspective` 계산 전용(매 프레임 필요). 커밋 경로(`alertHour`·햅틱)는
    /// `committedIndex`가 따로 진다 — 원근은 부드러운 연속값이 필요하고 커밋은 "새 행이 중심에
    /// 왔다"는 이산 사건이라 세밀도가 다르다.
    @State private var scrollOffsetY: CGFloat
    /// 마지막으로 커밋한 행 인덱스 — 이 값이 바뀔 때만 `alertHour`를 쓰고 햅틱을 낸다.
    @State private var committedIndex: Int
    /// **58차-c — 기대 목표 인덱스 게이트.** "지금 프로그램 스크롤이 이 행을 향해 비행 중이다 —
    /// 도착할 때까지 지오메트리 콜백은 커밋하지 않는다"는 뜻이고, 도착(스냅 == 목표)하는 순간
    /// 스스로 비워진다(`dialCommitDecision`). 초기 센터링과 a11y 스텝의 애니메이션 스윕이 둘 다
    /// 이 게이트를 쓴다.
    ///
    /// 여기 있던 불리언 `isInteractive`(56~58차-b)는 이 일을 못 했다. `.task`가 `scrollTo`
    /// **직후 동기로** 켰는데 초기 센터링·시트 프리젠테이션이 만드는 `onScrollGeometryChange`
    /// 콜백은 그 본문보다 **늦게** 도착하므로, 게이트는 사실상 늘 열린 채였고 무접촉 오픈이
    /// 커밋 경로를 그대로 발화시켰다. 증거의 결이 둘로 갈리니 묶지 말 것 —
    /// **9→7은 실측**(58차-c RED 프로브가 `trajectory [7]`로 잡았다, `probe-RED-220345.xcresult`),
    /// **9→6은 재구성**(58차 세션 콘솔 관찰 + 무보정 clamp 산술: 원시 오프셋 < 22면 반올림이 0 이하로
    /// 떨어져 clamp가 인덱스 0=6시로 끌어올린다). 58차-b 리뷰가 이 쌍을 "measurement로 제시된
    /// reconstruction"이라 지적했으므로 확신도를 올려 붙이지 않는다.
    /// 실기기에서는 정착 콜백이 최종값을 되돌려 놓아 눈에 띄지 않지만 자국이
    /// 남는다 — 과도 구간의 일시 오기록이 `@AppStorage`를 거쳐 `ExpiryNotifier.reschedule`을
    /// 헛돌리고(알림 재등록 churn), 손대지 않은 다이얼에서 선택 틱 햅틱이 운다. 그리고 정착
    /// **전에** 시트가 뜯기면(플링 후 스와이프 dismiss, 백그라운드 킬) 그 과도값이 그대로 저장값이
    /// 되어 남는다 — 이것이 이 수정의 사용자 가시 심각도다.
    ///
    /// 불리언 대신 목표 인덱스를 드는 이유는 SwiftUI `scrollTo`에 완료 콜백이 없기 때문이다.
    /// "언제 끝나는가"를 시간으로 추측하는 대신 "어디에 닿아야 끝인가"를 값으로 들면, 도착 판정이
    /// 곧 완료 신호가 된다 — 타이밍 추측이 아니라 좌표가 게이트를 연다.
    @State private var pendingScrollTarget: Int?

    init() {
        let hour = ExpiryNotifier.alertHour
        let idx = Self.index(ofHour: hour) ?? 0
        _scrollOffsetY = State(initialValue: CGFloat(idx) * Self.rowHeight - Self.topInset)
        _committedIndex = State(initialValue: idx)
        // 58차-c — 게이트는 `.task`가 아니라 여기서 무장한다. 프리젠테이션이 만드는 첫 지오메트리
        // 콜백이 `.task` 본문보다 먼저 도착할 수 있어, `.task`에서 시드하면 그 사이에 무장 없는
        // 창이 생긴다 — 정확히 그 창이 58차-b가 남긴 구멍이었다.
        _pendingScrollTarget = State(initialValue: idx)
    }

    var body: some View {
        // 61차 — 다이얼 하나뿐인 선택 시트라 콘텐츠 맞춤 높이(§14.5). 옛 `.height(300)`은 호출부의 매직 넘버였다.
        SheetShell(title: "Alert time", onClose: { dismiss() }, sizing: .fitted) {
            ScrollViewReader { proxy in
                GeometryReader { geo in
                    let bandHeight = geo.size.height
                    let topInset = max(0, (bandHeight - Self.rowHeight) / 2)
                    ZStack {
                        selectionBand
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(Self.hours, id: \.self) { hour in
                                    dialRow(hour, topInset: topInset).id(hour)
                                }
                            }
                            .scrollTargetLayout()
                        }
                        // 첫·마지막 행도 밴드 중앙까지 올 수 있게 위아래를 행 반 폭만큼 비운다
                        // (§ safeAreaPadding 트릭 — `.viewAligned`가 재는 "정렬 경계"가 이 여백의
                        // 안쪽 가장자리라, 그 좌표계에서는 오프셋 0 = 0번 행이 밴드 중앙이다.
                        // **58차** — `onScrollGeometryChange`가 보고하는 원시 `contentOffset.y`는
                        // 이 여백(`topInset`)만큼 밀려 있어 같은 불변식이 아니다. 이 오프셋을 쓰는
                        // 두 소비자가 **함께** `topInset`을 되더해 보정한다 — 원근 계산
                        // (`dialDistance`)과 커밋 판정(`snapIndex`)이다. 원근에서 빠뜨리면 밴드 밖
                        // 위쪽 행이 선택 행보다 진하게 보이고(58차), 커밋에서 빠뜨리면 저장값이
                        // 두 칸 이른 시각(화면상 위쪽 행)으로 어긋난다(58차-b) — 각각 아래 두
                        // 주석 참고. transform이 원시 오프셋을 보고한다는 컨벤션 자체는 58차가
                        // 잠근 계약이라 그대로 둔다: 보정은 소비자 쪽에서 한다.
                        .safeAreaPadding(.vertical, topInset)
                        .scrollTargetBehavior(.viewAligned)
                        .scrollBounceBehavior(.basedOnSize)
                        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, newOffset in
                            scrollOffsetY = newOffset
                            // **58차-c** — 커밋 여부와 게이트 처분을 한 번에 정하는 순수 판정
                            // (`dialCommitDecision`). 도착 판정이 곧 초기 센터링의 완료 신호이므로,
                            // 게이트를 여는 1차 경로는 여기다 — 아래 `.onScrollPhaseChange`는 안전망일
                            // 뿐이다(초기 `scrollTo`는 `withAnimation` 없는 즉시 점프라 페이즈 전이가
                            // 아예 안 생길 수 있어, 해제를 페이즈에 기대면 안 된다).
                            let snap = Self.snapIndex(forOffset: newOffset, topInset: topInset,
                                                      rowHeight: Self.rowHeight,
                                                      count: Self.hours.count)
                            let decision = Self.dialCommitDecision(pendingTarget: pendingScrollTarget,
                                                                   snapIndex: snap,
                                                                   committedIndex: committedIndex)
                            pendingScrollTarget = decision.pendingTarget
                            if let commit = decision.commit {
                                committedIndex = commit
                                alertHour = Self.hours[commit]
                            }
                        }
                        // **58차-c 안전망** — 사용자가 다이얼에 손을 대는 순간 게이트를 연다.
                        // 프로그램 스크롤이 병리적으로 목표 행에 닿지 못해도(중간에 낚아채인 센터링)
                        // 터치가 두 번째 열쇠라 다이얼이 영영 먹통이 되지 않는다. 매핑 자체는
                        // `dialGateClears(on:)`가 순수하게 지고 여기서는 대입만 한다 — 그쪽 주석에
                        // `.animating`을 열면 안 되는 이유(a11y 스윕 보호)가 있다.
                        //
                        // **받아들인 대가(58차-c 리뷰 MINOR-5)** — 해제 열쇠 셋(초기 센터링 도착,
                        // 드래그가 목표 행을 지나며 만드는 도착, 터치)이 **모두** 빗나가면 사용자가
                        // 고른 행이 조용히 유실된다(fail-closed). 이 시트엔 확인 버튼이 없어 다이얼
                        // 위치 자체가 커밋이라, 저장 실패를 알리는 신호가 화면에 없다. 옛 fail-open
                        // (손대지 않은 값을 덮어쓰던 것)보다 데이터는 안전하지만 실패는 보이지 않는다 —
                        // 확률이 매우 낮아 감수한 선택이지 못 본 위험이 아니다.
                        .onScrollPhaseChange { _, newPhase in
                            if Self.dialGateClears(on: newPhase) { pendingScrollTarget = nil }
                        }
                    }
                }
                // `.onAppear`가 아니라 `.task`인 이유는 51차와 같다(42차 — 요소 등록 전에 실행되면
                // 이동이 유실되는 창이 있다). **58차-c** — 여기서 게이트를 켜던 `isInteractive = true`는
                // 사라졌다. 게이트는 `init()`이 이미 목표 행으로 무장했고, 이 `scrollTo`가 그 행에
                // **도착**하는 순간 지오메트리 콜백이 스스로 푼다. 이 줄이 게이트를 켜던 시절엔
                // 켜는 시점이 늘 콜백보다 일러서 초기 센터링이 통째로 커밋으로 샜다
                // (§`pendingScrollTarget` 주석).
                .task {
                    proxy.scrollTo(alertHour, anchor: .center)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Alert time")
                .accessibilityValue(Text(verbatim: Self.hourLabel(alertHour)))
                // **58차-c** — 값은 이 액션이 **먼저** 확정하고(VoiceOver가 방금 읽어 준 그 시각이다)
                // 화면만 애니메이션으로 뒤따른다. 그래서 스윕 도중 콜백에는 커밋 권한이 없어야 한다:
                // 게이트가 없던 시절엔 3행→4행 이동 중간에 스냅 3이 잡혀 `committedIndex`가 4→3→4로
                // 튀었다 — 한 스텝에 선택 햅틱 3연발, `@AppStorage` 10→9→10 churn. 목표에 닿으면
                // 게이트가 스스로 풀리고, 도중에 사용자가 드래그로 끼어들면 위 `.onScrollPhaseChange`가
                // 대신 푼다. 리듀스모션(`ReffiMotion.gated`)이면 애니메이션 없는 즉시 점프라 도착
                // 콜백 한 번에 풀린다. 무엇을 쓸지는 `dialAccessibilityStep`이 순수하게 정하고
                // 여기서는 대입만 한다.
                .accessibilityAdjustableAction { direction in
                    guard let step = Self.dialAccessibilityStep(fromHour: alertHour, direction: direction)
                    else { return }
                    alertHour = step.hour
                    committedIndex = step.index
                    scrollOffsetY = CGFloat(step.index) * Self.rowHeight - Self.topInset
                    pendingScrollTarget = step.pendingTarget
                    withAnimation(ReffiMotion.gated(ReffiMotion.standard, reduce: reduceMotion)) {
                        proxy.scrollTo(step.hour, anchor: .center)
                    }
                }
            }
            .reffiFeedback(.selection, trigger: committedIndex)
            // 다이얼은 `GeometryReader`라 고유 높이가 없다 — 맞춤 시트의 실측(`sheetFitHeight`)에서
            // 0으로 접히므로 보이는 행 수만큼 높이를 못 박는다(61차). 밴드 기하는 그대로 여기서
            // 파생된다: 220 − 44의 절반이 `topInset`(88 = 정확히 두 행)이라 위아래로 두 행씩 보인다.
            .frame(height: Self.rowHeight * CGFloat(Self.visibleRows))
            .sheetInset()
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
    /// 연속 거리(`distance`)로 원근을 매겨 시스템 휠의 페이드를 종이 문법으로 옮긴다. `topInset`은
    /// 호출부(`GeometryReader`)가 재는 밴드 상단 여백 — `dialDistance`가 왜 필요한지는 그쪽 주석.
    ///
    /// **60차 — 선택(밴드 중앙) 행만 hero(32)로 확대한다(오너 판정, §3.4).** §3.4의 숫자 3단
    /// 규율은 새 중간 크기 발명을 금지하지만, `hero`는 애초 "화면당 하나뿐인 주지표"를 위해 남겨
    /// 둔 단이고 이 다이얼이 지금 보여주는 선택된 시각이 정확히 그 자리다 — 그래서 넷째 단을 여는
    /// 대신 이미 있는 hero·body 두 단 사이에서 이 행의 소속만 거리로 정한다. `body`·`hero` 두
    /// `Text`를 겹쳐 두고 `dialHeroBlend`로 불투명도만 크로스페이드하는 이유는 `Font`가 SwiftUI의
    /// 보간 대상이 아니기 때문이다(opacity·scale과 달리 폰트 자체를 바꾸면 중간 프레임 없이 즉시
    /// 팝된다). 두 레이어가 각자 제 role로 그려지므로(`hero`의 `.largeTitle` 램프, `body`의
    /// `.subheadline` 램프) 크로스페이드 도중에도 접근성 글자 크기마다 그 role의 진짜 Dynamic
    /// Type 곡선을 탄다 — body를 상수 배율로 스케일업하는 방식이었다면 hero의 실제 곡선과
    /// 어긋났을 것이다. `rowHeight`·`topInset`·`snapIndex`는 전혀 건드리지 않는다 — hero는
    /// 시각 크로스페이드일 뿐 스냅 기하와 무관해 56~58차가 잠근 앵커 테스트가 그대로 선다.
    private func dialRow(_ hour: Int, topInset: CGFloat) -> some View {
        let label = Self.hourLabel(hour)
        let index = Self.index(ofHour: hour) ?? 0
        let distance = Self.dialDistance(index: index, scrollOffsetY: scrollOffsetY,
                                          topInset: topInset, rowHeight: Self.rowHeight)
        let perspective = Self.dialPerspective(distance: distance)
        let rawHeroBlend = Self.dialHeroBlend(distance: distance)
        // 리듀스모션에선 크로스페이드 대신 즉시 전환(§7.4) — 0.5 문턱은 두 이웃 행이 정확히
        // 절반씩 걸치는 대칭 핸드오프 지점과 같아, 끊어도 어색하지 않다.
        let heroBlend = reduceMotion ? (rawHeroBlend >= 0.5 ? 1.0 : 0.0) : rawHeroBlend
        return ZStack {
            Text(verbatim: label)
                .font(.reffiNum(.body, for: label))
                .opacity(1 - heroBlend)
            Text(verbatim: label)
                .font(.reffiNum(.hero, for: label))
                .opacity(heroBlend)
        }
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
    ///
    /// **58차-b 회귀**: `topInset` 되더하기는 `dialDistance`와 같은 이유로 필요하다 — 원시
    /// `contentOffset.y`는 `safeAreaPadding` 여백만큼 밀려 있어, 되더해야 비로소 행 인덱스
    /// 좌표계다. 58차는 이 보정을 렌더 소비자(`dialDistance`)에만 넣고 커밋 소비자인 여기를
    /// 빠뜨렸다. 보정 전에는 시간 9(인덱스 3)가 밴드 중앙에 정착한 오프셋 56이
    /// `round(56/44)`=1(=7시)로 계산돼, **열기만 해도** 그리고 다이얼을 굴릴 때마다 저장값이
    /// 두 칸 이른 시각(화면상 위쪽 행)으로 어긋났다 — 다이얼은 위가 06시라 인덱스가 2 작다는 건
    /// 곧 두 시간 이른 값이다(`i*44 - 76`을 무보정으로 나누면 언제나 `round(i - 1.727)` = `i - 2`).
    /// 직전 세션 콘솔에서 실측된 9→6은 그중 프리젠테이션 도중 상단 근처(원시 오프셋 < 22 —
    /// 무보정 반올림이 0 이하로 떨어져 clamp가 인덱스 0으로 끌어올린다) 콜백이 끼어든 경우다.
    static func snapIndex(forOffset offset: CGFloat, topInset: CGFloat, rowHeight: CGFloat, count: Int) -> Int {
        guard count > 0, rowHeight > 0 else { return 0 }
        let raw = Int(((offset + topInset) / rowHeight).rounded())
        return min(max(raw, 0), count - 1)
    }

    /// 커밋 게이트 판정(58차-c) — 지오메트리 콜백 하나를 받아 ① 게이트를 어떻게 둘지 ② 커밋할
    /// 인덱스가 있는지를 함께 돌려준다. `snapIndex`가 "어느 행이 중심인가"를 답한다면 이쪽은
    /// "그 답을 지금 믿어도 되는가"를 답한다 — 뷰 렌더 없이 잠기도록 둘 다 순수 함수다.
    ///
    /// `pendingTarget`은 "프로그램 스크롤이 이 행을 향해 비행 중"이라는 뜻이다(초기 센터링,
    /// a11y 스텝의 애니메이션 스윕). 비행 중엔 침묵하고, **도착(스냅 == 목표)** 하는 순간 게이트만
    /// 풀고 커밋은 하지 않는다 — 그 값은 이미 옳기 때문이다(`init()`과 adjustable 액션이 목표를
    /// 정할 때 `committedIndex`·`alertHour`를 직접 썼다). 게이트가 풀린 뒤에야 스냅 변화가 비로소
    /// 사용자의 선택으로 읽힌다. 도착 판정을 **정확히** 같음으로 두는 이유는, "근처면 도착"으로
    /// 느슨하게 풀면 관성이 스치고 지나가는 이웃 행에서 조기에 열려 아직 프로그램 스크롤인
    /// 나머지 구간이 커밋으로 새기 때문이다.
    ///
    /// **58차-c 회귀**: 이 자리에 있던 불리언 `isInteractive`는 `.task`가 `scrollTo` 직후 동기로
    /// 켜서 초기 센터링·프리젠테이션 콜백을 전부 통과시켰다 — 무접촉 오픈이 저장값을 건드리고
    /// 선택 햅틱을 울렸다(§`pendingScrollTarget` 주석의 실측 서사).
    ///
    /// **전제조건(58차-c 리뷰 NIT-1)**: `snapIndex`는 반드시 `hours`의 유효 인덱스여야 한다.
    /// 호출부가 반환된 `commit`으로 `hours[commit]`을 첨자하므로 범위 밖이면 트랩이다. 이 함수는
    /// 스스로 clamp하지 않고 `snapIndex(forOffset:...)`의 자체 clamp에 의존한다 — 다른 산출 경로를
    /// 물리면 그쪽이 범위를 책임져야 한다.
    static func dialCommitDecision(pendingTarget: Int?, snapIndex: Int,
                                   committedIndex: Int) -> (pendingTarget: Int?, commit: Int?) {
        if let pendingTarget {
            // 도착이면 게이트만 푼다(커밋 없음). 아직 비행 중이면 침묵 — 게이트를 그대로 든다.
            return snapIndex == pendingTarget ? (nil, nil) : (pendingTarget, nil)
        }
        // 게이트가 열린 뒤 — 중심 행이 바뀐 것만 커밋한다(같은 행 재보고는 no-op).
        return snapIndex == committedIndex ? (nil, nil) : (nil, snapIndex)
    }

    /// 페이즈 → 게이트 해제 여부(58차-c) — 사용자의 손이 닿은 위상에서만 참이다.
    ///
    /// **`.animating`이 거짓인 것이 a11y 보호의 핵심 계약이다.** adjustable 스텝은
    /// `withAnimation` + `scrollTo`로 화면을 옮기는데 그때의 위상이 바로 `.animating`이다. 여기서
    /// 해제하면 스윕 중간 스냅(3행→4행 이동 중의 3)이 커밋 권한을 얻어 `committedIndex`가 4→3→4로
    /// 튄다 — 한 스텝에 햅틱 3연발, `@AppStorage` 10→9→10 churn. `.decelerating`도 같은 이유로
    /// 거짓이다(관성은 사용자의 손이 이미 떠난 구간이라, 해제는 `.tracking` 시점에 이미 끝났다).
    ///
    /// `ScrollPhase`는 `@frozen`이라(SDK 확인: `SwiftUICore.swiftinterface:625`, 5케이스) 전수
    /// 스위치가 안전하고 `@unknown default`가 불필요하다 — 테스트도 5케이스를 전수 단언한다.
    ///
    /// **이 함수가 잡는 것과 못 잡는 것**(58차-c 리뷰 MAJOR): 잡는 것은 **매핑 의미론**이다 —
    /// `.animating`을 해제 쪽으로 옮기는 뮤테이션은 테스트가 빨갛게 만든다. 못 잡는 것은 **뷰의
    /// 대입**이다 — 호출부가 반환값을 무시하거나 `pendingScrollTarget = nil`을 지워도 순수
    /// 테스트는 전부 초록이다. 그 잔여 공백은 호스팅 a11y 프로브가 메워야 하는데, 이 환경에서는
    /// 애니메이션 `scrollTo`가 완주하지 않아 플랩 자체가 재현되지 않는다(판별력 없는 가드는 남기지
    /// 않는다는 58차-b 규율) — 그래서 공백으로 남기고 여기 적어 둔다.
    static func dialGateClears(on phase: ScrollPhase) -> Bool {
        switch phase {
        case .tracking, .interacting: return true
        case .idle, .decelerating, .animating: return false
        }
    }

    /// 접근성 adjustable 한 스텝의 상태 전이(58차-c) — 새 시각·그 행 인덱스·무장할 게이트 목표를
    /// 한 번에 정한다. 아무 일도 일어나지 않아야 하면(경계에서 더 밀 수 없거나 현재 시각이 목록
    /// 밖이면) `nil`이라 호출부가 그대로 빠져나간다.
    ///
    /// `pendingTarget`이 `index`와 **같다**는 것이 이 함수가 지는 계약이다. a11y 스텝은 값을 먼저
    /// 직접 쓰고 화면만 뒤따르게 하므로, 게이트는 "방금 쓴 그 행에 화면이 도착할 때까지"만 닫혀
    /// 있어야 한다. 둘이 어긋나면 도착 판정이 영영 안 맞아 게이트가 안 열리거나(선택 유실), 엉뚱한
    /// 행에서 열려 스윕 중간 커밋이 샌다.
    ///
    /// **이 함수가 잡는 것과 못 잡는 것**(58차-c 리뷰 MAJOR): 잡는 것은 **전이 의미론**이다 —
    /// 목표를 인덱스와 다르게 만들거나 경계 no-op을 깨는 뮤테이션은 테스트가 빨갛게 만든다.
    /// 못 잡는 것은 **뷰의 대입**이다 — 호출부에서 `pendingScrollTarget = step.pendingTarget` 한
    /// 줄만 지워도 a11y 커밋 플랩이 그대로 부활하는데 순수 테스트는 전부 초록으로 남는다.
    /// 그 잔여 공백을 메울 호스팅 a11y 프로브는 이 환경에서 판별력을 가질 수 없다(위 `dialGateClears`
    /// 주석과 같은 이유 — 애니메이션 `scrollTo` 미완주로 플랩이 재현되지 않는다).
    static func dialAccessibilityStep(fromHour hour: Int,
                                      direction: AccessibilityAdjustmentDirection)
        -> (hour: Int, index: Int, pendingTarget: Int)? {
        let newHour = steppedHour(from: hour, direction: direction)
        guard newHour != hour, let idx = index(ofHour: newHour) else { return nil }
        return (hour: newHour, index: idx, pendingTarget: idx)
    }

    /// 다이얼 원근 거리 — 이 행이 지금 밴드 중앙에서 몇 칸 떨어져 있는가. `scrollOffsetY`(스크롤뷰가
    /// `onScrollGeometryChange`로 보고하는 원시 `contentOffset.y`)는 위 `safeAreaPadding` 트릭이
    /// 만든 상단 여백(`topInset`)만큼 밴드 중앙 기준에서 밀려 있다 — `.viewAligned`의 정렬 좌표계는
    /// "오프셋 0 = 0번 행이 중앙"이지만, 원시 `contentOffset.y`는 그 좌표계와 `topInset`만큼 어긋난다.
    ///
    /// **58차 회귀**: 이 되더하기가 빠진 채 `scrollOffsetY`를 그대로 `rowHeight`로 나눠 쓰면, 원근의
    /// 정점(거리 0)이 실제 밴드 중앙보다 `topInset/rowHeight`행 위에 잡힌다(58차 당시 실측값
    /// `topInset`≈76·`rowHeight`=44 → 약 1.7행이라 뚜렷하게 위쪽 행 쪽으로 쏠렸다. 61차에 다이얼
    /// 높이가 220으로 고정되며 `topInset`은 88 = 정확히 두 행이 됐다 — 어긋남의 크기만 바뀌고
    /// 되더하기가 필요하다는 논지는 그대로다). 그 결과 밴드 안의 선택 행(예: 9시)이 바로 위 미선택 행(예: 8시)
    /// 보다 옅게 보였다 — 페이드 정점이 밴드를 등지고 위쪽으로 새어 있었던 것. 순수 함수라 스크롤·뷰 없이 잠글 수 있다.
    static func dialDistance(index: Int, scrollOffsetY: CGFloat, topInset: CGFloat, rowHeight: CGFloat) -> Double {
        guard rowHeight > 0 else { return 0 }
        return Double(index) - Double((scrollOffsetY + topInset) / rowHeight)
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

    /// Hero 전이 폭(60차) — 이 폭 안에서 선택 행(hero)과 인접 행(body) 사이를 선형 크로스페이드
    /// 한다. 1행 전체를 쓰는 이유는 대칭 핸드오프다: 인접 행이 정확히 밴드 중앙에 오는 순간
    /// (거리 1)엔 이 행이 완전히 body로 넘어가 있어야, 두 행이 동시에 hero로 보이는 "이중
    /// 히어로" 순간이 생기지 않는다. `perspectiveRange`(2.5, 옅음·작아짐의 감쇠 폭)와 다른
    /// 축이라 별도 상수다 — 저건 "몇 행 떨어지면 바닥에 닿는가", 이건 "몇 행 안에서 딱 한
    /// 행만 hero로 남는가"라 감쇠 곡선을 공유할 이유가 없다.
    private static let heroBlendRange: Double = 1.0

    /// 선택 행 hero 확대(60차, §3.4) — 이 행이 지금 "화면당 하나뿐인 주지표" 자리에 얼마나
    /// 들어와 있는가(0=완전 body, 1=완전 hero). 중심(거리 0)에서 1, `heroBlendRange` 밖에서
    /// 0 — 선형 보간. 순수 함수라 스크롤·뷰 없이 잠글 수 있다(`dialRow`가 실제 렌더에 쓴다).
    static func dialHeroBlend(distance: Double) -> Double {
        let clamped = min(abs(distance), heroBlendRange)
        return 1 - clamped / heroBlendRange
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
