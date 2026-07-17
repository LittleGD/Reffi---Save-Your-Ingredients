import SwiftUI
import UserNotifications

/// 온보딩 — [인트로] 가치 3장(기록→레시피→리포트): 하단 버튼 없이 스와이프, 마지막 장에서 "Let's Start" 등장.
///        [셋업 시트] "Let's Start" → 하단에서 올라오는 시트에서 개인화(가구·취향) + 알림 프라이밍을 Next로 진행.
/// 인트로/셋업 각각 3점 인디케이터. 혜택 중심 카피, 언제든 건너뛰기, 답은 ProfileStore에 즉시 저장(가입 전이어도 로컬 유지).
struct OnboardingView: View {
    @Environment(ProfileStore.self) private var profile
    @Environment(FridgeStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onFinish: () -> Void

    @State private var page = 0             // 인트로 페이지 0…introLast
    @State private var showSetup = false    // "Let's Start" → 하단에서 올라오는 셋업 시트
    @State private var setupPage = 0        // 셋업 시트 내 페이지 0…setupLast
    @State private var stamping = false     // 셋업 완료 시 "Start" 도장 슬램 연출
    @State private var stampScale: CGFloat = 2.4
    @State private var stampOpacity: Double = 0
    private let introLast = 2               // 인트로 마지막 장(page 2) — 여기서 "Let's Start"로 셋업 시트를 연다
    private let setupLast = 2               // 셋업 3장(가구·취향·알림)의 마지막

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        #if DEBUG
        // 스크린샷·QA용 — `-onboardingPage N`으로 특정 페이지 직행.
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-onboardingPage"), i + 1 < args.count,
           let n = Int(args[i + 1]) {
            _page = State(initialValue: min(max(0, n), introLast))
        }
        // 셋업 시트 QA — `-onboardingSetup`으로 시트를 바로 열고, `-onboardingSetupPage N`으로 특정 장 직행.
        if args.contains("-onboardingSetup") {
            _showSetup = State(initialValue: true)
        }
        if let i = args.firstIndex(of: "-onboardingSetupPage"), i + 1 < args.count,
           let n = Int(args[i + 1]) {
            _setupPage = State(initialValue: min(max(0, n), setupLast))
            _showSetup = State(initialValue: true)
        }
        #endif
    }

