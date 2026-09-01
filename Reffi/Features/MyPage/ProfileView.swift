import SwiftUI
import UserNotifications

/// 프로필/마이(§5) — 무낭비 리포트 + 요리 취향(스타일·비선호·알레르기) + 알림 + 계정.
/// 구성은 앱 공통 종이 캔버스 위에 Fridge의 "흰 영수증 더미" 문법(톱니+점선)을 얹은 것이다 —
/// 설정 화면이라 틸트·슬립 없이 정돈된 정렬만 쓴다.
///
/// **글자 위계는 카드마다 세 단이다**: 이름표(`groupLabel` 12/Medium/muted) → 행 라벨
/// (`checklistItem` 16/SemiBold/ink) → 행 값(`metaText` 13/Medium/ink2 · muted).
///
/// 세 단은 **크기·굵기·잉크가 같은 방향**을 가리켜야 한다. 렌더 스템 두께(Pretendard OTF에서
/// 잰 weight별 스템폭 × 크기)로 1.254 → 2.000 → 1.359pt다. 행 라벨이 `body`(16/Regular)이던
/// 동안은 라벨 1.344 vs 값 1.359로 **값이 오히려 굵어**, 크기·잉크가 세운 계단을 획 무게가
/// 정면으로 부정했다 — 사람 눈이 위계로 먼저 읽는 신호는 크기가 아니라 획이라, 두 줄의 획이
/// 같으면 크기 차이는 위계가 아니라 "크기를 잘못 지정했다"로 읽힌다. 굵기 차는 Dynamic Type
/// 전 구간에서 불변이므로 **굵기로 만든 계단만 접근성 크기에서 살아남는다**(크기비는 AX5에서
/// 1.23 → 1.05로 사실상 사라진다).
/// 이름표가 가장 작고 옅고 얇은 것도 같은 규칙이다 — 아래를 가리키는 라벨이지 스스로 읽히는
/// 제목이 아니다(자세한 근거는 `ReceiptCard` 본문 주석).
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

    // 알림 SSOT — ExpiryNotifier의 @AppStorage 키를 직접 읽어 실제 스케줄에 반영한다.
    @AppStorage(ExpiryNotifier.enabledKey) private var alertsEnabled = false
    @AppStorage(ExpiryNotifier.hourKey) private var alertHour = ExpiryNotifier.defaultHour

    // 감각 SSOT — 같은 키를 홈(MainView)과 모든 햅틱 호출부(`.reffiFeedback`)가 함께 읽는다.
    @AppStorage(ReffiFeedback.hapticsKey) private var hapticsEnabled = true
    @AppStorage(ReffiFeedback.tiltKey) private var tiltEnabled = true

    // 앱 내 언어 SSOT(38차) — `RootGateView`가 같은 키로 루트 `.environment(\.locale)`을 건다.
    @AppStorage(AppLanguage.key) private var languageRaw = AppLanguage.system.rawValue
    @State private var languagePickerOpen = false
    /// 가구 인원 드롭다운(49차) — 언어 행과 같은 문법. 두 픽커는 **동시에 열리지 않으므로**
    /// `DropdownAnchorKey`(마지막 non-nil을 남긴다)를 공유해도 앵커가 섞이지 않는다.
    @State private var householdPickerOpen = false

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
                        // 헤더는 영수증 스택과 **다른 층**이다(디스플레이 34 + 부제 한 줄 = 페이지 표지).
                        // 카드 이름표가 12로 내려간 뒤 34 ↔ 12가 카드 간격과 같은 24로 맞붙으면 헤더가
                        // 첫 카드의 제목처럼 읽힌다 — 카드 사이보다 한 단 넓은 32를 줘, 이름표가 잃은
                        // 경계 신호를 여백이 대신 진다.
                        .padding(.bottom, ReffiSpace.s2)
                    // 영수증 스택 — 설정 화면이라 기울임 없이 정돈된 정렬(질서 있는 영수증 문법).
                    // 무낭비 리포트는 냉장고 페이지 History(No-waste report)로 이동.
                    // **영수증 다섯 장**(49차) — 이전엔 여덟 장이었고 그중 셋(Recipes·Language·Household)이
                    // 행 하나 또는 컨트롤 하나만 담은 카드였다. 1행짜리 영수증은 카드 여백(위 23 + 아래 15
                    // + 이름표 줄)이 내용보다 큰 상태라, 스크롤할수록 "칸만 많고 든 게 없다"로 읽힌다.
                    // 묶는 축은 **무엇에 대한 설정인가**다: 요리(추천을 정하는 값 전부) / 알림 / 감각 /
                    // 앱(언어·데이터) / 계정.
                    cookingReceipt
                    alertsReceipt
                    feelReceipt
                    appReceipt
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
        // 배경도 게이트 안쪽이다 — 단색 한 장이라 비용은 작지만, 본문을 세우지 않는 프레임에
        // 배경만 세워 두면 "가려진 동안은 아무것도 세우지 않는다"는 이 화면의 계약이 반쪽이 된다.
        // (블롭 세 장 + 글래스 프로스트를 걷어내면서 `store.sorted`를 읽던 accent 계산도 함께 사라졌다 —
        // 신선도는 이제 배경이 아니라 뱃지·도장·D-N 잉크가 진다, §2.5.)
        .background { if isActive { PaperCanvasBackground() } }
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
        // 언어 픽커(38차) — `PaperDropdown` 루트 오버레이(ScrollView 클리핑 밖, `FridgeView` 정렬
        // 드롭다운과 같은 문법이나 트리거가 하나뿐이라 시트용 `paperDropdownOverlay`를 그대로 쓴다.
        .paperDropdownOverlay(isPresented: languagePickerOpen,
                              options: AppLanguage.allCases,
                              selected: AppLanguage.resolve(stored: languageRaw),
                              label: { $0.displayName(in: currentDisplayLocale) },
                              seed: 4,
                              onDismiss: { languagePickerOpen = false }) { applyLanguage($0) }
        .paperDropdownOverlay(isPresented: householdPickerOpen,
                              options: HouseholdSize.allCases,
                              selected: profile.household,
                              label: { $0.label },
                              seed: 6,
                              onDismiss: { householdPickerOpen = false }) { profile.household = $0 }
        // 40차 — 팝업 전수 종이화. 시스템 alert·confirmationDialog를 전부 PaperDialog로 옮긴다
        // (design_system.md §14.7 개정 — 룰⑧의 "파괴 확인은 시스템에 남긴다" 경계는 이 라운드의
        // 사용자 결정으로 폐기됐다). 행동 배선·role·햅틱·카피는 원본과 완전히 동일하다 — 의미는
        // 얼리고 재질만 바꾼다. 딤 탭은 취소 행동이 있는 질문형만 취소로 받는다(§14.7).
        .paperDialog(isPresented: $showLogout, title: "Log out of Reffi?",
                    message: "Your fridge and history stay on this device.\nLog back in anytime.",
                    seed: 1, backdropDismisses: true,
                    primary: PaperDialogAction("Log out", role: .destructive) { Task { await auth.signOut() } },
                    secondary: PaperDialogAction("Cancel", role: .cancel) {})
        .paperDialog(isPresented: $showDelete, title: "Erase this device's data?",
                    message: "This erases this device's data and logs you out.\nYour account stays on the server.",
                    seed: 2, backdropDismisses: true,
                    primary: PaperDialogAction("Erase", role: .destructive) {
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
                    },
                    secondary: PaperDialogAction("Cancel", role: .cancel) {})
        .paperDialog(isPresented: $showDenied, title: "Notifications are off",
                    message: "Allow notifications for Reffi in Settings to get expiry alerts.",
                    seed: 3, backdropDismisses: true,
                    // 안내가 지시하는 목적지로 가는 문(42차·F25) — 돌아오면 scenePhase 동기화가
                    // 토글을 스스로 맞춘다(`syncAuthorization`).
                    primary: PaperDialogAction("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    },
                    secondary: PaperDialogAction("Later", role: .cancel) {})
        .paperDialog(isPresented: $showSampleConfirm, title: "Load the sample fridge?",
                    message: "Your current ingredients and history will be replaced.",
                    seed: 4, backdropDismisses: true,
                    primary: PaperDialogAction("Replace", role: .destructive) {
                        destructiveHaptic += 1   // 룰⑦ — 파괴 확정(.warning)
                        withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                            store.loadSampleData()
                        }
                    },
                    secondary: PaperDialogAction("Cancel", role: .cancel) {})
        .paperDialog(isPresented: $showResetConfirm, title: "Reset all data?",
                    message: "Ingredients and history will be deleted.\nThis can't be undone.",
                    seed: 5, backdropDismisses: true,
                    primary: PaperDialogAction("Reset", role: .destructive) {
                        destructiveHaptic += 1   // 룰⑦ — 파괴 확정(.warning)
                        withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                            store.resetAllData()
                        }
                    },
                    secondary: PaperDialogAction("Cancel", role: .cancel) {})
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
                            // 폴백 판별은 공용 `String.hasHangul`(§ReffiTypography) — 아바타는 64pt 원 안
                            // 전용 크기라 role 대신 실크기를 적는다. `scaleEffect` 광학 축소를 걷고(42차 —
                            // 획 두께·베이스라인 계약 위반) 두 스크립트 모두 `.largeTitle` 곡선으로 통일:
                            // 한글 사용자와 라틴 사용자가 접근성 큰 글씨에서 같은 레이아웃을 본다.
                            .font(avatarInitial.hasHangul
                                  ? .custom("Pretendard-Bold", size: 28, relativeTo: .largeTitle)
                                  : .custom("StoryScript-Regular", size: 30, relativeTo: .largeTitle))
                            .foregroundStyle(ReffiColor.blueDark)
                    }
                }
                .frame(width: 64, height: 64)
                .background {
                    let s = PaperBlob(sides: 9, seed: 2)
                    s.fill(ReffiColor.blueLight).paperEdge(s)
                }
                VStack(alignment: .leading, spacing: ReffiSpace.s0) {
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

    /// 부제 — 고정 한 벌(42차). 취향 요약을 얹으면 두 스크롤 아래 Cuisines 행 값과 같은 문자열이
    /// 한 화면에 두 번 떠, 요약이 아니라 미리보기가 됐다(같은 사실 두 번 말하기).
    private var subtitle: String { AppLanguage.localizedNow("Saving food with Reffi") }

    // MARK: - 요리 취향 영수증
    /// 요리 영수증(49차) — 추천·재입고 수량을 정하는 값이 **한 장에** 모인다.
    /// 옛 Taste(4행) + Household(칩 카드) + Recipes(1행) 셋을 합쳤다. 가구 인원이 칩 넉 장에서
    /// `SettingsRow` + 드롭다운으로 접힌 것이 이 통합의 유일한 실질 변경이다 — 카드 안 컨트롤 문법이
    /// 행 하나로 통일되고(같은 카드에 "행 + chevron"과 "칩 단일선택" 두 문법이 섞이지 않는다),
    /// 언어 행이 이미 쓰는 `paperDropdownOverlay`를 그대로 재사용해 새 컴포넌트가 0개다.
    /// **트레이드오프**: 선택지 넷이 한눈에 보이던 것이 한 탭 뒤로 간다. 되돌리려면 이 행을 옛
    /// `householdReceipt`의 칩 행으로 바꾸면 되고, 그때는 카드가 여섯 장이 된다.
    private var cookingReceipt: some View {
        ReceiptCard(title: "Cooking") {
            // 값 잉크는 **상태 하나로만** 갈린다(50차 · `SettingsRow.ValueState`). 빔은 `.unset`,
            // 고른 값은 `.set`이다 — 예전엔 Cuisines·My recipes만 빔을 muted로 넘기고 나머지 셋은
            // 아무것도 안 넘겨 기본 ink2로 떨어져, 같은 "None yet"이 한 카드 안에서 두 잉크로 섰다.
            SettingsRow(label: "Cuisines", value: profile.cuisines.summaryText,
                        valueState: profile.cuisines.isEmpty ? .unset : .set) {
                sheet = .cuisines
            }
            ReceiptRule()
            SettingsRow(label: "Favorites", value: tagSummary(profile.favorites),
                        valueState: profile.favorites.isEmpty ? .unset : .set) { sheet = .favorites }
            ReceiptRule()
            SettingsRow(label: "Disliked", value: tagSummary(profile.disliked),
                        valueState: profile.disliked.isEmpty ? .unset : .set) { sheet = .disliked }
            ReceiptRule()
            SettingsRow(label: "Allergies", value: tagSummary(profile.allergies),
                        valueState: profile.allergies.isEmpty ? .unset : .set) { sheet = .allergies }
            ReceiptRule()
            SettingsRow(label: "Household", value: profile.household.label) {
                householdPickerOpen.toggle()
            }
            .anchorPreference(key: DropdownAnchorKey.self, value: .bounds) {
                householdPickerOpen ? $0 : nil
            }
            ReceiptRule()
            SettingsRow(label: "My recipes",
                        value: store.userRecipes.isEmpty ? AppLanguage.localizedNow("None yet") : "\(store.userRecipes.count)",
                        valueState: store.userRecipes.isEmpty ? .unset : .set) {
                showMyRecipes = true
            }
        }
    }

    private func tagSummary(_ tags: [String]) -> String {
        guard !tags.isEmpty else { return AppLanguage.localizedNow("None yet") }   // 빈 상태 카피 통일(Cuisines·시트와 동일)
        let head = tags.prefix(2).joined(separator: ", ")
        let extra = tags.count - Swift.min(2, tags.count)
        return extra > 0 ? "\(head) +\(extra)" : head
    }

    // MARK: - 알림 영수증 — ExpiryNotifier 실배선(토글=권한요청·롤백, 시각=스케줄 반영).
    private var alertsReceipt: some View {
        ReceiptCard(title: "Alerts") {
            // 감각 영수증과 같은 토글 행 문법(SettingsToggle) — 여백·타이포·VoiceOver 처리를 공유한다.
            SettingsToggle(title: "Expiry alerts",
                           caption: "Every morning",
                           isOn: $alertsEnabled, seed: 0)
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
                SettingsRow(label: "Time", value: alertHourText) { sheet = .time }
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
        ReceiptCard(title: "Feel") {
            SettingsToggle(title: "Collision haptics",
                           caption: "When ingredients bump",
                           isOn: $hapticsEnabled, seed: 1)
            ReceiptRule()
            SettingsToggle(title: "Tilt gravity",
                           caption: "When you tilt the phone",
                           isOn: $tiltEnabled, seed: 2)
        }
    }

    // MARK: - 내 레시피 영수증 (커스텀 — 추천 풀에 합류)
    // MARK: - 언어 영수증(2026-08, 38차) — 인앱 픽커로 전환.
    // 이전엔 iOS 설정 딥링크가 정본이었다(§Data 79번째 줄 옛 근거). `.environment(\.locale)` +
    // `AppleLanguages` 오버라이드로 실제 전환이 가능해져 딥링크를 걷었다 — `AppLanguage.swift`가
    // 그 경계(즉시 반영 vs 재실행 필요)를 정직하게 문서화한다.
    /// "지금 화면이 보여 주는 언어" — 행 값과 드롭다운 옵션 라벨(38차)이 같은 기준으로 리졸브되게
    /// 명시적으로 못 박는다(`AppLanguage.displayName(in:)` 문서 참고 — `.system` 라벨은
    /// `.environment(\.locale)`에 기대면 방금 바꾼 언어를 못 따라간다).
    private var currentDisplayLocale: Locale { AppLanguage.resolve(stored: languageRaw).resolvedLocale }

    /// 앱 영수증(49차) — 옛 Language(1행 + 각주)와 Data(버튼 1~2개)를 합쳤다. 둘 다 "요리"도
    /// "계정"도 아닌 **앱 자체의 설정**이라 한 장이 맞고, 각각으로는 카드 한 장을 채우지 못했다.
    private var appReceipt: some View {
        ReceiptCard(title: "App") {
            SettingsRow(label: "App language",
                        value: AppLanguage.resolve(stored: languageRaw).displayName(in: currentDisplayLocale)) {
                languagePickerOpen.toggle()
            }
            .anchorPreference(key: DropdownAnchorKey.self, value: .bounds) {
                languagePickerOpen ? $0 : nil
            }
            ReceiptRule()
            Text("Some text updates right away.\nRestart Reffi to apply everywhere.")
                .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                .padding(.horizontal, ReffiSpace.s5)
                // 같은 카드 안 행(`SettingsRow`)과 **같은 세로 리듬**이다. s3으로 좁혀 두면 절취선 하나를
                // 사이에 두고 위 행은 16, 아래 안내문은 12가 되어 카드가 아래쪽만 눌린 것처럼 읽힌다.
                .padding(.vertical, ReffiSpace.s4)

            ReceiptRule()
            if Self.showsSampleLoad(isGuest: auth.isGuest) {
                QuietButton(title: "Load the sample fridge", icon: ReffiIcon.fridge, tint: ReffiColor.blueDark) {
                    if store.isPristine {
                        withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                            store.loadSampleData()
                        }
                    } else {
                        showSampleConfirm = true
                    }
                }
                // s4인 것이 계산이다: `QuietButton`이 자기 안에 s2(8)를 이미 갖고 있어 16 + 8 = 24 =
                // 카드 거터(s5)가 된다. s3이던 동안 이 버튼들의 잉크만 다른 모든 줄(이름표·행 라벨)보다
                // 4pt 왼쪽에서 시작해, 영수증 한 장 안에 왼쪽 정렬선이 둘 있었다.
                .padding(.horizontal, ReffiSpace.s4)
                .padding(.vertical, ReffiSpace.s1)
                ReceiptRule()
            }
            QuietButton(title: "Reset all data", icon: ReffiIcon.toss, tint: ReffiColor.urgentDark) {
                showResetConfirm = true
            }
            .padding(.horizontal, ReffiSpace.s4)   // 위와 같은 정렬선(s4 + QuietButton 내부 s2 = 카드 거터)
            .padding(.vertical, ReffiSpace.s1)
        }
    }

    /// 언어 선택 커밋 — `PaperDropdown`이 고르자마자 스스로 닫으므로(`paperDropdownOverlay`) 여기선
    /// 값만 반영한다. 순서가 중요하다: AppStorage를 먼저 써야 `.environment(\.locale)`이 같은 프레임에
    /// 새 값으로 다시 걸린다.
    private func applyLanguage(_ language: AppLanguage) {
        languageRaw = language.rawValue
        language.applyAppleLanguagesOverride()
    }

    /// "Load the sample fridge"는 **게스트에서만** 보인다(2026-08, 36차 owner decision) — 로그인 계정은
    /// 실 데이터를 다루므로 샘플로 갈아엎는 진입점 자체를 주지 않는다. 로그인 상태의 유일한 소스는
    /// `accountReceipt`가 이미 읽는 `auth.isGuest`와 같다(§Account 영수증). 행과 그 아래 절취선을
    /// **함께** 조건문에 묶어, 숨을 때 짝 잃은 `ReceiptRule`이 남지 않게 한다.
    /// 순수 규칙(뷰 밖에서 유닛 테스트로 고정 — `FridgeTab.initial(from:)`과 같은 문법):
    /// 샘플 로드 행은 게스트에게만 보인다.
    static func showsSampleLoad(isGuest: Bool) -> Bool { isGuest }

    // MARK: - 계정 영수증
    private var accountReceipt: some View {
        ReceiptCard(title: "Account") {
            if auth.isGuest {
                // 게스트는 상태 표시와 진입점을 한 행으로 합친다(2026-08, 37차) — 예전엔 탭 안 되는
                // "Guest mode · Sign up to keep your data" 안내 줄 바로 아래 별도 "Log in / Sign up"
                // 버튼이 있어, 안내문은 액션처럼 읽히는데 정작 탭이 안 되고 진짜 액션은 한 칸 아래
                // 떨어져 있었다. `SettingsRow`(라벨+값+셰브런, 전체가 탭 표면)로 하나의 명확한
                // 진입점만 남긴다 — 같은 목적지(인증 시트)로 가는 입구를 화면에 흩뿌리지 않는다.
                // 카피는 정직하게: 서버 백업은 없으므로 약속하지 않고, 로컬 기기에 남는다는 사실만 말한다.
                SettingsRow(label: "Guest mode", value: AppLanguage.localizedNow("On this device")) {
                    showAuth = true   // 익명 세션을 유지한 채 시트에서 전환/로그인(승계 보장).
                }
            } else {
                // 로그인 상태도 **게스트와 같은 행 문법**이다(라벨=checklistItem/ink · 값=metaText/ink2).
                // 예전엔 이 자리만 손으로 조립한 HStack이었고 라벨·값을 둘 다 caption으로 적어, 같은
                // "계정 상태" 한 칸이 로그인 사용자에겐 14/Medium 두 조각으로, 게스트에겐 16/Regular
                // 라벨 + 값으로 보였다 — 한 파일 여섯 줄 간격에서 같은 의미 계층이 두 위계로 갈렸고,
                // 그 갈림이 게스트 화면에서 "Guest mode"만 혼자 다른 스타일로 떠 보이게 한 원인이다.
                // 갈 곳이 없는 행이라 `action`을 넘기지 않는다 — 버튼으로 감싸지도, 셰브런을 그리지도
                // 않는다(행동 없는 행에 누를 수 있다는 신호를 붙이지 않는다).
                SettingsRow(label: "Logged in",
                            value: auth.userEmail ?? "",
                            valueTruncation: .middle)
                ReceiptRule()
                QuietButton(title: "Log out", icon: ReffiIcon.go, tint: ReffiColor.blueDark) {
                    showLogout = true
                }
                .padding(.horizontal, ReffiSpace.s4)   // 위 Data 영수증과 같은 정렬선
                .padding(.vertical, ReffiSpace.s1)
            }
            ReceiptRule()
            // toss(재료 버림)와 의미 충돌 방지 — 탈퇴는 별도 아이콘(x).
            // 라벨은 실동작을 말한다(42차 — MVP 원칙): 서버 계정은 남으므로 "Delete account"는
            // 거짓말이었다. 서버 삭제가 생기면 그때 그 이름을 되살린다.
            QuietButton(title: "Erase this device", icon: ReffiIcon.close, tint: ReffiColor.urgentDark) {
                showDelete = true
            }
            .padding(.horizontal, ReffiSpace.s4)   // 위와 같은 정렬선
            .padding(.vertical, ReffiSpace.s1)
        }
    }
}

