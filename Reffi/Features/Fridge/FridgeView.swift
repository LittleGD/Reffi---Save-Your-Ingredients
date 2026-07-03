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

    /// 정렬·보기 선택 — 세션을 넘어 유지(리서치: 정렬 선택은 기억되어야 재방문 비용이 준다).
    @AppStorage("fridge.sort") private var sortRaw: String = FridgeSort.expiry.rawValue
    @AppStorage("fridge.compact") private var compact = false
    /// 요약 페이저 현재 장(리포트 0 · 장보기 1) — 세션 한정.
    @State private var summaryPage = 0

    private let cardHeight: CGFloat = 170   // 길게 늘려 슬립·틸트로 생기는 측면 빈틈을 덮음
    private let overlap: CGFloat = -60   // advance(=높이+겹침)=110 유지 → 이름 안전 구간 불변
    private let cardInset: CGFloat = 18   // 페이지 마진 위 추가 인셋 — 영수증 폭 좁힘(가운데)

    private var sort: FridgeSort { FridgeSort(rawValue: sortRaw) ?? .expiry }

    /// 표시 순서 — 기본은 임박순(§8.1). 동률은 이름순으로 결정적.
    private var items: [Ingredient] {
        switch sort {
        case .expiry:   store.sorted
        case .freshest: store.sorted.reversed()
        case .recent:   store.ingredients.sorted {
            $0.boughtDaysAgo != $1.boughtDaysAgo
                ? $0.boughtDaysAgo < $1.boughtDaysAgo : $0.daysLeft < $1.daysLeft
        }
        }
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
        .sheet(isPresented: $showHistory) { HistoryView() }
        .sheet(isPresented: $showShopping) { ShoppingListView() }
        .sheet(item: $editing) { IngredientEditView(ingredient: $0) }
        #if DEBUG
        // 스크린샷·QA용 — `-showHistory` 런치 인자로 History 시트 바로 열기(-previewCarousel 선례).
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-showHistory") { showHistory = true }
        }
        #endif
    }

    // MARK: 접힌 스택
    private var collapsed: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReffiSpace.s5) {
                header
                summaryRow
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
            ScrollView {
                ExpandedFridgeCard(ingredient: sel, onEdit: { editing = sel })
                    .matchedGeometryEffect(id: sel.id, in: ns)
                    .contentShape(Rectangle())
                    .onTapGesture { deselect() }
                    .padding(.horizontal, ReffiGrid.margin + cardInset)
                    .padding(.top, ReffiSpace.s2)
                    .padding(.bottom, ReffiSpace.s3)
            }
            outcomeButtons(sel)
                .padding(.top, ReffiSpace.s2)
            Spacer(minLength: ReffiSpace.s2)
            if !others.isEmpty { bottomStack(others) }
        }
    }

    private var doneBar: some View {
        HStack {
            Spacer()
            Button { deselect() } label: {
                ReffiIcon.close.reffi(15, .bold)
                    .foregroundStyle(ReffiColor.ink)
                    .frame(width: 40, height: 40)
                    .background {
                        let s = PaperRect(cornerRadius: ReffiRadius.md, seed: 4)
                        s.fill(ReffiColor.oklch(0.99, 0.006, 90)).paperEdge(s)
                    }
                    .reffiShadow1()
            }
            .buttonStyle(.paperPress)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, ReffiGrid.margin)
        .padding(.top, ReffiSpace.s3)
    }

    /// 처리 — 먹음/버림. store에서 제거 + 카운트 후 복귀.
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
        let maxVisible: CGFloat = 132
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
                Text("\(items.count) in stock")
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                Spacer(minLength: ReffiSpace.s2)
                sortMenu
                viewToggle
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 정렬 메뉴 — 체크 그룹 하나만(모호함 제거). 라벨은 현재 정렬을 상시 노출. 종이컷 칩(§13.5).
    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $sortRaw) {
                ForEach(FridgeSort.allCases) { s in
                    Text(s.label).tag(s.rawValue)
                }
            }
        } label: {
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
        }
        .accessibilityLabel("Sort: \(sort.label)")
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
                                value: "\(store.toBuy.count)", tint: ReffiColor.blueDark,
                                stamped: false, seed: 8)
                }
                .buttonStyle(.paperPress)
                .accessibilityLabel("Shopping list, \(store.toBuy.count) items")
                .padding(.horizontal, cardInset)
                .tag(0)

                Button { showHistory = true } label: {
                    summaryCard(icon: ReffiIcon.report, title: "No-waste report",
                                value: "\(store.wasteRate)%", tint: rateColor, stamped: true, seed: 7)
                }
                .buttonStyle(.paperPress)
                .accessibilityLabel("Open no-waste report, \(store.wasteRate) percent wasted")
                .padding(.horizontal, cardInset)
                .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 62)

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

    /// 요약 카드 공통 해부(아이콘·제목·값·셰브론) — 리포트만 도장 외곽선으로 격리(유일한 강조).
    private func summaryCard(icon: Ph, title: String, value: String,
                             tint: Color, stamped: Bool, seed: Int) -> some View {
        HStack(spacing: ReffiSpace.s1 + 2) {
            icon.reffi(16, .bold).foregroundStyle(tint)
            Text(title)
                .font(.custom("Pretendard-SemiBold", size: 15, relativeTo: .subheadline))
                .foregroundStyle(ReffiColor.ink)
                .lineLimit(1).fixedSize()   // 제목은 절대 말줄임하지 않는다(우선 확보)
            Spacer(minLength: ReffiSpace.s1)
            Text(value)
                .font(.reffiNum(16, relativeTo: .body)).foregroundStyle(tint)
                .lineLimit(1).minimumScaleFactor(0.8)
            ReffiIcon.chevron.reffi(10, .bold).foregroundStyle(ReffiColor.muted)
        }
        .padding(.horizontal, ReffiSpace.s3)
        .frame(minHeight: 52)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .background {
            if stamped {
                let s = RoundedRectangle(cornerRadius: ReffiRadius.lg, style: .continuous)
                ZStack {
                    s.strokeBorder(tint.opacity(0.9), lineWidth: 2)                 // 도장 이중선
                    s.inset(by: 3.5).strokeBorder(tint.opacity(0.5), lineWidth: 1)
                }
            } else {
                let s = PaperRect(cornerRadius: ReffiRadius.lg, seed: seed)
                s.fill(ReffiColor.paper).paperEdge(s, tint: ReffiColor.ink.opacity(0.06))
            }
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

    // MARK: 액션
    private func select(_ ing: Ingredient) { withAnimation(motion) { selectedID = ing.id } }
    private func deselect() { withAnimation(motion) { selectedID = nil } }
    private func remove(_ ing: Ingredient, ate: Bool) {
        withAnimation(motion) {
            selectedID = nil
            if ate { store.eat(ing) } else { store.toss(ing) }
        }
    }
}

/// 냉장고 정렬 기준 — rawValue는 AppStorage 영속화용 안정 키.
enum FridgeSort: String, CaseIterable, Identifiable {
    case expiry    // 임박순(기본) — 위에서부터 먹어야 할 순서(§8.1)
    case freshest  // 신선한 순 — 여유 있는 재료부터
    case recent    // 최근 등록순 — 방금 사 온 것부터

    var id: String { rawValue }
    var label: String {
        switch self {
        case .expiry:   "Expiring first"
        case .freshest: "Freshest first"
        case .recent:   "Recently added"
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
                    .font(.custom("Pretendard-SemiBold", size: 16, relativeTo: .body))
                    .foregroundStyle(ReffiColor.ink).lineLimit(1)
                Text(ingredient.amount)
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2).lineLimit(1)
            }
            Spacer(minLength: ReffiSpace.s2)
            Text(ingredient.dDayText)
                .font(.reffiNum(15, relativeTo: .subheadline))
                .foregroundStyle(f.dark)   // §2.6 캔버스/종이 위 색-텍스트는 dark
        }
        .padding(.horizontal, ReffiSpace.s4)
        .padding(.vertical, ReffiSpace.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            let s = PaperRect(cornerRadius: ReffiRadius.md, seed: ingredient.daysLeft &+ 3)
            s.fill(ReffiColor.oklch(0.985, 0.004, 90)).paperEdge(s, tint: ReffiColor.ink.opacity(0.06))
        }
        .shadow(color: ReffiColor.ink.opacity(0.05), radius: 3, x: 0, y: 1)
        .accessibilityElement(children: .combine)
    }
}