    var body: some View {
        ZStack {
            LiquidGlassBackground(accent: accent)
            VStack(spacing: 0) {
                topBar
                TabView(selection: $page) {
                    valuePage(hero: { recordHero(active: page == 0) },
                              title: "Log your fridge\nlike a receipt",
                              body: "Add what you buy — we'll count down the expiry dates.")
                        .tag(0)
                    valuePage(hero: { recipeHero(active: page == 1) },
                              title: "Today's recipes,\nfrom what expires first",
                              body: "Eat the most urgent ingredients first, top to bottom.")
                        .tag(1)
                    valuePage(hero: { reportHero(active: page == 2) },
                              title: "Days without waste\nadd up to a report",
                              body: "Watch your no-waste streak grow, day by day.")
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(motion, value: page)

                introDots
                bottomButton
            }
        }
        // "Let's Start" → 하단에서 올라와 화면 전체를 덮는 셋업(개인화·알림). Start cooking과 동일한 풀스크린 커버.
        .fullScreenCover(isPresented: $showSetup) {
            setupSheet
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
            Text(verbatim: "Reffi").reffiType(.display).foregroundStyle(ReffiColor.blueDark)
                .scaleEffect(0.62, anchor: .leading)   // 워드마크 축소 배치(위계는 페이지 타이틀에)
            Spacer()
            QuietButton(title: "Skip", tint: ReffiColor.ink2) { onFinish() }
        }
        .padding(.horizontal, ReffiGrid.margin)
        .padding(.top, ReffiSpace.s3)
    }

    // MARK: 가치 페이지 — 히어로(텍스트를 그대로 시각화한 미니 영수증) + 한글 디스플레이(§3.1)

    private func valuePage<H: View>(@ViewBuilder hero: () -> H,
                                    title: LocalizedStringKey, body copy: LocalizedStringKey) -> some View {
        VStack(alignment: .center, spacing: ReffiSpace.s5) {
            Spacer(minLength: 0)
            hero()
                .frame(maxWidth: .infinity)
                .frame(height: 292)               // 고정 히어로 슬롯 — 3페이지 타이틀·본문 위치를 동일하게 고정
                .padding(.bottom, ReffiSpace.s4)

            // 영문 디스플레이 = Story Script(§3.1 브랜드 모먼트 — 워드마크·온보딩 타이틀). 인트로 카피는 가운데 정렬.
            Text(title)
                .reffiType(.display)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .foregroundStyle(ReffiColor.ink)
            Text(copy)
                .reffiType(.body)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .foregroundStyle(ReffiColor.ink2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, ReffiGrid.margin + ReffiSpace.s2)
    }

    // MARK: 히어로 3종 — 각 페이지 카피를 시각적으로 재연(설명 일치)

    /// ① "영수증을 찍어서 관리" — 장본 영수증을 카메라로 찍는 모먼트(뷰파인더+카메라 배지)가 먼저 떴다
    ///    사라지고, 그 자리에 정리된 냉장고 영수증(재료·D-day)이 올라온다. 페이지2와 동일한 "찍힘→정리" 패턴.
    private func recordHero(active: Bool) -> some View {
        ZStack {
            captureMotif
                .flashReveal(active: active)                      // ① 영수증 찍는 모먼트 — 떴다 사라짐
            fridgeReceiptMini
                .heroReveal(.riseUp, active: active, delay: 1.05)  // ② 정리된 영수증이 올라옴
        }
    }

    /// 정리된 냉장고 영수증 — recordHero가 올리는 결과물(재료·D-day). 재료명은 정본 사전(entry.displayName)에서
    /// 결정적으로 조회(receiptRows) — D-day는 장식이므로 재료 순서 기반 고정값을 유지한다.
    private var fridgeReceiptMini: some View {
        miniReceipt(seed: 0) {
            VStack(spacing: ReffiSpace.s3) {
                heroHeader("REFFI · FRIDGE")
                ForEach(Array(receiptRows.enumerated()), id: \.offset) { i, row in
                    if i > 0 { heroDash }
                    heroRow(row.glyph, row.name, row.dDay, row.color)
                }
            }
        }
    }

    /// 캡처→정리 히어로 3종("찍힘"의 영수증 ↔ "정리"의 냉장고 영수증에 같은 재료가 등장)이 공유하는 조회 결과 —
    /// 정본 사전에서 id로 결정적으로 조회(랜덤 금지). id 조회가 실패하면(사전 로드 실패 등 극단 상황) 사전의
    /// 다른 엔트리로 개수를 채워 소스코드 리터럴 재료명이 남지 않게 한다.
    private static let receiptEntryIDs = ["tomato", "spinach", "milk"]

    private var receiptRows: [(glyph: FoodGlyph, name: String, dDay: String, color: Color)] {
        let lex = IngredientLexicon.shared
        var entries = Self.receiptEntryIDs.compactMap { lex.entry(id: $0) }
        if entries.count < Self.receiptEntryIDs.count {
            let extra = lex.entries.filter { e in !entries.contains { $0.id == e.id } }
            entries.append(contentsOf: extra.prefix(Self.receiptEntryIDs.count - entries.count))
        }
        let dDays = ["D-2", "D-1", "D-5"]                                             // 장식 — 재료 순서 기반 고정값
        let colors = [ReffiColor.soonDark, ReffiColor.soonDark, ReffiColor.freshDark]
        return zip(entries, zip(dDays, colors)).map { entry, meta in
            (glyph: FoodGlyph(rawValue: entry.glyph) ?? .generic, name: entry.displayName, dDay: meta.0, color: meta.1)
        }
    }

    /// 영수증 찍는 모먼트 — 장본 영수증 + 카메라 뷰파인더 코너 + 카메라 배지("찍는다").
    private var captureMotif: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            heroHeader("GROCERY · RECEIPT")
            ForEach(Array(receiptRows.enumerated()), id: \.offset) { _, row in
                captureRow(row.name)
            }
        }
        .padding(.horizontal, ReffiSpace.s4)
        .padding(.vertical, ReffiSpace.s3 + 2)
        .frame(width: 170)
        .background(ReffiColor.paper, in: ReceiptShape(tooth: 6))
        .reffiShadow1()
        // 카메라 뷰파인더 — 종이 바깥으로 코너 브래킷.
        .overlay(ViewfinderBrackets()
            .stroke(ReffiColor.blueDark, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .padding(-12))
        // 카메라 배지 — "찍는" 행위.
        .overlay(alignment: .bottomTrailing) {
            ReffiIcon.camera.reffi(18, .fill).foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(ReffiColor.blue, in: Circle())
                .overlay(Circle().stroke(ReffiColor.paper, lineWidth: 2.5))
                .offset(x: 16, y: 16)
        }
    }

    /// 가격 표기는 제거 — 앱에 재료 가격 데이터 소스가 없어(장바구니 금액 미추적) 실데이터화할 수 없다.
    private func captureRow(_ name: String) -> some View {
        Text(verbatim: name)                               // 사전 표시명 — 데이터 verbatim(§i18n)
            .font(.custom("Pretendard-Medium", size: 13, relativeTo: .caption))
            .foregroundStyle(ReffiColor.ink2)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    /// ② "임박 재료 → 오늘의 레시피" — 접시(달걀+Today 도장)가 먼저 떴다 사라지고, 그 자리에 레시피 주문서가 올라옴.
    private func recipeHero(active: Bool) -> some View {
        ZStack {
            eggDish
                .flashReveal(active: active)                      // ① 접시 — 떴다 사라짐
            orderTicketMini
                .heroReveal(.riseUp, active: active, delay: 1.05)  // ② 주문서가 그 자리에 올라옴
        }
    }

    /// 오늘의 접시 — 달걀 실루엣 + Today 도장.
    private var eggDish: some View {
        ZStack(alignment: .topTrailing) {
            PaperSilhouette(glyph: .egg, fresh: .fresh)
                .frame(width: 132, height: 132)
            DDayStamp(text: String(localized: "Today"), color: ReffiColor.urgentDark, size: 15)
                .offset(x: 14, y: -6)
        }
    }

    /// 레시피 주문서 미니 — §13 OrderMemoCard의 시각을 축약한 정적 티켓(온보딩 히어로용).
    /// 실제 카드는 풀스크린 덱·발주 부작용이 있어 그대로 못 넣으므로, 폰트·색·종이 문법만 재사용해 재연.
    /// 레시피명·재료명·조리 시간은 heroTicket()(RecipeCatalog 시드 우선, 폴백은 사전)에서 온다 — 리터럴 금지.
    private var orderTicketMini: some View {
        let shape = ReceiptShape(tooth: 8)
        let ticket = Self.heroTicket()
        return VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            // 헤더 — 주방 오더 티켓
            HStack(alignment: .firstTextBaseline) {
                Text("ORDER").font(.custom("Pretendard-Bold", size: 12, relativeTo: .caption))
                    .tracking(2.5).foregroundStyle(ReffiColor.ink)
                Spacer(minLength: 0)
                Text(verbatim: "#01").font(.reffiNum(13, relativeTo: .caption)).foregroundStyle(ReffiColor.ink2)
            }
            Text(verbatim: "TABLE · REFFI KITCHEN")
                .font(.custom("Pretendard-Medium", size: 9, relativeTo: .caption2))
                .tracking(1.5).foregroundStyle(ReffiColor.ink2)
            DashedRule()
            // 판정문(임박 소진) + 메뉴 + 시간 — "1"은 아래 D-day 중 "Today" 1건과 짝지어진 장식 표기.
            Text("Saves \(1) expiring today")   // 기존 포맷 키 재사용 — ko 번역이 이미 존재
                .font(.custom("Pretendard-Bold", size: 11, relativeTo: .caption2))
                .tracking(0.2).foregroundStyle(ReffiColor.urgentDark)
            HStack(alignment: .firstTextBaseline, spacing: ReffiSpace.s2) {
                Text(verbatim: ticket.name)                // 시드 레시피명 — 데이터 verbatim(§i18n)
                    .font(.custom("Pretendard-Bold", size: 20, relativeTo: .title3))
                    .tracking(-0.3).foregroundStyle(ReffiColor.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                if let minutes = ticket.minutes {
                    HStack(spacing: 3) {
                        ReffiIcon.time.reffi(11).foregroundStyle(ReffiColor.ink2)
                        Text(verbatim: "\(minutes) min").font(.custom("Pretendard-Medium", size: 11, relativeTo: .caption))
                            .foregroundStyle(ReffiColor.ink2)
                    }
                }
            }
            DashedRule()
            Text("ON THE TICKET")
                .font(.custom("Pretendard-SemiBold", size: 10, relativeTo: .caption2))
                .tracking(1.4).foregroundStyle(ReffiColor.ink2)
            ForEach(Array(ticket.rows.enumerated()), id: \.offset) { _, row in
                ticketMiniRow(row.name, row.dDay, row.color)
            }
            // Cook this 밴드(정적) — 실제 카드의 blue 발주 CTA를 종이컷+그레인으로 그대로 재연.
            Text("Cook this")
                .font(ReffiTextRole.subhead.font).tracking(ReffiTextRole.subhead.tracking)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, ReffiSpace.s2 + 1)
                .background {
                    let band = PaperCutRect(seed: 1)
                    band.fill(ReffiColor.blue)
                        .overlay(PaperGrain(seed: 5).clipShape(band))
                        .paperEdge(band, tint: ReffiColor.paperEdgeOnFill)
                }
                .padding(.top, 2)
        }
        .padding(.horizontal, ReffiSpace.s4 + 2)
        .padding(.vertical, ReffiSpace.s3)
        .frame(width: 250)
        .background(shape.fill(ReffiColor.paper))
        .overlay(shape.stroke(ReffiColor.ink.opacity(0.07), lineWidth: 1))
        .reffiShadow1()
        .clipped()   // 데이터 길이 방어(리뷰 P2-2) — 레시피명 2줄 등으로 늘어나도 카드 밖으로 넘치지 않게
    }

    /// 티켓 한 줄(축약) — 체크박스 + 이름 + D-N.
    private func ticketMiniRow(_ name: String, _ dDay: String, _ color: Color) -> some View {
        HStack(spacing: ReffiSpace.s2) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(color.opacity(0.7), lineWidth: 1.5)
                .frame(width: 13, height: 13)
            Text(verbatim: name)                           // 시드 재료명 — 데이터 verbatim(§i18n)
                .font(.custom("Pretendard-SemiBold", size: 15, relativeTo: .subheadline))
                .foregroundStyle(ReffiColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: ReffiSpace.s2)
            Text(verbatim: dDay)
                .font(.reffiNum(12, relativeTo: .caption))
                .foregroundStyle(color)
        }
    }

