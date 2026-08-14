import SwiftUI
import PhosphorSwift

/// 냉장고 — 전체 재고를 임박순으로 쌓은 "흰 영수증" 스택(§13).
/// 영수증 냉장고의 IA(스택 + 탭→상세 + 히스토리)를 그대로, 비주얼은 Main의 종이컷 언어로.
/// 카드 탭 → Wallet식으로 펼쳐져 상세(구매정보 + Ate/Tossed), 나머지는 하단에 collapse.
struct FridgeView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Namespace private var ns
    @State private var selectedID: Ingredient.ID?
    @State private var showHistory = false
    @State private var showShopping = false
    @State private var editing: Ingredient?
    /// 정렬 드롭다운 열림 — 앱 커스텀 `PaperDropdown`(스톡 Menu 대체). 세션 한정.
    @State private var sortMenuOpen = false
    /// 판정(Ate/Tossed) 햅틱 카운터 — `MainView.decisionHaptic`과 동일 트리거·weight(룰⑦: 같은 의미는 같은 햅틱).
    @State private var decisionHaptic = 0
    /// 펼친 영수증의 실측 높이 — 스크롤 뷰가 콘텐츠보다 커지지 않게 묶는 캡(0이면 미측정 = 캡 없음).
    /// 글자 크기·재료가 바뀌면 다시 측정된다.
    @State private var receiptHeight: CGFloat = 0

    /// 정렬·보기 선택 — 세션을 넘어 유지(리서치: 정렬 선택은 기억되어야 재방문 비용이 준다).
    @AppStorage("fridge.sort") private var sortRaw: String = FridgeSort.expiry.rawValue
    @AppStorage("fridge.compact") private var compact = false
    /// 요약 페이저 현재 장(리포트 0 · 장보기 1) — 세션 한정.
    @State private var summaryPage = 0
    /// 카테고리 필터(nil = 전체) — **영속화하지 않는다**. 정렬은 재방문 비용을 줄이지만 필터는
    /// "지금 이 순간 좁혀 보기"라, 다음 실행에 살아 있으면 재고가 사라진 것처럼 보인다(세션 한정).
    @State private var activeCategory: String?
    /// 직전에 본 전체 재고 id — 이번 변화에서 **새로 나타난** 재료를 가려내는 기준(필터 자동 해제).
    @State private var knownIDs: Set<Ingredient.ID> = []

    private let cardHeight: CGFloat = 170   // 길게 늘려 슬립·틸트로 생기는 측면 빈틈을 덮음
    private let overlap: CGFloat = -60   // advance(=높이+겹침)=110 유지 → 이름 안전 구간 불변
    private let cardInset: CGFloat = 18   // 페이지 마진 위 추가 인셋 — 영수증 폭 좁힘(가운데)

    private var sort: FridgeSort { FridgeSort(rawValue: sortRaw) ?? .expiry }

    /// 표시 순서 — 기본은 임박순(§8.1). 동률은 이름순으로 결정적. 필터 이전의 전체 재고다
    /// (칩 카운트·"in stock" 숫자는 항상 이 목록 기준 — 필터를 켜도 재고 총량은 변하지 않는다).
    private var sortedItems: [Ingredient] {
        switch sort {
        case .expiry:   store.sorted
        case .freshest: store.sorted.reversed()
        case .recent:   store.ingredients.sorted {
            $0.boughtDaysAgo != $1.boughtDaysAgo
                ? $0.boughtDaysAgo < $1.boughtDaysAgo : $0.daysLeft < $1.daysLeft
        }
        }
    }
    /// 실제 표시 목록 — 정렬 후 카테고리 필터 적용. 스택·간편보기·펼침 하단 스택이 모두 이 목록을 쓴다.
    private var items: [Ingredient] {
        FridgeCategoryFilter.apply(activeCategory, to: sortedItems)
    }
    /// 재고에 존재하는 카테고리 + 개수(캐논 순서) — 칩 행의 유일한 데이터 소스.
    private var categoryCounts: [FridgeCategoryFilter.Bucket] {
        FridgeCategoryFilter.buckets(of: sortedItems)
    }
    private var accent: Color { items.first?.freshness.main ?? ReffiColor.fresh }
    private var selected: Ingredient? { items.first { $0.id == selectedID } }
    private var motion: Animation? { ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion) }

    /// 영수증 틸트 — 평면(Z) 회전 ±4° 랜덤(결정적 의사난수). 위아래로 제각각 기울어 더미 느낌.
    private func tilt(_ i: Int) -> Double {
        [4, -3, 2, -4, 3, -2, 1][i % 7]
    }
    /// 가로 삐져나옴 — 좌우로 제각각 비져나옴(틸트와 위상 달라 상관 없음).
    private func slip(_ i: Int) -> CGFloat {
        [14, -12, 16, -10, 12, -16, 10][i % 7]
    }

    var body: some View {
        ZStack {
            LiquidGlassBackground(accent: accent)
            if let sel = selected {
                expanded(sel)
            } else {
                collapsed
            }
            // 하단 마스크 — 화면 끝(홈 인디케이터 포함)까지 크림으로 덮어, 떠 있는 네비 밑으로
            // 카드가 새지 않게. VStack이 화면을 꽉 채우고 safe area를 무시 → 바닥 정렬이 물리적 끝에 닿음.
            if selected == nil {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    LinearGradient(colors: [ReffiColor.canvas.opacity(0), ReffiColor.canvas],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 72)             // 위쪽: 카드가 부드럽게 사라짐
                    ReffiColor.canvas.frame(height: 70) // 아래쪽: 네비 밑은 완전한 크림(잔상 제거)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
        }
        // 정렬 드롭다운 — 트리거 칩 앵커 아래에 떠서(ScrollView 클리핑 밖, zIndex dropdown) 전체 콘텐츠 위를 덮는다.
        // 딤 없는 투명 탭 캐처가 바깥 탭을 받아 닫는다(가벼운 드롭다운, 모달 아님 — scrim 금지).
        .overlayPreferenceValue(DropdownAnchorKey.self) { anchor in
            GeometryReader { proxy in
                if sortMenuOpen, let anchor {
                    let rect = proxy[anchor]
                    let width: CGFloat = 220
                    let x = min(max(ReffiGrid.margin, rect.maxX - width),
                                max(ReffiGrid.margin, proxy.size.width - width - ReffiGrid.margin))
                    ZStack(alignment: .topLeading) {
                        Color.clear
                            .contentShape(Rectangle())
                            .ignoresSafeArea()
                            .onTapGesture { closeSortMenu() }
                        PaperDropdown(options: FridgeSort.allCases,
                                      selected: sort,
                                      label: { $0.label },
                                      seed: 5) { newSort in
                            sortRaw = newSort.rawValue
                            closeSortMenu()
                        }
                        .frame(width: width)
                        .offset(x: x, y: rect.maxY + ReffiSpace.s1)
                        .transition(.scale(scale: 0.92, anchor: .topTrailing).combined(with: .opacity))
                    }
                    .zIndex(ReffiZ.dropdown)
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: decisionHaptic)
        // 필터 안전장치 — 판정은 전부 `FridgeCategoryFilter.resolved`(순수 함수, 유닛 테스트 대상)가 하고
        // 여기선 상태만 옮긴다. 카테고리가 비었을 때뿐 아니라 **필터 밖 재료가 새로 들어왔을 때**도
        // 전체로 풀어, 추가한 결과가 화면에서 사라지는 일이 없게 한다.
        // 감지 키는 id가 아니라 `changeKey`(id + 카테고리)다 — 이름을 고치면 글리프·카테고리가 다시
        // 파생되는데 id는 그대로라, id만 보면 "필터 켠 카테고리가 비었는데 훅이 안 도는" 갇힘이 생긴다.
        // `initial: true`로 첫 표시에서 knownIDs를 채운다(그 시점 activeCategory는 nil이라 부작용 없음).
        .onChange(of: sortedItems.map(FridgeCategoryFilter.changeKey(of:)), initial: true) { _, _ in
            let current = Set(sortedItems.map(\.id))
            let added = current.subtracting(knownIDs)
            knownIDs = current
            let next = FridgeCategoryFilter.resolved(activeCategory, in: sortedItems, added: added)
            if next != activeCategory {
                withAnimation(motion) { activeCategory = next }   // 값이 실제로 바뀔 때만 — 재진입 안전
            }
        }
        // 펼쳐 둔 카드가 표시 목록 밖으로 밀려나면 선택을 접는다(유령 상세 방지).
        // 위 훅이 필터를 풀면 목록이 넓어지므로, 그 결과까지 반영된 최종 목록을 기준으로 판단한다.
        .onChange(of: items.map(\.id)) { _, ids in
            if let id = selectedID, !ids.contains(id) {
                withAnimation(motion) { selectedID = nil }
            }
        }
        // History·To buy도 Start cooking처럼 하단에서 올라와 전체를 덮는 풀스크린 커버.
        .fullScreenCover(isPresented: $showHistory) { HistoryView() }
        .fullScreenCover(isPresented: $showShopping) { ShoppingListView() }
        .sheet(item: $editing) { IngredientEditView(ingredient: $0) }
        // 자정 경과 — 탭을 띄워둔 채 날이 바뀌어도 D-day 도장·정렬이 갱신되게(메인과 동일 패턴).
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            dayTick += 1
        }
        #if DEBUG
        // 스크린샷·QA용 — `-showHistory` 런치 인자로 History 시트 바로 열기(-previewCarousel 선례).
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-showHistory") { showHistory = true }
            // `-toBuy` To buy 커버 직행. `-toBuy.search`(검색 시트 자동 오픈)는 단독 지정해도 커버가 열린다.
            if ProcessInfo.processInfo.arguments.contains("-toBuy")
                || ProcessInfo.processInfo.arguments.contains("-toBuy.search") { showShopping = true }
            // `-fridgeExpand` — 첫 재료를 바로 펼침(Ate/Tossed 버튼 QA용). 샘플 시드가 늦을 수 있어 지연 재시도.
            if ProcessInfo.processInfo.arguments.contains("-fridgeExpand") {
                selectedID = items.first?.id
                if selectedID == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { selectedID = items.first?.id }
                }
            }
            // `-fridgeExpandSolo` — 재료 1개만 남기고 펼침(하단 스택 없는 레이아웃 QA용).
            if ProcessInfo.processInfo.arguments.contains("-fridgeExpandSolo") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    items.dropFirst().forEach { store.toss($0) }
                    selectedID = items.first?.id
                }
            }
            // `-fridge.sortOpen` — 정렬 드롭다운 자동 오픈(스크린샷용).
            if ProcessInfo.processInfo.arguments.contains("-fridge.sortOpen") {
                sortMenuOpen = true
            }
            // `-fridgeEdit` — 첫 재료의 편집 시트 자동 표시(-loadSample과 함께). 시드가 늦으면 지연 재시도.
            if ProcessInfo.processInfo.arguments.contains("-fridgeEdit") {
                editing = items.first
                if editing == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { editing = items.first }
                }
            }
        }
        #endif
    }

    @State private var dayTick = 0   // 자정 리렌더 트리거

    // MARK: 접힌 스택
    private var collapsed: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReffiSpace.s5) {
                let _ = dayTick   // 자정 틱 의존 — 날이 바뀌면 이 서브트리를 재계산
                header
                summaryRow
                if categoryCounts.count > 1 { categoryFilterRow }   // 한 종류뿐이면 필터가 무의미 — 행을 아예 뺀다
                if items.isEmpty {
                    emptyState
                } else {
                    if compact {
                        compactList
                    } else {
                        VStack(spacing: overlap) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { i, ing in
                                FridgeCard(ingredient: ing, depth: i, seed: i, height: cardHeight)
                                    .matchedGeometryEffect(id: ing.id, in: ns)
                                    .zIndex(Double(i))
                                    .contentShape(Rectangle())
                                    .onTapGesture { select(ing) }
                                    .padding(.horizontal, cardInset)
                                    .rotationEffect(.degrees(tilt(i)))
                                    .offset(x: slip(i))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, ReffiGrid.margin)
            .padding(.top, ReffiSpace.s5)
            .padding(.bottom, 120)   // 끝까지 스크롤해도 마지막 카드가 네비 위로 올라오게
        }
    }

    /// 간편보기 — 틸트·겹침 없는 납작한 영수증 행. 훑어보기(스캔)에 최적화.
    private var compactList: some View {
        LazyVStack(spacing: ReffiSpace.s2) {
            ForEach(items) { ing in
                FridgeCompactRow(ingredient: ing)
                    .matchedGeometryEffect(id: ing.id, in: ns)
                    .contentShape(Rectangle())
                    .onTapGesture { select(ing) }
            }
        }
        .padding(.horizontal, cardInset)
    }

    // MARK: 펼친(Wallet) 레이아웃
    private func expanded(_ sel: Ingredient) -> some View {
        let others = items.filter { $0.id != sel.id }
        return VStack(spacing: 0) {
            doneBar
            // 영수증만 스크롤하고 판정 버튼(Ate/Tossed)은 스크롤 **밖**에 둔다 — 이 화면의 유일한 1차 액션이라
            // 어떤 글자 크기·재고 수에서도 잘리면 안 된다(§7.3). 버튼을 스크롤 콘텐츠 안에 넣으면 하단 스택(≤132)과
            // 네비 클리어런스(96)가 먹은 만큼 뷰포트가 좁아져 기본 글자 크기에서도 라벨이 잘렸다.
            //
            // "영수증 끝에서 20 아래 부착"이라는 의도는 그대로 유지한다:
            //   ① 스크롤 밖 하단 s3(12) + ② 버튼 상단 s2(8) = 20 — 간격을 스크롤 밖에 둬서
            //      영수증이 넘쳐 스크롤돼도 시각 간격 20이 변하지 않는다.
            //   ③ 스크롤 높이를 콘텐츠 높이(receiptHeight)로 묶어, 영수증이 뷰포트보다 짧아도
            //      스크롤 뷰가 남는 높이를 먹고 늘어나지 않게 한다(= 영수증과 버튼 사이가 벌어지지 않음).
            ScrollView {
                ExpandedFridgeCard(ingredient: sel, onEdit: { editing = sel })
                    .matchedGeometryEffect(id: sel.id, in: ns)
                    .contentShape(Rectangle())
                    .onTapGesture { deselect() }
                    .padding(.top, ReffiSpace.s2)
                    .padding(.horizontal, ReffiGrid.margin + cardInset)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { receiptHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)   // 콘텐츠가 다 들어가면 바운스 없음(영수증이 버튼 위로 튀지 않게)
            .frame(maxHeight: receiptHeight > 0 ? receiptHeight : CGFloat.infinity)
            .layoutPriority(1)   // 남는 높이를 아래 Spacer와 반씩 나눠 갖지 않게 — 캡 안에서 먼저 배분
            .padding(.bottom, ReffiSpace.s3)
            outcomeButtons(sel)
                .padding(.top, ReffiSpace.s2)
            Spacer(minLength: ReffiSpace.s2)
            if !others.isEmpty {
                bottomStack(others)
            } else {
                // 마지막 재료 — 하단 스택이 없으면 그 몫의 네비 클리어런스(96)도 사라져
                // Ate/Tossed 버튼이 떠 있는 네비 밑에 깔린다. 스택 자리만큼 바닥을 비워둔다.
                Color.clear.frame(height: 96)
            }
        }
    }

    private var doneBar: some View {
        HStack {
            Spacer()
            PaperCloseButton(action: deselect)   // 룰① — 종이 X의 단일 공급원(시각40/히트44/paper)
        }
        .padding(.horizontal, ReffiGrid.margin)
        .padding(.top, ReffiSpace.s3)
    }

    /// 처리 — 먹음/버림. store에서 제거 + 카운트 후 복귀.
    /// 스크롤 밖에 도킹되는 1차 액션 — 높이를 고정하지 마라(큰 글자에서 라벨이 잘린다). 블롭 88 ≥ 44(§7.3).
    private func outcomeButtons(_ sel: Ingredient) -> some View {
        // Main의 결정 오버레이와 동일한 종이컷 아이콘 버튼(기본 88 + s6 간격).
        HStack(spacing: ReffiSpace.s6) {
            PaperIconButton(icon: ReffiIcon.toss, label: "Tossed", intent: .soft, seed: 0) {
                remove(sel, ate: false)
            }
            PaperIconButton(icon: ReffiIcon.ate, label: "Ate", intent: .primary, seed: 1) {
                remove(sel, ate: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// 하단 collapse 스택 — 나머지 영수증을 띠로 겹침. 탭 시 그 카드로 전환.
    private func bottomStack(_ others: [Ingredient]) -> some View {
        // 112 = 종전 132에서 20 양보 — 펼침 화면의 주인공은 영수증이라, 기본 글자 크기에서
        // 하단 톱니(ReceiptShape 절취선)까지 온전히 보이도록 배경 스택의 몫을 줄였다.
        let maxVisible: CGFloat = 112
        let count = max(1, others.count)
        let peek = min(26, (maxVisible - 48) / CGFloat(max(1, count - 1)))
        let visible = CGFloat(count - 1) * peek + 48
        return VStack(spacing: -(cardHeight - peek)) {
            ForEach(Array(others.enumerated()), id: \.element.id) { i, ing in
                FridgeCard(ingredient: ing, depth: i, seed: ing.daysLeft, height: cardHeight)
                    .matchedGeometryEffect(id: ing.id, in: ns)
                    .zIndex(Double(i))
                    .contentShape(Rectangle())
                    .onTapGesture { select(ing) }
            }
        }
        .frame(height: visible, alignment: .top)
        .clipShape(Rectangle())
        .contentShape(Rectangle())
        .padding(.horizontal, ReffiGrid.margin + cardInset)
        .padding(.bottom, 96)
        // 위로 스와이프(또는 탭) → 냉장고 스택으로 촤라락 복귀.
        .gesture(
            DragGesture(minimumDistance: 16)
                .onEnded { v in if v.translation.height < -36 { deselect() } }
        )
    }

    // MARK: 헤더 — 서브라인 오른쪽 끝에 정렬·보기 통합 메뉴(별도 행 제거, 수직 적층 최소화)
    private var header: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s1) {
            Text("Fridge").reffiType(.display).foregroundStyle(ReffiColor.ink)
            HStack(spacing: ReffiSpace.s2) {
                // Ate/Tossed 숫자는 리포트와 중복이라 뺐다 — 한 번에 보이는 정보 최소화.
                Text("\(sortedItems.count) in stock")
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                Spacer(minLength: ReffiSpace.s2)
                sortMenu
                viewToggle
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 정렬 칩 — 현재 정렬 라벨을 상시 노출하는 종이컷 칩(§13.5). 비주얼은 그대로, 탭하면 스톡 Menu 대신
    /// 앱 커스텀 `PaperDropdown`을 토글한다. 칩 바운드를 앵커로 올려 드롭다운을 바로 아래에 띄운다.
    private var sortMenu: some View {
        Button { toggleSortMenu() } label: {
            HStack(spacing: ReffiSpace.s1) {
                ReffiIcon.sort.reffi(12, .bold)
                Text(sort.label)
                    .font(ReffiTextRole.caption.font)
                    .tracking(ReffiTextRole.caption.tracking)
            }
            .foregroundStyle(ReffiColor.ink)
            .padding(.horizontal, ReffiSpace.s3)
            .padding(.vertical, ReffiSpace.s2)
            .background {
                let s = PaperRect(cornerRadius: ReffiRadius.sm, seed: 5)
                s.fill(ReffiColor.paper).paperEdge(s)
            }
            .frame(minHeight: 44)   // §7.3 터치 타깃
            .contentShape(Rectangle())
            .anchorPreference(key: DropdownAnchorKey.self, value: .bounds) { $0 }
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel("Sort: \(sort.label)")
    }

    // MARK: 카테고리 필터 칩 행 — 정렬(순서)과 직교하는 "좁혀 보기". 정렬 칩과 같은 종이 문법이되,
    // 선택 상태는 면 반전(ink 면 + onInk 글자)으로 한눈에 구분한다(드롭다운의 체크 문법은 팝업 전용).
    private var categoryFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ReffiSpace.s2) {
                categoryChip(name: String(localized: "All"), count: sortedItems.count,
                             on: activeCategory == nil, seed: 9) { setCategory(nil) }
                ForEach(categoryCounts, id: \.category) { bucket in
                    categoryChip(name: FridgeCategoryFilter.displayName(bucket.category),
                                 count: bucket.count,
                                 on: activeCategory == bucket.category,
                                 seed: FridgeCategoryFilter.chipSeed(bucket.category)) { setCategory(bucket.category) }
                }
            }
            // 스크롤 콘텐츠 자체에 마진을 줘 첫/마지막 칩이 화면 끝에 붙지 않게. 세로 패딩은
            // 종이 프레스(스케일)·헤어라인이 스크롤 클립에 잘리지 않는 여유.
            .padding(.horizontal, ReffiGrid.margin)
            .padding(.vertical, 3)
        }
        .scrollClipDisabled()
        .padding(.horizontal, -ReffiGrid.margin)   // 상위 페이지 마진 상쇄 — 행만 가장자리까지 흐른다
        .padding(.vertical, -3)
    }

    /// 필터 칩 한 개 — 라벨 + 개수. 히트 44(§7.3), 선택은 면 반전 + `.isSelected` 트레잇.
    private func categoryChip(name: String, count: Int, on: Bool, seed: Int,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: ReffiSpace.s1) {
                Text(name)
                    .font(ReffiTextRole.caption.font)
                    .tracking(ReffiTextRole.caption.tracking)
                    .foregroundStyle(on ? ReffiColor.onInk : ReffiColor.ink)
                Text(count.formatted())
                    .font(.reffiNum(12, relativeTo: .caption))
                    .foregroundStyle(on ? ReffiColor.onInk.opacity(0.72) : ReffiColor.ink2)
            }
            .lineLimit(1)
            .padding(.horizontal, ReffiSpace.s3)
            .padding(.vertical, ReffiSpace.s2)
            .background {
                let s = PaperRect(cornerRadius: ReffiRadius.xs, seed: seed)
                if on {
                    s.fill(ReffiColor.ink)   // 선택 = 면 반전(윤곽선 칩들 사이에서 유일한 채워진 면)
                } else {
                    s.fill(ReffiColor.paper).paperEdge(s)
                }
            }
            .frame(minHeight: 44)   // §7.3 터치 타깃
            .contentShape(Rectangle())
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel(String(localized: "Filter: \(name)"))
        .accessibilityValue(count.formatted())
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    /// 칩 탭 — 같은 칩 재탭은 해제(= 전체). 목록이 통째로 갈리므로 선택된 상세는 접는다.
    private func setCategory(_ category: String?) {
        withAnimation(motion) {
            activeCategory = (category == activeCategory) ? nil : category
            selectedID = nil
        }
    }

    /// 보기 전환 — 메뉴에 숨기지 않는 원탭 토글(사진·파일 앱 문법). 아이콘은 "누르면 바뀔 모습".
    private var viewToggle: some View {
        Button {
            withAnimation(motion) { compact.toggle() }
        } label: {
            (compact ? ReffiIcon.stackView : ReffiIcon.compactView).reffi(14, .bold)
                .foregroundStyle(ReffiColor.ink)
                .padding(ReffiSpace.s2 + 2)
                .background {
                    let s = PaperRect(cornerRadius: ReffiRadius.sm, seed: 6)
                    s.fill(ReffiColor.paper).paperEdge(s)
                }
                .frame(minWidth: 44, minHeight: 44)   // §7.3
                .contentShape(Rectangle())
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel(compact ? "Switch to stack view" : "Switch to simple view")
    }

    // MARK: 요약 페이저 — 한 번에 카드 한 장(점진적 공개), 점 인디케이터로 다음 장 예고.
    // 순서 = 사용 빈도: 장보기(할 일, 수시) 먼저 → 리포트(회고, 가끔)는 도장 강조 + 한 스와이프.
    private var summaryRow: some View {
        VStack(spacing: ReffiSpace.s2) {
            TabView(selection: $summaryPage) {
                Button { showShopping = true } label: {
                    summaryCard(icon: ReffiIcon.receipt, title: "To buy",
                                value: "\(store.toBuy.count)", tint: ReffiColor.blueDark, seed: 8)
                }
                .buttonStyle(.paperPress)
                .accessibilityLabel("Shopping list, \(store.toBuy.count) items")
                .padding(.horizontal, cardInset)
                .tag(0)

                Button { showHistory = true } label: {
                    summaryCard(icon: ReffiIcon.report, title: "No-waste report",
                                value: "\(store.wasteRate)%", tint: rateColor, seed: 7)
                }
                .buttonStyle(.paperPress)
                .accessibilityLabel("Open no-waste report, \(store.wasteRate) percent wasted")
                .padding(.horizontal, cardInset)
                .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 72)   // 종이컷 버튼 minHeight 56 + 그림자·프레스 여유

            HStack(spacing: 6) {
                ForEach(0..<2, id: \.self) { i in
                    Circle()
                        .fill(i == summaryPage ? ReffiColor.ink2 : ReffiColor.muted.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }
            .accessibilityHidden(true)
        }
    }

    /// 요약 카드 = 종이컷 버튼(§13.5) — 메인 CTA(PaperButton)와 같은 8각형 셰입 + 종이 질감 + 그림자.
    /// 색은 크림 위 sub 면 + ink 글자(§2.6), 아이콘·값만 의미색(To buy=blue, 리포트=낭비율색).
    private func summaryCard(icon: Ph, title: LocalizedStringKey, value: String,
                             tint: Color, seed: Int) -> some View {
        HStack(spacing: ReffiSpace.s2) {
            icon.reffi(17, .bold).foregroundStyle(tint)
            Text(title)
                .reffiType(.checklistItem)
                .foregroundStyle(ReffiColor.ink)
                .lineLimit(1).fixedSize()   // 제목은 절대 말줄임하지 않는다
            Spacer(minLength: ReffiSpace.s1)
            Text(value)
                .font(.reffiNum(17, relativeTo: .body)).foregroundStyle(tint)
                .lineLimit(1)
            ReffiIcon.chevron.reffi(11, .bold).foregroundStyle(ReffiColor.ink2)
        }
        .padding(.horizontal, ReffiSpace.s5)
        .frame(maxWidth: .infinity, minHeight: 56)
        .contentShape(Rectangle())
        .background {
            let s = PaperCutRect(seed: seed)                            // 아이콘 버튼(9각)·CTA와 같은 8각형
            s.fill(ReffiColor.paper)                                    // 밝은 종이 면(sub는 크림 위에서 칙칙)
                .overlay(PaperGrain(seed: UInt64(seed) &+ 11, strength: 0.7).clipShape(s))  // 옅은 질감
                .paperEdge(s, tint: ReffiColor.ink.opacity(0.06), width: 1)
                .compositingGroup()
                .reffiShadow1()
        }
    }

    /// 낭비율 색 — HistoryView와 동일 임계값(색=정보, §1). 캔버스 위라 dark 변형(§2.6).
    private var rateColor: Color {
        switch store.wasteRate {
        case ...10: ReffiColor.freshDark
        case ...30: ReffiColor.soonDark
        default:    ReffiColor.urgentDark
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            Text("Nothing here yet").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
            Text("Add ingredients and they’ll stack up here.")
                .reffiType(.body).foregroundStyle(ReffiColor.ink2)
        }
        .padding(ReffiSpace.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            let s = PaperRect(cornerRadius: ReffiRadius.lg, seed: 3)
            s.fill(ReffiColor.sub).paperEdge(s)
        }
    }

    // MARK: 정렬 드롭다운 — 진입 .pop / 이탈 .exit(§7.5), reduced-motion 존중.
    private func toggleSortMenu() { sortMenuOpen ? closeSortMenu() : openSortMenu() }
    private func openSortMenu() {
        withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) { sortMenuOpen = true }
    }
    private func closeSortMenu() {
        withAnimation(ReffiMotion.gated(ReffiMotion.exit, reduce: reduceMotion)) { sortMenuOpen = false }
    }

    // MARK: 액션
    private func select(_ ing: Ingredient) { withAnimation(motion) { selectedID = ing.id } }
    private func deselect() { withAnimation(motion) { selectedID = nil } }
    private func remove(_ ing: Ingredient, ate: Bool) {
        decisionHaptic += 1
        withAnimation(motion) {
            selectedID = nil
            if ate { store.eat(ing) } else { store.toss(ing) }
        }
    }
}

/// 냉장고 카테고리 필터의 순수 로직 — 뷰 상태 없이 목록만 다룬다(유닛 테스트 가능).
///
/// 그룹 키는 저장된 `ingredient.category`가 아니라 **글리프 파생 라벨**(`FoodGlyph.categoryLabel`)이다.
/// 저장 카테고리는 레거시·스캔 경로에서 "Meat · Beef" 같은 자유 문자열이 섞여 들어와 칩이 파편화되고
/// 로컬라이즈 키도 없다. 글리프 라벨은 항상 캐논 10종이라 칩 집합이 안정적이고 전부 번역돼 있다
/// (History 도넛 그룹핑도 같은 키를 쓴다 — 한 화면 두 기준을 만들지 않는다).
enum FridgeCategoryFilter {
    /// 칩 고정 순서 — 사용 빈도(신선식품 → 저장식품 → 기타). 재고에 있는 것만 이 순서로 노출된다.
    /// 정본은 `FoodGlyph.categoryOrder` 하나 — To buy 검색 시트의 픽커 섹션도 같은 상수를 본다.
    static let order = FoodGlyph.categoryOrder

    /// 칩 한 개분 — 캐논 카테고리 키 + 재고 개수.
    struct Bucket: Equatable {
        let category: String
        let count: Int
    }

    /// 재료의 필터 키(캐논 영문).
    static func key(of ingredient: Ingredient) -> String { ingredient.glyph.categoryLabel }

    /// 뷰의 자동 해제 훅이 쓰는 **변화 감지 키** — id만으로는 부족하다. 이름을 고치면
    /// `FridgeStore.update`가 글리프와 카테고리를 다시 파생시키는데 id는 그대로라, id 배열만 보는
    /// 훅은 아예 돌지 않는다. 그러면 필터가 방금 비워진 카테고리를 계속 가리켜 재고가 가득한데도
    /// 빈 상태 화면에 갇힌다(칩 행도 그 카테고리를 잃어 선택 표시가 사라진다). 카테고리를 키에 섞어
    /// 재료의 **소속이 바뀌는 것도 변화로** 잡는다.
    static func changeKey(of ingredient: Ingredient) -> String {
        "\(ingredient.id.uuidString)|\(key(of: ingredient))"
    }

    /// 재고에 실제로 존재하는 카테고리만, 고정 순서로 + 개수. 목록에 없는 카테고리 칩은 만들지 않는다.
    static func buckets(of items: [Ingredient]) -> [Bucket] {
        var counts: [String: Int] = [:]
        for item in items { counts[key(of: item), default: 0] += 1 }
        return order.compactMap { c in counts[c].map { Bucket(category: c, count: $0) } }
    }

    /// 필터 적용 — nil(전체)이면 입력 순서 그대로. 정렬은 호출부에서 이미 끝난 상태를 전제.
    static func apply(_ category: String?, to items: [Ingredient]) -> [Ingredient] {
        guard let category else { return items }
        return items.filter { key(of: $0) == category }
    }

    /// 재고 변화 후 필터가 어떤 값이어야 하는지 — **뷰의 자동 해제가 그대로 호출하는 유일한 규칙**이다
    /// (뷰에 같은 판단을 다시 적으면 테스트가 실물과 어긋난다). 전체(nil)로 풀어야 하는 경우 둘:
    ///   ① 해당 카테고리 재고가 하나도 안 남음 — 마지막 한 개를 먹거나 버렸을 때 빈 화면에 가두지 않는다.
    ///   ② **새로 들어온 재료가 전부 필터 밖** — 필터를 켠 채 재료를 추가하면 화면에 아무 변화가 없어
    ///      "추가가 안 됐다"로 읽힌다. 추가 결과는 언제나 눈에 보여야 한다.
    /// - Parameters:
    ///   - category: 현재 활성 필터(nil = 전체).
    ///   - items: 필터 **이전**의 전체 표시 목록.
    ///   - added: 이번 변화에서 새로 나타난 재료 id. 비어 있으면 ②는 판정하지 않는다.
    static func resolved(_ category: String?, in items: [Ingredient],
                         added: Set<Ingredient.ID> = []) -> String? {
        guard let category, items.contains(where: { key(of: $0) == category }) else { return nil }
        guard added.isEmpty
                || items.contains(where: { added.contains($0.id) && key(of: $0) == category })
        else { return nil }
        return category
    }

    /// 칩 종이 셰이프 시드 — **카테고리 키**에서 유도한다(재고 개수가 아니라). 개수를 쓰면 먹거나
    /// 추가할 때마다 손으로 오린 윤곽이 다시 랜덤해지고(§13.1: 시드가 같으면 항상 같은 모양),
    /// 개수가 같은 칩끼리는 똑같이 생긴다. 20 오프셋은 같은 화면의 다른 종이 면
    /// (빈 상태 3 · 정렬 칩 5 · 보기 토글 6 · 요약 카드 7/8 · All 칩 9)과 겹치지 않기 위한 것.
    static func chipSeed(_ category: String) -> Int {
        20 + (order.firstIndex(of: category) ?? order.count)
    }

    /// 표시명 — 저장·비교는 영문 캐논, 표시만 로컬라이즈(카테고리 키는 이미 카탈로그에 등록돼 있다).
    static func displayName(_ category: String) -> String {
        String(localized: String.LocalizationValue(category))
    }
}

/// 냉장고 정렬 기준 — rawValue는 AppStorage 영속화용 안정 키.
enum FridgeSort: String, CaseIterable, Identifiable {
    case expiry    // 임박순(기본) — 위에서부터 먹어야 할 순서(§8.1)
    case freshest  // 신선한 순 — 여유 있는 재료부터
    case recent    // 최근 등록순 — 방금 사 온 것부터

    var id: String { rawValue }
    /// 표시 라벨 — 저장값은 영문 식별자 그대로, 표시만 로컬라이즈.
    var label: String {
        switch self {
        case .expiry:   String(localized: "Expiring first")
        case .freshest: String(localized: "Freshest first")
        case .recent:   String(localized: "Recently added")
        }
    }
}

/// 간편보기 행 — 겹침 없는 납작한 흰 영수증 조각. 실루엣 + 이름 + 수량 + D-day.
struct FridgeCompactRow: View {
    let ingredient: Ingredient

    var body: some View {
        let f = ingredient.freshness
        return HStack(spacing: ReffiSpace.s3) {
            PaperSilhouette(glyph: ingredient.glyph, fresh: f)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(ingredient.name)
                    .reffiType(.checklistItem)
                    .foregroundStyle(ReffiColor.ink).lineLimit(1)
                Text(verbatim: ingredient.quantityText)
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2).lineLimit(1)
            }
            Spacer(minLength: ReffiSpace.s2)
            if ingredient.isFrozen {
                DDayStamp(text: String(localized: "FROZEN"), color: ReffiColor.blueDark, size: 10)
            }
            Text(ingredient.dDayText)
                .font(.reffiNum(15, relativeTo: .subheadline))
                .foregroundStyle(f.dark)   // §2.6 캔버스/종이 위 색-텍스트는 dark
        }
        .padding(.horizontal, ReffiSpace.s4)
        .padding(.vertical, ReffiSpace.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            let s = PaperRect(cornerRadius: ReffiRadius.md, seed: ingredient.daysLeft &+ 3)
            s.fill(ReffiColor.receipt).paperEdge(s, tint: ReffiColor.ink.opacity(0.06))
        }
        .reffiShadowCardCompact()   // 한 화면에 여러 장 반복되는 납작한 행
        .accessibilityElement(children: .combine)
    }
}

/// 흰 영수증 카드 한 장 — ReceiptShape + 종이질감 + 음식 실루엣 + 이름. 색은 Due date에만(임박 신호).
struct FridgeCard: View {
    let ingredient: Ingredient
    var depth: Int = 0
    var seed: Int = 0
    var height: CGFloat = 128

    private let toothH: CGFloat = ReffiTooth.card

    var body: some View {
        let f = ingredient.freshness
        let shape = ReceiptShape(tooth: toothH)
        let paper = ReffiColor.receipt   // 흰 영수증

        return VStack(alignment: .leading, spacing: ReffiSpace.s1) {
            // 상단 행 — 카테고리(좌) / [FROZEN] + D-day 도장(우 상단 코너).
            // 냉동은 스택을 쪼개지 않고(영수증 더미 메타포 유지) 도장 하나로 구분한다(§13).
            HStack(alignment: .top, spacing: ReffiSpace.s2) {
                Text(LocalizedStringKey(ingredient.category))   // 카테고리는 영문 캐논 저장 — 표시만 로컬라이즈
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2).lineLimit(1)
                Spacer(minLength: ReffiSpace.s3)
                if ingredient.isFrozen {
                    DDayStamp(text: String(localized: "FROZEN"), color: ReffiColor.blueDark, size: 12)
                }
                DDayStamp(text: ingredient.dDayText, color: f.dark, size: 17)
            }
            HStack(spacing: ReffiSpace.s3) {
                PaperSilhouette(glyph: ingredient.glyph, fresh: f)
                    .frame(width: 46, height: 46)
                Text(ingredient.name)
                    .reffiType(.subhead).foregroundStyle(ReffiColor.ink).lineLimit(1)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, ReffiSpace.s5)
        .padding(.top, ReffiSpace.s4 + toothH)
        .padding(.bottom, toothH)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(height: height)
        .background(paper, in: shape)
        .paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
        .reffiShadowCardCompact()   // 겹쳐 쌓이는 카드라 얕은 단
    }
}

/// 펼친 상세 — 흰 영수증 한 장에 큰 일러스트 + 구매 정보(영수증 명세). 색은 Due date에만.
struct ExpandedFridgeCard: View {
    let ingredient: Ingredient
    var onEdit: () -> Void = {}
    private let toothH: CGFloat = ReffiTooth.card

    /// 영수증 번호 — 이름에서 유도(장식, 안정적).
    private var receiptNo: String {
        let s = abs(ingredient.name.unicodeScalars.reduce(7) { $0 &* 31 &+ Int($1.value) })
        return String(format: "No. %04d", s % 10000)
    }

    var body: some View {
        let f = ingredient.freshness
        let shape = ReceiptShape(tooth: toothH)
        let paper = ReffiColor.receipt   // 흰 영수증

        return VStack(alignment: .leading, spacing: 0) {
            // 헤더 — 큰 일러스트 + (카테고리·편집) / (이름·Due date)
            HStack(spacing: ReffiSpace.s4) {
                PaperSilhouette(glyph: ingredient.glyph, fresh: f)
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(LocalizedStringKey(ingredient.category))
                            .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                        Spacer()
                        Button(action: onEdit) {
                            ReffiIcon.manual.reffi(16, .bold)
                                .foregroundStyle(ReffiColor.ink2)
                                .frame(minWidth: 44, minHeight: 44)   // §7.3 최소 터치 타깃
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.paperPress)
                        .accessibilityLabel("Edit")
                    }
                    HStack(alignment: .center, spacing: ReffiSpace.s2) {
                        Text(ingredient.name).reffiType(.heading).foregroundStyle(ReffiColor.ink)
                        Spacer()
                        if ingredient.isFrozen {
                            DDayStamp(text: String(localized: "FROZEN"), color: ReffiColor.blueDark, size: 11)
                        }
                        DDayStamp(text: ingredient.dDayText, color: f.dark, size: 14)
                    }
                }
            }
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.top, ReffiSpace.s4 + toothH)
            .padding(.bottom, ReffiSpace.s3)

            dashRule
            VStack(spacing: 0) {
                row("Purchased", ingredient.purchasedText)
                row("Where", ingredient.placeText)
                row("Quantity", ingredient.quantityText)
                row("Expires", "\(ingredient.expiresText) · \(ingredient.dDayText)", valueColor: f.dark)
                row("Storage", ingredient.storage.label)
            }
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s2)

            dashRule
            HStack {
                Text(verbatim: "REFFI · KEEP IT FRESH")
                    .reffiType(.monoEyebrow)
                    .foregroundStyle(ReffiColor.muted)
                Spacer()
                Text(receiptNo)
                    .font(.reffiNum(11, relativeTo: .caption2)).foregroundStyle(ReffiColor.muted)
            }
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.top, ReffiSpace.s3)
            .padding(.bottom, ReffiSpace.s2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, toothH)
        .background(paper, in: shape)
        .paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
        .reffiShadowCard()
    }

    private func row(_ label: LocalizedStringKey, _ value: String, valueColor: Color = ReffiColor.ink) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                Spacer(minLength: ReffiSpace.s4)
                Text(value)
                    .font(.reffiNum(15, relativeTo: .subheadline))
                    .foregroundStyle(valueColor)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, ReffiSpace.s2 + 2)
        }
    }

    private var dashRule: some View {
        HLine().stroke(ReffiColor.ink.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(height: 1)
            .padding(.horizontal, ReffiSpace.s5)
    }
}