// MARK: - 재사용 컴포넌트

/// 흰 영수증 카드 — Fridge 영수증(FridgeCard·ExpandedFridgeCard)과 같은 문법.
/// 톱니(절취) 엣지 + 헤더 + 점선 룰.
/// 헤더 라벨은 번역되는 문자열이라 올캡 모노 크롬(`sectionLabel`)이 아니라 그 번역 가능한
/// 쌍둥이 `groupLabel`을 쓴다(§3.5).
struct ReceiptCard<Content: View>: View {
    /// **`String`이 아니라 `LocalizedStringKey`인 것이 요점이다(41차).** 둘의 차이는 로컬라이즈가
    /// **언제** 일어나는가다: `Text(String)`은 verbatim 렌더라 조회가 호출부의 `String(localized:)`
    /// 시점에 끝나고, 그 조회는 `Bundle.main` = **다음 실행**을 봐야 바뀐다. `LocalizedStringKey`면
    /// 조회가 SwiftUI로 넘어가 루트의 `.environment(\.locale)`(38차 앱 내 언어 전환)을 그대로 따른다.
    ///
    /// 38차 직후 실측했을 때 영수증 제목 여덟(Taste·Household·Notifications·Feel·My recipes·
    /// Language·Data·Account)만 재실행 전까지 영어로 남아, 한글 행 라벨 위에 영어 섹션 헤더가
    /// 얹히는 그림이 됐다. `AppLanguage`가 문서화한 "정직한 경계"는 **보간으로 굳은 문자열**에나
    /// 해당하는 제약이고, 이 제목들은 그냥 리터럴이라 애초에 그 경계 안에 있을 이유가 없었다.
    /// 되돌리지 말 것 — `String(localized:)`로 감싸는 순간 여덟이 다시 경계 밖으로 나간다.
    let title: LocalizedStringKey
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
                // 쓰지 않는다(§3.5) — 한글엔 대문자가 없어 `.uppercased()`가 no-op이 되고 11pt에
                // 자간 1.4만 남는다. 번역되는 라벨의 자리는 `groupLabel`이다.
                //
                // **이 줄은 제목이 아니라 이름표다.** 자기가 읽히려고 있는 게 아니라 아래 행 묶음을
                // 여는 라벨이라, 아래 행 라벨(`checklistItem` 16/SemiBold/ink)보다 작고(12) 옅고
                // (`muted`) 얇다(Medium). 예전엔 `caption`(14/Medium/ink2)이었는데 그러면 행 라벨과
                // 비가 16/14 = 1.14라 계단이 서지 않는 데다, 더 작은 이 줄이 더 굵어 크기·색이 만든
                // 신호를 굵기가 정면으로 상쇄했다 — 위계가 약해지는 게 아니라 **없는 것으로** 읽힌다.
                // 지금은 크기 16/12 = 1.333, 스템 2.000/1.254 = 1.60배로 두 신호가 같은 방향이다
                // (행 라벨을 SemiBold로 올린 50차 이후 격차가 더 벌어졌다).
                //
                // **다시 키우지 말 것.** 카드 안 안내문(`caption` 14/ink2 — 가구 인원·언어·토글 설명)이
                // 이 줄보다 크고 진한 것은 결함이 아니라 이 줄이 아이브로우라는 뜻이다. 저 안내문들은
                // "읽는 문장"이고 이 줄은 "가리키는 라벨"이라, 둘의 순서는 크기가 아니라 역할이 정한다.
                //
                // `muted`는 이 토큰이 성문화한 "약한 텍스트" 자리 그대로다. 읽혀야 하는 이름 줄을
                // muted로 두지 않는다는 반대편 선례(History 히어로의 창 이름 줄, 26차 muted→ink2)와
                // 충돌하지 않는다: 저쪽은 그 줄 자체가 콘텐츠고 여기는 아래를 가리키는 라벨이다.
                // 대비는 실측으로 통과한다(muted on receipt 라이트 5.51 · 다크 4.66, §2.6 표).
                //
                // 시각 위계를 내린 대가는 **의미 위계로 갚는다**: 시각으로만 제목이던 이 줄이 더 조용해진
                // 만큼, VoiceOver 로터의 제목 탐색이 영수증 여덟 장을 짚을 수 있어야 한다
                // (`SheetHeader`·`CoverHeader`·`PaperDialog`가 이미 같은 계약을 지킨다).
                Text(title)
                    .reffiType(.groupLabel)
                    .foregroundStyle(ReffiColor.muted)
                    .accessibilityAddTraits(.isHeader)
                if let stamp {
                    DDayStamp(text: stamp, color: ReffiColor.freshDark, size: 10)
                        .padding(.leading, ReffiSpace.s2)
                }
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.reffiNum(.meta, for: trailing)).foregroundStyle(ReffiColor.muted)
                }
            }
            .padding(.horizontal, ReffiSpace.s5)
            // 이름표를 12/muted로 내린 만큼 **여백이 그 존재를 대신 만든다**: 위는 넓게 열어 이 줄이
            // 카드의 시작임을 보이고(s5 + tooth — `receiptSurface`가 모든 영수증에 쓰는 상단 인셋과
            // 같은 값이라, 손으로 조립한 이 카드만 s4로 얕던 어긋남도 함께 사라진다), 아래는 좁혀
            // 절취선·행 묶음에 붙인다. 이름표는 자기 위가 아니라 **아래에 속한다** — 이 비대칭이
            // 뒤집히면 이름표가 위 카드의 꼬리처럼 읽힌다.
            .padding(.top, ReffiSpace.s5 + toothH)
            .padding(.bottom, ReffiSpace.s2)

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
///
/// 스위치 재질은 `PaperToggleStyle`(§13.5, 2026-08 34차) — 스톡 캡슐 대신 손으로 자른 종이
/// 트랙+손잡이다. 스타일은 시각만 바꾸므로 위 VoiceOver 계약(라벨=제목·힌트=설명·값=켬/끔)은
/// 그대로 유지된다. `seed`는 호출부가 인스턴스마다 다르게 줘 나란히 선 토글끼리 종이 결이 겹치지 않게 한다.
struct SettingsToggle: View {
    let title: LocalizedStringKey
    /// **값형 캡션이다 — 문장이 아니라 값**(49차). 3~5어로 "언제/무엇에" 하나만 답하고 줄바꿈하지
    /// 않는다. 완결 문장을 넣던 동안 세 토글이 전부 402pt 폭에서 두 줄로 접혀 행 높이가 들쭉날쭉했고,
    /// 캡션이 `ink2`라 라벨(`ink`)과 무게가 붙어 "라벨 > 값" 방향이 서지 않았다.
    /// `SettingsRow`가 라벨(checklistItem/ink) > 값(metaText/ink2)으로 이미 세운 그 방향에 맞춘다 —
    /// 여기 캡션은 role은 `caption`으로 두되 잉크를 `muted`로 한 단 내린다.
    /// 한 문장이 꼭 필요하면 행이 아니라 **카드 마지막 각주**로 내린다(Language 영수증 선례).
    let caption: LocalizedStringKey
    @Binding var isOn: Bool
    var seed: Int = 0

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: ReffiSpace.s0) {
                // 라벨은 `SettingsRow`와 **같은 role**이어야 한다 — 한 영수증 안에 토글 행과 값 행이
                // 섞여 서므로, 여기만 `body`(Regular)로 남으면 같은 카드에서 라벨 열의 획이 행마다
                // 갈린다(자세한 근거는 `SettingsRow` 독 코멘트의 스템 두께 계산).
                Text(title).reffiType(.checklistItem).foregroundStyle(ReffiColor.ink)
                Text(caption).reffiType(.caption).foregroundStyle(ReffiColor.muted)
                    .lineLimit(1)
            }
        }
        .toggleStyle(PaperToggleStyle(seed: seed))
        .accessibilityLabel(title)
        .accessibilityHint(caption)
        .padding(.horizontal, ReffiSpace.s5)
        .padding(.vertical, ReffiSpace.s4)
        .frame(minHeight: ReffiChrome.tapMin)   // 히트 타깃 하한(§7.3) — 두 줄이라 이미 넘지만 계약은 명시한다
    }
}