    /// 히어로 티켓 표시 데이터.
    private struct HeroTicket {
        struct Row { let name: String; let dDay: String; let color: Color }
        let name: String
        let minutes: Int?
        let rows: [Row]
    }

    /// 히어로 티켓 선택 — RecipeCatalog 시드에서 결정적으로 고른다(랜덤·Date 금지 — 프리뷰 불안정).
    /// 우선순위: id == "bibimbap" → 재료 2개+ 첫 한식(cuisine == "korean") → 첫 레시피.
    /// 시드 로드 실패(빈 카탈로그) 폴백: 히어로를 숨기지 않고 사전(IngredientLexicon) 첫 엔트리들로 구성해
    /// 어떤 경로에도 소스코드 리터럴 레시피명이 남지 않게 한다.
    private static func heroTicket() -> HeroTicket {
        let dDayMeta: [(String, Color)] = [("Today", ReffiColor.urgentDark),
                                            ("1d", ReffiColor.soonDark),
                                            ("2d", ReffiColor.soonDark)]
        let seed = RecipeCatalog.loadSeed()
        if let recipe = seed.first(where: { $0.id == "bibimbap" })
            ?? seed.first(where: { $0.cuisine == "korean" && $0.ingredients.count >= 2 })
            ?? seed.first {
            let names = recipe.ingredients.prefix(3).map(\.displayName)
            let rows = zip(names, dDayMeta).map { HeroTicket.Row(name: $0, dDay: $1.0, color: $1.1) }
            return HeroTicket(name: recipe.displayName, minutes: recipe.minutes, rows: rows)
        }
        // 극단 폴백 — 시드 카탈로그가 비어도 사전 엔트리로 티켓을 채운다(조리 시간 데이터는 없어 시간 칩은 생략).
        let entries = IngredientLexicon.shared.entries
        let names = entries.dropFirst().prefix(3).map(\.displayName)
        let rows = zip(names, dDayMeta).map { HeroTicket.Row(name: $0, dDay: $1.0, color: $1.1) }
        return HeroTicket(name: entries.first?.displayName ?? "", minutes: nil, rows: rows)
    }

