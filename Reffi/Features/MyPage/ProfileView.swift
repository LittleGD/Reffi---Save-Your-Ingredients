import SwiftUI
import UserNotifications

/// 프로필/마이(§5) — 무낭비 리포트 + 요리 취향(스타일·비선호·알레르기) + 알림 + 계정.
/// 구성은 Main의 리퀴드글래스 배경 + Fridge의 "흰 영수증 더미" 문법(톱니+점선+틸트·슬립)을 그대로 따른다.
/// 흰 종이 면은 그레인 없이 깨끗하게 — 그레인은 채도 버튼 면 전용(PaperButton 문법).
struct ProfileView: View {
    /// 현재 탭으로 표시 중인지 — 아니면 본문을 세우지 않는다(`MainView(isActive:)`·`FridgeView` 선례).
    /// 루트가 세 패인을 모두 살려 두는 대가로, 가려진 이 화면도 store 변이마다 body가 다시 돌아
    /// 리퀴드글래스 블롭 세 장과 영수증 일곱 장을 보이지도 않는 채로 다시 그렸다.
    /// 상태(`@AppStorage`·시트 선택)와 시트 프레젠테이션은 그대로 살고, 그리는 것만 끊는다.
    var isActive: Bool = true

    @Environment(FridgeStore.self) private var store
    @Environment(ProfileStore.self) private var profile
    @Environment(AuthStore.self) private var auth
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    // 알림 SSOT — ExpiryNotifier의 @AppStorage 키를 직접 읽어 실제 스케줄에 반영한다.
    @AppStorage(ExpiryNotifier.enabledKey) private var alertsEnabled = false
    @AppStorage(ExpiryNotifier.hourKey) private var alertHour = ExpiryNotifier.defaultHour

    // 감각 SSOT — 같은 키를 홈(MainView)과 모든 햅틱 호출부(`.reffiFeedback`)가 함께 읽는다.
    @AppStorage(ReffiFeedback.hapticsKey) private var hapticsEnabled = true
    @AppStorage(ReffiFeedback.tiltKey) private var tiltEnabled = true

    @State private var sheet: Sheet?
    @State private var showLogout = false
    @State private var showDelete = false
    @State private var showAuth = false
    @State private var showMyRecipes = false
    @State private var showResetConfirm = false
    @State private var showSampleConfirm = false
    @State private var showDenied = false
    @State private var destructiveHaptic = 0   // 룰⑦ — 계정삭제·전체초기화 확정 시 .warning 트리거

    private enum Sheet: String, Identifiable {
        case nickname, cuisines, favorites, disliked, allergies, time
        var id: String { rawValue }
    }

    /// 스크롤 앵커 id — 하단 섹션까지 프로그램 스크롤(QA 스크린샷)용.
    private enum Anchor: Hashable { case bottom }

    /// 영수증 인셋 — Fridge cardInset처럼 페이지 마진 위에 추가로 좁혀 영수증 폭을 만든다.
    private let receiptInset: CGFloat = 6