/// 설정 행 — 라벨 + 값(+ 셰브런). 탭하면 편집 시트로.
///
/// **행 안의 위계는 세 신호(크기·굵기·잉크)가 같은 방향을 가리킬 때만 선다.** 라벨은
/// `checklistItem`(16/SemiBold/ink), 값은 `metaText`(13/Medium/ink2 또는 muted)다.
///
/// 라벨이 `body`(16/**Regular**)이던 동안 렌더 스템 두께는 라벨 16 × 0.0840 = **1.344pt** ·
/// 값 13 × 0.1045 = **1.359pt**로 값이 오히려 굵었다(Pretendard OTF에서 잰 weight별 스템폭).
/// 46차가 값을 `caption` 14에서 `metaText` 13으로 내린 것은 그 역전을 +8.9%에서 +1.1%로 줄였을
/// 뿐 **부호를 못 바꿨다** — x-height는 값이 19% 작은데 획은 같은 두께라, 두 줄은 위계가 아니라
/// "폰트 크기를 잘못 지정했다"로 읽혔다. `checklistItem`은 16 × 0.1250 = **2.000pt**로 라벨이
/// 값보다 47% 굵다. 크기 1.231배·잉크 15.33 vs 7.77과 이제 셋이 같은 방향이다.
///
/// **굵기로 만든 계단만 Dynamic Type 전 구간에서 산다.** 크기로만 만든 계단은 AX5에서
/// 1.231 → 1.046으로 사라지지만(`.body` 17→53 vs `.caption` 12→43 곡선), weight 차는 어느
/// 콘텐츠 크기에서도 불변이다. `relativeTo`는 `body`와 같은 `.body`라 AX 곡선 자체는 안 변한다.
/// 라벨을 Regular로 되돌리거나 값을 키우려거든 이 계산부터 다시 할 것.
///
/// **값 열은 한 벌이다 — 폰트도 크기도 갈리지 않는다.** 값을 훑는 열이 행마다 변주하면 사용자가
/// 규칙을 유도할 수 없다(자세한 근거는 아래 `face`의 값 렌더 주석).
///
/// **`action`이 nil이면 이 행은 버튼이 아니고 셰브런도 그리지 않는다.** 셰브런은 "누르면 다음이
/// 있다"는 약속이라 갈 곳 없는 행에 그리면 그 자리에서 위약 UI가 된다. 그래서 셰브런 유무를
/// 별도 플래그로 두지 않고 `action`에서 파생한다 — 플래그로 두면 둘을 어긋나게 넘긴 조합이
/// 컴파일을 통과하고, 그 조합은 언젠가 반드시 넘어온다.
struct SettingsRow: View {
    /// 값 열의 잉크를 정하는 **상태**. 색을 직접 받던 `valueColor: Color`를 대체한다(50차).
    ///
    /// 자유 파라미터이던 동안 같은 카드 안에서 같은 "비어 있음"이 두 잉크로 렌더됐다: Cuisines·
    /// My recipes만 빔을 `muted`로 넘겼고 Favorites·Disliked·Allergies는 아무것도 안 넘겨 기본값
    /// `ink2`로 떨어져, 같은 "None yet"이 어떤 행에선 사용자가 고른 값처럼 읽혔다. 색을 받는 한
    /// 그 어긋난 조합은 언제나 컴파일을 통과한다 — 셰브런을 별도 플래그가 아니라 `action`에서
    /// 파생시킨 것과 같은 이유로, 여기도 색이 아니라 상태를 받는다.
    ///
    /// 값이 `blueDark`이던 두 행은 이 전환에서 **버렸다**: 7행 중 2행에만 붙어 "파랑 = 내가 고른 값"
    /// 이라는 규칙이 읽히지 않았고, 파랑은 이 앱에서 "누를 수 있다"를 지는 색이라(§2.6 · 같은 카드의
    /// `QuietButton`) 값이 그 색을 쓰면 정작 링크의 신호가 희석된다.
    enum ValueState {
        case set      // 사용자가 고른 값 · 시스템이 아는 사실(이메일·시각·인원)
        case unset    // 아직 안 고른 자리 — 값 문자열은 "None yet" 계열 안내다

