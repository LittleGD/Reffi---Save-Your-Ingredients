import SwiftUI
import UserNotifications

/// 온보딩 — 가치 3장(기록→레시피→리포트) + 개인화 2장(가구·취향) + 알림 프라이밍 1장.
/// 혜택 중심 카피, 언제든 건너뛰기 가능, 개인화 답은 ProfileStore에 바로 저장(가입 전이어도 로컬 유지).
struct OnboardingView: View {
    @Environment(ProfileStore.self) private var profile
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
                              title: "냉장고 속 재료를\n영수증처럼 기록해요",
                              body: "사 온 재료를 등록하면 유통기한을 대신 세어드려요.")
                        .tag(0)
                    valuePage(hero: { recipeHero },
                              title: "임박한 재료로\n오늘의 레시피를 추천해요",
                              body: "가장 급한 재료부터 먹을 수 있게, 위에서부터 순서대로.")
                        .tag(1)
                    valuePage(hero: { reportHero },
                              title: "버리지 않은 날들이\n리포트로 쌓여요",
                              body: "무낭비 스트릭과 절약 리포트로 변화를 확인하세요.")
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
                QuietButton(title: "건너뛰기", tint: ReffiColor.ink2) { onFinish() }
            }
        }
        .padding(.horizontal, ReffiGrid.margin)
        .padding(.top, ReffiSpace.s3)
    }

    // MARK: 가치 페이지 — 히어로(텍스트를 그대로 시각화한 미니 영수증) + 한글 디스플레이(§3.1)

    private func valuePage<H: View>(@ViewBuilder hero: () -> H,
                                    title: String, body copy: String) -> some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s5) {
            Spacer(minLength: 0)
            hero()
                .frame(maxWidth: .infinity)
                .padding(.bottom, ReffiSpace.s4)

            Text(title)
                .font(ReffiTextRole.display.koreanDisplayFont)
                .lineSpacing(4)
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
                heroRow(.tomato, "토마토", "D-2", ReffiColor.soonDark)
                heroDash
                heroRow(.leaf, "시금치", "D-1", ReffiColor.soonDark)
                heroDash
                heroRow(.milk, "우유", "D-5", ReffiColor.freshDark)
            }
        }
    }

    /// ② "임박 재료 → 오늘의 레시피" — Today 재료 아래 레시피 제안이 찍힌 티켓.
    private var recipeHero: some View {
        miniReceipt(seed: 1) {
            VStack(spacing: ReffiSpace.s3) {
                heroHeader("REFFI · TODAY")
                heroRow(.egg, "계란", "Today", ReffiColor.urgentDark)
                heroRow(.tomato, "토마토", "D-2", ReffiColor.soonDark)
                heroDash
                HStack(spacing: ReffiSpace.s2) {
                    ReffiIcon.ai.reffi(15, .bold)
                    Text("오늘의 레시피 · 토마토 프리타타")
                        .font(.custom("Pretendard-SemiBold", size: 14, relativeTo: .caption))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(ReffiColor.blueDark)
            }
        }
    }

    /// ③ "리포트로 쌓여요" — 스트릭 도장 + 낭비율이 찍힌 무낭비 리포트.
    private var reportHero: some View {
        miniReceipt(seed: 2) {
            VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                HStack(spacing: ReffiSpace.s2) {
                    Text("NO-WASTE REPORT")
                        .font(.custom("Pretendard-Bold", size: 10, relativeTo: .caption2)).tracking(1.2)
                        .foregroundStyle(ReffiColor.muted)
                    DDayStamp(text: "DAY 12", color: ReffiColor.freshDark, size: 9)
                    Spacer(minLength: 0)
                }
                HStack(alignment: .firstTextBaseline, spacing: ReffiSpace.s2) {
                    Text("8%").font(.reffiNum(36, relativeTo: .largeTitle))
                        .foregroundStyle(ReffiColor.freshDark)
                    Text("낭비율").reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                    Spacer(minLength: 0)
                }
                heroDash
                Text("Ate 12 · Tossed 1")
                    .font(.reffiNum(13, relativeTo: .caption)).foregroundStyle(ReffiColor.ink2)
            }
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

    private func heroRow(_ glyph: FoodGlyph, _ name: String, _ dDay: String, _ color: Color) -> some View {
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
        questionPage(title: "몇 명이 먹나요?",
                     body: "레시피 양과 장보기 수량을 여기에 맞춰드려요.") {
            HStack(spacing: ReffiSpace.s2) {
                ForEach(HouseholdSize.allCases) { h in
                    SelectableChip(text: h.label, selected: profile.household == h) {
                        profile.household = h
                    }
                }
            }
        }
    }

    // MARK: 개인화 ② 요리 취향 — 멀티 선택(프로필 Cuisines와 동일 문법)

    private var cuisinePage: some View {
        questionPage(title: "어떤 요리를 좋아하세요?",
                     body: "여러 개 골라도 돼요. 추천 레시피에 반영돼요.") {
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
        questionPage(title: "버리기 전에\n딱 한 번 알려드릴까요?",
                     body: "임박한 재료가 있을 때만, 하루 한 번 아침에 알려드려요.") {
            VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                // 개인화 payoff — 방금 답한 내용을 즉시 반영해 "맞춰졌다"는 신호(리서치: aha moment).
                HStack(spacing: ReffiSpace.s2) {
                    ReffiIcon.ai.reffi(18, .bold).foregroundStyle(ReffiColor.blueDark)
                    Text("\(profile.cuisines.summaryText) · \(profile.household.label) 기준으로 추천을 준비했어요")
                        .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                        .lineLimit(2)
                }
                HStack(spacing: ReffiSpace.s2) {
                    ReffiIcon.countdown.reffi(18, .bold).foregroundStyle(ReffiColor.blueDark)
                    Text("기본: 유통기한 3일 전 · 오전 8시")
                        .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                }
                Text("설정은 프로필에서 언제든 바꿀 수 있어요.")
                    .reffiType(.caption).foregroundStyle(ReffiColor.muted)
            }
        }
    }

    /// 질문 페이지 공통 — 흰 영수증 카드에 질문 + 컨트롤.
    private func questionPage<C: View>(title: String, body copy: String,
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
        .accessibilityLabel("\(page + 1) / \(last + 1) 페이지")
    }

    @ViewBuilder private var bottomButton: some View {
        VStack(spacing: ReffiSpace.s1) {
            if page == last {
                PaperButton(title: "알림 켜고 시작하기", seed: 2) { requestNotifications() }
                QuietButton(title: "나중에 할게요", tint: ReffiColor.ink2) {
                    profile.notifyEnabled = false
                    onFinish()
                }
                .frame(maxWidth: .infinity)
            } else {
                PaperButton(title: "다음", seed: 2) {
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
                profile.notifyEnabled = granted
                onFinish()
            }
        }
    }
}