    var body: some View {
        @Bindable var profile = profile
        ScrollViewReader { proxy in
        ScrollView {
            // 가려진 동안은 **아무것도 세우지 않는다**(위 `isActive` 주석) — 상태는 그대로 살아 있고,
            // 활성화되는 프레임에 이 서브트리가 통째로 다시 선다(포기하는 것은 스크롤 위치 하나다).
            if isActive {
                VStack(alignment: .leading, spacing: ReffiSpace.s5) {
                    header
                    // 영수증 스택 — 설정 화면이라 기울임 없이 정돈된 정렬(질서 있는 영수증 문법).
                    // 무낭비 리포트는 냉장고 페이지 History(No-waste report)로 이동.
                    tasteReceipt
                    householdReceipt
                    notifyReceipt
                    feelReceipt
                    recipesReceipt
                    languageReceipt
                    dataReceipt
                    accountReceipt
                    Color.clear.frame(height: 1).id(Anchor.bottom)   // 스크롤 하단 앵커(QA 스크린샷)
                }
                .padding(.horizontal, ReffiGrid.margin + receiptInset)
                .padding(.top, ReffiSpace.s5)
                .padding(.bottom, ReffiChrome.navClearance)   // 떠 있는 캡슐 네비 위로 스크롤 여유
            }
        }
        #if DEBUG
        // 스크린샷·QA용 — 하단 섹션(Data·Account)까지 스크롤(-fridgeTab 선례).
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-profileBottom") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    proxy.scrollTo(Anchor.bottom, anchor: .bottom)
                }
            }
        }
        #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 배경도 게이트 안쪽이다 — 블롭 세 장 + 글래스 프로스트가 가려진 채로 서 있을 이유가 없고,
        // `accent`가 읽는 `store.sorted`(전체 정렬)도 비활성 프레임에서는 돌지 않는다.
        .background { if isActive { LiquidGlassBackground(accent: accent) } }
        .sheet(item: $sheet) { which in
            switch which {
            case .nickname:  NicknameEditSheet().presentationDetents([.height(260)])
            case .cuisines:  CuisinePickerSheet().presentationDetents([.medium, .large])
            case .favorites: TagEditorSheet(title: "Favorites", placeholder: "e.g. Tofu",
                                            tags: $profile.favorites).presentationDetents([.medium, .large])
            case .disliked:  TagEditorSheet(title: "Disliked", placeholder: "e.g. Cucumber",
                                            tags: $profile.disliked).presentationDetents([.medium, .large])
            case .allergies: TagEditorSheet(title: "Allergies", placeholder: "e.g. Peanuts",
                                            tags: $profile.allergies).presentationDetents([.medium, .large])
            case .time:      NotifyTimeSheet().presentationDetents([.height(300)])
            }
        }
        .sheet(isPresented: $showAuth) { AuthView() }
        .sheet(isPresented: $showMyRecipes) { MyRecipesView() }
        // 룰⑧ — 로그아웃은 세션만 해지하는 상태 전환이다. 냉장고·이력·프로필은 이 기기에
        // 그대로 남고, 소유자 키도 직전 계정 id로 유지된다(AuthStore.signOut / accountUserID).
        // 뒤이어 붙는 익명 게스트 세션은 소유자 대조 대상이 아니라 콜드 런치를 거쳐도 와이프가 없다
        // (ReffiApp.reconcileDataOwner 보장 ①). → 파괴가 아니므로 confirmationDialog가 맞다.
        // 룰⑦ 파괴 확인 햅틱(.warning)도 넣지 않는다 — 지우는 데이터가 없어 파괴 분류가 아니다.
        .confirmationDialog(Text("Log out of Reffi?"), isPresented: $showLogout, titleVisibility: .visible) {
            Button("Log out", role: .destructive) { Task { await auth.signOut() } }
        } message: {
            // 정직한 카피 — 확인 강도를 낮춘 만큼 결과를 명시한다(데이터는 남는다).
            Text("Your fridge and history stay on this device. Log back in anytime.")
        }
        // 룰⑧ — 계정삭제는 복구 불가능 → alert(중앙 고정, 실수 방지) 유지.
        .alert("Delete account", isPresented: $showDelete) {
            Button("Delete", role: .destructive) {
                destructiveHaptic += 1   // 룰⑦ — 파괴 확정(.warning)
                Task {
                    await auth.signOut()      // scope .local — 오프라인에서도 로그아웃
                    store.resetAllData()      // 이 기기 냉장고·이력 삭제
                    profile.resetAll()        // 프로필·취향 초기화
                    // 소유자 키도 함께 해제 — 남겨두면 이후 게스트 구간에 새로 쌓은 데이터가
                    // 다음 가입 시 '다른 계정 전환'으로 오인돼 조용히 와이프된다(승계 안내와 모순).
                    UserDefaults.standard.removeObject(forKey: DataOwner.key)
                    // 온보딩 플래그는 유지 — 재온보딩을 강제하지 않는다.
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            // 정직한 카피 — 서버 계정 완전 삭제는 준비 중(AuthStore TODO: Edge Function).
            Text("This erases this device's data and signs you out. Full server account deletion is coming soon.")
        }
        // 룰⑧ — 순수 알림성(권한 안내) → alert 유지.
        .alert(Text("Notifications are off"), isPresented: $showDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Allow notifications for Reffi in Settings to get expiry alerts.")
        }
        // 룰⑧ — 샘플 로드는 복구 불가능(loadSampleData가 pendingUndo를 먼저 지운다) → alert.
        .alert("Load the sample fridge?", isPresented: $showSampleConfirm) {
            Button("Replace with sample data", role: .destructive) {
                destructiveHaptic += 1   // 룰⑦ — 파괴 확정(.warning)
                withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                    store.loadSampleData()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your current ingredients and history will be replaced.")
        }
        // 룰⑧ — 전체초기화는 복구 불가능 → confirmationDialog에서 alert로 재분류.
        .alert("Reset all data?", isPresented: $showResetConfirm) {
            Button("Reset everything", role: .destructive) {
                destructiveHaptic += 1   // 룰⑦ — 파괴 확정(.warning)
                withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                    store.resetAllData()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Ingredients and history will be deleted. This can't be undone.")
        }
        .reffiFeedback(.warning, trigger: destructiveHaptic)
        // 시스템 설정에서 권한을 나중에 회수한 경우 — 토글이 켜진 채 조용히 실패하지 않게 동기화.
        .task { await syncAuthorization() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await syncAuthorization() } }
        }
    }

    /// 알림 권한 동기화 — 켜진 상태인데 시스템 권한이 거부로 바뀌었으면 토글을 내리고 스케줄을 걷어낸다.
    private func syncAuthorization() async {
        guard alertsEnabled else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus == .denied {
            alertsEnabled = false
            ExpiryNotifier.reschedule(for: store.ingredients)
        }
    }

    /// 배경 액센트 — 가장 임박한 재료의 신선도색(Fridge와 동일, 세 탭이 한 몸).
    private var accent: Color { store.sorted.first?.freshness.main ?? ReffiColor.fresh }

    // MARK: - 헤더 (아바타 + 닉네임 — Main·Fridge 디스플레이 헤더 문법)
    private var header: some View {
        Button { sheet = .nickname } label: {
            HStack(spacing: ReffiSpace.s4) {
                // 아바타 — 닉네임 이니셜(워드마크 서체, 한글은 Pretendard). 빈 닉네임은 아이콘 폴백.
                // 잉크는 blueDark다 — blue는 흰 글자를 받는 면 색이라 blue-light 종이 위에서 대비가 안 선다(§2.2).
                Group {
                    if avatarInitial.isEmpty {
                        ReffiIcon.profile.reffi(30).foregroundStyle(ReffiColor.blueDark)
                    } else {
                        Text(avatarInitial)
                            // 폴백 판별은 공용 `String.hasHangul`(§ReffiTypography) — 아바타만 라틴 쪽이
                            // 30pt 전용 크기라 `font(for:)`를 그대로 못 쓰고 판별만 공유한다.
                            .font(avatarInitial.hasHangul
                                  ? ReffiTextRole.display.koreanDisplayFont
                                  : .custom("StoryScript-Regular", size: 30, relativeTo: .title))
                            // 한글 아바타는 디스플레이 role(34) 재사용 + 28pt로 축소(전용 사이즈 신설 금지, 시각 동일).
                            .scaleEffect(avatarInitial.hasHangul ? 28.0 / 34.0 : 1, anchor: .center)
                            .foregroundStyle(ReffiColor.blueDark)
                    }
                }
                .frame(width: 64, height: 64)
                .background {
                    let s = PaperBlob(sides: 9, seed: 2)
                    s.fill(ReffiColor.blueLight).paperEdge(s)
                }
                VStack(alignment: .leading, spacing: 2) {
                    // 한글 닉네임은 Story Script(한글 미지원) 대신 Pretendard Bold 폴백(§3.1).
                    Text(profile.nickname)
                        .font(ReffiTextRole.display.font(for: profile.nickname))
                        .foregroundStyle(ReffiColor.ink)
                        .lineLimit(1)
                    Text(subtitle).reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                }
                Spacer(minLength: 0)
                ReffiIcon.manual.reffi(16, .bold).foregroundStyle(ReffiColor.muted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.reffiPress)
        .accessibilityLabel("Edit nickname")
        .accessibilityValue(profile.nickname)
    }

    /// 아바타 이니셜 — 닉네임 첫 글자(대문자).
    private var avatarInitial: String {
        String(profile.nickname.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
    }

    /// 부제 — 요리 취향 요약(스트릭은 리포트 도장으로 이동해 중복 제거). 취향 없으면 담백한 문구.
    private var subtitle: String {
        profile.cuisines.isEmpty ? String(localized: "Saving food with Reffi") : profile.cuisines.summaryText
    }

    // MARK: - 요리 취향 영수증
    private var tasteReceipt: some View {
        ReceiptCard(title: String(localized: "Taste")) {
            SettingsRow(label: "Cuisines", value: profile.cuisines.summaryText,
                        valueColor: profile.cuisines.isEmpty ? ReffiColor.muted : ReffiColor.blueDark) {
                sheet = .cuisines
            }
            ReceiptRule()
            SettingsRow(label: "Favorites", value: tagSummary(profile.favorites)) { sheet = .favorites }
            ReceiptRule()
            SettingsRow(label: "Disliked", value: tagSummary(profile.disliked)) { sheet = .disliked }
            ReceiptRule()
            SettingsRow(label: "Allergies", value: tagSummary(profile.allergies)) { sheet = .allergies }
        }
    }

    // MARK: - 가구 인원 영수증 — 레시피 양·쇼핑 수량의 근거. 인라인 칩 단일 선택(Remind me 문법).
    private var householdReceipt: some View {
        ReceiptCard(title: String(localized: "Household")) {
            VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                Text("We'll size your restock amounts to match.")
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                HStack(spacing: ReffiSpace.s2) {
                    ForEach(HouseholdSize.allCases) { h in
                        SelectableChip(text: h.label, selected: profile.household == h,
                                       fullWidth: false) {
                            profile.household = h
                        }
                    }
                }
            }
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s4)
        }
    }

    private func tagSummary(_ tags: [String]) -> String {
        guard !tags.isEmpty else { return String(localized: "None yet") }   // 빈 상태 카피 통일(Cuisines·시트와 동일)
        let head = tags.prefix(2).joined(separator: ", ")
        let extra = tags.count - Swift.min(2, tags.count)
        return extra > 0 ? "\(head) +\(extra)" : head
    }

    // MARK: - 알림 영수증 — ExpiryNotifier 실배선(토글=권한요청·롤백, 시각=스케줄 반영).
    private var notifyReceipt: some View {
        ReceiptCard(title: String(localized: "Notifications")) {
            // 감각 영수증과 같은 토글 행 문법(SettingsToggle) — 여백·타이포·VoiceOver 처리를 공유한다.
            SettingsToggle(title: "Expiry alerts",
                           caption: "A morning reminder for what expires today and tomorrow",
                           isOn: $alertsEnabled)
            .onChange(of: alertsEnabled) { _, on in
                if on {
                    // 켤 때만 권한 요청 — 거부되면 토글을 되돌리고 안내(§소프트 애스크).
                    Task {
                        if await ExpiryNotifier.requestAuthorization() {
                            ExpiryNotifier.reschedule(for: store.ingredients)
                        } else {
                            alertsEnabled = false
                            showDenied = true
                        }
                    }
                } else {
                    ExpiryNotifier.reschedule(for: store.ingredients)   // 끄면 대기 알림 제거
                }
            }

            if alertsEnabled {
                ReceiptRule()
                SettingsRow(label: "Time", value: alertHourText, numeric: true) { sheet = .time }
            }
            // 후속: ExpiryNotifier는 D-0/D-1(오늘·내일 만료)만 발화한다 — 리드데이(D-N) 선택은
            // 스케줄러가 아직 지원하지 않아 UI에서 뺐다. 리드데이 지원을 넣을 때 칩 UI를 되살린다.
        }
        // 시각 변경(NotifyTimeSheet가 같은 @AppStorage 키를 쓴다)을 실제 스케줄에 반영.
        .onChange(of: alertHour) { _, _ in
            if alertsEnabled { ExpiryNotifier.reschedule(for: store.ingredients) }
        }
    }

    /// 알림 시각 표시 — 정시(:00) 라벨.
    private var alertHourText: String { NotifyTimeSheet.hourLabel(alertHour) }

    // MARK: - 감각 영수증 — 홈 물리 필드의 촉각·기울임 실배선(§7.6 · §13.4).
    // 두 스위치 모두 **시스템 접근성 설정 위에 얹히는 선택**이다: Reduce Motion이 켜져 있으면
    // 기울임은 이 토글과 무관하게 꺼지고(시스템 우선), 토글은 Reduce Motion을 쓰지 않는 사람이
    // "그래도 폰이 흔들리는 건 싫다"고 말하는 자리다.
    private var feelReceipt: some View {
        ReceiptCard(title: String(localized: "Feel")) {
            SettingsToggle(title: "Collision haptics",
                           caption: "Feel ingredients knock into each other on the counter",
                           isOn: $hapticsEnabled)
            ReceiptRule()
            SettingsToggle(title: "Tilt gravity",
                           caption: "Tilt your phone and the ingredients roll that way",
                           isOn: $tiltEnabled)
        }
    }

    // MARK: - 내 레시피 영수증 (커스텀 — 추천 풀에 합류)
    private var recipesReceipt: some View {
        ReceiptCard(title: String(localized: "My recipes")) {
            SettingsRow(label: "Custom recipes",
                        value: store.userRecipes.isEmpty ? String(localized: "None yet") : "\(store.userRecipes.count)",
                        valueColor: store.userRecipes.isEmpty ? ReffiColor.muted : ReffiColor.blueDark,
                        numeric: !store.userRecipes.isEmpty) {
                showMyRecipes = true
            }
        }
    }

    // MARK: - 언어 영수증 — 앱별 언어는 iOS 설정이 정본. 인앱 가짜 스위처(재시작 필요·번들 스위즐)
    // 대신 설정 딥링크로 보낸다(위약 금지). en·ko .lproj가 둘 다 있어 설정에 언어 행이 항상 노출된다.
    private var languageReceipt: some View {
        ReceiptCard(title: String(localized: "Language")) {
            SettingsRow(label: "App language", value: currentLanguageName) {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            ReceiptRule()
            Text("Switch between English and Korean in iOS Settings.")
                .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                .padding(.horizontal, ReffiSpace.s5)
                .padding(.vertical, ReffiSpace.s3)
        }
    }

    /// 현재 앱 언어의 엔도님(English·한국어) — 로케일에서 파생한 데이터 값이라 xcstrings 등록 대상이 아니다.
    private var currentLanguageName: String {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        return Locale(identifier: code).localizedString(forLanguageCode: code)?.capitalized ?? code
    }

    // MARK: - 데이터 관리 영수증 (샘플 불러오기·전체 초기화)
    private var dataReceipt: some View {
        ReceiptCard(title: String(localized: "Data")) {
            QuietButton(title: "Load the sample fridge", icon: ReffiIcon.fridge, tint: ReffiColor.blueDark) {
                if store.isPristine {
                    withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                        store.loadSampleData()
                    }
                } else {
                    showSampleConfirm = true
                }
            }
            .padding(.horizontal, ReffiSpace.s3)
            .padding(.vertical, ReffiSpace.s1)
            ReceiptRule()
            QuietButton(title: "Reset all data", icon: ReffiIcon.toss, tint: ReffiColor.urgentDark) {
                showResetConfirm = true
            }
            .padding(.horizontal, ReffiSpace.s3)
            .padding(.vertical, ReffiSpace.s1)
        }
    }

    // MARK: - 계정 영수증
    private var accountReceipt: some View {
        ReceiptCard(title: String(localized: "Account")) {
            // 로그인 상태 행 — 이메일(로그인) 또는 게스트 안내.
            HStack {
                Text(auth.isGuest ? "Guest mode" : "Signed in")
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                Spacer()
                Text(auth.userEmail ?? String(localized: "Sign up to keep your data"))
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink)
                    .lineLimit(1).truncationMode(.middle)
            }
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s3)
            ReceiptRule()
            QuietButton(title: auth.isGuest ? "Log in / Sign up" : "Log out",
                        icon: ReffiIcon.go, tint: ReffiColor.blueDark) {
                // 게스트는 익명 세션을 유지한 채 시트에서 전환/로그인(승계 보장).
                if auth.isGuest { showAuth = true }
                else { showLogout = true }
            }
            .padding(.horizontal, ReffiSpace.s3)
            .padding(.vertical, ReffiSpace.s1)
            ReceiptRule()
            // toss(재료 버림)와 의미 충돌 방지 — 탈퇴는 별도 아이콘(x).
            QuietButton(title: "Delete account", icon: ReffiIcon.close, tint: ReffiColor.urgentDark) {
                showDelete = true
            }
            .padding(.horizontal, ReffiSpace.s3)
            .padding(.vertical, ReffiSpace.s1)
        }
    }
}