        /// `muted`는 다크 영수증 위 4.66:1로 §2.6 본문 하한(4.5)에 여유가 0.16뿐이다.
        /// **아직 값이 아닌 자리에만** 쓰는 것이 그 여유를 정당화하는 근거다 — muted는 역할로
        /// 낮추는 자리이지 대비로 낮추는 자리가 아니다.
        var ink: Color { self == .set ? ReffiColor.ink2 : ReffiColor.muted }
    }

    /// 셰브런 글리프 한 변 — 셰브런과 그 자리 비움 스페이서가 **같은 상수**를 봐야 값 열 우측 축이
    /// 어긋나지 않는다(아래 `face` 참고).
    private static let chevronSide: CGFloat = 13

    let label: LocalizedStringKey
    var value: String? = nil
    /// 값의 잉크는 색이 아니라 **상태**로 받는다(위 `ValueState`). 기본은 "고른 값".
    var valueState: ValueState = .set
    /// 값이 길어 접힐 때 **어디를** 접는가. 기본은 tail이고, 꼬리가 곧 신원인 값(이메일)만 middle로
    /// 넘긴다 — tail로 접으면 "verylongname@ex…"가 되어 어느 계정인지가 통째로 사라진다.
    var valueTruncation: Text.TruncationMode = .tail
    /// nil = 표시 전용 행(위 주석) — 버튼으로 감싸지 않는다. 트레일링 클로저 호환을 위해 마지막 자리.
    var action: (() -> Void)? = nil

