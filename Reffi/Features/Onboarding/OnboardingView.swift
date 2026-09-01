import SwiftUI
import UserNotifications

/// 온보딩 — [인트로] 가치 3장(기록→레시피→리포트): 하단 버튼 없이 스와이프, 마지막 장에서 "Let's start" 등장.
///        [셋업 시트] "Let's start" → 하단에서 올라오는 시트에서 개인화(가구·취향) + 알림 프라이밍을 Next로 진행.
/// 인트로/셋업 각각 3점 인디케이터. 혜택 중심 카피, 언제든 건너뛰기, 답은 ProfileStore에 즉시 저장(가입 전이어도 로컬 유지).
struct OnboardingView: View {
    @Environment(ProfileStore.self) private var profile
    @Environment(FridgeStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onFinish: () -> Void

    @State private var page = 0             // 인트로 페이지 0…introLast
    @State private var showSetup = false    // "Let's start" → 하단에서 올라오는 셋업 시트
    @State private var setupPage = 0        // 셋업 시트 내 페이지 0…setupLast
    @State private var stamping = false     // 셋업 완료 시 "Start" 도장 슬램 연출
    @State private var stampScale: CGFloat = 2.4
    @State private var stampOpacity: Double = 0
    private let introLast = 2               // 인트로 마지막 장(page 2) — 여기서 "Let's start"로 셋업 시트를 연다
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
            PaperCanvasBackground()
            VStack(spacing: 0) {
                topBar
                TabView(selection: $page) {
                    valuePage(hero: { recordHero(active: page == 0) },
                              title: "Log your fridge\nlike a receipt",
                              body: "Add what you buy. We'll count down the expiry dates.")
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
        // "Let's start" → 하단에서 올라와 화면 전체를 덮는 셋업(개인화·알림). Start cooking과 동일한 풀스크린 커버.
        .fullScreenCover(isPresented: $showSetup) {
            setupSheet
        }
    }

    // **페이지 인덱스로 배경색을 바꾸지 마라.** 이 자리엔 `page`를 urgent → soon → fresh 로 옮기는
    // `accent`가 있었고 그 색이 전면 배경을 물들였다. 두 가지가 동시에 틀렸다.
    // ① 앱을 처음 여는 사람이 가장 먼저 보는 화면(page 0)이 **붉은 얼룩**으로 시작했다 — 그 장이
    //    하는 말은 "장 본 것을 영수증처럼 기록해 두라"인데, 아직 아무것도 상하지 않은 사람에게
    //    위험색을 먼저 칠하고 있었다. 색과 카피가 서로 다른 말을 했다.
    // ② 신선도는 배경이 지는 사실이 아니다(§2.5) — 인디케이터 바·D-day 잉크·도장이 그 몫이다.
    // 세 장의 신선도 서사는 지금 **일러스트 안에** 있다: 냉장고 영수증 행이 자기 D-day의 신선도로
    // 시들고(`heroRow`), 접시엔 오늘 만료 도장(urgentDark)이, 리포트엔 무낭비 도장(freshDark)이
    // 찍힌다. 그쪽이 배경 얼룩보다 정확하다 — 페이지가 실제로 말하는 것을 말한다.

    private var motion: Animation? {
        ReffiMotion.gated(ReffiMotion.enter, reduce: reduceMotion)   // 면 전환 = 진입(§7.1 dur-3 ease-out)
    }

    // MARK: 상단 — 워드마크(좌) + 건너뛰기(우)

    private var topBar: some View {
        HStack {
            // 워드마크 축소 배치(위계는 페이지 타이틀에) — `scaleEffect`가 아니라 **실제 21pt**다(42차):
            // 레이어 축소는 사이드베어링·획 두께까지 0.62배로 줄여 마진선 과밀착 + 잉크 무게 불일치를
            // 만들었고, 레이아웃엔 축소 전 크기를 보고해 자리도 거짓이었다. 자간 0은 display 규약(§3.1).
            Text(verbatim: "Reffi")
                .font(.custom("StoryScript-Regular", size: 21, relativeTo: .title2))
                .foregroundStyle(ReffiColor.blueDark)
            Spacer()
            QuietButton(title: "Skip", tint: ReffiColor.ink2) { onFinish() }
                // QuietButton의 내재 가로 패딩(s2)이 우측선을 8pt 안으로 밀었다 — 마진선으로 되민다(42차).
                .padding(.trailing, -ReffiSpace.s2)
        }
        .padding(.horizontal, ReffiGrid.margin)
        .padding(.top, ReffiSpace.s3)
    }

    // MARK: 가치 페이지 — 히어로(텍스트를 그대로 시각화한 미니 영수증) + 한글 디스플레이(§3.1)

    /// 타이틀만 `LocalizedStringResource`인 이유: Display 폰트를 고르려면 **해석된 문자열**이 필요한데
    /// `LocalizedStringKey`는 그 결과를 밖으로 내주지 않는다(아래 스크립트 폴백 주석 참고).
    private func valuePage<H: View>(@ViewBuilder hero: () -> H,
                                    title: LocalizedStringResource, body copy: LocalizedStringKey) -> some View {
        // 페이저 안이라 넘친 콘텐츠를 되찾을 길이 없다 — `TabView(.page)`는 자기 경계로 잘라내고,
        // 스와이프는 옆 장으로 갈 뿐 잘린 글자를 데려오지 않는다. 큰 글씨에서 타이틀·본문이 자라면
        // 세로로 흐르게 두고 스크롤로 닿게 한다. 점·CTA는 이 밖(부모 VStack)에 고정이라 그대로 남는다.
        // 히어로는 `GeometryReader`(이탈 클로저)에 들어가기 전에 값으로 받아 둔다 — 빌더 인자는 non-escaping이다.
        let heroView = hero()
        let titleText = String(localized: title)
        return GeometryReader { geo in
            ScrollView {
                VStack(alignment: .center, spacing: ReffiSpace.s5) {
                    // **상단 정박**(49차) — 대칭 Spacer 쌍이 블록을 세로 중앙에 세워, 타이틀이
                    // 화면 62% 지점에서 시작하고 히어로 위에 큰 빈 띠가 남았다. 레퍼런스 감사에서
                    // 인트로 장은 예외 없이 히어로·텍스트를 **상단 절반에 붙이고** 남는 슬랙을
                    // 텍스트 아래 한 덩어리로 몰아 점·CTA 바로 위에 둔다. 앞 Spacer를 고정
                    // `s7`로 바꾸고 뒤만 가변으로 두면 타이틀이 약 47%로 올라오고, 히어로 슬롯이
                    // 292 고정이라 3장 정렬은 그대로다. 큰 글씨에서 콘텐츠가 화면을 넘으면
                    // `minHeight` 덕에 지금처럼 스크롤로 전환된다(동작 불변).
                    Spacer(minLength: 0).frame(height: ReffiSpace.s7)
                    heroView
                        .frame(maxWidth: .infinity)
                        .frame(height: 292)       // 고정 히어로 슬롯 — 3페이지 타이틀·본문 위치를 동일하게 고정
                        // 히어로는 **장식**(미니 영수증·티켓 소품)이라 글자 상한을 건다: 고정 폭 소품(250·272)이
                        // AX에서 슬롯 292 밖으로 터져 나온다. 아래 타이틀·본문은 정보라 상한 없이 다 자란다.
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .padding(.bottom, ReffiSpace.s4)

                    // 영문 디스플레이 = Story Script(§3.1 브랜드 모먼트 — 워드마크·온보딩 타이틀). 인트로 카피는 가운데 정렬.
                    // 세 장 다 번역되는 타이틀이라 스크립트 폴백을 경유한다(ko는 Pretendard Bold, §3.1).
                    Text(verbatim: titleText)
                        .reffiType(.display, for: titleText)
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
                // 컨테이너 높이를 바닥으로 깔아 남는 세로를 **아래 Spacer 하나가** 흡수하고,
                // 콘텐츠가 그보다 커질 때만 스크롤이 생긴다(49차 — 옛 대칭 Spacer 쌍은 위 주석).
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
                .padding(.horizontal, ReffiGrid.margin + ReffiSpace.s2)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
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
                    heroRow(row.glyph, row.name, row.dDay, row.fresh)
                }
            }
        }
    }

    /// 캡처→정리 히어로 3종("찍힘"의 영수증 ↔ "정리"의 냉장고 영수증에 같은 재료가 등장)이 공유하는 조회 결과 —
    /// 정본 사전에서 id로 결정적으로 조회(랜덤 금지). id 조회가 실패하면(사전 로드 실패 등 극단 상황) 사전의
    /// 다른 엔트리로 개수를 채워 소스코드 리터럴 재료명이 남지 않게 한다.
    private static let receiptEntryIDs = ["tomato", "spinach", "milk"]

    /// 행이 **색이 아니라 신선도**를 들고 다니는 이유: 같은 사실을 잉크(D-day)와 일러스트(시듦)가
    /// 함께 져야 하는데, `Color` 하나만 넘기면 실루엣이 그 사실을 볼 수 없어 조용히 `.fresh`로 굳는다
    /// (실제로 그랬다 — D-1 재료 옆에 흠 하나 없는 일러스트가 서 있었다). 파생은 `heroRow` 한 곳에서.
    private var receiptRows: [(glyph: FoodGlyph, name: String, dDay: String, fresh: Freshness)] {
        let lex = IngredientLexicon.shared
        var entries = Self.receiptEntryIDs.compactMap { lex.entry(id: $0) }
        if entries.count < Self.receiptEntryIDs.count {
            let extra = lex.entries.filter { e in !entries.contains { $0.id == e.id } }
            entries.append(contentsOf: extra.prefix(Self.receiptEntryIDs.count - entries.count))
        }
        // 남은 일수는 장식(재료 순서 기반 고정값)이지만, **표기와 색은 본 앱과 같은 정본**을 탄다 —
        // 온보딩이 가르친 표기를 앱이 안 쓰면 첫 화면부터 약속이 어긋난다.
        let daysLeft = [2, 1, 5]
        return zip(entries, daysLeft).map { entry, days in
            (glyph: FoodGlyph(rawValue: entry.glyph) ?? .generic,
             name: entry.displayName,
             dDay: Ingredient.dDayText(daysLeft: days),
             fresh: Freshness(daysLeft: days))
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
        .padding(.vertical, ReffiSpace.s3)
        .frame(width: 170)
        .background(ReffiColor.paper, in: ReceiptShape(tooth: ReffiTooth.chip))
        // 뷰파인더·카메라 배지는 **일부러 그림자 뒤**다 — 종이 밖에 떠 있는 소품이라 종이의
        // 그림자를 함께 받으면 안 된다. 순서를 바꾸면 브래킷과 배지가 종이의 들림을 물려받는다.
        .reffiShadow1()
        // 카메라 뷰파인더 — 종이 바깥으로 코너 브래킷.
        .overlay(ViewfinderBrackets()
            .stroke(ReffiColor.blueDark, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .padding(-12))
        // 카메라 배지 — "찍는" 행위.
        .overlay(alignment: .bottomTrailing) {
            ReffiIcon.camera.reffi(18, .fill).foregroundStyle(ReffiColor.onAccent)   // blue 면 위(§2.7)
                .frame(width: 40, height: 40)
                .background(ReffiColor.blue, in: Circle())
                .overlay(Circle().stroke(ReffiColor.paper, lineWidth: 2.5))
                .offset(x: 16, y: 16)
        }
    }

    /// 가격 표기는 제거 — 앱에 재료 가격 데이터 소스가 없어(장바구니 금액 미추적) 실데이터화할 수 없다.
    private func captureRow(_ name: String) -> some View {
        Text(verbatim: name)                               // 사전 표시명 — 데이터 verbatim(§i18n)
            .reffiType(.metaText)
            .foregroundStyle(ReffiColor.ink2)
            .lineLimit(1)
            .minimumScaleFactor(ReffiShrink.chrome)
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
            // 이 도장은 크롬 단어가 아니라 **D-day 표기**다(`Ingredient.dDayText`가 오늘에 내는 그 값) —
            // 온보딩이 가르친 표기를 본 앱이 그대로 써야 하므로 캡스도 냉장고 도장과 같이 간다.
            DDayStamp(text: Ingredient.dDayText(daysLeft: 0), color: ReffiColor.urgentDark, size: 15,
                      caps: false,
                      accessibilityLabel: Ingredient.dDayAccessibilityText(daysLeft: 0))
                .offset(x: 14, y: -6)
        }
    }

    /// 레시피 주문서 미니 — §13 OrderMemoCard의 시각을 축약한 정적 티켓(온보딩 히어로용).
    /// 실제 카드는 풀스크린 덱·발주 부작용이 있어 그대로 못 넣으므로, 폰트·색·종이 문법만 재사용해 재연.
    /// 레시피명·재료명·조리 시간은 heroTicket()(RecipeCatalog 시드 우선, 폴백은 사전)에서 온다 — 리터럴 금지.
    private var orderTicketMini: some View {
        let shape = ReceiptShape(tooth: ReffiTooth.card)
        let ticket = Self.heroTicket()
        return VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            // 헤더 — 주방 오더 티켓
            HStack(alignment: .firstTextBaseline, spacing: ReffiSpace.s2) {
                // 모노 티켓 크롬은 verbatim 영문 고정 — 실제 OrderMemoCard와 같은 규칙(§13.5).
                // 크라운은 한 줄·한 role: 온보딩이 가르친 크롬을 본 앱이 그대로 쓴다.
                Text(verbatim: "ORDER · REFFI KITCHEN")
                    .reffiType(.monoTicketLabel).foregroundStyle(ReffiColor.ink)
                    .lineLimit(1).minimumScaleFactor(ReffiShrink.fit)
                Spacer(minLength: ReffiSpace.s2)
                Text(verbatim: "#01").reffiType(.monoTicketLabel).foregroundStyle(ReffiColor.ink2)
            }
            ReffiRule(.ticket)
            // 판정문(임박 소진) + 메뉴 + 시간 — "1"은 아래 D-day 중 "Today" 1건과 짝지어진 장식 표기.
            Text("Saves \(1) expiring today")   // 기존 포맷 키 재사용 — ko 번역이 이미 존재
                .reffiType(.metaText).foregroundStyle(ReffiColor.urgentDark)
            HStack(alignment: .firstTextBaseline, spacing: ReffiSpace.s2) {
                Text(verbatim: ticket.name)                // 시드 레시피명 — 데이터 verbatim(§i18n)
                    // 미니 티켓의 메뉴명 — `scaleEffect` 광학 축소 대신 **실제 20pt**(42차, `reffiStamp`와
                    // 같은 "동일 문법·가변 크기" 탈출구). 레이어 축소는 베이스라인·자간 계약을 깨고
                    // Dynamic Type 곡선 위에 또 곱해진다.
                    .font(.custom("Pretendard-Bold", size: 20, relativeTo: .title3)).tracking(-0.3)
                    .foregroundStyle(ReffiColor.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(ReffiShrink.fit)
                Spacer(minLength: 0)
                if let minutes = ticket.minutes {
                    HStack(spacing: ReffiSpace.s0) {
                        ReffiIcon.time.reffi(11).foregroundStyle(ReffiColor.ink2)
                        // 조리 시간은 크롬이 아니라 본문 문구 — 기존 "%lld min" 키를 타야 한국어에서 "N분"이 된다.
                        Text("\(minutes) min").reffiType(.metaText)
                            .foregroundStyle(ReffiColor.ink2)
                    }
                }
            }
            ReffiRule(.ticket)
            Text(verbatim: "ON THE TICKET")   // 위 크라운과 같은 모노 크롬 role
                .reffiType(.monoTicketLabel).foregroundStyle(ReffiColor.ink2)
            ForEach(Array(ticket.rows.enumerated()), id: \.offset) { _, row in
                ticketMiniRow(row.name, row.dDay, row.color)
            }
            // Cook this 밴드(정적) — 실제 카드의 blue 발주 CTA를 종이컷+그레인으로 그대로 재연.
            Text("Cook this")
                .font(ReffiTextRole.subhead.font).tracking(ReffiTextRole.subhead.tracking)
                .foregroundStyle(ReffiColor.onAccent)   // 실제 카드와 같은 blue 면 위 콘텐츠(§2.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, ReffiSpace.s2)
                .background {
                    let band = PaperCutRect(seed: 1)
                    band.fill(ReffiColor.blue)
                        .overlay(PaperGrain(seed: 5).clipShape(band))
                        .paperEdge(band, tint: ReffiColor.paperEdgeOnFill)
                }
                .padding(.top, ReffiSpace.s0)
        }
        .padding(.horizontal, ReffiSpace.s4)
        .padding(.vertical, ReffiSpace.s3)
        .frame(width: 250)
        // **자르는 것은 콘텐츠고, 그림자는 그 밖에 남는다.** 여기엔 `.reffiShadow1()` **다음에**
        // `.clipped()`가 있었다 — 클립은 앞 체인의 렌더 결과(그림자 포함)를 뷰의 **사각** bounds로
        // 자르는데 이 종이는 톱니(`ReceiptShape`)라 위아래가 안으로 파여 있어서, 톱니 골에 걸린
        // 그림자만 남고 나머지는 잘려 종이 둘레에 직사각형 자국이 남았다. 방어의 목적(레시피명이
        // 2줄로 늘어나도 종이 밖으로 넘치지 않게, 리뷰 P2-2)은 콘텐츠에만 걸면 그대로 달성되고,
        // 종이 모양으로 자르므로 사각 클립보다 오히려 정확하다.
        .clipShape(shape)
        .background(shape.fill(ReffiColor.paper))
        .overlay(shape.stroke(ReffiColor.paperEdge, lineWidth: 1))
        .reffiShadow1()
    }

    /// 티켓 한 줄(축약) — 체크박스 + 이름 + D-N.
    private func ticketMiniRow(_ name: String, _ dDay: String, _ color: Color) -> some View {
        HStack(spacing: ReffiSpace.s2) {
            PaperRect(cornerRadius: ReffiRadius.xs, seed: 3)
                .stroke(color.opacity(0.7), lineWidth: 1.5)
                .frame(width: 13, height: 13)
            Text(verbatim: name)                           // 시드 재료명 — 데이터 verbatim(§i18n)
                .reffiType(.badgeLabel)
                .foregroundStyle(ReffiColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(ReffiShrink.tab)
            Spacer(minLength: ReffiSpace.s2)
            Text(verbatim: dDay)
                .font(.reffiNum(.meta))
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
        // D-day 표기는 앱 유일의 정본 포매터를 탄다(`Ingredient.dDayText`) — 위 냉장고 영수증(receiptRows)과
        // 같은 규칙이다. 리터럴로 적으면 ko 기기에서 이 히어로만 영어로 남는다. 올캡도 씌우지 않는다:
        // 냉장고 카드의 도장이 `caps: false`로 찍는 그 값이라 여기서 대문자로 바꾸면 표기가 갈린다.
        let dDayMeta: [(String, Color)] = [(Ingredient.dDayText(daysLeft: 0), ReffiColor.urgentDark),
                                            (Ingredient.dDayText(daysLeft: 1), ReffiColor.soonDark),
                                            (Ingredient.dDayText(daysLeft: 2), ReffiColor.soonDark)]
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
    ///
    /// `receiptSurface`를 타지 않는 유일한 영수증 면이다 — 272pt 고정폭 소품이라 세로 여백 기준이
    /// 카드(s5)가 아니라 한 단 아래(s4)이고, 폭도 컨테이너를 채우지 않는다. 다만 **톱니 보정은 같은
    /// 공식**(base + tooth)을 쓴다 — 톱니를 바꿨을 때 이 소품만 어긋나지 않게.
    private func miniReceipt<C: View>(seed: Int, @ViewBuilder _ content: () -> C) -> some View {
        let shape = ReceiptShape(tooth: ReffiTooth.chip)
        return content()
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s4 + ReffiTooth.chip)
            .frame(width: 272)
            .background(ReffiColor.receipt, in: shape)
            .paperEdge(shape)
            .reffiShadow1()
            .rotationEffect(.degrees(seed % 2 == 0 ? -2 : 2))
    }

    private func heroHeader(_ text: String) -> some View {
        HStack {
            Text(text)
                .reffiType(.monoEyebrow)
                .foregroundStyle(ReffiColor.muted)
            Spacer(minLength: 0)
        }
    }

    private var heroDash: some View { ReffiRule(.receipt) }

    private func heroRow(_ glyph: FoodGlyph, _ name: String, _ dDay: String, _ fresh: Freshness) -> some View {
        HStack(spacing: ReffiSpace.s3) {
            // **이 행이 흉내 내는 표면(냉장고 카드·간편 행)은 실루엣에 실제 신선도를 넘긴다**
            // (`FridgeView`) — 여기만 `.fresh`로 굳혀 두면 온보딩이 "D-1"이라 적어 놓고 그 옆에
            // 갓 딴 재료를 그려, 앱이 쓰는 시듦 언어(§13.3)를 첫 화면부터 부정한다. soon은 채도
            // 0.85·형태 0.5라 알아채기 전에 먼저 느껴지는 정도지, 겁주는 그림이 아니다.
            PaperSilhouette(glyph: glyph, fresh: fresh)
                .frame(width: ReffiFoodIcon.rowMini, height: ReffiFoodIcon.rowMini)
            Text(verbatim: name)                           // 사전 표시명 — 데이터 verbatim(§i18n)
                .reffiType(.badgeLabel)
                .foregroundStyle(ReffiColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(ReffiShrink.chrome)
            Spacer(minLength: 0)
            Text(dDay)
                .font(.reffiNum(.body))
                .foregroundStyle(fresh.dark)   // 캔버스 위 색-as-텍스트는 dark 단(§2.6)
        }
    }

    // MARK: 개인화 ① 가구 인원 — 레시피 양의 근거(프로필 Household와 동일 문법)

    private var householdPage: some View {
        questionPage(title: "How many are eating?",
                     body: "We'll size your restock amounts to match.") {
            // 칩은 내용 크기(fullWidth false) — 균등 4등분은 "2 people" 등을 말줄임시킨다.
            HStack(spacing: ReffiSpace.s2) {
                ForEach(HouseholdSize.allCases) { h in
                    SelectableChip(text: h.labelKey, selected: profile.household == h,
                                   fullWidth: false, onCard: true) {
                        profile.household = h
                    }
                }
            }
        }
    }

    // MARK: 개인화 ② 요리 취향 — 멀티 선택(프로필 Cuisines와 동일 문법)

    private var cuisinePage: some View {
        questionPage(title: "What do you like to cook?",
                     body: "Pick as many as you like. Recipes will follow.") {
            // 같은 데이터를 같은 칩으로 그리는 프로필 시트(`CuisinePickerSheet`)가 `.leading`이다 —
            // 온보딩에서 고른 것을 프로필에서 고치는 흐름이라 두 화면이 연달아 보인다(49차).
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: ReffiSpace.s2)],
                      alignment: .leading, spacing: ReffiSpace.s2) {
                ForEach(CuisineStyle.allCases) { c in
                    SelectableChip(text: c.labelKey, selected: profile.cuisines.contains(c),
                                   fullWidth: false, onCard: true) {
                        profile.toggleCuisine(c)
                    }
                }
            }
        }
    }

    // MARK: 알림 프라이밍 — 가치 설명 후 시스템 권한(소프트 애스크)

    private var notifyPage: some View {
        // 하드 개행 제거(49차) — 그 `\n`은 **중앙 2줄 균형용** 장치였다. 좌측 정렬에서는 짧은 첫 줄
        // 뒤에 들쭉날쭉한 둘째 줄이 남아 오히려 어색하다 — 자연 줄바꿈에 맡긴다(§9.4 마지막 항).
        questionPage(title: "A heads-up before food goes bad?",
                     body: "Once a day, only when something's expiring.") {
            // 두 행은 각각 내용 크기로 줄어드는데 문구 길이가 달라, 중앙 정렬에서는 두 아이콘이
            // 서로 다른 x에 섰다(49차) — 좌측으로 붙이면 아이콘 열이 하나로 정렬되고, 취향 미선택으로
            // 첫 행이 빠질 때도 남은 행이 옆으로 밀리지 않는다.
            VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                // 개인화 payoff — 방금 답한 내용을 즉시 반영해 "맞춰졌다"는 신호(리서치: aha moment).
                // 실동작 정합: 레시피 튜닝은 요리 취향(cuisines)만, 가구 인원(household)은 재입고·수량
                // 맥락이라 서로 다른 구로 분리한다. 취향 미선택이면 튜닝 구는 생략(빈 요약을 안 보이게).
                HStack(alignment: .top, spacing: ReffiSpace.s2) {
                    ReffiIcon.ai.reffi(18, .bold).foregroundStyle(ReffiColor.blueDark)
                    VStack(alignment: .leading, spacing: ReffiSpace.s0) {
                        if !profile.cuisines.isEmpty {
                            Text("Tuned for \(profile.cuisines.summaryText)")
                                .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                                .lineLimit(1)
                        }
                        Text("Restock sized for \(profile.household.label)")
                            .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                            .lineLimit(1)
                    }
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
    ///
    /// **좌측 정렬이다(49차, §9.4).** 옛 주석은 "셋업 3장은 전부 중앙정렬"이었지만 이 세 장은
    /// 표지가 아니라 **폼**이다(가구 인원 단일선택·취향 멀티선택·알림 프라이밍) — §9.4의 중앙 예외
    /// ②는 "주변에 정렬선이 없고 화면에 그것 하나뿐인 표지형"이라 여기에 걸리지 않는다. 결정적
    /// 근거는 컴포넌트 쪽에 있다: `receiptSurface(alignment:)`의 기본값이 `.leading`이고 앱의 호출
    /// 아홉 곳 중 **여기 한 곳만** `.center`를 넘기고 있었다 — 같은 종이가 이 화면에서만 다른 축이었다.
    /// `title`이 `LocalizedStringKey`가 아니라 `String.LocalizationValue`인 이유: display role은
    /// 한글이 섞이면 Story Script → Pretendard Bold로 폴백해야 하는데(§3.1), 그 판별에 **실제로
    /// 그려질 문자열**이 필요하다. SwiftUI는 `Text`가 든 키의 해석 결과를 밖으로 주지 않으므로
    /// 호출부 대신 여기서 한 번 풀어 같은 값을 `Text`와 `reffiType(_:for:)` 둘에 함께 넘긴다.
    private func questionPage<C: View>(title: String.LocalizationValue, body copy: LocalizedStringKey,
                                       @ViewBuilder control: () -> C) -> some View {
        let titleText = String(localized: title)
        return VStack(alignment: .leading, spacing: ReffiSpace.s4) {
            // **질문이 페이지 헤드라인이다**(49차). 옛 배치는 질문을 카드 **안** `menuName`(26)에 두고
            // 화면 최대 글자(34 display)를 "Step N" 인덱스가 썼다 — 이 장의 주제는 인덱스가 아니라
            // 질문이므로 자리를 맞바꾼다. 이제 카드는 **답하는 자리**(설명 + 컨트롤)만 담는다.
            // display role은 번역되는 텍스트라 스크립트 폴백을 경유해야 한다(§3.1, `for:` 오버로드).
            Text(verbatim: titleText)
                .reffiType(.display, for: titleText)
                .foregroundStyle(ReffiColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, ReffiGrid.margin)

            VStack(alignment: .leading, spacing: ReffiSpace.s4) {
                Text(copy).reffiType(.body).foregroundStyle(ReffiColor.ink2)
                control()
                    .padding(.top, ReffiSpace.s2)
            }
            .receiptSurface(elevated: .floating)
            .padding(.horizontal, ReffiGrid.margin)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, ReffiSpace.s5)
    }

    /// 셋업 진행 게이지(49차) — 3칸 절취선. 완료·현재 칸은 `ink2`, 남은 칸은 `muted`를 `inactive`로
    /// 흐린다(§7.2 — 표시자의 "지금이 아님"은 `disabled`가 아니라 `inactive`다).
    /// 옛 `setupDots`가 지던 낭독("Setup N of M")을 그대로 옮겨 받는다 — 진행 표시가 하나로 줄어도
    /// 보조기술이 듣는 문장은 같다.
    private var setupGauge: some View {
        HStack(spacing: ReffiSpace.s2) {
            ForEach(0...setupLast, id: \.self) { i in
                Capsule(style: .continuous)
                    .fill(i <= setupPage ? ReffiColor.ink2
                                         : ReffiColor.muted.opacity(ReffiOpacity.inactive))
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, ReffiGrid.margin)
        .padding(.top, ReffiSpace.s5 + 20)     // 그래버 대신 상태바에서 ~20px 내림(옛 헤더와 같은 값)
        .padding(.bottom, ReffiSpace.s5)
        .animation(motion, value: setupPage)
        .accessibilityElement()
        .accessibilityLabel("Setup \(setupPage + 1) of \(setupLast + 1)")
    }

    // MARK: 하단 — 페이지 점 + 진행 버튼

    /// 인트로 3점 인디케이터.
    private var introDots: some View {
        HStack(spacing: 6) {
            ForEach(0...introLast, id: \.self) { i in
                Circle()
                    .fill(i == page ? ReffiColor.ink2 : ReffiColor.muted.opacity(ReffiOpacity.inactive))
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.bottom, ReffiSpace.s4)
        .animation(motion, value: page)
        .accessibilityElement()
        .accessibilityLabel("Intro \(page + 1) of \(introLast + 1)")
    }

    /// 인트로 하단 — 마지막 장에서만 "Let's start"(셋업 시트 오픈), 그 전엔 조용한 "Next".
    ///
    /// 1~2장에 전진 액션이 하나도 없던 시절엔 앱의 첫 화면에서 **유일하게 보이는 버튼이 이탈 경로(Skip)**라
    /// 위계상 탈출구가 #1이었다(감사 R3-2). 슬롯 높이(52)는 원래 예약돼 있어 레이아웃 점프 없이 들어간다.
    /// 스와이프가 여전히 주 이동 수단이므로 전진은 **조용한** 버튼이다 — 다만 tint가 `blueDark`라
    /// 중립 회색(`ink2`)인 Skip보다 먼저 읽힌다. 셋업 단계의 "Next"와 라벨도 맞춘다(한 플로우, 한 문법).
    @ViewBuilder private var bottomButton: some View {
        VStack(spacing: ReffiSpace.s1) {
            if page == introLast {
                PaperButton(title: "Let's start", seed: 2) {
                    showSetup = true
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                // 아이콘은 붙이지 않는다 — `QuietButton`은 아이콘이 라벨 **앞**이라 전진 화살표가
                // 뒤가 아닌 앞에 서서 방향 기표가 거꾸로 읽힌다(같은 파일 Skip도 아이콘 없는 호출이다).
                QuietButton(title: "Next", tint: ReffiColor.blueDark) {
                    withAnimation(motion) { page += 1 }
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 52)   // 버튼 유무와 무관하게 높이 예약 → 인트로 스와이프 시 점 위치 고정
        .padding(.horizontal, ReffiGrid.margin + ReffiSpace.s2)
        .padding(.bottom, ReffiSpace.s5)
        .animation(motion, value: page)
    }

    // MARK: 셋업 시트 — "Let's start"로 하단에서 올라오는 개인화(가구·취향) + 알림 프라이밍

    private var setupSheet: some View {
        ZStack {
            PaperCanvasBackground()
            VStack(spacing: 0) {
                // 상단 — **절취 게이지**(49차). 옛 형태는 `display` 34pt Story Script로 "Step 2"라는
                // **인덱스**를 화면 최대 글자로 세우고, 정작 이 장의 질문은 카드 안 26pt에 있었다 —
                // 홈 헤더와 같은 종류의 위계 역전이다(인덱스는 정보가 아니라 좌표다). 게다가 그 줄과
                // 하단 `setupDots`가 **같은 사실**(N번째 장)을 두 번 말해, 진행 표시가 화면에 둘이었다.
                // 둘을 한 쌍으로 은퇴시키고 진행은 게이지 하나가 진다 — 새 어휘가 아니라 이미 우리
                // 것인 절취선 문법으로 점을 다시 그린 것이다(§13.8 `ReffiRule`).
                setupGauge

                TabView(selection: $setupPage) {
                    householdPage.tag(0)
                    cuisinePage.tag(1)
                    notifyPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(motion, value: setupPage)

                setupButton
            }
        }
        // 셋업 완료 시 "Start" 도장이 위에서 쾅 찍히는 연출.
        .overlay { if stamping { startStamp } }
        .task {
            #if DEBUG
            // QA — `-onboardingSetupAutoAdvance`: 셋업 장을 자동 순환(전환 중 타이틀 캡처용).
            guard ProcessInfo.processInfo.arguments.contains("-onboardingSetupAutoAdvance") else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation(motion) { setupPage = (setupPage + 1) % (setupLast + 1) }
            }
            #endif
        }
    }

    /// "Start" 도장 슬램 — 큰 상태에서 스프링으로 내려앉으며(오버슈트) 임팩트 햅틱.
    private var startStamp: some View {
        ZStack {
            // 모달 딤(`scrim`)이 아니라 **슬램 플래시**다 — 도장이 내려앉는 0.75초만 배경을 눌러
            // 무게를 주는 조명이라, 손이 멈춰 있는 동안 서 있는 모달 딤과 역할이 갈린다(§2.7 `scrimFlash`).
            ReffiColor.scrimFlash.ignoresSafeArea()
            DDayStamp(text: String(localized: "Start"), color: ReffiColor.blueDark, size: 46,
                      relativeTo: .largeTitle)   // 화면 주인공 도장 — subheadline 곡선이면 AX에서 타이틀을 추월한다(42차)
                .scaleEffect(stampScale)
                .opacity(stampOpacity)
                // 슬램 임팩트 그림자(§6.2 예외·42차) — 앱 유일의 10% 초과 그림자라 토큰으로 부른다.
                .reffiShadowSlam()
        }
        // §7.6 — 이 순간의 의미는 "셋업 저장 완료"라 성공 완료(`.success`)다. 앱에서 유일했던
        // `.impact(.heavy)`는 매핑 표에도 예외(SpriteKit 물리 텍스처)에도 근거가 없는 오프맵이었다.
        .reffiFeedback(.success, trigger: stamping)
        .onAppear {
            // 오버슈트 = 쾅(§7.5 slam). Reduce Motion이면 도장은 연출 없이 그 자리에 찍혀 있다
            // (§7.4 — 줄이면 짧은 페이드로 갈아타는 게 아니라 애니메이션을 없앤다).
            withAnimation(ReffiMotion.gated(ReffiMotion.slam, reduce: reduceMotion)) {
                stampScale = 1; stampOpacity = 1
            }
        }
    }

    /// 셋업 완료 — 도장을 찍고 잠깐 뒤 온보딩 종료(게이트 → 메인 앱).
    private func finishWithStamp() {
        guard !stamping else { return }
        stamping = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { onFinish() }
    }

    /// 셋업 하단 3점 인디케이터.
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
    /// 연출은 **첫 방문 한 번**이다(42차) — TabView(.page)는 양방향이라 앞 페이지로 되돌아올 때마다
    /// 지연 연출을 처음부터 다시 돌리면, 두 번째 방문의 1.05초 지연이 내러티브가 아니라 로딩으로
    /// 읽힌다(§7.1 "마지막이 0.2초 넘게 늦으면 스태거가 아니라 '느리게 뜬다'"의 정신).
    @State private var played = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : hiddenScale)
            .offset(y: visible ? 0 : hiddenOffset)
            .onAppear { if active { reveal() } }   // 첫 페이지는 onChange가 없어 여기서 재생
            .onChange(of: active) { _, now in
                if now { reveal() }
                else if !played { visible = false }   // 재생 전 이탈만 리셋 — 재방문은 즉시 서 있는다
            }
    }

    private func reveal() {
        if played { visible = true; return }   // 재방문 — 지연·연출 없이 즉시
        played = true
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
        case .stamp: ReffiMotion.slam      // 오버슈트 = 쾅(§7.5) — 셋업 Start 도장과 같은 토큰
        case .riseUp: ReffiMotion.settle   // 스르륵 올라와 살짝 정착 = reflow와 같은 안착 스프링
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
        // 들고 나는 것은 §7.1 그대로다 — 오브젝트가 뜨는 것은 **진입**(ease-out dur-3),
        // 지는 것은 **이탈**(ease-in dur-1, 더 빠르게). 0.42/0.33은 어느 토큰에도 없던 길이라
        // 이 연출만 다른 시계를 쓰고 있었다. 머무는 시간(hold)은 아래 0.9초가 그대로 잡는다.
        withAnimation(ReffiMotion.enter) { shown = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            guard gen == token, active else { return }   // 최신 재생만 사라지게
            withAnimation(ReffiMotion.exit) { shown = false }
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