// MARK: - 재사용 컴포넌트

/// 흰 영수증 카드 — Fridge 영수증(FridgeCard·ExpandedFridgeCard)과 같은 문법.
/// 톱니(절취) 엣지 + 헤더 + 점선 룰, 면은 그레인 없는 깨끗한 흰 종이.
/// 헤더 라벨은 번역되는 문자열이라 올캡 모노 크롬이 아니라 `caption`을 쓴다(§3.5).
struct ReceiptCard<Content: View>: View {
    let title: String
    var stamp: String? = nil        // 제목 옆 고무 도장(DDayStamp) — 스트릭 등
    var trailing: String? = nil     // 헤더 우측 보조(날짜 등)
    @ViewBuilder var content: Content

    private let toothH: CGFloat = ReffiTooth.card

    var body: some View {
        let shape = ReceiptShape(tooth: toothH)
        let paper = ReffiColor.receipt   // 흰 영수증(Fridge와 동일)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                // 섹션 제목은 **번역되는** 문자열(취향·가구 인원·알림·내 레시피)이라 올캡 모노 크롬을
                // 쓰지 않는다(§3.5) — 한글엔 대문자가 없어 `.uppercased()`가 no-op이 되고 10pt에
                // 자간 1.6만 남는다. 문장형 라벨은 caption.
                Text(title)
                    .reffiType(.caption)
                    .foregroundStyle(ReffiColor.ink2)
                if let stamp {
                    DDayStamp(text: stamp, color: ReffiColor.freshDark, size: 10)
                        .padding(.leading, ReffiSpace.s2)
                }
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.reffiNum(.meta)).foregroundStyle(ReffiColor.muted)
                }
            }
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.top, ReffiSpace.s4 + toothH)
            .padding(.bottom, ReffiSpace.s3)

            ReceiptRule()
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, ReffiSpace.s2 + toothH)
        .background(paper, in: shape)
        .paperEdge(shape)
        .reffiShadowCardCompact()   // 스택 카드와 같은 얕은 단(Fridge와 동일)
    }
}

