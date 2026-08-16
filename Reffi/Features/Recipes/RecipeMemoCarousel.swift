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
    /// 덱이 자기 위에 띄운 **To buy 흐름 전체**(결과 팝업 → 이동 질문 → To buy 커버)의 표시 상태를
    /// 부모에게 알린다 — 부모(`MainView`)의 발주 지연 닫기가 **이 흐름이 떠 있는 동안에는 부모를 닫지
    /// 않도록**. 커버·팝업 계층을 아는 건 덱뿐이라 덱이 말한다.
    ///
    /// **팝업까지 신호에 포함하는 이유**: 지연 닫기가 팝업이 떠 있는 사이에 부모를 닫으면 팝업이 부모와
    /// 함께 걷혀(중첩 커버가 그랬던 것과 같은 캐스케이드) 사용자가 방금 띄운 질문이 손에서 사라지고,
    /// 나쁘면 팝업 해체 전환과 겹쳐 부모 닫기 요청 자체가 삼켜져 덱이 영영 안 닫힌다(`82cc116` 참고).
    /// true는 팝업①이 뜰 때 한 번, false는 흐름이 **끝날 때**(이동 취소 / To buy 닫힘) 한 번 —
    /// 팝업①→②→커버 사이에는 내려가지 않는다. 중간에 false가 새면 그 틈으로 지연 닫기가 빠져나간다.
    /// false를 **언제** 보내는지도 계약이다: 커버는 `onDismiss`(해체 완료 훅), 다이얼로그는 버튼을
    /// 누른 그 자리에서 곧바로 — 다이얼로그는 UIKit 프레젠테이션이 아니라 오버레이라 부모의 닫기 요청과
    /// 겹칠 전환이 없다(`endToBuyFlow()`에 근거).
    var onToBuyPresentationChange: (Bool) -> Void = { _ in }

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
    /// 커버 헤더의 실측 높이 — 브리지 행과 카드가 **둘 다** 이 값 아래에 선다. 기본 텍스트 크기의
    /// `CoverHeader`는 s4(16) + 44 + s3(12) = 72이라 초기값도 72지만, 큰 글씨에서 타이틀·부제가
    /// 2줄로 접히면 그만큼 자란다 — 고정 72로 두면 헤더가 브리지 행을 통째로 덮는다.
    @State private var headerHeight: CGFloat = 72
    /// 부족 재료를 담은 뒤 여는 To buy 커버. **덱 위에** 띄운다 — 덱 자체가 이미 풀스크린 커버라
    /// 메인(`MainView`)에서 열면 커버 2장을 동시에 요구하게 되고, 닫았을 때 티켓으로 못 돌아온다.
    /// 이제 칩 탭이 곧장 켜지 않는다 — 아래 두 팝업을 거쳐 사용자가 "보기"를 고를 때만 켜진다.
    @State private var showToBuy = false
    /// 팝업①(알림) — 담기 결과를 알린다. 두 상태를 **분리**해 두는 이유는 순차 표시 때문이다:
    /// 하나의 상태로 문안만 갈아끼우면 표시 중 내용 교체가 되어(같은 뷰가 정체를 유지한 채 글자만
    /// 바뀌어) 두 장이 한 장처럼 읽힌다. 상태가 갈라져 있으면 첫 장이 사라지고 둘째 장이 들어온다.
    @State private var showAddedPrompt = false
    /// 팝업①의 문안 갈래 — 새로 담긴 게 있었나. 팝업을 켜는 것과 **같은 업데이트**에서 정해지므로
    /// 표시 시점엔 이미 올바른 값이다.
    @State private var addedSomething = false
    /// 팝업②(질문) — 목록으로 갈지 묻는다. 팝업①의 확인 액션에서만 켜진다.
    ///
    /// 오버레이라 교대에 트릭이 필요 없다 — 첫 장을 내리는 것과 둘째 장을 올리는 것이 **같은 업데이트**에서
    /// 처리된다(시스템 알림 시절엔 프레젠테이션 큐를 믿어야 했다).
    @State private var showOpenToBuyPrompt = false

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
        // History·To buy는 앱 전역에서 하단에서 올라오는 풀스크린 커버다(`FridgeView`와 같은 진입).
        //
        // **닫힘은 `onDismiss`로 알린다(`onChange`가 아니라).** `onChange(of: showToBuy)`는 바인딩이
        // false가 되는 순간 — 즉 해체 **애니메이션이 시작되는** 시점 — 에 울린다. 그때 부모가 곧바로
        // 자기 커버를 닫으려 하면 전환 두 개가 겹쳐 UIKit이 그 요청을 삼키고, 바인딩(`showCarousel`)은
        // 이미 false라 다시 울릴 일이 없어 **덱이 영영 닫히지 않는다**(미뤄 둔 조리 화면 전환도 유실).
        // 실측 근거: 플레이크 실패 런의 UI 트리에 To buy는 사라졌는데 덱("Today's tickets" + 카드들)만
        // 남아 있었고, 조리 화면은 15초를 폴링해도 오지 않았다.
        // `onDismiss`는 해체가 **끝난 뒤** 울리므로 그 시점엔 겹칠 전환이 없다.
        .fullScreenCover(isPresented: $showToBuy,
                         onDismiss: { onToBuyPresentationChange(false) }) {
            ShoppingListView()
        }
        // 팝업① 알림 — **사실만** 말한다. 담긴 게 하나도 없었으면 담았다고 하지 않는다.
        // 룰⑧ 분류상 파괴가 아니라 순수 알림성이라 확인 버튼 하나짜리 중앙 다이얼로그다.
        // **바깥 탭은 무시**한다(`backdropDismisses` 기본값) — 여기서 조용히 끝나면 이어질 질문을
        // 못 받고, 방금 담긴 사실도 못 본 채 티켓으로 돌아간다. 나가는 길은 확인 하나뿐이다.
        .paperDialog(isPresented: $showAddedPrompt,
                     title: addedSomething ? "Added to To buy" : "Already on your To buy list",
                     seed: number(for: 3),
                     primary: PaperDialogAction("OK") { showOpenToBuyPrompt = true })
        // 팝업② 질문 — 이동은 **사용자가 고른다**(칩 탭이 곧 화면 이동이던 예전 동작을 대체한다).
        // 이쪽은 **바깥 탭 = 취소**다. 되돌릴 게 없는 질문이라 실수로 닫아도 잃는 게 없고,
        // 취소와 다른 결과를 내면 실수로 닫은 사용자가 의도하지 않은 이동을 하게 된다.
        .paperDialog(isPresented: $showOpenToBuyPrompt,
                     title: "View your To buy list?",
                     // 취소를 안전한 선택으로 만드는 한 줄 — 목록은 냉장고 탭의 To buy 카드로 다시 열린다.
                     message: "You can open it later from the Fridge tab.",
                     seed: number(for: 6),
                     backdropDismisses: true,
                     primary: PaperDialogAction("View") { showToBuy = true },
                     // 취소로 흐름이 끝난다 — 신호를 내려야 부모의 미뤄 둔 발주 전환이 이어진다
                     // (취소는 이동만 안 하는 것이지 발주 취소가 아니다).
                     secondary: PaperDialogAction("Cancel") { endToBuyFlow() })
    }

    /// 종이 삐뚤빼뚤함 시드 — 두 다이얼로그가 서로 다른 종이로 보이도록 앞 티켓 번호에 섞는다.
    private func number(for salt: Int) -> Int { (deck.first ?? 0) &+ salt }

    /// 칩이 담기를 마쳤다 — 결과 팝업을 띄우고, **이 순간부터** 덱 위에 무언가 떠 있다고 부모에게 알린다.
    /// 신호를 팝업 시작점에 두는 게 핵심이다: 담기 직후~팝업 표시 사이에 지연 닫기가 끼어들면
    /// 팝업이 부모와 함께 걷힌다. 이후 false는 "취소" 또는 "To buy 커버 닫힘" 한 곳에서만 나간다.
    private func didAddToBuy(_ addedAny: Bool) {
        addedSomething = addedAny
        onToBuyPresentationChange(true)
        showAddedPrompt = true
    }

    /// 흐름이 끝났음을 곧바로 알린다 — 부모의 미뤄 둔 발주 전환이 여기서 이어진다.
    ///
    /// **10차에는 여기에 0.6초 지연이 있었고, 11차에서 걷어냈다.** 지연의 이유는 순전히 시스템 알림
    /// 때문이었다: `.alert`은 UIKit 프레젠테이션이라 해체 전환이 진행 중일 때 부모 커버 닫기 요청이
    /// 들어오면 UIKit이 그 요청을 삼켰고(10차 UITest ⑨에서 3회 중 1회 재현), `.alert`에는
    /// 커버의 `onDismiss` 같은 완료 훅이 없어 지연으로 때울 수밖에 없었다.
    ///
    /// 이제 다이얼로그는 **같은 뷰 트리 안의 오버레이**(`PaperDialog`)다. 프레젠테이션 큐도, 겹칠
    /// 전환도 없다 — 오버레이가 사라지는 것과 부모 커버가 닫히는 것은 서로를 삼킬 수 없다.
    /// 지연을 걷어낸 뒤 취소 경로 UITest를 **10회 연속** 돌려 전부 통과하는 것으로 확인했다
    /// (10차에 이 결함이 있었을 때는 3회 중 1회 실패했다).
    private func endToBuyFlow() {
        onToBuyPresentationChange(false)
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
                      onAddedToBuy: didAddToBuy,
                      // 플릭 발주는 **앞 티켓만** — 뒤 티켓엔 0을 고정해 트리거가 전파되지 않게 한다.
                      fireTrigger: isFront ? fireTrigger : 0)
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
        .animation(ReffiMotion.gated(.easeOut(duration: ReffiJudgeZone.fade), reduce: reduceMotion),
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
        .animation(ReffiMotion.gated(.easeOut(duration: ReffiJudgeZone.hotDuration), reduce: reduceMotion),
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
        let target = CGSize(width: p.width / mag * 640, height: p.height / mag * 640)
        // 날려보낸 **그 티켓**을 기억해 두고, 0.18초 뒤에도 여전히 맨 앞일 때만 덱을 돌린다.
        // 그 사이에 다른 경로(접근성 "Next ticket" 액션, 날아가는 카드 위에서 시작된 새 플릭)가
        // 이미 덱을 돌렸으면 여기서 한 번 더 돌게 되고, 사용자가 보지도 못한 티켓이 조용히 넘어간다
        // (그 카드가 제스처를 쥔 채 뒤로 밀리면 onEnded가 오지 않아 축 잠금까지 남는다).
        let flicked = deck.first
        withAnimation(.easeOut(duration: 0.2)) { dragOffset = target }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            guard deck.first == flicked else { return }
            advance()
        }
    }

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
                    .frame(width: 44, height: 44)   // 시각 18pt, 히트 44pt(§7.3)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.paperPress)
            .accessibilityLabel(Text("Open recipe videos"))
            .accessibilityHint(Text("Opens YouTube in your browser"))
        }
        .padding(.leading, ReffiSpace.s4)
        .padding(.trailing, ReffiSpace.s1)
        .frame(minHeight: 44)
        .background {
            let shape = PaperRect(cornerRadius: ReffiRadius.sm, seed: 5)
            shape.fill(ReffiColor.paper)
                .paperEdge(shape, tint: ReffiColor.ink.opacity(0.08))
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
                // 재고는 있는데 덱이 빈 경우. 예전엔 원인이 '이름이 사전과 안 맞음' 하나였지만,
                // 부족 재료 3개 이상을 걸러내면서(`maxMissingForRecommendation`) **재료가 모자라서**
                // 비는 쪽이 더 흔해졌다. 두 원인과 각각의 행동(장보기 / 내 레시피 추가)을 함께 말한다.
                Text("Recipes need a few more ingredients than you have.\nRestock, or add your own recipe in Profile.")
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
