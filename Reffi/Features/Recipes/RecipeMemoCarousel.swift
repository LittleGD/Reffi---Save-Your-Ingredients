import SwiftUI
import PhosphorSwift

/// 레시피 추천 티켓 덱(§13) — 풀스크린, **네비 없음**. 주방 오더 티켓이 **실제로 겹쳐 쌓인 덱**:
/// 뒤에 보이는 종이가 장식이 아니라 다음 티켓이다. 수평 플릭은 **방향이 곧 의미**다 —
/// **왼쪽 = Pass**(앞 티켓이 뒤로 들어가고 다음이 올라온다, 순환), **오른쪽 = Cook**(발주 = "Cook this"
/// 버튼과 같은 경로). 드래그 중엔 좌우에 방향 예고 블롭이 뜬다(`flickZones`). 닫기 X로 메인 복귀.
struct RecipeMemoCarousel: View {
    let results: [RecipeRecommender.Result]
    /// 재고가 있는데 매칭 레시피가 0인 경우와 재고 자체가 없는 경우를 구분(빈 상태 카피).
    var hasIngredients: Bool = false
    /// 빈 덱에서 **호명할** 위험 재고 표시명 — **비-fresh 전체**(soon + urgent), 마감 임박순
    /// (호출부가 얼린 스냅샷). 비어 있으면(전부 신선하거나 재고 없음) 기존 일반 카피가 그대로 뜬다.
    /// 아래 `uncoveredNames`는 **urgent만** 세는 더 좁은 축이라 이름을 계열로 갈라 둔다.
    var atRiskNames: [String] = []
    /// 덱은 살아 있는데 **어떤 티켓도 쓰지 않는** 오늘 만료(`urgent`) 재료
    /// (`RecipeRecommender.uncoveredUrgent`). 비어 있으면 브리지 행 자체를 그리지 않는다.
    var uncoveredNames: [String] = []
    var onClose: () -> Void
    var onFire: (RecipeRecommender.Result) -> Void = { _ in }
    /// 고른 재료를 실제로 담는다 — **새로 담긴 수**를 돌려준다(이미 있던 것은 세지 않는다, §13.5).
    /// 덱은 팝업에서 고른 부분집합만 넘긴다. nil이면 담기 알약 자체가 그려지지 않는다.
    var onAddMissing: (([Recipe.Item]) -> Int)?
    /// 담기 흐름(팝업 3단)이 덱 위에 떠 있는가 — 켜지는 순간부터 끝날 때까지 **한 번씩만** 통지한다.
    /// 발주 후 지연 닫기가 이 신호를 보고 "취소가 아니라 미룸"으로 처리한다(`MainView.fire`).
    /// 중간에 false가 새면 그 틈으로 지연 닫기가 빠져나가, 사용자가 보던 팝업이 부모 커버와 함께 걷힌다.
    var onToBuyPresentationChange: (Bool) -> Void = { _ in }
    /// 마지막 팝업에서 "보기"를 고르면 — 덱 커버를 걷고 냉장고의 To buy 패인으로 데려간다.
    var onOpenToBuy: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @State private var order: [Int] = []          // 덱 순서 — [0]이 맨 앞
    @State private var dragOffset: CGSize = .zero
    @State private var fired = false              // 발주 후 덱 잠금(슬램 유지)
    /// 진행 중인 드래그가 잡은 축 — 제스처당 **한 번만** 정하고 끝날 때까지 고정한다(`frontDrag` 참고).
    /// nil = 아직 우세 축이 갈리지 않음(= 아무 것도 커밋하지 않는다).
    @State private var dragAxis: Axis?
    /// 오른쪽 플릭(Cook) → 앞 티켓의 발주 트리거. 발주 상태는 카드가 소유하므로(슬램 연출 구동)
    /// 부모는 이 카운터로 카드의 `fire()`를 부른다 — "Cook this" 버튼과 같은 경로를 태우려는 것이다.
    @State private var fireTrigger = 0
    /// 미커버 브리지 행의 실측 높이 — 카드 예산에서 빼려면 고정값이 아니라 실제 높이가 필요하다
    /// (Dynamic Type을 키우면 한 줄도 두 배가 된다). 0 = 아직 안 그렸거나 행이 없음.
    @State private var bridgeHeight: CGFloat = 0
    // MARK: 담기 3단 팝업 상태 — 선택(체크리스트) → 알림(담김) → 질문(이동)
    /// 이번 흐름이 다루는 부족 재료. 팝업이 뜬 뒤 덱을 넘겨도 목록이 바뀌지 않게 **스냅샷**으로 든다.
    @State private var pickItems: [Recipe.Item] = []
    /// 체크된 행 — `pickItems`의 인덱스. 기본은 **전부 체크**다(부족하다고 이미 판정된 목록이라,
    /// 기본값이 '아무것도 안 담음'이면 흔한 경우에 사용자가 매번 손을 더 대야 한다).
    @State private var pickChecked: Set<Int> = []
    @State private var showPick = false
    @State private var showAdded = false
    @State private var showMove = false
    /// 직전 담기의 결과 — 알림 팝업이 **사실을 말하기 위해** 필요하다(N건 담김 / 이미 있던 것).
    @State private var addedCount = 0
    @State private var alreadyCount = 0
    @State private var addHaptic = 0

