import SwiftUI
import UserNotifications

/// 온보딩 — 가치 3장(기록→레시피→리포트) + 개인화 2장(가구·취향) + 알림 프라이밍 1장.
/// 혜택 중심 카피, 언제든 건너뛰기 가능, 개인화 답은 ProfileStore에 바로 저장(가입 전이어도 로컬 유지).
struct OnboardingView: View {
    @Environment(ProfileStore.self) private var profile
    @Environment(FridgeStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onFinish: () -> Void

    @State private var page = 0
    private let last = 5

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        #if DEBUG
        // 스크린샷·QA용 — `-onboardingPage N`으로 특정 페이지 직행.
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-onboardingPage"), i + 1 < args.count,
           let n = Int(args[i + 1]) {
            _page = State(initialValue: min(max(0, n), last))
        }
        #endif
    }

    var body: some View {
        ZStack {
            LiquidGlassBackground(accent: accent)
            VStack(spacing: 0) {
                topBar
                TabView(selection: $page) {
                    valuePage(hero: { recordHero },
                              title: "Log your fridge\nlike a receipt",
                              body: "Add what you buy — we'll count down the expiry dates.")
                        .tag(0)
                    valuePage(hero: { recipeHero },
                              title: "Today's recipes,\nfrom what expires first",
                              body: "Eat the most urgent ingredients first, top to bottom.")
                        .tag(1)
                    valuePage(hero: { reportHero },
                              title: "Days without waste\nadd up to a report",
                              body: "Watch your no-waste streak and savings grow.")
                        .tag(2)
                    householdPage.tag(3)
                    cuisinePage.tag(4)
                    notifyPage.tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(motion, value: page)

                dots
                bottomButton
            }
        }
    }

    private var accent: Color {
        switch page {
        case 0: ReffiColor.urgent
        case 1: ReffiColor.soon
        case 2: ReffiColor.fresh
        default: ReffiColor.blue
        }
    }
    private var motion: Animation? {
        ReffiMotion.gated(.easeOut(duration: 0.24), reduce: reduceMotion)
    }

    // MARK: 상단 — 워드마크(좌) + 건너뛰기(우)

    private var topBar: some View {
        HStack {
            Text("Reffi").reffiType(.display).foregroundStyle(ReffiColor.blueDark)
                .scaleEffect(0.62, anchor: .leading)   // 워드마크 축소 배치(위계는 페이지 타이틀에)
            Spacer()
            if page < last {
                QuietButton(title: "Skip", tint: ReffiColor.ink2) { onFinish() }
            }
        }
        .padding(.horizontal, ReffiGrid.margin)
        .padding(.top, ReffiSpace.s3)
    }

    // MARK: 가치 페이지 — 히어로(텍스트를 그대로 시각화한 미니 영수증) + 한글 디스플레이(§3.1)

    private func valuePage<H: View>(@ViewBuilder hero: () -> H,
                                    title: LocalizedStringKey, body copy: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s5) {
            Spacer(minLength: 0)
            hero()
                .frame(maxWidth: .infinity)
                .padding(.bottom, ReffiSpace.s4)

            // 영문 디스플레이 = Story Script(§3.1 브랜드 모먼트 — 워드마크·온보딩 타이틀).
            Text(title)
                .reffiType(.display)
                .foregroundStyle(ReffiColor.ink)
            Text(copy)
                .reffiType(.body).foregroundStyle(ReffiColor.ink2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, ReffiGrid.margin + ReffiSpace.s2)
    }

    // MARK: 히어로 3종 — 각 페이지 카피를 시각적으로 재연(설명 일치)

    /// ① "영수증처럼 기록" — 재료·D-day가 줄줄이 적힌 냉장고 영수증.
    private var recordHero: some View {
        miniReceipt(seed: 0) {
            VStack(spacing: ReffiSpace.s3) {
                heroHeader("REFFI · FRIDGE")
                heroRow(.tomato, "Tomato", "D-2", ReffiColor.soonDark)
                heroDash
                heroRow(.leaf, "Spinach", "D-1", ReffiColor.soonDark)
                heroDash
                heroRow(.milk, "Milk", "D-5", ReffiColor.freshDark)
            }
        }
    }

    /// ② "임박 재료 → 오늘의 레시피" — 큰 재료 일러스트(Today 도장) + 레시피 추천 예시 칩.
    private var recipeHero: some View {
        VStack(spacing: ReffiSpace.s4) {
            ZStack(alignment: .topTrailing) {
                PaperSilhouette(glyph: .egg, fresh: .fresh)
                    .frame(width: 150, height: 150)
                DDayStamp(text: String(localized: "Today"), color: ReffiColor.urgentDark, size: 15)
                    .offset(x: 14, y: -6)
            }
            // 레시피 추천 예시 — AI(§2.4 Blue) 칩. 틴트 면 위 ink(§2.6 AAA).
            HStack(spacing: ReffiSpace.s2) {
                ReffiIcon.ai.reffi(15, .bold).foregroundStyle(ReffiColor.blueDark)
                Text("Today's recipe · Tomato frittata")
                    .font(.custom("Pretendard-SemiBold", size: 14, relativeTo: .caption))
                    .foregroundStyle(ReffiColor.ink)
                    .lineLimit(1)
            }
            .padding(.horizontal, ReffiSpace.s4)
            .padding(.vertical, ReffiSpace.s2 + 2)
            .background(ReffiColor.blueLight, in: Capsule())
        }
    }

    /// ③ "리포트로 쌓여요" — 큰 일러스트 + 무낭비 스트릭 도장(이전 버전 문법).
    private var reportHero: some View {
        ZStack(alignment: .topTrailing) {
            PaperSilhouette(glyph: .leaf, fresh: .fresh)
                .frame(width: 168, height: 168)
            DDayStamp(text: String(localized: "DAY \(12)"), color: ReffiColor.freshDark, size: 15)
                .offset(x: 14, y: -6)
        }
    }

    /// 미니 영수증 셸 — Fridge 카드와 같은 흰 영수증(톱니), 살짝 틸트로 종이 무드.
    private func miniReceipt<C: View>(seed: Int, @ViewBuilder _ content: () -> C) -> some View {
        let shape = ReceiptShape(tooth: 6)
        return content()
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s4 + 6)
            .frame(width: 272)
            .background(ReffiColor.oklch(0.985, 0.004, 90), in: shape)
            .paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
            .reffiShadow1()
            .rotationEffect(.degrees(seed % 2 == 0 ? -2 : 2))
    }