/// D-day 도장 — 기울어진 둥근 사각 외곽선 + 글자(영수증 "START" 스탬프 느낌, §13). 색은 신선도색.
struct DDayStamp: View {
    let text: String
    let color: Color
    var size: CGFloat = 13

    var body: some View {
        Text(text.uppercased())
            .font(.custom("Pretendard-Bold", size: size, relativeTo: .subheadline))
            .tracking(size * 0.06)
            .foregroundStyle(color)
            .padding(.horizontal, size * 0.7)
            .padding(.vertical, size * 0.32)
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.46, style: .continuous)
                    .stroke(color, lineWidth: max(1.6, size * 0.12))
            }
            .rotationEffect(.degrees(-7))
            .accessibilityLabel(text)
    }
}

/// 흰 영수증 카드 한 장 — ReceiptShape + 종이질감 + 음식 실루엣 + 이름. 색은 Due date에만(임박 신호).
struct FridgeCard: View {
    let ingredient: Ingredient
    var depth: Int = 0
    var seed: Int = 0
    var height: CGFloat = 128

    private let toothH: CGFloat = 7

    var body: some View {
        let f = ingredient.freshness
        let shape = ReceiptShape(tooth: toothH)
        let paper = ReffiColor.oklch(0.985, 0.004, 90)   // 흰 영수증

        return VStack(alignment: .leading, spacing: ReffiSpace.s1) {
            // 상단 행 — 카테고리(좌) / D-day 도장(우 상단 코너).
            HStack(alignment: .top) {
                Text(ingredient.category)
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2).lineLimit(1)
                Spacer(minLength: ReffiSpace.s3)
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
        .shadow(color: ReffiColor.ink.opacity(0.06), radius: 4, x: 0, y: 2)   // 약한 드롭섀도
    }
}

/// 펼친 상세 — 흰 영수증 한 장에 큰 일러스트 + 구매 정보(영수증 명세). 색은 Due date에만.
struct ExpandedFridgeCard: View {
    let ingredient: Ingredient
    var onEdit: () -> Void = {}
    private let toothH: CGFloat = 7