    /// 커버 헤더의 실측 높이 — 브리지 행과 카드가 **둘 다** 이 값 아래에 선다. 기본 텍스트 크기의
    /// `CoverHeader`는 s4(16) + 44 + s3(12) = 72이라 초기값도 72지만, 큰 글씨에서 타이틀·부제가
    /// 2줄로 접히면 그만큼 자란다 — 고정 72로 두면 헤더가 브리지 행을 통째로 덮는다.
    @State private var headerHeight: CGFloat = 72

    /// 수평 플릭 커밋 임계(예측 변위 width) — 넘기면 부호가 곧 의미다(+ Cook / − Pass).
    private let flickCommit: CGFloat = 160
    /// 예고 블롭 크기 — 홈 판정 바스켓과 같은 규격을 `ReffiJudgeZone`에서 함께 읽는다(§13.4).
    private let zoneSide: CGFloat = ReffiJudgeZone.side

    /// 덱 입력은 호출부가 넘긴 스냅샷 고정 — 열려 있는 동안 늘거나 재랭크되지 않는다(단일 정체성).
    private var deck: [Int] { order.isEmpty ? Array(results.indices) : order }

    var body: some View {
        GeometryReader { geo in
            // 카드 높이 캡(근본) — 카드가 컨테이너를 절대 넘지 못하게 safe area에 연동해 예산을 뺀다.
            // topInset = safe top + 헤더 실측 높이 + 뒤티켓 peek(28), botInset = safe bottom + 12.
            // 기존 124/86과 유사한 시각을 유지하되 기기별 노치·홈 인디케이터에 안전하다.
            // 헤더 예산은 **실측**이다(`headerHeight`) — 72로 박아 두면 큰 글씨에서 부제가 두 줄로
            // 접히는 순간 헤더가 그 아래 브리지 행을 덮는다(ZStack에서 topBar가 마지막에 그려진다).
            // 미커버 브리지 행이 있으면 그 실측 높이(+간격)만큼 카드 예산에서 더 뺀다 —
            // 행은 카드 **위**에 서므로 겹칠 자리가 아니라 자기 자리를 가져가야 한다.
            let headerBottom = geo.safeAreaInsets.top + headerHeight
            let bridgeBudget = showsBridge ? bridgeHeight + ReffiSpace.s2 : 0
            let topInset = headerBottom + bridgeBudget + 28
            let botInset = geo.safeAreaInsets.bottom + 12
            let cardHeight = max(0, geo.size.height - topInset - botInset)
            ZStack(alignment: .top) {
                ReffiColor.paperPass.ignoresSafeArea()
                if results.isEmpty { emptyState } else { ticketDeck(cardHeight: cardHeight, topInset: topInset) }
                if showsBridge { bridgeRow.padding(.top, headerBottom) }
                topBar
            }
        }
        .onAppear { order = Array(results.indices) }
        // 팝업 셋은 **같은 뷰 트리 안의 오버레이**다(§14.7) — 시스템 알림이면 해체 전환이 부모 커버의
        // 닫기 요청과 겹쳐 그 요청이 삼켜진다(10차에서 3회 중 1회 재현). 오버레이는 전환 큐가 없다.
        .paperChecklistDialog(isPresented: $showPick,
                              title: "Pick what to add",
                              message: "Uncheck anything you already have.",
                              rows: pickRows,
                              checked: $pickChecked,
                              // 확정 라벨은 **개수형**이다(`ReceiptScanView`의 담기 CTA와 같은 키) —
                              // 진입 알약("Add to list")과 라벨이 갈려야 무엇을 누르는지가 흐려지지
                              // 않고, 0건이면 "Add 0 items"가 disabled로 남아 이유까지 설명한다.
                              confirmTitle: "Add \(pickChecked.count) items",
                              seed: 12,
                              onConfirm: commitAdd,
                              onClose: { endAddFlow() })
        .paperDialog(isPresented: $showAdded,
                     title: addedTitle,
                     message: addedMessage,
                     seed: 13,
                     // 알림형은 딤 탭을 무시한다 — 조용히 닫히면 이어질 질문을 못 받는다(§14.7).
                     primary: PaperDialogAction("OK") { showMove = true })
        .paperDialog(isPresented: $showMove,
                     title: "View your To buy list?",
                     message: "You can open it later from the Fridge tab.",
                     seed: 14,
                     backdropDismisses: true,   // 질문형 — 바깥 탭 = 취소(실수로 이동시키지 않는다)
                     primary: PaperDialogAction("View") { endAddFlow(openToBuy: true) },
                     secondary: PaperDialogAction("Cancel") { endAddFlow() })
        .sensoryFeedback(.success, trigger: addHaptic)   // 목록에 담김 = 성공 완료(§7.6)
    }