    private func heroHeader(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.custom("Pretendard-Bold", size: 10, relativeTo: .caption2)).tracking(1.2)
                .foregroundStyle(ReffiColor.muted)
            Spacer(minLength: 0)
        }
    }

    private var heroDash: some View {
        HLine().stroke(ReffiColor.ink.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(height: 1)
    }

    private func heroRow(_ glyph: FoodGlyph, _ name: LocalizedStringKey, _ dDay: String, _ color: Color) -> some View {
        HStack(spacing: ReffiSpace.s3) {
            PaperSilhouette(glyph: glyph, fresh: .fresh)
                .frame(width: 28, height: 28)
            Text(name)
                .font(.custom("Pretendard-SemiBold", size: 15, relativeTo: .subheadline))
                .foregroundStyle(ReffiColor.ink)
            Spacer(minLength: 0)
            Text(dDay)
                .font(.reffiNum(14, relativeTo: .subheadline))
                .foregroundStyle(color)
        }
    }

    // MARK: 개인화 ① 가구 인원 — 레시피 양의 근거(프로필 Household와 동일 문법)

    private var householdPage: some View {
        questionPage(title: "How many are eating?",
                     body: "We'll size recipes and shopping lists to match.") {
            // 칩은 내용 크기(fullWidth false) — 균등 4등분은 "2 people" 등을 말줄임시킨다.
            HStack(spacing: ReffiSpace.s2) {
                ForEach(HouseholdSize.allCases) { h in
                    SelectableChip(text: h.label, selected: profile.household == h,
                                   fullWidth: false) {
                        profile.household = h
                    }
                }
            }
        }
    }

    // MARK: 개인화 ② 요리 취향 — 멀티 선택(프로필 Cuisines와 동일 문법)

    private var cuisinePage: some View {
        questionPage(title: "What do you like to cook?",
                     body: "Pick as many as you like — recipes will follow.") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: ReffiSpace.s2)],
                      alignment: .leading, spacing: ReffiSpace.s2) {
                ForEach(CuisineStyle.allCases) { c in
                    SelectableChip(text: c.label, selected: profile.cuisines.contains(c),
                                   fullWidth: false) {
                        profile.toggleCuisine(c)
                    }
                }
            }
        }
    }

    // MARK: 알림 프라이밍 — 가치 설명 후 시스템 권한(소프트 애스크)

    private var notifyPage: some View {
        questionPage(title: "A heads-up before\nfood goes bad?",
                     body: "Once a day, only when something's expiring.") {
            VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                // 개인화 payoff — 방금 답한 내용을 즉시 반영해 "맞춰졌다"는 신호(리서치: aha moment).
                HStack(spacing: ReffiSpace.s2) {
                    ReffiIcon.ai.reffi(18, .bold).foregroundStyle(ReffiColor.blueDark)
                    Text("Tuned for \(profile.cuisines.summaryText) · \(profile.household.label)")
                        .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                        .lineLimit(1)
                }
                HStack(spacing: ReffiSpace.s2) {
                    ReffiIcon.countdown.reffi(18, .bold).foregroundStyle(ReffiColor.blueDark)
                    Text("3 days before · 8 AM")
                        .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                }
            }
        }
    }

    /// 질문 페이지 공통 — 흰 영수증 카드에 질문 + 컨트롤.
    private func questionPage<C: View>(title: LocalizedStringKey, body copy: LocalizedStringKey,
                                       @ViewBuilder control: () -> C) -> some View {
        let shape = ReceiptShape(tooth: 7)
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: ReffiSpace.s4) {
                Text(title)
                    .font(.custom("Pretendard-Bold", size: 26, relativeTo: .title))
                    .lineSpacing(3)
                    .foregroundStyle(ReffiColor.ink)
                Text(copy).reffiType(.body).foregroundStyle(ReffiColor.ink2)
                control()
                    .padding(.top, ReffiSpace.s2)
            }
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s5 + 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ReffiColor.oklch(0.985, 0.004, 90), in: shape)
            .paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
            .reffiShadow1()
            .padding(.horizontal, ReffiGrid.margin)
            Spacer(minLength: 0)
        }
    }

    // MARK: 하단 — 페이지 점 + 진행 버튼

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(0...last, id: \.self) { i in
                Circle()
                    .fill(i == page ? ReffiColor.ink2 : ReffiColor.muted.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.bottom, ReffiSpace.s4)
        .accessibilityLabel("Page \(page + 1) of \(last + 1)")
    }

    @ViewBuilder private var bottomButton: some View {
        VStack(spacing: ReffiSpace.s1) {
            if page == last {
                PaperButton(title: "Turn on alerts & start", seed: 2) { requestNotifications() }
                QuietButton(title: "Maybe later", tint: ReffiColor.ink2) {
                    // 알림 SSOT = ExpiryNotifier 키. 프로필 토글이 같은 키를 읽는다.
                    UserDefaults.standard.set(false, forKey: ExpiryNotifier.enabledKey)
                    onFinish()
                }
                .frame(maxWidth: .infinity)
            } else {
                PaperButton(title: "Next", seed: 2) {
                    withAnimation(motion) { page += 1 }
                }
            }
        }
        .padding(.horizontal, ReffiGrid.margin + ReffiSpace.s2)
        .padding(.bottom, ReffiSpace.s5)
    }

    /// 시스템 알림 권한 — 프라이밍 페이지에서 맥락 설명 후에만 요청(§리서치: 소프트 애스크).
    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            Task { @MainActor in
                // 알림 SSOT = ExpiryNotifier 키. 권한이 나면 임박 알림을 켜고 재스케줄한다.
                UserDefaults.standard.set(granted, forKey: ExpiryNotifier.enabledKey)
                if granted { ExpiryNotifier.reschedule(for: store.ingredients) }
                onFinish()
            }
        }
    }
}