    /// 영수증 번호 — 이름에서 유도(장식, 안정적).
    private var receiptNo: String {
        let s = abs(ingredient.name.unicodeScalars.reduce(7) { $0 &* 31 &+ Int($1.value) })
        return String(format: "No. %04d", s % 10000)
    }

    var body: some View {
        let f = ingredient.freshness
        let shape = ReceiptShape(tooth: toothH)
        let paper = ReffiColor.oklch(0.985, 0.004, 90)   // 흰 영수증

        return VStack(alignment: .leading, spacing: 0) {
            // 헤더 — 큰 일러스트 + (카테고리·편집) / (이름·Due date)
            HStack(spacing: ReffiSpace.s4) {
                PaperSilhouette(glyph: ingredient.glyph, fresh: f)
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(ingredient.category).reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                        Spacer()
                        Button(action: onEdit) {
                            ReffiIcon.manual.reffi(16, .bold)
                                .foregroundStyle(ReffiColor.ink2)
                                .frame(width: 30, height: 30)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.paperPress)
                        .accessibilityLabel("Edit")
                    }
                    HStack(alignment: .center) {
                        Text(ingredient.name).reffiType(.heading).foregroundStyle(ReffiColor.ink)
                        Spacer()
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
                row("Quantity", ingredient.amount)
                row("Expires", "\(ingredient.expiresText) · \(ingredient.dDayText)", valueColor: f.dark)
                row("Storage", ingredient.storage)
            }
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s2)

            dashRule
            HStack {
                Text("REFFI · KEEP IT FRESH")
                    .font(.custom("Pretendard-Bold", size: 10, relativeTo: .caption2)).tracking(1.2)
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
        .shadow(color: ReffiColor.ink.opacity(0.06), radius: 5, x: 0, y: 2)
    }

    private func row(_ label: String, _ value: String, valueColor: Color = ReffiColor.ink) -> some View {
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

/// 가로 점선/구분선용 1px 라인.
struct HLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