    // MARK: - 담기 3단 팝업

    /// 체크리스트 행 — **장보기 표기로 정리한 이름·글리프**를 보여 준다(레시피 원문이 아니라).
    /// 목록에 실제로 서게 될 줄이 "Garlic"인데 팝업이 "minced garlic"을 고르게 하면, 고른 것과
    /// 담긴 것의 이름이 갈린다. 해석은 `RecipeRecommender.toBuyEntry` 한 곳이 한다(담기와 같은 함수).
    private var pickRows: [PaperChecklistDialog.Row] {
        pickItems.enumerated().map { idx, item in
            let entry = RecipeRecommender.toBuyEntry(for: item)
            return PaperChecklistDialog.Row(id: idx, name: entry.name, glyph: entry.glyph)
        }
    }

    private var addedTitle: LocalizedStringKey {
        addedCount > 0 ? "Added \(addedCount) items" : "Already on your list"
    }

    /// 부분 담김(고른 것 중 일부는 이미 있었다)일 때만 한 줄을 더한다 — 개수 두 개를 나란히 세우면
    /// 알림이 정산서가 된다. 0건이면 "새로 담을 게 없다"고 사실만 말한다.
    private var addedMessage: LocalizedStringKey? {
        if addedCount == 0 { return "Nothing new to add." }
        return alreadyCount > 0 ? "The rest were already on your list." : nil
    }

    /// 알약 탭 — 흐름의 시작. 여기서 프레젠테이션 신호를 켜고, 끝(취소·닫기·이동)에서만 끈다.
    private func startAddFlow(_ items: [Recipe.Item]) {
        guard !items.isEmpty else { return }
        pickItems = items
        pickChecked = Set(items.indices)
        addedCount = 0
        alreadyCount = 0
        onToBuyPresentationChange(true)
        showPick = true
    }

    /// 체크된 것만 담는다. 하나도 체크되지 않은 상태는 CTA가 `disabled`라 여기 도달하지 않는다.
    private func commitAdd() {
        let picked = PaperChecklistDialog.selected(pickItems, checked: pickChecked)
        let added = onAddMissing?(picked) ?? 0
        addedCount = added
        alreadyCount = Self.alreadyOnListCount(picked: picked, added: added)
        if added > 0 { addHaptic += 1 }   // 아무 것도 안 담겼으면 울리지 않는다(3차 ⑥ 규약)
        showAdded = true
    }

    /// "이미 목록에 있었다"로 셀 수 있는 수 — **줄 수가 아니라 목록 키 수** 기준이다.
    /// 두 항목이 같은 장보기 표제어로 풀리면(커스텀 레시피의 "다진 마늘"+"마늘 한 쪽") 목록엔 한
    /// 줄만 생기는데, `picked.count - added`로 세면 나머지 하나가 "이미 있었다"로 둔갑해 알림이
    /// 거짓말을 한다. 키 유도는 `appendToBuy`가 실제로 쓰는 식(캐논 ?? 소문자 이름)과 같다.
    /// `internal`(비-private): 문구 분기가 이 수 하나에 걸려 있어 테스트가 같은 식을 검사한다.
    static func alreadyOnListCount(picked: [Recipe.Item], added: Int) -> Int {
        let keys = Set(picked.map { item -> String in
            let entry = RecipeRecommender.toBuyEntry(for: item)
            return entry.canonicalID ?? entry.name.lowercased()
        })
        return max(0, keys.count - added)
    }