/// 영수증 카드 헤더 아래 절취선 — Fridge 상세의 dashRule과 같은 `ReffiRule(.receipt)`에 카드 거터만 더한다.
/// (예전엔 "동일"이라 적어 두고 잉크만 0.14로 갈려 있었다.)
struct ReceiptRule: View {
    var body: some View {
        ReffiRule(.receipt).padding(.horizontal, ReffiSpace.s5)
    }
}

/// 설정 토글 행 — 제목 + 한 줄 설명 + 스위치. 여백·타이포는 `SettingsRow`와 같은 문법이라
/// 한 영수증 안에서 두 행이 섞여도 줄 높이가 어긋나지 않는다.
///
/// VoiceOver는 **제목을 라벨로, 설명을 힌트로** 읽는다 — 두 줄을 한 라벨로 이어 붙이면
/// 스위치를 훑는 동안 행마다 설명 문장이 통째로 낭독돼 목록을 지나가기가 어려워진다.
/// 상태(켬/끔)와 조작은 SwiftUI Toggle 기본 동작 그대로다.
struct SettingsToggle: View {
    let title: LocalizedStringKey
    let caption: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).reffiType(.body).foregroundStyle(ReffiColor.ink)
                Text(caption).reffiType(.caption).foregroundStyle(ReffiColor.ink2)
            }
        }
        .tint(ReffiColor.blue)
        .accessibilityLabel(title)
        .accessibilityHint(caption)
        .padding(.horizontal, ReffiSpace.s5)
        .padding(.vertical, ReffiSpace.s4)
        .frame(minHeight: ReffiChrome.tapMin)   // 히트 타깃 하한(§7.3) — 두 줄이라 이미 넘지만 계약은 명시한다
    }
}

/// 설정 행 — 라벨 + 값 + 셰브런. 탭하면 편집 시트로.
struct SettingsRow: View {
    let label: LocalizedStringKey
    var value: String? = nil
    var valueColor: Color = ReffiColor.ink2
    var showChevron: Bool = true
    var numeric: Bool = false   // 시간·수량 등 데이터성 숫자 값 → reffiNum 의무(§3.4)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ReffiSpace.s3) {
                Text(label).reffiType(.body).foregroundStyle(ReffiColor.ink)
                Spacer(minLength: ReffiSpace.s4)
                if let value {
                    Text(value)
                        .font(numeric ? .reffiNum(.body) : ReffiTextRole.caption.font)
                        .tracking(numeric ? 0 : ReffiTextRole.caption.tracking)
                        .foregroundStyle(valueColor)
                        .lineLimit(1)
                }
                if showChevron {
                    ReffiIcon.chevron.reffi(13, .bold).foregroundStyle(ReffiColor.muted)
                }
            }
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.reffiPress)
    }
}