    /// ③ "리포트로 쌓여요" — 큰 일러스트 + 무낭비 스트릭 도장(이전 버전 문법).
    /// 연출: 실루엣 pop → DAY 도장 슬램(②와 리듬 통일).
    private func reportHero(active: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            PaperSilhouette(glyph: .leaf, fresh: .fresh)
                .frame(width: 168, height: 168)
                .heroReveal(.pop, active: active, delay: 0)
            DDayStamp(text: String(localized: "DAY \(12)"), color: ReffiColor.freshDark, size: 15)
                .offset(x: 14, y: -6)
                .heroReveal(.stamp, active: active, delay: 0.25)
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
            Text(verbatim: name)                           // 사전 표시명 — 데이터 verbatim(§i18n)
                .font(.custom("Pretendard-SemiBold", size: 15, relativeTo: .subheadline))
                .foregroundStyle(ReffiColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Text(dDay)
                .font(.reffiNum(14, relativeTo: .subheadline))
                .foregroundStyle(color)
        }
    }

    // MARK: 개인화 ① 가구 인원 — 레시피 양의 근거(프로필 Household와 동일 문법)

    private var householdPage: some View {
        questionPage(title: "How many are eating?",
                     body: "We'll size your restock amounts to match.") {
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
                    Text("Today & tomorrow · 9 AM")
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

    /// 인트로 3점 인디케이터.
    private var introDots: some View {
        HStack(spacing: 6) {
            ForEach(0...introLast, id: \.self) { i in
                Circle()
                    .fill(i == page ? ReffiColor.ink2 : ReffiColor.muted.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.bottom, ReffiSpace.s4)
        .animation(motion, value: page)
        .accessibilityElement()
        .accessibilityLabel("Intro \(page + 1) of \(introLast + 1)")
    }

    /// 인트로 하단 — 마지막 장에서만 "Let's Start"(셋업 시트 오픈). 그 전엔 스와이프로 이동.
    @ViewBuilder private var bottomButton: some View {
        VStack(spacing: ReffiSpace.s1) {
            if page == introLast {
                PaperButton(title: "Let's Start", seed: 2) {
                    showSetup = true
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            // page < introLast: 하단 버튼 없음 — 스와이프로 이동, 인디케이터만 노출.
        }
        .frame(maxWidth: .infinity, minHeight: 52)   // 버튼 유무와 무관하게 높이 예약 → 인트로 스와이프 시 점 위치 고정
        .padding(.horizontal, ReffiGrid.margin + ReffiSpace.s2)
        .padding(.bottom, ReffiSpace.s5)
        .animation(motion, value: page)
    }

    // MARK: 셋업 시트 — "Let's Start"로 하단에서 올라오는 개인화(가구·취향) + 알림 프라이밍

    private var setupSheet: some View {
        ZStack {
            LiquidGlassBackground(accent: ReffiColor.blue)
            VStack(spacing: 0) {
                // 상단 — 디스플레이 폰트(Story Script)로 현재 단계를 가운데 표기.
                Text("Step \(setupPage + 1)")
                    .reffiType(.display)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(ReffiColor.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.top, ReffiSpace.s5 + 20)              // 그래버 대신 상태바에서 ~20px 내림
                    .padding(.bottom, ReffiSpace.s2)
                    .accessibilityLabel("Step \(setupPage + 1) of \(setupLast + 1)")

                TabView(selection: $setupPage) {
                    householdPage.tag(0)
                    cuisinePage.tag(1)
                    notifyPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(motion, value: setupPage)

                setupDots
                setupButton
            }
        }
        // 셋업 완료 시 "Start" 도장이 위에서 쾅 찍히는 연출.
        .overlay { if stamping { startStamp } }
    }

    /// "Start" 도장 슬램 — 큰 상태에서 스프링으로 내려앉으며(오버슈트) 임팩트 햅틱.
    private var startStamp: some View {
        ZStack {
            Color.black.opacity(0.10).ignoresSafeArea()
            DDayStamp(text: String(localized: "Start"), color: ReffiColor.blueDark, size: 46)
                .scaleEffect(stampScale)
                .opacity(stampOpacity)
                .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: stamping)
        .onAppear {
            let anim: Animation = reduceMotion
                ? .easeOut(duration: 0.2)
                : .spring(response: 0.26, dampingFraction: 0.5)   // 오버슈트 = 쾅
            withAnimation(anim) { stampScale = 1; stampOpacity = 1 }
        }
    }

    /// 셋업 완료 — 도장을 찍고 잠깐 뒤 온보딩 종료(게이트 → 메인 앱).
    private func finishWithStamp() {
        guard !stamping else { return }
        stamping = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { onFinish() }
    }

    /// 셋업 하단 3점 인디케이터.
    private var setupDots: some View {
        HStack(spacing: 6) {
            ForEach(0...setupLast, id: \.self) { i in
                Circle()
                    .fill(i == setupPage ? ReffiColor.ink2 : ReffiColor.muted.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
        .frame(maxWidth: .infinity)               // 가로 가운데 정렬
        .padding(.bottom, ReffiSpace.s4)
        .animation(motion, value: setupPage)
        .accessibilityElement()
        .accessibilityLabel("Setup \(setupPage + 1) of \(setupLast + 1)")
    }

    /// 셋업 하단 — 마지막(알림)에서만 시작 버튼, 그 전엔 Next.
    @ViewBuilder private var setupButton: some View {
        VStack(spacing: ReffiSpace.s1) {
            if setupPage == setupLast {
                PaperButton(title: "Turn on alerts & start", seed: 2) { requestNotifications() }
                QuietButton(title: "Maybe later", tint: ReffiColor.ink2) {
                    // 알림 SSOT = ExpiryNotifier 키. 프로필 토글이 같은 키를 읽는다.
                    UserDefaults.standard.set(false, forKey: ExpiryNotifier.enabledKey)
                    finishWithStamp()
                }
                .frame(maxWidth: .infinity)
            } else {
                PaperButton(title: "Next", seed: 2) {
                    withAnimation(motion) { setupPage += 1 }
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
                finishWithStamp()
            }
        }
    }
}

// MARK: - 히어로 진입 연출 — 인트로 페이지가 활성화될 때 재생(스와이프 재방문 시에도)

/// 히어로 요소 등장 연출(§7 — transform·opacity만). 이탈 시 즉시 리셋해 재방문마다 다시 재생.
/// reduce-motion(§7.4)이면 연출 없이 최종 상태로 즉시 표시.
private struct HeroReveal: ViewModifier {
    enum Kind {
        case pop     // 살짝 오버슈트 등장 — 실루엣·도장
        case stamp   // 도장 슬램 — 큰 상태에서 쾅 내려앉음(셋업 Start 도장과 같은 문법)
        case riseUp  // 하단에서 스르륵 올라옴 — 영수증·주문서 카드
    }
    let kind: Kind
    let active: Bool
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : hiddenScale)
            .offset(y: visible ? 0 : hiddenOffset)
            .onAppear { if active { reveal() } }   // 첫 페이지는 onChange가 없어 여기서 재생
            .onChange(of: active) { _, now in
                if now { reveal() } else { visible = false }   // 이탈은 애니메이션 없이 리셋
            }
    }

    private func reveal() {
        withAnimation(reduceMotion ? nil : animation.delay(delay)) { visible = true }
    }

    private var hiddenScale: CGFloat {
        switch kind {
        case .riseUp: 1
        case .pop: 0.9
        case .stamp: 2.0
        }
    }
    private var hiddenOffset: CGFloat { kind == .riseUp ? 150 : 0 }   // 아래(화면 밖)에서 올라옴
    private var animation: Animation {
        switch kind {
        case .pop: ReffiMotion.pop
        case .stamp: .spring(response: 0.26, dampingFraction: 0.5)   // 오버슈트 = 쾅
        case .riseUp: .spring(response: 0.55, dampingFraction: 0.72) // 스르륵 올라와 살짝 정착
        }
    }
}

private extension View {
    func heroReveal(_ kind: HeroReveal.Kind, active: Bool, delay: Double) -> some View {
        modifier(HeroReveal(kind: kind, active: active, delay: delay))
    }
    func flashReveal(active: Bool) -> some View {
        modifier(FlashReveal(active: active))
    }
}

/// 오브젝트가 떴다 사라지는 연출(§7 — opacity·scale만) — 페이지1 "찍힘"·페이지2 "접시".
/// 페이드 인 → 잠깐 유지 → 페이드 아웃. 그 자리에 뒤이어 카드(riseUp)가 올라온다.
/// reduce-motion(§7.4)이면 오브젝트를 생략(뒤 카드는 즉시 표시).
private struct FlashReveal: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var token = 0   // 재생 세대 — 재방문 시 이전 asyncAfter 무효화

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.92)
            .onAppear { if active { play() } }
            .onChange(of: active) { _, now in
                if now { play() } else { shown = false }   // 이탈은 즉시 숨김
            }
    }

    private func play() {
        guard !reduceMotion else { shown = false; return }   // reduce: 오브젝트 생략
        token += 1
        let gen = token
        shown = false
        withAnimation(.easeOut(duration: 0.42)) { shown = true }      // 페이드 인
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            guard gen == token, active else { return }               // 최신 재생만 사라지게
            withAnimation(.easeIn(duration: 0.33)) { shown = false }  // 페이드 아웃
        }
    }
}

/// 카메라 뷰파인더 코너 브래킷 4개 — "찍는" 프레임.
private struct ViewfinderBrackets: Shape {
    var len: CGFloat = 22
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY + len)); p.addLine(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX + len, y: r.minY))
        p.move(to: CGPoint(x: r.maxX - len, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY + len))
        p.move(to: CGPoint(x: r.minX, y: r.maxY - len)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX + len, y: r.maxY))
        p.move(to: CGPoint(x: r.maxX - len, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - len))
        return p
    }
}