    /// 흐름의 유일한 출구 — 어느 갈래로 끝나든 신호를 **정확히 한 번** 내린다.
    private func endAddFlow(openToBuy: Bool = false) {
        showPick = false
        showAdded = false
        showMove = false
        pickItems = []
        pickChecked = []
        onToBuyPresentationChange(false)
        if openToBuy { onOpenToBuy() }
    }

    // MARK: - 티켓 덱 (뒤 종이 = 실제 다음 티켓)

    private func ticketDeck(cardHeight: CGFloat, topInset: CGFloat) -> some View {
        ZStack {
            ForEach(Array(deck.enumerated().reversed()), id: \.element) { position, idx in
                ticketCard(idx: idx, depth: position, cardHeight: cardHeight, topInset: topInset)
            }
            flickZones(cardHeight: cardHeight, topInset: topInset)
                .zIndex(Double(deck.count) + 1)   // 카드 zIndex는 1...deck.count — 그 위
        }
        .accessibilityAction(named: Text("Next ticket")) { advance() }
    }

    @ViewBuilder private func ticketCard(idx: Int, depth: Int, cardHeight: CGFloat, topInset: CGFloat) -> some View {
        let isFront = depth == 0
        // 가장 깊은 티켓(depth ≥ 2)만 headerOnly 경량 렌더 — 바로 뒤(depth 1)는 풀 렌더라
        // 플릭 승격(1→0)이 내용 변화 없이 매끄럽다(ScrollView 상태·래스터 유지, 번쩍임 없음).
        // 전환 진입 성능은 '무거운 카드 3→2장'으로 이득 대부분 유지(§13.6).
        OrderMemoCard(result: results[idx],
                      number: idx + 1,
                      headerOnly: depth >= 2,
                      // 앞 티켓 톱니 사이로 뒤 카드 ORDER 행이 반쪽 글리프로 새던 결함 —
                      // 노출 띠(14pt)는 글자 없는 종이로 고정한다.
                      peek: depth >= 1,
                      onFire: { fire(results[idx]) },
                      // 플릭 발주는 **앞 티켓만** — 뒤 티켓엔 0을 고정해 트리거가 전파되지 않게 한다.
                      fireTrigger: isFront ? fireTrigger : 0,
                      // 카드는 목록을 넘기기만 한다 — 고르기·담기·이동은 덱 위 팝업의 일이다.
                      onPickMissing: onAddMissing == nil ? nil : { startAddFlow($0) })
            .frame(height: cardHeight)   // 카드가 컨테이너를 넘지 못하게 캡(headerOnly도 동일 캡)
            .padding(.horizontal, ReffiGrid.margin + 8)
            .padding(.top, topInset)
            .scaleEffect(isFront ? 1 : 1 - CGFloat(depth) * 0.035, anchor: .top)
            .offset(y: isFront ? 0 : CGFloat(depth) * -14)   // 뒤 티켓이 위로 머리를 내민다
            .rotationEffect(.degrees(isFront ? Double(dragOffset.width / 22)
                                             : (idx % 2 == 0 ? -2.2 : 2.4)),
                            anchor: .top)
            .offset(isFront ? dragOffset : .zero)
            .allowsHitTesting(isFront)
            .accessibilityHidden(!isFront)
            .zIndex(Double(deck.count - depth))
            // `deck.count > 1` 가드는 두지 않는다 — 오른쪽 플릭은 넘김이 아니라 발주라 1장 덱에서도 성립한다.
            .gesture(isFront && !fired ? frontDrag : nil)
    }

    // MARK: - 방향 예고 블롭 (홈 판정 바스켓 문법 이식)