    var body: some View {
        if let action {
            Button(action: action) { face.contentShape(Rectangle()) }
                .buttonStyle(.reffiPress)
        } else {
            // 버튼 경로는 SwiftUI가 라벨·값을 한 요소로 묶어 주지만 이 경로는 묶어 주지 않는다 —
            // 그대로 두면 "Logged in"과 이메일이 두 번의 스와이프로 갈린다(`FridgeView.row` 선례).
            face.accessibilityElement(children: .combine)
        }
    }

    private var face: some View {
        HStack(spacing: ReffiSpace.s3) {
            Text(label).reffiType(.checklistItem).foregroundStyle(ReffiColor.ink)
            Spacer(minLength: ReffiSpace.s4)
            if let value {
                Text(value)
                    // **값 열은 한 벌이다**(50차). 예전엔 `numeric` 플래그가 데이터성 숫자를
                    // `reffiNum(.body)`(GSF-Regular 15 / ko Pretendard-Regular 15)로 갈라, 한 카드 여섯
                    // 행의 값 열에서 패밀리·크기·굵기가 동시에 갈렸다 — 조용해야 할 열이 변주하고
                    // 훑어야 할 라벨 열이 균일한, 정확히 반대의 상태였다.
                    // §3.4가 tabular를 의무로 거는 근거는 "자릿수가 바뀔 때 폭이 흔들리지 않게"인데
                    // 이 값들("3" · "9:00 AM")은 **세로로 정렬되는 숫자 열이 아니라** 행마다 오른쪽 끝에
                    // 홀로 서는 값이라 그 근거가 성립하지 않는다. 세로 숫자 열이 생기면 그때 되살릴 것.
                    // 자간은 metaText가 0이라 `reffiType`이 그대로 0을 건다.
                    .reffiType(.metaText)
                    .foregroundStyle(valueState.ink)
                    .lineLimit(1)
                    .truncationMode(valueTruncation)
            }
            if action != nil {
                ReffiIcon.chevron.reffi(Self.chevronSide, .bold).foregroundStyle(ReffiColor.muted)
            } else {
                // **그리지 않는 것과 자리를 비우는 것은 다르다.** 위 계약대로 갈 곳 없는 행엔 셰브런을
                // 그리지 않지만, 그리지 않은 만큼 값이 오른쪽으로 밀려 그 행만 값 열 우측 축이
                // 25pt(셰브런 13 + HStack spacing s3=12) 밖으로 나갔다(로그인 상태의 "Logged in" 한 곳).
                // 투명 스페이서는 "누르면 다음이 있다"를 약속하지 않으므로 위약 UI가 아니다 —
                // 약속은 그대로 없고 축만 유지한다.
                Color.clear.frame(width: Self.chevronSide, height: Self.chevronSide)
            }
        }
        .padding(.horizontal, ReffiSpace.s5)
        .padding(.vertical, ReffiSpace.s4)
    }
}