    /// 수평 드래그 중에만 뜨는 방향 예고 — 좌 = Pass(다음 티켓), 우 = Cook(발주).
    /// 홈 판정 바스켓(§13.6 3-1)의 문법을 그대로 가져온다: 86pt 종이 블롭 + 채운 아이콘, **글자 없음**.
    /// 홈은 SpriteKit이라 `ImageRenderer`로 텍스처를 굽고 스킴이 바뀔 때마다 다시 구워야 했지만,
    /// 여기선 SwiftUI 라이브 뷰라 적응형 토큰이 알아서 따라온다(다시 굽는 절차 자체가 없다).
    ///
    /// **z는 카드 위, 위치는 카드 옆(좌우 여백)이다.** 카드 뒤에 두면 정반대로 읽힌다 — 카드가
    /// 오른쪽으로 밀릴 때 드러나는 건 카드가 **비운 왼쪽**이라, 정작 Cook 블롭은 카드에 가리고
    /// Pass 블롭만 보인다. 예고가 진행 방향과 어긋나면 없느니만 못하므로 z를 올리고 히트테스트를 끈다.
    ///
    /// **시각 전용이다(VoiceOver 미노출)** — 홈 존 선례. 같은 동작의 접근성 경로는 티켓의
    /// "Cook this" 버튼과 덱의 "Next ticket" 커스텀 액션이 담당하고, 여기 라벨을 달면 3번째 경로가 된다.
    private func flickZones(cardHeight: CGFloat, topInset: CGFloat) -> some View {
        let dx = dragOffset.width
        let live = dragAxis == .horizontal && dx != 0
        // 커밋 임계의 60% — 예측 변위(속도 포함)가 임계를 넘길 지점을 실제 변위로 앞당겨 잡은 값이다.
        // 실제 변위가 임계에 닿고서야 부풀면 예고가 아니라 사후 보고가 된다.
        let hot = flickCommit * 0.6
        return HStack(spacing: 0) {
            // Pass 색 = `PaperIconLabel.Intent.neutral`(sub 면 + ink2 잉크)과 **같은 쌍**이다 —
            // 판정 커버의 3번째 선택지(Freeze)가 쓰는 그 중립 블롭. Pass는 티켓을 지우는 게 아니라
            // 덱 뒤로 보낼 뿐이라 urgent 빨강(Tossed 계열)을 쓰면 파괴로 읽힌다.
            // 넘길 티켓이 없으면(1장 덱) 예고하지 않는다 — 지키지 못할 예고다.
            flickZone(icon: ReffiIcon.pass, fill: ReffiColor.sub, tint: ReffiColor.ink2,
                      seed: 3, hot: live && dx <= -hot)
                .opacity(deck.count > 1 ? 1 : 0)
            Spacer(minLength: 0)
            // Cook 색 = Ate 바스켓·"Cook this" CTA와 같은 브랜드 블루 계열(긍정 액션 색족).
            flickZone(icon: ReffiIcon.recipe, fill: ReffiColor.blueLight, tint: ReffiColor.blueDark,
                      seed: 6, hot: live && dx >= hot)
        }
        .padding(.horizontal, ReffiSpace.s3)
        .frame(height: cardHeight)   // 카드와 같은 세로 박스 → 블롭이 카드 세로 중앙에 선다
        .padding(.top, topInset)
        .opacity(live ? ReffiJudgeZone.alpha : 0)   // 완전 불투명이 아닌 0.96 — 홈 존과 같은 토큰
        // 등장·소멸(홈 `SKAction.fadeAlpha` 대응). 놓는 순간 축이 풀려 커밋 여부와 무관하게 사라진다.
        .animation(ReffiMotion.gated(ReffiMotion.easeOut(duration: ReffiJudgeZone.fade), reduce: reduceMotion),
                   value: live)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 예고 블롭 한 장 — 홈 `makeZone(toss:)`과 같은 구성(fill 블롭 + 0.35 스트로크 + 30pt `.fill` 아이콘).
    /// seed가 다르면 두 블롭의 삐뚤빼뚤함이 갈린다(홈 3/6 선례를 그대로 쓴다).
    /// 하이라이트는 **스케일만** 1.14×(0.1초) — 색은 바꾸지 않는다(홈과 동일).
    private func flickZone(icon: Ph, fill: Color, tint: Color, seed: Int, hot: Bool) -> some View {
        ZStack {
            PaperBlob(sides: 9, seed: seed).fill(fill)
            PaperBlob(sides: 9, seed: seed).stroke(tint.opacity(0.35), lineWidth: 1.5)
            icon.reffi(30, .fill).foregroundStyle(tint)
        }
        .frame(width: zoneSide, height: zoneSide)
        .scaleEffect(hot ? ReffiJudgeZone.hotScale : 1)
        .animation(ReffiMotion.gated(ReffiMotion.easeOut(duration: ReffiJudgeZone.hotDuration), reduce: reduceMotion),
                   value: hot)
    }

    /// 앞 티켓 드래그 — 카드 위 드래그를 중재하는 **유일한 지점**이다(카드는 탭만 받는다).
    /// 한 제스처에서 우세 축을 **한 번만** 판별해 고정한다: 수평(|Δx| > |Δy|·1.4)만 의미가 있고,
    /// 수직(|Δy| > |Δx|·1.4)은 커밋 대상이 없어 아무 것도 하지 않는다. 매 이벤트 재판정하면 곡선
    /// 드래그에서 분기가 바뀌며 직전 분기가 남긴 상태(`dragOffset`)가 스테일로 굳는다 — 축을 잠가 그 창을 없앤다.
    ///
    /// 축이 갈리지 않은 애매한 구간(대략 35.5°~54.5°)은 끝까지 nil로 남아 **아무 것도 커밋하지 않는다**
    /// — 추종 피드백 없이 상태가 뒤집히는 걸 막는다.
    private var frontDrag: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { v in
                if dragAxis == nil {
                    let dx = abs(v.translation.width), dy = abs(v.translation.height)
                    if dx > dy * 1.4 { dragAxis = .horizontal }
                    else if dy > dx * 1.4 { dragAxis = .vertical }
                    else { return }   // 아직 갈리지 않았다 — 다음 이벤트에서 다시 본다
                }
                // 라이브 추종은 **양방향 모두** 허용한다 — 오른쪽은 넘김이 아니라 발주라 덱이 1장이어도
                // 성립하고, 왼쪽도 (넘길 티켓이 없으면) 스프링 복귀로 "임계 미달"과 같은 답을 준다.
                guard dragAxis == .horizontal else { return }
                dragOffset = v.translation
            }
            .onEnded { v in
                let p = v.predictedEndTranslation
                let axis = dragAxis
                dragAxis = nil   // 어느 경로로 끝나든 축은 여기서 반드시 푼다
                switch axis {
                case .horizontal:
                    // **부호가 곧 의미다** — 오른쪽은 발주(Cook), 왼쪽은 다음 티켓(Pass).
                    // 세로 성분(옛 |Δy| > 220 폴백)으로는 커밋하지 않는다: 방향이 의미를 가진 뒤로는
                    // 세로로 크게 튕긴 수평 드래그가 Cook인지 Pass인지 지목할 수 없다. 게다가 카드
                    // 본문은 기본 텍스트 크기에서 스크롤되지 않는 ScrollView라 세로 드래그를 삼키지
                    // 않는다 — 옛 폴백은 카드 본문 어디서든 오발동했다.
                    if p.width > flickCommit {
                        // 발주는 넘김이 아니다 — 카드는 날아가지 않고 제자리로 돌아오고 그 위에 슬램이 찍힌다.
                        withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                            dragOffset = .zero
                        }
                        fireTrigger += 1   // 카드 내부 fire() — "Cook this" 버튼과 같은 상태 변화·햅틱·잠금
                    } else if p.width < -flickCommit, deck.count > 1 {
                        // 플릭이 성립하면 flickAway가 dragOffset을 이어받아 날려보낸다(advance가 0으로 되돌림).
                        flickAway(toward: p)
                    } else {
                        withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                            dragOffset = .zero
                        }
                    }
                case .vertical:
                    break   // 세로로 커밋할 상태가 없다(축약↔펼침 없음) — 조용히 끝낸다
                case .none:
                    break   // 애매 구간 — 커밋 없음(dragOffset도 애초에 건드리지 않았다)
                }
            }
    }

    /// Pass(왼쪽 플릭) 연출 — 앞 티켓을 튕긴 방향으로 날린 뒤 덱을 회전시킨다.
    /// Cook(오른쪽)은 여기 오지 않는다 — 발주한 티켓은 화면에 남아 슬램을 받는다.
    private func flickAway(toward p: CGSize) {
        guard deck.count > 1 else { return }
        if reduceMotion {
            advance()
            return
        }
        let mag = max(1, hypot(p.width, p.height))
        let target = CGSize(width: p.width / mag * Self.flyDistance, height: p.height / mag * Self.flyDistance)
        // **커밋은 속도로 판정하는데 연출만 고정 0.2초**였다 — 손목으로 튕긴 티켓과 임계선을 겨우
        // 넘긴 티켓이 똑같은 속도로 빠져나가니, 세게 던진 손이 만든 운동량이 화면에서 끊겼다.
        // 같은 `predictedEndTranslation`이 곧 속도의 대리값이므로(변위 + 감속 예측), 그 크기로
        // 이탈 시간을 정한다. 클램프 밖은 둘 다 못 쓴다: 너무 빠르면 카드가 사라진 줄 모르고,
        // 너무 느리면 던진 힘이 허공에서 멎는다.
        let fly = min(Self.flyMax, max(Self.flyMin, Self.flyDistance / mag * Self.flyFactor))
        // 날려보낸 **그 티켓**을 기억해 두고, 이탈이 거의 끝난 뒤에도 여전히 맨 앞일 때만 덱을 돌린다.
        // 그 사이에 다른 경로(접근성 "Next ticket" 액션, 날아가는 카드 위에서 시작된 새 플릭)가
        // 이미 덱을 돌렸으면 여기서 한 번 더 돌게 되고, 사용자가 보지도 못한 티켓이 조용히 넘어간다
        // (그 카드가 제스처를 쥔 채 뒤로 밀리면 onEnded가 오지 않아 축 잠금까지 남는다).
        let flicked = deck.first
        withAnimation(ReffiMotion.easeOut(duration: fly)) { dragOffset = target }
        DispatchQueue.main.asyncAfter(deadline: .now() + fly * Self.flySwapRatio) {
            guard deck.first == flicked else { return }
            advance()
        }
    }

    /// 플릭 이탈 — 카드가 날아가는 거리(pt)와, 던진 세기를 시간으로 바꾸는 상수들.
    ///
    /// `flyFactor`는 "예측 변위가 mag이면 640pt를 이만큼에 지난다"의 근사다: 임계선을 살짝 넘긴
    /// 커밋(mag ≈ 180)이 상한 0.28에, 손목으로 튕긴 것(mag ≳ 420)이 하한(dur-1)에 붙는다.
    /// 하한은 §7.1 마이크로 듀레이션 그대로고, 상한만 면 전환(dur-3)보다 살짝 길다 — 화면 밖으로
    /// 나가는 거리라 dur-3에 맞추면 느린 플릭이 뚝 끊긴다.
    private static let flyDistance: CGFloat = 640
    private static let flyFactor: Double = 0.08
    private static let flyMin: Double = ReffiMotion.dur1
    private static let flyMax: Double = 0.28
    /// 덱 회전 시점 — 이탈이 거의 끝난 지점(옛 0.2초 연출의 0.18초와 같은 비율).
    private static let flySwapRatio: Double = 0.9

    /// 맨 앞 티켓을 덱 뒤로 — 다음 티켓이 스프링으로 올라온다.
    private func advance() {
        guard deck.count > 1, !fired else { return }
        var d = deck
        d.append(d.removeFirst())
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { dragOffset = .zero }
        withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) { order = d }
    }

    private func fire(_ result: RecipeRecommender.Result) {
        fired = true   // 덱 잠금 — 슬램이 보이는 동안 플릭 방지
        onFire(result)
    }

    // MARK: - 상단 바

    /// 커버 헤더 — 단일 공급원 `CoverHeader`(§14.2: 풀스크린 커버 = 중앙 타이틀 + 종이 X).
    /// 부제는 **두 방향을 모두** 가르쳐야 한다: 오른쪽 플릭은 넘김이 아니라 발주라,
    /// "튕기면 다음 티켓"만 말하면 오른손잡이가 안내를 따라 하다가 발주를 걸게 된다.
    private var topBar: some View {
        CoverHeader(title: "Today's tickets",
                    subtitle: "Flick left to pass, right to cook. Ranked by what spoils first.",
                    onClose: onClose)
            // 헤더가 실제로 차지한 높이를 브리지 행·카드 예산으로 되돌린다(고정값 금지 — 위 `headerBottom` 참고).
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
    }

    // MARK: - 영상 브리지 (덱이 임박 재료를 못 다룰 때의 출구)

    /// 호명 대상 — **최대 2종**. 셋 이상을 다 부르면 안내가 목록이 되어버린다(티켓이 아니라 리스트
    /// 화면이 할 일). 나머지는 덱·냉장고가 계속 들고 있다. 문구와 영상 버튼이 **같은 배열**을 본다 —
    /// 버튼이 첫 번째만 열면 두 번째로 부른 재료에는 브리지가 메우려던 침묵이 그대로 남는다.
    private func spoken(_ names: [String]) -> [String] {
        Array(names.prefix(2))
    }

    /// 호명 문구용 이름 묶음 — 호명 대상을 ", "로 잇는다.
    private func named(_ names: [String]) -> String {
        spoken(names).joined(separator: ", ")
    }

    /// 브리지 행은 **덱이 있을 때만** 뜬다 — 빈 덱의 출구는 빈 상태 자체가 담당한다(중복 안내 금지).
    private var showsBridge: Bool { !results.isEmpty && !uncoveredNames.isEmpty }

    /// 미커버 임박 브리지 — 티켓 덱 위 **한 줄짜리** 종이 행. "이 티켓들이 안 쓰는 재료"를 말하고
    /// 그 자리에서 영상 검색으로 보낸다. 덱이 압박(“오늘 N개 위험”)만 하고 정작 그 재료를 다루지
    /// 않는 침묵을 메우는 것이 목적이라, 다룰 게 없으면(=`uncoveredNames` 비면) 아예 그리지 않는다.
    private var bridgeRow: some View {
        HStack(spacing: ReffiSpace.s2) {
            // 재료 이름은 영·한 모두 문장 **끝**에 온다 — 한 줄로 묶으면 큰 글씨에서 잘려 나가는 부분이
            // 정확히 이 행의 유일한 payload다. 두 줄까지 접고 그 전에 더 깊이 축소한다(행 높이는 실측이라
            // 자라도 카드를 덮지 않는다).
            Text("Nothing on these tickets uses \(named(uncoveredNames)).")
                .reffiType(.metaText).foregroundStyle(ReffiColor.ink2)
                .lineLimit(2).minimumScaleFactor(0.7)
            Spacer(minLength: ReffiSpace.s2)
            Button {
                openURL(RecipeVideoSearch.urlForIngredients(spoken(uncoveredNames)))
            } label: {
                ReffiIcon.youtube.reffi(18, .fill)
                    .foregroundStyle(ReffiColor.urgentDark)
                    .frame(width: ReffiChrome.tapMin, height: ReffiChrome.tapMin)   // 시각 18pt, 히트 44pt(§7.3)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.paperPress)
            .accessibilityLabel(Text("Open recipe videos"))
            .accessibilityHint(Text("Opens YouTube in your browser"))
        }
        .padding(.leading, ReffiSpace.s4)
        .padding(.trailing, ReffiSpace.s1)
        .frame(minHeight: ReffiChrome.tapMin)
        .background {
            let shape = PaperRect(cornerRadius: ReffiRadius.sm, seed: 5)
            shape.fill(ReffiColor.paper)
                .paperEdge(shape)
        }
        .padding(.horizontal, ReffiGrid.margin + 8)
        // 실측 높이를 카드 예산으로 되돌린다 — 고정값으로 잡으면 큰 글씨에서 카드 머리를 덮는다.
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bridgeHeight = $0 }
    }

    /// 빈 덱 — 원인 기반 안내: 재료가 있는데 매칭 0이면 **그 임박 재료를 호명하고** 영상으로 보낸다.
    /// 이름을 부르지 않으면 "매칭 0"은 앱의 사정일 뿐이고, 사용자는 여전히 오늘 뭘 해야 할지 모른다.
    /// 전부 신선하거나 재고가 없으면(=`atRiskNames` 빔) 기존 카피 그대로 — 호명할 대상이 없다.
    private var emptyState: some View {
        VStack(spacing: ReffiSpace.s4) {
            FoodMotif(glyph: .generic).frame(width: 110, height: 110)
            Text("No tickets yet").reffiType(.heading).foregroundStyle(ReffiColor.ink)
            if !atRiskNames.isEmpty {
                Text("\(named(atRiskNames)) won't last long. Find a video and cook it today.")
                    .reffiType(.body).foregroundStyle(ReffiColor.ink2).multilineTextAlignment(.center)
                PaperButton(title: "Open recipe videos", fullWidth: false, seed: 5) {
                    openURL(RecipeVideoSearch.urlForIngredients(spoken(atRiskNames)))
                }
                .accessibilityHint(Text("Opens YouTube in your browser"))
            } else if hasIngredients {
                // 재고는 있는데 덱이 빈 경우. 원인이 **둘**이라 문안도 둘을 함께 말한다:
                // ① 재료가 모자람(부족 3개 이상은 `maxMissingForRecommendation`이 거른다)
                // ② 재료 이름이 사전과 안 맞아 `used`가 비어 후보에서 빠짐(`rank`의 `!$0.used.isEmpty`).
                // ②는 여전히 살아 있는 경로라 원인을 ①로 단정하면, 오타로 등록한 사용자는 장을 봐도
                // 덱이 계속 비고 진짜 해법(이름 확인)은 화면 어디에도 없게 된다.
                Text("No tickets from what's in your fridge yet.\nCheck the ingredient names, restock, or add your own recipe in Profile.")
                    .reffiType(.body).foregroundStyle(ReffiColor.ink2).multilineTextAlignment(.center)
            } else {
                Text("Keep a few ingredients on, then start cooking.")
                    .reffiType(.body).foregroundStyle(ReffiColor.ink2).multilineTextAlignment(.center)
            }
        }
        .padding(ReffiSpace.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
