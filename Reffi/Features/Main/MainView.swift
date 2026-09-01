import SwiftUI
import SpriteKit
import PhosphorSwift

/// 메인(§13) — 임박 재료 선택 + 요리하기, 단 두 가지.
/// 작업대(`FridgeStore.counterIngredients`)의 재료가 위에서 **진짜 물리로 떨어져 쌓여 그대로 남고**
/// (SpriteKit, 끌어서 던지기·탭 판정), 버튼 위엔 같은 재료의 **뱃지**가 함께 남는다.
/// 판정으로 빈 자리는 냉장고의 다음 임박 재료가 채운다(§13.6). **요리시작**을 누르면 오더 메모 캐러셀로.
/// 작업대·되돌리기 상태는 store에 살아 탭을 오가도 유지된다(undo 토스트는 RootTabView 공통).
struct MainView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(ProfileStore.self) private var profile
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 앱이 백그라운드로 내려가면 씬을 확실히 멈춘다(아래 scenePaused). `.inactive`는 **일부러 뺐다** —
    /// 앱 전환기·알림 배너 같은 잠깐의 상태에서도 씬이 멈춰 첫 프레임이 회색으로 남는다.
    @Environment(\.scenePhase) private var scenePhase
    /// 큰 글자에서 상단 블록의 배치를 가른다(아래 body) — 그 크기에선 헤더와 상태 카드만으로
    /// 뷰포트를 넘겨, 물리 필드가 자리를 다 내주고도 글자가 잘렸다.
    @Environment(\.dynamicTypeSize) private var typeSize

    // 알림 유도(프리퍼미션) — 첫 임박 재료가 생긴 순간이 가치가 증명되는 순간이다.
    // 알림은 기본 OFF + 스위치가 MyPage에만 있어, 여기서 한 번 제안하지 않으면 발견되지 않는다.
    @AppStorage(ExpiryNotifier.enabledKey) private var alertsEnabled = false
    @AppStorage("expiryAlertPromptSeen") private var alertPromptSeen = false

    // 프로필 "감각" 토글 — 씬이 이미 떠 있는 상태에서 바꿔도 다음 프레임부터 반영된다(아래 onChange).
    // 시스템 Reduce Motion이 우선이고, 이 둘은 그 위에 얹히는 사용자 선택이다(§7.4 · `ReffiFeedback`).
    @AppStorage(ReffiFeedback.hapticsKey) private var hapticsEnabled = true
    @AppStorage(ReffiFeedback.tiltKey) private var tiltEnabled = true

    /// 현재 탭으로 표시 중인지 — 아닐 때 물리 씬을 일시정지한다(배터리).
    var isActive: Bool = true
    /// 냉장고의 To buy 패인으로 데려가 달라 — 덱의 담기 흐름이 "보기"로 끝날 때 루트가 받는다.
    /// 라우터를 새로 만들지 않는다: 이 앱의 화면 전환은 전부 클로저·바인딩으로 위로 올린다
    /// (선례: `onClose`·`onFire`·`onAddMissing`). 실제 탭 전환은 `RootTabView`가 한다.
    var onOpenToBuy: () -> Void = {}

    /// SKScene 보관 박스 — @State 초기값 식은 뷰 구조체가 재생성될 때마다 평가되므로(예: undo 토스트
    /// 등장·소멸마다 RootTabView body 재평가 → MainView 재구성) 씬을 게으르게 만들어 1회만 생성한다.
    private final class SceneBox { lazy var scene = IngredientDropScene() }
    @State private var sceneBox = SceneBox()
    private var scene: IngredientDropScene { sceneBox.scene }
    @State private var deciding: Ingredient?       // Ate/Tossed 결정 중인 재료(투명 풀스크린 커버)
    @State private var showCarousel = false
    @State private var showSteps = false           // 단계별 레시피(발주 직후 + Cooking now 카드에서)
    @State private var showAdd = false
    @State private var carouselSnapshot: [RecipeRecommender.Result] = []   // 커버 입력 동결(발주 중 재랭크 방지)
    /// 빈 덱에서 호명할 위험 재고 이름 — **비-fresh 전체**(soon + urgent), 중복 제거, **앞 2개 =
    /// 앵커·파트너**(48차 E5, `invitationNames`). 덱과 **같은 틱**에 얼린다(아래 `snapshotCarousel`).
    @State private var atRiskSnapshot: [String] = []
    /// 빈 덱 + 전부 신선일 때의 초대 문안이 호명할 전체 재고 이름 — 중복 제거, **앞 2개 =
    /// 앵커·파트너**(48차 E5, `invitationNames`). 위 두 스냅샷과 **같은 틱**에 얼린다 —
    /// 따로 계산하면 문구와 검색어가 다른 시점의 재고를 본다.
    @State private var fridgeNamesSnapshot: [String] = []
    /// 오늘 요리 핀 스냅샷(48차 E6) — 티켓 used 줄의 압정 마크 판정. 덱과 같은 틱에 얼린다
    /// (커버가 열린 동안 핀이 바뀌어도 티켓 표시는 스냅샷 계약대로 고정).
    @State private var pinnedSnapshot: Set<UUID> = []
    // 개봉 확인(44차 오너 결정) — 밀봉 가공식품의 2주 주기 "개봉했나요?" 프롬프트 상태.
    @State private var showSealedCheck = false
    @State private var sealedCheckItems: [Ingredient] = []   // 스냅샷(다이얼로그가 뜬 동안 불변)
    @State private var sealedChecked: Set<Int> = []          // 체크 = 개봉했다(행 인덱스)
    @State private var sealedCheckPrompted = false           // 런치당 1회 — 탭 복귀마다 뜨면 잔소리다
    @State private var firedTicket = false         // 커버당 발주 1회 — 슬램 창의 더블 파이어 방지
    @State private var coverGeneration = 0         // 지연 닫기 타이머가 새로 연 커버를 닫지 못하게
    /// 담기 흐름(팝업 3단)이 덱 위에 떠 있다 — 켜져 있는 동안 발주 지연 닫기를 **미룬다**.
    @State private var toBuyOverDeck = false
    /// 미뤄 둔 지연 닫기 — **취소가 아니라 보류**다. 흐름이 끝나면 그대로 이어 실행한다.
    @State private var pendingDeckDismiss = false
    /// 커버가 걷힌 뒤 To buy로 간다 — 커버 해체와 탭 전환을 같은 프레임에 겹치지 않게 하는 한 칸.
    @State private var pendingToBuyJump = false
    @State private var fireHaptic = 0
    @State private var decisionHaptic = 0
    /// 필드 실측 폭 — `fieldRestHeight`의 한 줄 하한이 칩 변(폭 파생)을 알아야 해서 잰다.
    /// 첫 레이아웃 전(0)에는 행 공식만 쓰고, 폭이 잡히면 같은 프레임에 하한이 따라온다.
    @State private var fieldWidth: CGFloat = 0
    /// 필드가 실제로 받은 레이아웃 슬롯 — 드래그 하늘은 이 슬롯을 **바꾸지 않고** 위로 넘친다.
    @State private var fieldSlotHeight: CGFloat = 0
    /// 상태 카드(발주 진행/알림 배너)의 실측 높이(+상단 s3) — 드래그 하늘이 이 카드 **뒤까지** 닿는다.
    /// 카드가 없으면 0: 하늘은 카드가 있던 선(슬롯 위 dragFieldHeadroom)에서 멈춘다.
    /// 정지 캡은 더미를 껴안는 게 맞지만, 잡는 순간에는 들어 올릴 하늘이(드래그),
    /// 낳는 순간에는 떨어져 들어올 하늘이(스폰 = 화면 최상단 밖) 있어야 한다(§13.4).
    /// 슬롯 상단의 화면 기준 y — 스폰 하늘이 "화면 최상단 밖"까지 열리는 데 필요한 거리.
    @State private var fieldSlotGlobalTop: CGFloat = 0
    /// 직전 렌더의 뱃지 id — 이번에 **새로 들어온 뱃지**를 가려내 등장 스태거를 매기는 기준이다.
    @State private var knownBadgeIDs: Set<Ingredient.ID> = []

    private let margin = ReffiGrid.margin

    /// 이 프레임의 작업대 — **body 진입부에서 한 번만** 뽑아 아래로 흘린다.
    /// `store.counterIngredients`는 호출마다 재료 사전을 새로 만들고 전체를 다시 정렬하는데,
    /// 예전엔 헤더 문구·배경 어컨트·필드 캡·뱃지 행·씬 동기화 키가 각자 그것을 불러
    /// 한 body에 열 번 넘게 같은 정렬을 돌렸다(store가 바뀔 때마다, 즉 판정 한 번에 여러 번).
    /// 파생값(임박·이연 수·id 배열)도 여기서 함께 굳혀 하위가 다시 훑지 않게 한다.
    private struct CounterDigest {
        let items: [Ingredient]
        /// 뱃지 행의 ForEach·전환 트리거가 쓰는 id 배열 — 세 곳이 각자 map 하지 않게 한 번만.
        let ids: [Ingredient.ID]
        // **"맨 앞 재료의 신선도"는 여기 없다.** 그 값의 유일한 소비처가 화면 전체를 물들이던
        // 배경 어컨트였고, 배경이 앱 공통 크림 한 장이 되면서 함께 죽었다(아래 `background(_:)`).
        // 다시 넣지 마라 — 여기 서 있는 것만으로 "배경이 신선도를 지는 게 자연스럽다"는 근거가 되고,
        // 신선도는 이미 뱃지 인디케이터 바·D-day 잉크가 말한다(§2.5).
        let urgent: Int
        let soon: Int

        init(_ items: [Ingredient]) {
            self.items = items
            ids = items.map(\.id)
            var urgent = 0
            var soon = 0
            for item in items {
                switch item.freshness {
                case .urgent: urgent += 1
                case .soon:   soon += 1
                case .fresh:  break
                }
            }
            self.urgent = urgent
            self.soon = soon
        }
    }

    /// **이벤트 시점**의 작업대 — 탭·제스처·발주가 도착한 그 순간을 읽는다.
    /// body가 쓰는 `CounterDigest`와 갈라 둔 것은 의도다: 판정은 커버가 열려 있던 동안 바뀐 재고를
    /// 봐야 하고, 그리기는 이 프레임의 한 장을 봐야 한다(둘을 하나로 묶으면 한쪽이 조용히 낡는다).
    private var liveCounter: [Ingredient] { store.counterIngredients }
    private var carouselResults: [RecipeRecommender.Result] {
        // 소비 후보 = 전체 가용 재고(예약 제외) — 티켓이 쓰는 재료가 작업대 밖에 있어도
        // 함께 소비 처리돼 '실제로 썼는데 재고에 남는' 유령 재고가 생기지 않는다.
        // 프로필 취향(§5.2)을 랭킹에 실배선 — 알레르기 하드 필터·선호/기피·요리스타일 보정.
        // 핀(47차)은 여기서 따로 넘기지 않는다 — 정본이 store라 `rankedRecipes`가 자기
        // `pinnedIDs`를 `rank(pinnedIDs:)`로 항상 싣는다(호출부가 잊으면 위약이 되는 파라미터를
        // 호출부에 두지 않는다는 그쪽 주석의 계약). 이 앱의 rank 진입점은 이 한 곳뿐이다.
        Array(store.rankedRecipes(preferences: RecipePreferences(profile: profile)).prefix(3))
    }
    /// 씬 일시정지 — 다른 탭, 그리고 씬을 완전히 덮는 **풀스크린 커버**(캐러셀·조리 화면·판정)에
    /// 가려진 동안은 물리 렌더와 60Hz 모션 갱신을 멈춘다. 조리 화면(`showSteps`)은 불투명 커버라
    /// 여기서 빠지면 안 보이는 씬이 계속 돌고 손 움직임이 그 씬을 다시 깨운다.
    /// `showAdd`는 뺀다 — 풀스크린 커버가 아니라 시트(`.large` detent)라 위쪽에 표시 뷰가 남고,
    /// 시트를 닫는 순간 정지화면이 잠깐 보이는 쪽이 더 나쁘다.
    /// **백그라운드**도 포함한다 — iOS가 서스펜드하며 모션 콜백을 알아서 끊긴 하지만,
    /// 여기서 명시하면 SKView 렌더 루프까지 결정적으로 멈추고 달그락 엔진도 함께 내려간다.
    private var scenePaused: Bool {
        !isActive || scenePhase == .background || showCarousel || showSteps || deciding != nil
    }
    /// 씬 동기화 트리거 — id·이름·글리프·신선도 어느 것이 바뀌어도 칩이 따라간다.
    private func sceneSyncKey(_ counter: CounterDigest) -> [String] {
        counter.items.map { "\($0.id.uuidString)#\($0.name)#\($0.glyph.rawValue)#\($0.freshness)" }
    }

    var body: some View {
        // 이 프레임의 작업대를 여기서 **한 번만** 뽑는다(위 `CounterDigest` 주석) — 아래 조각들은
        // 전부 이 한 장을 받아 쓴다. 예전엔 조각마다 store를 다시 불러 같은 정렬이 반복됐다.
        let counter = CounterDigest(store.counterIngredients)
        return VStack(spacing: 0) {
            if typeSize.isAccessibilitySize {
                // **큰 글자에선 상단 블록이 스크롤한다.** 헤더(워드마크+날짜+미션)와 상태 카드만으로
                // 뷰포트를 넘겨서, 아래 필드가 자리를 0까지 내주고도 날짜·미션·배너가 한 줄씩으로
                // 깎였다(AX5 실측). 그 크기에서 필드를 물리는 것은 손해가 아니다: SpriteKit 노드라
                // 접근성 트리에 없는 표면이고, 거기서만 되는 일(끌어서 판정)도 바로 아래 뱃지 탭이
                // 그대로 연다 — 큰 글자를 켠 사람에게 잘린 글자 대신 온전한 글자를 준다.
                // 필드가 있던 자리를 그대로 물려받으므로(같은 위치·같은 흡수 역할) 뱃지 행과 CTA는
                // 두 배치에서 같은 자리에 못 박혀 있다. AX 크기 전환은 이 앱의 기존 처세와 같은 문법이다
                // (캡슐 네비=아이콘만, 냉장고=간편 목록).
                ScrollView {
                    VStack(spacing: 0) {
                        statusBlock(counter)
                        // 작업대가 비면 필드가 그리던 안내를 여기서 그대로 세운다 — 그릴 칩이 없는
                        // 씬은 배경일 뿐이라, 안내만 옮겨도 잃는 것이 없다. 옮기지 않으면 이 안내는
                        // 필드가 받은 몫 안에서 짓눌려 CTA 위로 겹쳐 흘렀다(AX5 실측).
                        if counter.items.isEmpty {
                            emptyField
                                .padding(.horizontal, margin)
                                .padding(.top, ReffiSpace.s6)
                        }
                    }
                }
                // 내용이 뷰포트 안에 들어오면 튕기지 않는다 — 스크롤이 생겼다는 신호는 넘칠 때만.
                .scrollBounceBehavior(.basedOnSize)
                .layoutPriority(-1)   // 아래 필드와 같은 이유로 **남는 것을 받는** 자리다
            } else {
                statusBlock(counter)
                    // 종이 카드가 **앞**, 그 뒤가 하늘 — 드래그 오버행(아래 필드의 위로 넘친 몫)이
                    // 배너 카드 밑으로 미끄러져 들어간다. 순서상 필드가 나중이라 zIndex 없이는
                    // 넘친 씬이 카드를 덮는다.
                    .zIndex(1)

                physicsField(counter)
                    // 씬의 실높이 = **항상 화면 최상단까지**(오너 결정: 물리 천장은 폰 화면 끝
                    // 가장자리 고정, 가변 금지 — 여닫는 하늘은 자이로에 안 열리고 열림도 비일관이라
                    // 걷어냈다). SwiftUI 프레임은 클립하지 않으므로 SKView가 카드·헤더 뒤로 올라서고,
                    // 레이아웃 슬롯(아래 maxHeight 프레임)은 고정이라 형제들은 미동도 하지 않는다.
                    // 리사이즈는 재료 수가 바뀔 때뿐 — 드래그·자이로·스폰이 같은 천장을 쓴다.
                    .frame(height: fieldSceneHeight(counter), alignment: .bottom)
                    .frame(maxWidth: .infinity, maxHeight: fieldRestHeight(counter), alignment: .bottom)
                    .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { r in
                        fieldWidth = r.width
                        fieldSlotHeight = r.height
                        fieldSlotGlobalTop = r.minY
                        scene.restHeight = r.height   // 존 앵커의 정본 — 하늘과 무관하게 제자리
                    }
                    // 남는 공백은 **전부 위로** 몬다 — 더미가 뱃지 바로 위에 내려앉는다.
                    // 가운데 정렬이던 시절엔 필드 상자 자체가 화면 중앙에 떠서, 칩이 상자 바닥에
                    // 정확히 붙어 있는데도 "바닥에 안 붙는다"로 읽혔다(-physLab 오버레이로 확인).
                    // 중력 방향(아래)과 더미가 앉는 자리가 어긋나면 물리가 거짓말하는 것처럼 보인다.
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    // **필드는 남는 것을 받는 자리지, 먼저 가져가는 자리가 아니다.** VStack은 같은
                    // 우선순위의 자식들에게 "남은 높이 ÷ 남은 개수"를 차례로 제안하는데,
                    // `maxHeight: .infinity`인 이 상자는 제안받은 몫을 통째로 삼킨다 — 그래서 자리가
                    // 빠듯해지면 헤더 문장이 먼저 깎였다. 순위를 낮춰 **맨 마지막에** 세우면 헤더와
                    // 상태 카드가 제 높이를 먼저 가져가고 필드가 그 나머지를 받는다(넉넉한 기본
                    // 크기에선 순서만 바뀔 뿐 값이 같다 — 픽셀 대조 완료).
                    .layoutPriority(-1)
            }

            badgeRow(counter)

            // 보조 줄(49차) — 동사만 있는 CTA는 결과를 눌러 봐야 알 수 있었다. 임박 재료가 있을 때만
            // 그 개수를 인쇄해 헤더의 "N at risk today"와 화면 아래 결정 지점을 잇는다.
            // 임박이 0이면 줄을 세우지 않는다(빈 문자열로 자리를 남기지 않는다) — 곧 먹을 것만 있을 땐
            // 미션 줄이 이미 말했으므로 CTA는 동사 하나로 돌아간다.
            PaperButton(title: "Start cooking",
                        // 문구는 **덱 티켓의 크라운과 같은 키**를 쓴다("Saves N expiring today") —
                        // 같은 사실을 두 표면이 다른 말로 하면 그게 곧 §용어 분열이고, 여기선 누르기
                        // 직전과 직후에 같은 문장이 이어져 결정이 확인된다(신규 문자열 0개).
                        subtitle: counter.urgent > 0 ? "Saves \(counter.urgent) expiring today" : nil) { cook() }
                .padding(.horizontal, margin)
                .padding(.top, ReffiSpace.s3)
                // 스크롤이 아니라 화면에 못 박힌 CTA라 **자리 예약** 쪽이다(§9.3) — 냉장고 펼침의
                // 바닥 여백과 같은 값을 본다. 홈만 자기 상수(86)를 들고 있어 네비 높이를 건드리면
                // 여기만 조용히 어긋났다.
                .padding(.bottom, ReffiChrome.navReserve)
                .disabled(counter.items.isEmpty)   // 디밍은 PaperButton이 §7.2로 처리 — 여기서 겹치면 곱해진다.
        }
        .animation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion), value: store.activeCook)
        // 가려진 패인은 배경을 세우지 않는다 — FridgeView·ProfileView와 같은 계약이다.
        // **아끼는 것은 이제 픽셀이 아니라 계약이다.** 배경이 블러 블롭 세 장이던 시절엔 이 게이트가
        // 그리기 비용의 대부분을 내리는 최적화였는데, 지금 여기 서는 것은 단색 한 장 + 시노라 비용이
        // 거의 없다. 그래도 남기는 이유는 셋이 같은 규칙을 따라야 다음에 배경에 무엇이 붙어도
        // 가려진 패인이 그것을 그리지 않기 때문이고, 무엇보다 **루트가 이미 같은 크림을 칠하고 있어서**
        // (`RootTabView`) 게이트가 닫혀도 보이는 색은 한 톨도 달라지지 않기 때문이다 — 그 일치가
        // 애니메이션 없는 `pane` 전환에서 바탕이 튀지 않는 유일한 근거다.
        .background { if isActive { PaperCanvasBackground() } }
        .reffiFeedback(.impact(weight: .medium), trigger: fireHaptic)
        .reffiFeedback(.impact(weight: .light), trigger: decisionHaptic)
        .fullScreenCover(isPresented: $showCarousel, onDismiss: {
            // 덱이 사라졌으면 그 위에 뜬 것도 없다 — 신호가 true로 굳으면 **다음 발주의 지연 닫기가
            // 영영 미뤄진다**(팝업엔 해체 완료 훅이 없어 극단 타이밍에서 실제로 굳을 수 있다).
            toBuyOverDeck = false
            pendingDeckDismiss = false
            if pendingToBuyJump {
                // 사용자가 방금 고른 목적지가 조리 화면보다 앞선다 — 여기서 조리 커버를 열면
                // 그 위에 덮여 To buy가 보이지 않는다(발주 뒤 담기 흐름에서 실제로 겹치는 경로다).
                pendingToBuyJump = false
                onOpenToBuy()
            } else if firedTicket, store.activeCook != nil {
                // 발주로 닫혔으면 곧장 단계별 레시피로 — "Cook this"의 다음 화면은 조리다.
                showSteps = true
            }
        }) {
            RecipeMemoCarousel(results: carouselSnapshot,
                               hasIngredients: !store.ingredients.isEmpty,
                               atRiskNames: atRiskSnapshot,
                               fridgeNames: fridgeNamesSnapshot,
                               onClose: { showCarousel = false },
                               onFire: fire,
                               // 패스 기록(48차 E3) — 왼쪽 플릭·"Next ticket" 액션만 이 콜백을
                               // 탄다(발주·닫기는 카루셀이 애초에 부르지 않는다). 기록은 즉시
                               // store로 가지만 열린 덱은 스냅샷이라 재랭크되지 않는다.
                               onPass: { store.recordPass(recipeID: $0) },
                               pinnedIDs: pinnedSnapshot,
                               onAddMissing: { store.addMissingToBuy($0, sourceRecipeID: $1) },
                               onToBuyPresentationChange: { active in
                                   toBuyOverDeck = active
                                   // 흐름이 끝나는 순간 미뤄 둔 닫기를 **그대로 잇는다** — 발주 뒤
                                   // 팝업에서 취소해도 ORDER · FIRED 전환은 사라지지 않는다.
                                   if !active, pendingDeckDismiss {
                                       pendingDeckDismiss = false
                                       showCarousel = false
                                   }
                               },
                               onOpenToBuy: {
                                   pendingToBuyJump = true
                                   showCarousel = false   // 탭 전환은 `onDismiss`에서 — 순서가 곧 안전이다
                               })
        }
        .fullScreenCover(isPresented: $showSteps) {
            CookingStepsView(onClose: { showSteps = false })
        }
        // 판정은 투명 풀스크린 커버 — 하단 네비까지 덮어 모달리티가 깨지지 않는다.
        .fullScreenCover(item: $deciding) { ing in
            DecisionCover(ingredient: ing,
                          reduceMotion: reduceMotion,
                          onCommit: { ate in commit(ing, ate: ate) },
                          onFreeze: { commitFreeze(ing) },
                          onCancel: { closeDecision() })
                .presentationBackground(.clear)
        }
        .sheet(isPresented: $showAdd) {
            AddIngredientSheet()   // presentationDetents는 시트 내부에서 적용(중복 방지)
        }
        // 자정 경과 — D-day·신선도 파생 UI와 씬 라벨 점을 다시 계산한다.
        // 씬에 넘기는 목록은 **그때의 재고**다(`liveCounter`) — 이 클로저는 마지막 body의 digest를
        // 붙들고 있어서, 자정이 그 뒤라면 digest는 이미 어제의 한 장이다.
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            dayTick += 1
            scene.sync(liveCounter)
        }
        // 개봉 확인(44차 오너 결정) — 밀봉 가공식품이 미개봉인 채 2주가 지나면 묻는다.
        // **확정(Apply)만 상태를 바꾼다**: 체크 = 개봉(실효 기한이 개봉 후 기한으로 줄어든다),
        // 미체크 = 확인 시각 갱신(2주 뒤 재확인). X·딤 닫기는 아무것도 바꾸지 않아 다음 런치에
        // 다시 뜬다 — 답을 안 받았는데 조용히 2주를 미루면 "묻는다"는 약속이 위약이 된다.
        .overlay {
            if showSealedCheck {
                PaperChecklistDialog(
                    title: "Anything opened yet?",
                    message: "Sealed items keep their long dates until opened. Checked ones switch to the after-opening use-by date.",
                    rows: sealedCheckItems.enumerated().map { i, ing in
                        PaperChecklistDialog.Row(id: i, name: ing.displayName, glyph: ing.glyph)
                    },
                    checked: $sealedChecked,
                    confirmTitle: "Apply",
                    allowsEmptyConfirm: true,   // 미체크 = "전부 아직 안 열었다"는 유효한 답(2주 뒤 재확인)
                    seed: 9,
                    onConfirm: confirmSealedCheck,
                    onClose: { showSealedCheck = false })
            }
        }
        .onAppear { presentSealedCheckIfDue() }
        #if DEBUG
        // `-tiltLab` — 기울기 QA용 하단 오버레이. overlay라 헤더·배너·뱃지 행·CTA 레이아웃은 그대로다.
        .overlay(alignment: .bottom) { tiltLabOverlay }
        .onAppear {   // 미리보기/검증용: `-loadSample`로 샘플 시드, `-previewCarousel 1`로 캐러셀 바로 열기.
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-loadSample"), store.isPristine {
                store.loadSampleData()
            }
            if args.contains("-previewCarousel") {
                snapshotCarousel()
                showCarousel = true
            }
            if args.contains("-previewAdd") { showAdd = true }   // 재료 추가 시트 스크린샷 검증용
            // `-cookCarousel` — 티켓 덱을 런치 시 자동 오픈(스크린샷·UI 테스트용).
            // 시드가 부모(RootTabView)의 `-uiTestSampleFridge`로 들어오는 조합도 있어 한 박자 늦게 연다(`-cookTicket` 선례).
            if args.contains("-cookCarousel") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    // 시드 자가 보장 — 스냅샷을 이 시점에 **한 번만** 읽으므로, 부모 시드가 없거나
                    // 늦으면 덱이 영구히 빈 채로 열린다(테스트는 느려지는 게 아니라 실패한다).
                    // `-cookTicket`이 loadSampleData()를 직접 부르는 선례를 따라 여기서 채운다.
                    if store.available.isEmpty { store.loadSampleData() }
                    snapshotCarousel()
                    showCarousel = true
                }
            }
            // `-cookTicket` — 조리 티켓은 fire 없인 열리지 않아 스크린샷 QA가 막힌다.
            // 진행 중 세션이 없으면 샘플로 강제 발주한 뒤 곧장 CookingStepsView를 연다.
            if args.contains("-cookTicket") {
                if store.activeCook == nil {
                    store.loadSampleData()
                    if let top = carouselResults.first { store.cook(top) }
                }
                // fire 직후 같은 프레임의 커버 프레젠테이션은 씹힌다(-fridgeExpand 선례) — 한 박자 늦게 연다.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showSteps = true }
            }
            // `-cookTicket.noSteps`(39차) — 커스텀 레시피(편집기가 단계를 더 이상 안 받아 기본
            // 빈 배열, 33c8861)로 강제 발주해 "단계 없음 → 주방 전표 링크 없음" 경로를 UI 테스트가
            // 재현할 수 있게 한다. 재료명은 샘플 시드의 첫 재료를 그대로 써 매칭을 보장한다
            // (`RecipeRecommender.result`가 이름으로 맞춰야 `cook()`이 실제로 발주된다).
            if args.contains("-cookTicket.noSteps") {
                if store.activeCook == nil {
                    store.loadSampleData()
                    if let firstName = store.sorted.first?.name {
                        let noStepRecipe = Recipe.userRecipe(name: "No-Step Test Dish",
                                                              ingredientNames: [firstName], minutes: 10)
                        store.cook(RecipeRecommender.result(for: noStepRecipe, ingredients: store.sorted))
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showSteps = true }
            }
        }
        #endif
    }

    @State private var dayTick = 0   // 자정 리렌더 트리거

    // MARK: - Tilt lab (`-tiltLab`, DEBUG)

    #if DEBUG
    /// 런치 인자 순수 파서 — `-tiltLab.x -0.9`처럼 값이 음수면 NSArgumentDomain(UserDefaults)이 `-0.9`를
    /// 다음 키로 오인해 바인딩을 통째로 잃는다(`-fridge.compact YES` 선례는 값이 항상 양수/문자라 문제가
    /// 없었다). 그래서 ProcessInfo.arguments를 직접 순회해 값을 뽑는다 — 순수 함수라 음수·클램프·누락
    /// 같은 케이스를 실기기/시뮬레이터 없이 유닛 테스트로 고정할 수 있다.
    /// `internal`(비-private) — TiltLabLaunchArgTests가 `@testable import Reffi`로 직접 호출한다.
    /// 반환: x/y는 파싱 성공 시에만 값이 실리고(실패·누락이면 nil, 다음 토큰은 소비하지 않음) -1...1로
    /// 클램프된다. labOn은 `-tiltLab` 존재, x 파싱 성공, y 파싱 성공, `-tiltLab.shake` 존재 중 하나만
    /// 참이어도 true. shake는 `-tiltLab.shake` 존재 여부.
    static func tiltLabLaunchConfig(from args: [String]) -> (x: Double?, y: Double?, labOn: Bool, shake: Bool) {
        func value(after flag: String) -> Double? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count,
                  let raw = Double(args[i + 1]) else { return nil }
            return min(1, max(-1, raw))
        }
        let x = value(after: "-tiltLab.x")
        let y = value(after: "-tiltLab.y")
        let shake = args.contains("-tiltLab.shake")
        let labOn = args.contains("-tiltLab") || x != nil || y != nil || shake
        return (x, y, labOn, shake)
    }

    /// 프로세스당 한 번만 파싱 — 아래 여러 프로퍼티가 ProcessInfo.arguments를 반복해 읽지 않도록 캐싱.
    private static let tiltLabConfig = Self.tiltLabLaunchConfig(from: ProcessInfo.processInfo.arguments)

    @State private var tiltLabX: Double = Self.tiltLabConfig.x ?? 0    // 주입 중력 x(정규화) — 오른쪽이 +
    @State private var tiltLabY: Double = Self.tiltLabConfig.y ?? -1   // 주입 중력 y(정규화) — 위가 +, 세워 든 기본 자세가 -1

    /// `-tiltLab` 또는 `-tiltLab.x/.y`(파싱 성공) 또는 `-tiltLab.shake` 중 하나만 있어도 실험실을 켠다.
    private var tiltLabOn: Bool { Self.tiltLabConfig.labOn }

    /// 기울기 실험실 — X/Y 슬라이더로 씬 중력 벡터를 직접 주입한다. 시뮬레이터엔 자이로가 없어
    /// CoreMotion 경로를 탈 수 없으므로, 굴러가는 모양 QA는 사실상 이 경로로만 가능하다.
    /// CTA 위에 얹어(하단 패딩) 요리시작 버튼은 계속 누를 수 있게 둔다.
    @ViewBuilder private var tiltLabOverlay: some View {
        if tiltLabOn {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(verbatim: "TILT LAB")
                        .reffiType(.monoEyebrow).foregroundStyle(ReffiColor.blueDark)
                    Spacer()
                    Text(verbatim: String(format: "x %.2f   y %.2f", tiltLabX, tiltLabY))
                        .reffiType(.metaText).foregroundStyle(ReffiColor.ink2)
                }
                tiltLabSlider("X", value: $tiltLabX)
                tiltLabSlider("Y", value: $tiltLabY)
                HStack(spacing: ReffiSpace.s3) {
                    Button { scene.shakeBurst() } label: {
                        Text(verbatim: "SHAKE")
                            .reffiType(.monoEyebrow)
                            .foregroundStyle(ReffiColor.onAccent)   // blue 면 위 콘텐츠(§2.7)
                            .padding(.horizontal, ReffiSpace.s3)
                            .padding(.vertical, 4)
                            .background(ReffiColor.blue, in: Capsule())
                    }
                    .buttonStyle(.reffiPress)
                    clatterCounter
                    Spacer()
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, ReffiSpace.s4)
            .padding(.vertical, ReffiSpace.s2)
            .background {
                let shape = PaperRect(cornerRadius: ReffiRadius.md)
                shape.fill(ReffiColor.paper).paperEdge(shape)
            }
            .reffiShadow1()
            .padding(.horizontal, margin)
            .padding(.bottom, ReffiChrome.navReserve + 60)
            .onAppear {
                pushTiltLab()
                scene.onClatter = { [clatterLog] in
                    clatterLog.times.append(ProcessInfo.processInfo.systemUptime)
                    if clatterLog.times.count > 240 { clatterLog.times.removeFirst(120) }
                }
                // `-tiltLab.shake` — 버튼을 코드로 못 눌러서, 런치 1.5초 뒤 버스트를 한 번 자동 발동한다
                // (재료가 자리를 잡은 뒤라야 충돌이 의미 있다). 단독 지정 시에도 tiltLabConfig.labOn이
                // true가 되어 이 오버레이(및 onAppear)가 열리므로 스케줄이 정상 발동한다.
                if Self.tiltLabConfig.shake {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { scene.shakeBurst() }
                }
            }
            .onChange(of: tiltLabX) { _, _ in pushTiltLab() }
            .onChange(of: tiltLabY) { _, _ in pushTiltLab() }
        }
    }

    /// 햅틱 발화 시각 로그 — @State가 아니라 **참조 박스**에 담는다. 초당 수십 회 발화를 @State에
    /// 쓰면 그때마다 SwiftUI가 물리 필드까지 다시 그린다. TimelineView가 자기 주기로 읽어 가면 충분하다.
    private final class ClatterLog { var times: [TimeInterval] = [] }
    @State private var clatterLog = ClatterLog()

    /// 최근 1초 햅틱 발화 수 — 시뮬레이터엔 햅틱 하드웨어가 없어 **이 숫자가 유일한 관측 수단**이다.
    /// 정지한 더미에서 0으로 떨어지는지(웅웅 방지 증명)도 여기서 본다.
    private var clatterCounter: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            let now = ProcessInfo.processInfo.systemUptime
            let recent = clatterLog.times.filter { now - $0 < 1 }.count
            Text(verbatim: "HAPTIC \(recent)/s")
                .reffiType(.metaText)
                .foregroundStyle(recent > 0 ? ReffiColor.blueDark : ReffiColor.ink2)
        }
    }

    private func tiltLabSlider(_ label: String, value: Binding<Double>) -> some View {
        HStack(spacing: ReffiSpace.s2) {
            Text(verbatim: label)
                .reffiType(.metaText).foregroundStyle(ReffiColor.ink2).frame(width: 12)
            Slider(value: value, in: -1...1)
        }
    }

    /// 슬라이더 값을 씬에 주입 — 씬은 이 값을 CoreMotion보다 우선한다.
    private func pushTiltLab() {
        scene.debugTilt = CGVector(dx: tiltLabX, dy: tiltLabY)
    }
    #endif

    // MARK: - Background

    /// 배경 — 앱 공통 크림 한 장. **이 화면도 예외가 아니다.**
    ///
    /// 여기는 원래 최임박 재료의 신선도를 받아 화면 전체를 물들이는 블러 블롭 세 장이었고, 그 위에
    /// "오늘 만료가 있으면 상단에 옅은 웜톤 시노"가 한 겹 더 있었다. 46차에 블롭을 걷은 뒤 시노만
    /// 남겨 보고 오너가 실기에서 판정했다: **그것도 걷는다.** 근거는 두 가지다.
    /// ① 블롭이 사라진 평탄한 크림 위에서 시노는 "은은한 강조"가 아니라 화면 절반을 덮은
    ///    그라데이션으로 읽혔다 — 걷어낸 층과 시각적으로 같은 종류다.
    /// ② 그 사실은 이미 세 번 말해진다: 헤드라인("N at risk today"), 뱃지의 신선도 인디케이터,
    ///    D-day 잉크. 배경은 네 번째 사본이었고, 사본은 위계를 만들지 못하고 바탕만 흐린다.
    ///
    /// **이 자리에 색을 다시 들이지 마라** — 신선도 3색이든 긴급도 한 겹이든. 배경이 상수라야
    /// 애니메이션 없는 `RootTabView.pane` 전환에서 바탕이 튀지 않고, 루트·시트·도킹 CTA·하단
    /// 마스크가 칠하는 `canvas`와 이음매 없이 만난다(46차 §13.2).

    // MARK: - 상단 블록 · 뱃지 행 (두 배치가 함께 쓰는 조각)

    /// 헤더 + 상태 카드 — 못 박힌 배치(기본 크기)와 스크롤 배치(큰 글자)가 **같은 한 장**을 본다.
    /// 손으로 두 번 쓰면 한쪽만 조용히 어긋난다(판정 커버 `outcomeButtons`와 같은 이유).
    @ViewBuilder private func statusBlock(_ counter: CounterDigest) -> some View {
        header(counter)
            .padding(.horizontal, margin)
            // **세 루트 페이지의 제목이 같은 높이에서 시작한다**(23차). 냉장고·프로필이 둘 다
            // `s5`인데 홈만 `s2`라 탭을 오갈 때 제목이 16pt 튀었다(실측: 홈 78.3pt vs 나머지 94.5pt).
            // 남는 세로 공간은 이 블록 **아래에 오는 상자**가 흡수한다(기본 크기=`physicsField`의
            // `maxHeight: .infinity` + 바닥 정렬, 큰 글자=그 자리를 물려받은 스크롤 상자) — 그래서
            // 더미가 앉는 자리는 그대로다(필드는 `fieldRestHeight`로 이미 캡이 걸려 있다).
            .padding(.top, ReffiSpace.s5)

        // 발주 진행 카드(§13.6 C) — 헤더 아래 죽은 공간이 상태 표면이 된다.
        if let cook = store.activeCook {
            cookingNowCard(cook)
                .padding(.horizontal, margin)
                .padding(.top, ReffiSpace.s3)
                .transition(.move(edge: .top).combined(with: .opacity))
        } else if showAlertPrompt(counter) {
            alertPromptCard
                .padding(.horizontal, margin)
                .padding(.top, ReffiSpace.s3)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ViewBuilder private func badgeRow(_ counter: CounterDigest) -> some View {
        if !counter.items.isEmpty {
            badgeScroll(counter)
                .padding(.bottom, ReffiSpace.s2)
                .id(dayTick)   // 자정 경과 시 D-day·신선도색 재계산
        }
    }

    // MARK: - Header

    /// `statusBlock`의 `margin`·`s5`는 이미 세 루트 페이지의 상단 오프셋을 맞춘 값이다(23차 주석) —
    /// 하지만 그 값은 바깥 패딩일 뿐, 이 VStack 자체가 내용 폭(워드마크 글자 폭)만큼만 좁게 잡히면
    /// `body`의 바깥 VStack(정렬 지정 없음 = 기본 `.center`)이 이 좁은 블록을 통째로 화면 가운데로
    /// 밀어 버린다 — 실측(43차, 스크린샷 대조): 워드마크가 margin(16)이 아니라 사실상 센터 정렬로
    /// 떴다. Fridge `titleRow`가 쓰는 `.frame(maxWidth: .infinity, alignment: .leading)`를 그대로
    /// `wordmark`에 옮겨 헤더가 전체 폭을 먹고 leading에 고정되게 한다 — 타이틀→캡션 간격도 같은 김에
    /// Fridge `fridgeHeader`의 "제목-본문 간격" 문법(s3)으로 올린다(옛 값 s1은 이 정렬 버그와 무관하게
    /// 그냥 좁았다).
    ///
    /// **49차 — 위계 역전을 바로잡는다.** 화면에서 가장 큰 글자가 워드마크(34pt)였는데 그건 오늘에
    /// 대해 아무것도 말하지 않고, 정작 이 화면의 유일한 판단 근거인 미션 문장은 `caption`(14)로
    /// 네 번째 단에 앉아 있었다 — 정보 가치와 글자 크기가 정확히 반대였다(레퍼런스 감사: 홈 대시보드는
    /// 예외 없이 **상태 문장**을 화면 최대 글자로 세우고 날짜를 그 위 작은 아이브로로 둔다).
    /// 램프를 `metaText`(13 muted 날짜) → `display`(34 워드마크) → `heading`(24 미션)으로 다시 짜
    /// 브랜드는 브랜드 자리에 남기고 **읽어야 할 문장이 가장 크게** 선다.
    /// 계층 순증은 0이다 — `caption`이 빠지고 `heading`이 들어오며, 날짜의 `metaText`는 캡슐 네비가
    /// 이미 쓰는 role이라 이 화면에 새 단을 만들지 않는다(§3.3 상한 7).
    private func header(_ counter: CounterDigest) -> some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            todayLine
            wordmark
            // 미션 헤더(D) — 오늘의 상태를 한 문장으로. 누계(Ate/Tossed)는 MyPage가 맡는다.
            // **빈 작업대에서는 이 줄이 서지 않는다(43차, 오너 결정 — 같은 말 두 번 금지).**
            // 빈 상태 블록(emptyField)이 같은 화면에서 "무엇을 하라"를 이미 가르치는데 캡션까지
            // "채우라"고 말하면 한 화면에 같은 지시가 네 겹이었고, 냉동·예약만 남은 분기에선
            // 빈 상태("냉장고 탭 확인")와 캡션("채우라")의 지시가 서로 갈리기까지 했다.
            // 지시는 빈 상태 블록 한 곳에 통합하고, 미션 줄은 셀 것이 있을 때만 선다.
            if let mission = missionText(counter) {
                mission
                    // 캡션이 아니라 **헤드라인**이다(49차) — 그래서 색도 ink2가 아니라 ink다.
                    .reffiType(.heading)
                    .foregroundStyle(counter.urgent > 0 ? ReffiColor.urgentDark : ReffiColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, ReffiSpace.s1)   // 워드마크와 한 덩어리로 붙지 않게 한 단만
            }
        }
    }

    /// 오늘 날짜 아이브로(49차) — 워드마크 위 작은 시간 앵커. 데이터형 메타라 role은 `metaText`,
    /// 잉크는 `muted`(§3.5 갈림길: 문장형은 caption, 데이터형은 metaText).
    /// 날짜 자체는 **기기 로케일**을 따른다(§13.6 38차 정책 — 앱 언어 선택과 분리).
    private var todayLine: some View {
        Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
            .reffiType(.metaText)
            .foregroundStyle(ReffiColor.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 브랜드 워드마크 — 비번역 라틴(Story Script). `maxWidth: .infinity` + leading은 글자를 늘이는
    /// 게 아니라(텍스트는 여전히 제 폭만큼만 그려진다) 이 뷰의 **레이아웃 폭**을 전체로 넓혀 위 `header`
    /// VStack이 화면 가운데로 밀리지 않게 고정하는 앵커다 — Fridge `titleRow`와 동일한 트릭.
    private var wordmark: some View {
        Text(verbatim: "Reffi").reffiType(.display).foregroundStyle(ReffiColor.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func missionText(_ counter: CounterDigest) -> Text? {
        if counter.items.isEmpty { return nil }   // 빈 상태 블록이 지시를 전담한다(위 주석)
        if counter.urgent > 0 { return Text("\(counter.urgent) at risk today. Cook one?") }
        if counter.soon > 0 { return Text("\(counter.soon) to eat soon. Plan tonight?") }
        // 임박이 없을 때도 **다음 한 걸음**을 지목한다 — "미리 해치우라"는 재촉만 남기면
        // 무엇부터인지가 없어 행동으로 이어지지 않는다(냉장고 정렬 기본값과 같은 순서를 말한다).
        return Text("All fresh. Cook the oldest one first.")
    }

    // MARK: - 알림 유도 배너 (프리퍼미션)

    /// 임박 재료가 있고 알림이 꺼져 있고 아직 제안 안 했을 때 한 번만.
    private func showAlertPrompt(_ counter: CounterDigest) -> Bool {
        !alertsEnabled && !alertPromptSeen && (counter.urgent + counter.soon) > 0
    }

    /// 미니 영수증 스트립(Cooking now와 같은 자리·같은 언어) — 켜기 / 나중에.
    ///
    /// 아이브로+문구 | 켜기 | 나중에 **3열 고정**이던 자리다. 큰 글자에선 셋이 한 줄에서 폭을 나눠
    /// 가지느라 전부 잘렸다(AX5 실측: 'MOR NIN…' · 'Kno…' · 'Tur n…') — 하나를 줄여 봐야 그 하나만
    /// 죽으므로 **배치를 통째로 접는다**: 문구 블록 위, 버튼 행 아래. 한 줄이 들어가는 크기에선
    /// 첫 후보가 그대로 뽑혀 렌더가 변하지 않는다(§3.3, 판정 커버 `outcomeRow`와 같은 처방).
    private var alertPromptCard: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: ReffiSpace.s3) {
                alertPromptCopy
                Spacer(minLength: ReffiSpace.s2)
                alertPromptActions
            }
            VStack(alignment: .leading, spacing: ReffiSpace.s1) {
                alertPromptCopy
                HStack(spacing: ReffiSpace.s3) {
                    alertPromptActions
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, ReffiSpace.s4)
        .padding(.vertical, ReffiSpace.s1)
        .frame(minHeight: ReffiChrome.tapMin)
        .background {
            let shape = ReceiptShape(tooth: ReffiTooth.chip)
            shape.fill(ReffiColor.paper).paperEdge(shape)
        }
        .reffiShadow1()
    }

    /// 두 배치가 **같은 문구 블록**을 본다 — 손으로 두 번 쓰면 한쪽만 조용히 어긋난다.
    /// 한 줄 제한을 두지 않는 것이 세로 폴백의 전부다: 접힌 뒤에는 폭이 온전하니 잘릴 이유가 없고,
    /// 가로 후보의 **이상 폭**은 줄 수와 무관하므로(한 줄 기준) 어느 배치를 고를지는 그대로다.
    private var alertPromptCopy: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s0) {
            Text(verbatim: "MORNING ALERTS")
                .reffiType(.monoEyebrow).foregroundStyle(ReffiColor.blueDark)
            Text("Know before food turns")
                .reffiType(.badgeLabel)
                .foregroundStyle(ReffiColor.ink)
                .minimumScaleFactor(ReffiShrink.chrome)
        }
    }

    /// 켜기 · 나중에 — 두 배치가 같은 순서로 세운다(위 `alertPromptCopy`와 같은 이유).
    @ViewBuilder private var alertPromptActions: some View {
        Button { enableAlerts() } label: {
            Text("Turn on")
                .reffiType(.pillLabel)
                .foregroundStyle(ReffiColor.blueDark)
                .padding(.horizontal, ReffiSpace.s3)
                .padding(.vertical, ReffiSpace.s2)
                // §13.1 종이컷 8각형(캡슐 금지) — 바로 아래 Start cooking(PaperButton)과 같은 재질 언어.
                // 다만 면은 채우지 않는다: blue 솔리드 면은 한 화면에 하나(Start cooking)뿐이어야
                // 부차 액션이 F패턴 #1을 가져가지 않는다(§2.4 5% 강조 배분, 감사 R3-1).
                .background {
                    let s = PaperCutRect(seed: 3)
                    // 면은 subRaised(§2.8·42차 — 이 칩은 종이 배너 카드 위라 sub는 다크에서 사라진다),
                    // 단면은 정본 `paperEdgeAccent`(α .18)다 — 옛 리터럴 .38은 강조 단면 토큰의 2배로,
                    // 부차 액션의 단면이 조리 티켓의 강조 종이보다 강하게 우는 역전을 만들었다(42차).
                    s.fill(ReffiColor.subRaised)
                        .paperEdge(s, tint: ReffiColor.paperEdgeAccent(ReffiColor.blueDark))
                }
                .frame(minHeight: ReffiChrome.tapMin)
                .contentShape(Rectangle())
        }
        .buttonStyle(.reffiPress)
        Button { withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) { alertPromptSeen = true } } label: {
            Text("Later")
                .reffiType(.pillLabel)
                .foregroundStyle(ReffiColor.ink2)
                .frame(minWidth: ReffiChrome.tapMin, minHeight: ReffiChrome.tapMin)
                .contentShape(Rectangle())
        }
        .buttonStyle(.reffiPress)
    }

    /// 켜기 — 시스템 권한 요청 후 성공 시 즉시 스케줄. 거부해도 다시 조르지 않는다(seen 처리).
    private func enableAlerts() {
        Task {
            let granted = await ExpiryNotifier.requestAuthorization()
            withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                alertPromptSeen = true
                if granted {
                    alertsEnabled = true
                    ExpiryNotifier.reschedule(for: store.ingredients)
                }
            }
        }
    }

    // MARK: - Cooking now (발주 진행 카드)

    /// 발주 후 "지금 요리 중" — 탭하면 단계별 레시피로 복귀(완료는 그 화면에서).
    /// 셰입은 CTA급(§13.5 `PaperCutRect` + 그레인 + `shadow-1`)이다 — 룰 ⑩이 규정한
    /// "몰입 커버 진입 = 눈에 띄는 CTA"에 맞춘다(감사 R3-3). 색은 종이 면을 유지해
    /// 바로 아래 Start cooking(blue 솔리드)과 경쟁하지 않는다.
    private func cookingNowCard(_ cook: FridgeStore.CookSession) -> some View {
        Button { showSteps = true } label: {
            HStack(spacing: ReffiSpace.s3) {
                VStack(alignment: .leading, spacing: ReffiSpace.s0) {
                    Text(verbatim: "COOKING NOW")
                        .reffiType(.monoEyebrow).foregroundStyle(ReffiColor.blueDark)
                    // 요리명과 경과 시간도 알림 배너와 같은 고정 2열이었다 — 큰 글자에선 둘이 남은
                    // 폭을 나눠 갖느라 이름이 먼저 잘리고 경과가 그 뒤를 따랐다. 한 줄이 들어갈 때만
                    // 한 줄로 두고, 안 들어가면 아래로 접는다(이름이 폭을 다투지 않고 순서도 그대로).
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 6) {
                            cookName(cook)
                            cookElapsed(cook)
                        }
                        VStack(alignment: .leading, spacing: ReffiSpace.s0) {
                            cookName(cook)
                            cookElapsed(cook)
                        }
                    }
                }
                Spacer(minLength: ReffiSpace.s2)
                ReffiIcon.chevron.reffi(15, .bold).foregroundStyle(ReffiColor.blueDark)
            }
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s3)
            .frame(minHeight: 56)
            .background {
                let s = PaperCutRect(seed: 5)                      // 메인 CTA(PaperButton)와 같은 8각형
                s.fill(ReffiColor.paper)
                    .overlay(PaperGrain(seed: 27, strength: 0.7).clipShape(s))   // 옅은 질감
                    .paperEdge(s)
                    .compositingGroup()
                    .reffiShadow1()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel(Text("Continue cooking \(cook.recipeName)"))
    }

    /// 두 배치가 같은 이름 한 장을 본다. 두 줄까지 푸는 것은 접힌 뒤의 이야기다 — 가로 후보는
    /// **한 줄 이상 폭**으로 재므로(줄 수와 무관) 어느 배치를 고를지는 그대로고, 세로로 접힌 다음엔
    /// 폭이 온전하니 긴 요리명이 잘릴 이유가 없다(판정 커버의 재료명과 같은 처방).
    private func cookName(_ cook: FridgeStore.CookSession) -> some View {
        Text(verbatim: cook.recipeName)
            .reffiType(.badgeLabel)
            .foregroundStyle(ReffiColor.ink)
            .lineLimit(2)
            .minimumScaleFactor(ReffiShrink.chrome)
    }

    private func cookElapsed(_ cook: FridgeStore.CookSession) -> some View {
        // 상대 시간 표기는 기기 로케일을 따른다(38차 — 앱 언어 선택과 분리, `AppLanguage.swift` 근거).
        Text(cook.startedAt, style: .relative)
            .environment(\.locale, .autoupdatingCurrent)
            .reffiType(.metaText)
            .foregroundStyle(ReffiColor.ink2)
    }

    // MARK: - Physics field (real engine, persistent pile)

    /// 정지 상태 필드 높이의 상한 — "쉬고 있는 더미"에 필요한 만큼만 자리를 잡는다.
    /// 필드가 화면 끝까지 늘어나면 중력에 눕는 더미는 바닥에 붙고 위쪽 여유가 통째로
    /// 빈 띠로 남아, 배너와 더미 사이가 뷰포트의 4분의 1이 됐다(감사 R3-4).
    /// 낙하 스폰은 씬 바깥 절대 좌표(`size.height + 700`)라 드라마는 이 캡과 무관하다.
    /// 칩은 화면 폭에서 3열로 눕으므로 행 수 = ⌈n/3⌉, 행 피치·바닥 여유는 실측값이다.
    /// **스프라이트 몫을 더 얹지 않는다(2026-08 실측으로 기각) — 단, 한 줄에는 예외가 실재했다.**
    /// 칩 스프라이트는 `chipSide` 정사각인데 충돌 바디는 그 높이의 0.28~0.71뿐이라 "그림이 캡 위로
    /// 잘리는 것 아닌가"를 의심할 만하고, `-physLab` 5회 실측(여러 행 더미)에서는 안착 그림 최상단이
    /// 캡을 11~13pt 밑돌았다(잘림 0건). 그러나 그 실측은 **행이 눕고 맞물리는 더미**의 이야기다 —
    /// 재료 ≤3이면 캡이 124pt로 떨어지는데 키 큰 글리프의 그려지는 높이(알파 bbox ≈ 0.78×칩 변,
    /// 402pt 폭에서 ≈131pt)가 그보다 크다. 밀폐 천장은 칩 **중심**만 지키므로 정착은 정상으로 끝나고
    /// 일러스트 상단만 프레임 경계에서 수평으로 잘렸다(2026-08-18 실기 재현: milk 게이블 소실).
    /// 그래서 행 공식 위에 씬이 계산한 한 줄 하한(`minRestFieldHeight`)을 깐다 — 칩 기하의 정본은 씬이다.
    /// 여유를 "전 행"에 얹으면 `sealedCeiling`이 함께 올라가 더미가 40pt 더 쌓인다(실측) — 그건 여전히 하지 않는다.
    private func fieldRestHeight(_ counter: CounterDigest) -> CGFloat {
        guard !counter.items.isEmpty else { return .infinity }   // 빈 작업대(카피·CTA)는 캡 대상이 아니다
        let rows = 96 * ceil(CGFloat(counter.items.count) / 3) + 28
        guard fieldWidth > 0 else { return rows }
        // 정지 캡: 한 개면 칩 하나의 키, 둘부터는 2단 탑(칩 위에 선 칩)의 키가 하한이다 —
        // 행 피치(96)는 눕고 맞물린 더미의 실측이라 선 채 안착한 실배치를 못 담았다(실기 잘림 2건).
        let rest = counter.items.count == 1
            ? max(rows, IngredientDropScene.minRestFieldHeight(width: fieldWidth))
            : max(rows, IngredientDropScene.stackedRestFieldHeight(width: fieldWidth))
        return rest
    }

    /// 씬(SpriteView)의 실높이 — **항상 화면 최상단까지**(오너 결정: 물리 천장은 폰 화면 끝
    /// 가장자리 고정, 가변 금지). 슬롯(레이아웃)은 그대로 두고 위로만 넘치므로 형제 배치는 불변이고,
    /// 여닫음 자체가 없어 리사이즈 아티팩트도 없다. 자이로·드래그·스폰이 같은 천장을 쓴다.
    /// 존은 `restHeight + dragFieldHeadroom`에 앵커된다(씬 layoutZones) — 존은 제자리(오너 결정).
    private func fieldSceneHeight(_ counter: CounterDigest) -> CGFloat? {
        guard fieldSlotHeight > 0, !counter.items.isEmpty else { return nil }
        // 슬롯 상단→화면 상단 거리만큼 위로. 실측 전(0)엔 드래그 여유만큼이라도 열어 둔다.
        let toScreenTop = fieldSlotGlobalTop > 0 ? fieldSlotGlobalTop
                                                 : IngredientDropScene.dragFieldHeadroom(width: fieldWidth)
        return fieldSlotHeight + toScreenTop
    }

    private func physicsField(_ counter: CounterDigest) -> some View {
        GeometryReader { geo in
            ZStack {
                // 주의: SpriteView(isPaused:)는 초기화 시점에 멈춰 첫 프레임이 안 그려질 수 있다(회색).
                // 일시정지는 씬이 스스로 관리한다(externallyPaused ∥ idle) — 첫 프레임 이후엔
                // SKView 렌더 루프까지 멈춰(마지막 프레임 정지화면) 가려진 탭의 유휴 CPU를 없앤다.
                // `-physLab`(DEBUG) — 콜라이더 오버레이. 칩 실루엣과 실제 충돌체가 어긋나면
                // 겹침·끼임의 원인이 물리 루프가 아니라 **바디 메트릭**이라, 화면만 봐선 못 가른다.
                SpriteView(scene: scene, options: [.allowsTransparency],
                           debugOptions: physLabDebugOptions)
                    .onAppear { configureScene(size: geo.size) }
                    .onChange(of: geo.size) { _, s in scene.size = s }
                    .onChange(of: sceneSyncKey(counter)) { _, _ in scene.sync(counter.items) }
                    .onChange(of: reduceMotion) { _, v in scene.reduceMotion = v }
                    .onChange(of: scenePaused) { _, p in scene.externallyPaused = p }
                    // 프로필에서 토글하고 홈으로 돌아오면 씬은 이미 서 있다 — 값만 흘려 넣으면
                    // 씬이 센서·햅틱 엔진 수명주기를 스스로 다시 파생시킨다(재시작 불요).
                    .onChange(of: tiltEnabled) { _, v in scene.tiltEnabled = v }
                    .onChange(of: hapticsEnabled) { _, v in scene.hapticsEnabled = v }
                    // 씬은 접근성 원소를 만들지 않아 사실상 조용하지만, 그것이 **의도**임을 명시한다
                    // (42차·F51) — 다른 장식(실루엣·글리프 더미)이 전부 명시적으로 가려진 규칙의
                    // 구멍으로 남지 않게. 판정의 대체 경로는 뱃지 행 → 판정 커버다.
                    .accessibilityHidden(true)
                if counter.items.isEmpty { emptyField }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    /// 릴리스에선 항상 빈 집합 — 진단 오버레이는 `#if DEBUG` 경로에만 존재한다.
    private var physLabDebugOptions: SpriteView.DebugOptions {
        #if DEBUG
        IngredientDropScene.physLab ? [.showsPhysics, .showsFPS] : []
        #else
        []
        #endif
    }

    private func configureScene(size: CGSize) {
        scene.scaleMode = .resizeFill
        scene.size = size
        scene.reduceMotion = reduceMotion
        scene.tiltEnabled = tiltEnabled
        scene.hapticsEnabled = hapticsEnabled
        scene.onRemove = { id in decide(id) }
        scene.onDecide = { id, wasted in gestureDecide(id, wasted: wasted) }
        scene.onPin = { id in togglePin(id) }
        // 하늘 개폐 = 드래그·스폰 수명주기. 씬이 같은 값은 재통지하지 않지만 방어적으로 비교 후 대입.
        scene.restHeight = fieldSlotHeight
        scene.externallyPaused = scenePaused
        scene.sync(liveCounter)
    }

    /// 제스처 판정(§13.6 B) — 존에 끌어다 놓으면 오버레이 없이 바로 확정. undo 토스트가 안전망.
    private func gestureDecide(_ id: UUID, wasted: Bool) {
        guard let ing = liveCounter.first(where: { $0.id == id }) else { return }
        decisionHaptic += 1
        withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) {
            if wasted { store.toss(ing) } else { store.eat(ing) }
        }
    }

    /// 핀 토글(47차) — 오른쪽 존 드래그인 = "오늘 이걸로 요리" 고정. 소비가 아니라 재료는 더미로
    /// 돌아오고, 상태는 배지 좌상단 압정과 추천 랭킹(`rankedRecipes`가 `pinnedIDs`를 스스로 싣는다)
    /// 이 보여 준다. 햅틱은 판정과 같은 축(가벼운 임팩트) — 존 커밋이라는 같은 제스처 문법의
    /// 사건이고, 꽂기/빼기 양쪽 모두 확정이라 양쪽 다 친다. 유령 id(경합)는 store가 무시한다.
    private func togglePin(_ id: UUID) {
        decisionHaptic += 1
        withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) {
            store.togglePin(id)
        }
    }

    /// 빈 작업대 — 첫 실행(데이터 전무)이면 온보딩 카피 + 샘플 CTA, 아니면 추가 유도.
    private var emptyField: some View {
        VStack(spacing: ReffiSpace.s4) {
            ReffiIcon.fridge.reffi(40).foregroundStyle(ReffiColor.muted)
            if store.isPristine {
                VStack(spacing: ReffiSpace.s1) {
                    Text("What's in your fridge?").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
                    Text("Add a few ingredients. Reffi tells you\nwhat to cook before they turn.")
                        .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                        .multilineTextAlignment(.center)
                }
            } else if !store.ingredients.isEmpty {
                // 재고는 있는데 작업대 후보가 없는 상태(전부 냉동 유예·조리 예약) — "없다"고만 하면
                // 냉장고 탭과 어긋나 보인다(실기 제보: In stock엔 있는데 홈엔 아무것도 없다).
                // 왜 비었는지와 어디서 볼 수 있는지를 말해 준다.
                VStack(spacing: ReffiSpace.s1) {
                    Text("Counter is clear").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
                    Text("Stock is waiting in the freezer or reserved for cooking. Check the Fridge tab.")
                        .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                        .multilineTextAlignment(.center)
                }
            } else {
                Text("Nothing to use yet").reffiType(.subhead).foregroundStyle(ReffiColor.ink2)
            }
            AddBadge { showAdd = true }
            if store.isPristine {
                Button {
                    withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                        store.loadSampleData()
                    }
                } label: {
                    // 캔버스 위 링크 잉크는 blueDark — 면 색인 blue는 다크 캔버스에서 대비가 무너진다(§2.2).
                    Text("Try a sample fridge")
                        .reffiType(.caption)
                        .foregroundStyle(ReffiColor.blueDark)
                        .underline()
                        .frame(minHeight: ReffiChrome.tapMin)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.reffiPress)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // 신선도 점 인디케이터(PR #4)는 §13.6 E(뱃지의 인디케이터 바·D-N과 중복 → 제거 결정)와 상충해 미채택.
    // MARK: - Badge scroll (persistent)

    /// 뱃지 행 — 긴급도순 가로 스크롤(가장 임박이 맨 앞). 끝에 ＋추가.
    /// (신선도 점 행은 뱃지의 인디케이터 바·D-N과 중복이라 제거 — §13.6 E)
    private func badgeScroll(_ counter: CounterDigest) -> some View {
        // 이번 렌더에서 **새로** 들어온 뱃지들 — 아직 `knownBadgeIDs`에 없는 것이 이번 진입분이다.
        // 영수증 스캔·샘플 냉장고처럼 한 번에 여럿이 들어오는 경로가 있어, 순서를 알아야 스태거를
        // 매길 수 있다(하나만 들어오면 목록도 하나라 지연은 0이다).
        let entering = counter.ids.filter { !knownBadgeIDs.contains($0) }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ReffiSpace.s2) {
                ForEach(Array(counter.items.enumerated()), id: \.element.id) { i, ing in
                    IngredientBadge(ingredient: ing, seed: i,
                                    pinned: store.isPinned(ing.id)) { decide(ing.id) }
                        // **진입과 이탈은 다른 사건이다.** 대칭(.scale 1.3)이면 새 뱃지가 130%에서
                        // 쪼그라들며 나타나 "방금 지운 것이 되돌아왔나"로 읽힌다. 진입은 §7.1대로
                        // 0.95에서 자라 오르고(하한 0.95 — scale(0) 금지), 이탈만 §7.5의 뿅(1.3)이다.
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95, anchor: .center).combined(with: .opacity)
                                .animation(ReffiMotion.gated(ReffiMotion.pop.delay(badgeEnterDelay(ing.id, in: entering)),
                                                             reduce: reduceMotion)),
                            removal: .scale(scale: 1.3, anchor: .center).combined(with: .opacity)))   // 뿅 사라짐
                }
                AddBadge(seed: counter.items.count) { showAdd = true }
            }
            .padding(.horizontal, margin)
            // 세로 s1은 행의 숨쉴 틈(레이아웃 리듬)이다. "그림자 여유"라던 옛 주석은 절반 거짓 —
            // reffiShadow1의 원거리 층(y8 + blur10)은 4pt를 한참 넘어 ScrollView 기본 클립에
            // 수평으로 잘렸고(오너 47차: "Start cooking 위에 잘린 그림자 모양"), 그림자를 살리는
            // 것은 이 패딩이 아니라 아래 `scrollClipDisabled`다.
            .padding(.vertical, ReffiSpace.s1)
        }
        // 배지 그림자·핀 압정은 종이 밖으로 드리우고 걸친다 — 가로 ScrollView의 기본 클립이
        // 그 몫을 잘라내던 것을 푼다. 패딩을 그림자만큼(18pt+) 키우는 대안은 행 높이를 부풀려
        // 필드·CTA 자리를 깎으므로 클립 해제가 정답이다. 가로로 새어 보일 걱정은 없다 —
        // 행은 원래 화면 폭을 다 쓰고, 스크롤로 밀려난 콘텐츠는 물리적으로 화면 밖이다.
        .scrollClipDisabled()
        .animation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion), value: counter.ids)
        // 진입분 판정 기준을 다음 변화로 넘긴다. `initial: true`로 첫 표시에서 채워 두지 않으면,
        // 나중에 한 개를 더해도 화면에 있던 전부가 "새로 들어온 것"으로 읽혀 엉뚱한 지연을 받는다.
        .onChange(of: counter.ids, initial: true) { _, now in knownBadgeIDs = Set(now) }
    }

    /// 여럿이 한꺼번에 들어올 때의 등장 지연(초) — 한 덩어리가 통째로 커지는 대신 하나씩 놓인다.
    /// 40ms는 §7.1 dur-1(120ms)의 1/3로, 앞뒤 뱃지의 팝이 겹치되 순서는 보이는 간격이다.
    /// 여섯 번째부터는 같은 지연으로 묶는다 — 스캔으로 열 개가 들어와도 마지막이 0.2초 넘게
    /// 늦으면 "느리게 뜬다"가 되지, 스태거로 읽히지 않는다.
    private func badgeEnterDelay(_ id: Ingredient.ID, in entering: [Ingredient.ID]) -> Double {
        guard let i = entering.firstIndex(of: id) else { return 0 }
        return Double(min(i, Self.badgeStaggerCap)) * Self.badgeStagger
    }

    private static let badgeStagger: Double = 0.04
    private static let badgeStaggerCap = 5

    // MARK: - Ate / Tossed decision

    /// 재료 탭 → "먹었나 버렸나" 묻기. 커버 자체의 슬라이드 애니메이션은 끄고 카드가 pop-in 한다.
    private func decide(_ id: UUID) {
        guard let ing = liveCounter.first(where: { $0.id == id }) else { return }
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { deciding = ing }
    }

    /// 커버 해체 — 여기 도착할 때 카드는 **이미 흐려져 있다**(`DecisionCover.close`가 §7.1 이탈을
    /// 먼저 재생하고 부른다). 그래서 `fullScreenCover`의 시스템 슬라이드만 끄면 되고, 이 시점의
    /// 0프레임 컷은 보이지 않는 것을 치우는 일이다.
    private func closeDecision() {
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { deciding = nil }
    }

    /// 선택 확정 → store에서 제거(실루엣·뱃지 뿅 사라짐) + 이력 기록 + 되돌리기 창(토스트는 탭 공통).
    private func commit(_ ing: Ingredient, ate: Bool) {
        decisionHaptic += 1
        closeDecision()
        withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) {
            if ate { store.eat(ing) } else { store.toss(ing) }
        }
    }

    /// 냉동(버리기 직전 구제) — 유예 14일의 새 시계를 받고 작업대에서 빠진다(유예 임박에 재등장).
    private func commitFreeze(_ ing: Ingredient) {
        decisionHaptic += 1
        closeDecision()
        withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) {
            store.freeze(ing)
        }
    }

    // MARK: - 개봉 확인(44차)

    /// 밀봉 확인 프롬프트 — 대상이 있으면 런치당 한 번만 띄운다. 목록은 스냅샷으로 얼린다
    /// (다이얼로그가 떠 있는 동안 재고가 바뀌어도 행 인덱스와 재료의 대응이 흔들리면 안 된다).
    private func presentSealedCheckIfDue() {
        guard !sealedCheckPrompted else { return }
        let due = store.sealedCheckDue
        guard !due.isEmpty else { return }
        sealedCheckPrompted = true
        sealedCheckItems = due
        sealedChecked = []
        showSealedCheck = true
    }

    private func confirmSealedCheck() {
        let opened = Set(sealedChecked.compactMap { i in
            sealedCheckItems.indices.contains(i) ? sealedCheckItems[i].id : nil
        })
        let still = Set(sealedCheckItems.map(\.id)).subtracting(opened)
        store.applySealedCheck(opened: opened, stillSealed: still)
        showSealedCheck = false
    }

    // MARK: - Cook / Fire the Ticket

    /// 커버 입력(덱·호명 이름·핀)을 **한 번에** 얼린다.
    /// 따로 계산하면 발주로 store가 바뀌는 사이에 서로 다른 시점의 재고를 보게 된다.
    private func snapshotCarousel() {
        let results = carouselResults
        let stock = store.available
        carouselSnapshot = results
        pinnedSnapshot = store.pinnedIDs   // 티켓 압정 마크(48차 E6) — 덱과 같은 틱에 동결
        // 호명은 문장 안에 들어가는 **표시 이름**이다 — 저장 `name`은 담던 순간 표기라 로케일이 박제된다
        // (§Ingredient.displayName). 빈 덱 문구와 그 옆 영상 검색어가 같은 배열(`atRiskSnapshot`)을
        // 쓰므로 여기 한 곳만 고르면 된다.
        //
        // 48차 E5 — 두 분기(위기 호명·초대 문안)가 **같은 앵커·파트너 규칙**으로 앞 2개를 세운다.
        // 파트너 후보는 각 분기의 자기 풀 안이다: 위기 분기 문구("won't last long")가 신선 재료를
        // 파트너로 부르면 문장이 거짓이 된다 — 풀을 갈라 문안의 참을 지킨다.
        let uncovered = RecipeRecommender.uncoveredUrgent(ingredients: stock, results: results)
        atRiskSnapshot = Self.invitationNames(pool: stock.filter { $0.freshness != .fresh },
                                              uncovered: uncovered)
        fridgeNamesSnapshot = Self.invitationNames(pool: stock, uncovered: uncovered)
    }

    /// 빈 덱 초대의 호명 순서(48차 E5) — 반환 배열의 **앞 2개가 곧 호명 쌍**이다(덱 뷰는
    /// `prefix(2)`만 읽는다 — `RecipeMemoCarousel.spoken`). 문안·YouTube 쿼리 구조는 불변, 선정만 바뀐다.
    ///
    /// **앵커** = 덱이 못 다루는 첫 urgent(`RecipeRecommender.uncoveredUrgent` — 41차에 홈 배너
    /// UI가 철거된 뒤 휴면이던 API의 소생이다. 철거된 것은 배너 UI지 함수 의미론이 아니고, 여기
    /// 소비처는 **문안 앵커 선정**이다 — 배너를 되살리는 것이 아니다), 없으면 풀의 최임박
    /// (= 현행 첫 항목과 동일 — 앵커 소생이 거부돼도 이 폴백만으로 항목이 성립한다).
    /// **파트너** = 나머지 중 시드 공출현(`RecipeCatalog.cooccurrence`) 최대 — "같이 요리된 증거"가
    /// 있는 조합이 문안·검색 쿼리로 나간다(현행 무검증 앞 2개는 "연어+요거트"류 조합을 내보낼 수
    /// 있었다). 동률은 임박순(풀 순서 안정 스캔), **전부 0이면 현행 2번째 폴백** — 128편 코퍼스에서
    /// 공출현 부재는 기대값 그 자체라 나쁜 궁합의 증거가 아니다(소프트 선호, 하드 필터 금지).
    /// 폴백 보장 덕에 이 변경의 하방은 현행과 동일하다(개악 불가능 구조).
    ///
    /// 순수 함수(뷰 상태 무접촉) — 두 분기가 같은 규칙을 타도록 한 곳에 두고, 유닛 테스트가
    /// 고정할 수 있게 한다(`fireDismissDelay(from:)` 선례).
    static func invitationNames(pool: [Ingredient], uncovered: [Ingredient]) -> [String] {
        // 표시 이름 중복 제거(44차 — "양파 그리고 양파" 방지). 임박순 입력이라 첫 등장이 곧 최임박.
        var seen = Set<String>()
        let unique = pool.filter { seen.insert($0.displayName).inserted }
        guard unique.count > 1 else { return unique.map(\.displayName) }
        // 앵커 대조는 표시 이름이다 — 중복 제거가 같은 이름의 뒤 항목을 걷어낸 뒤라 id 대조는
        // 정확히 그 경우(같은 이름 두 줄 중 뒤가 uncovered)에 빗나간다.
        let anchorIndex = uncovered.first
            .flatMap { u in unique.firstIndex { $0.displayName == u.displayName } } ?? 0
        var rest = unique
        let anchor = rest.remove(at: anchorIndex)
        var partnerIndex = 0
        if let anchorCanon = canon(anchor) {
            var best = 0
            for (i, candidate) in rest.enumerated() {
                guard let c = canon(candidate) else { continue }
                let n = RecipeCatalog.cooccurrence(anchorCanon, c)
                if n > best { best = n; partnerIndex = i }   // 초과만 갱신 — 동률은 임박순 첫 항목
            }
        }
        let partner = rest.remove(at: partnerIndex)
        return [anchor.displayName, partner.displayName] + rest.map(\.displayName)
    }

    /// 재고 한 줄의 캐논 — 해석 완료면 그대로, 아니면 사전 역조회. 엔진 `stockCanon`과 같은 눈이다
    /// (그쪽은 private — 식이 한 줄이라 재작성이 결합 해제보다 싸다는 판단. 갈리면 공출현 조회만
    /// 빗나가고 폴백이 받는다 — 매칭·소비 경로와는 무관하다).
    private static func canon(_ ing: Ingredient) -> String? {
        ing.canonicalID ?? IngredientLexicon.shared.canonicalID(for: ing.name)
    }

    private func cook() {
        guard !liveCounter.isEmpty else { return }
        snapshotCarousel()   // 발주로 store가 바뀌어도 커버 입력은 고정(재랭크 방지)
        firedTicket = false
        coverGeneration += 1                 // 이전 발주의 지연 닫기 타이머 무효화
        // 커버 표시를 한 틱 지연 — 80레시피 스코어링(carouselResults)과 커버 첫 프레임이
        // 같은 틱에 겹쳐 프레임드롭 나지 않게 랭킹 계산 틱과 표시 틱을 분리한다.
        DispatchQueue.main.async { showCarousel = true }
    }

    /// 티켓 발주(Fire the Ticket) — used 재료를 이 레시피로 전량 소비 처리 → 슬램 본 뒤 커버 닫기.
    /// 되돌리기 토스트는 store의 통합 undo가 띄운다. 커버당 1회만(더블 파이어 방지).
    ///
    /// **이 창 안에 덱 위로 팝업이 뜰 수 있다**(담기 3단 팝업, 2026-08). 그때 커버를 그냥 닫으면
    /// 사용자가 방금 띄운 질문이 부모와 함께 걷힌다 — 그래서 닫기는 취소가 아니라 **보류**가 되고,
    /// 흐름이 끝나는 순간 이어서 실행된다(`onToBuyPresentationChange`). 세대 검사는 그대로다.
    private func fire(_ result: RecipeRecommender.Result) {
        guard !firedTicket, !result.used.isEmpty else { return }
        firedTicket = true
        fireHaptic += 1
        // 스토어 변이는 애니메이션 밖에서 — 슬램 연출은 OrderMemoCard 로컬 fired 상태가 구동하고,
        // 메인 뱃지·씬 변화는 커버 뒤라 애니메이션이 필요 없다(전환 프레임드롭 방지).
        store.cook(result)
        let gen = coverGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.fireDismissDelaySeconds) {
            guard coverGeneration == gen else { return }   // 새로 연 커버는 닫지 않는다
            if toBuyOverDeck { pendingDeckDismiss = true } else { showCarousel = false }
        }
    }

    /// 발주 후 덱 커버가 닫히기까지의 유예(초) — 슬램 도장을 볼 시간이다.
    /// 이름을 아래 순수 함수와 다르게 둔 것은 의도다(같은 이름이면 프로퍼티 호출로 읽혀 모호해진다).
    private static var fireDismissDelaySeconds: Double {
        #if DEBUG
        return fireDismissDelay(from: ProcessInfo.processInfo.arguments)
        #else
        return defaultFireDismissDelay
        #endif
    }

    static let defaultFireDismissDelay: Double = 1.25

    #if DEBUG
    /// `-fireDismissDelay <초>` — 위 창을 넓히는 QA 훅. 1.25초는 UI 테스트가 "그 창 안에서 팝업을
    /// 띄우고 유예가 실제로 걸리는지"를 재현하기엔 너무 좁다(10차 선례에서 6초를 썼다).
    /// 뷰에서 분기를 늘리는 대신 **순수 함수**로 떼어 유닛 테스트로 고정한다
    /// (`FridgeTab.initial(from:)`·`tiltLabLaunchConfig` 선례). 값 파싱은 `arguments` 직접 순회다 —
    /// UserDefaults 인자로 두면 음수·소수 표기에서 바인딩을 잃는다.
    static func fireDismissDelay(from arguments: [String]) -> Double {
        guard let i = arguments.firstIndex(of: "-fireDismissDelay"), i + 1 < arguments.count,
              let value = Double(arguments[i + 1]), value > 0 else { return defaultFireDismissDelay }
        return value
    }
    #endif
}

/// Ate/Tossed 결정 — 투명 풀스크린 커버 위 딤 + 종이 카드 + 종이컷 아이콘 버튼 쌍 + 명시적 취소.
/// **오늘 만료(urgent)이고 아직 얼린 적 없는 재료**엔 3번째 선택지 Freeze가 나타난다(§13.6) —
/// 미리 얼려두기가 아니라 버리기 직전의 구제로만. 커버라서 하단 네비까지 덮인다(모달리티).
private struct DecisionCover: View {
    let ingredient: Ingredient
    let reduceMotion: Bool
    var onCommit: (Bool) -> Void
    var onFreeze: () -> Void = {}
    var onCancel: () -> Void

    @State private var shown = false
    /// 이탈 페이드가 도는 동안 잠금 — 그 창에 두 번째 판정이 들어오는 것을 막는다(아래 `close`).
    @State private var closing = false

    /// Freeze 노출 조건 — 오늘 만료(urgent) + 재냉동 아님(1회 제한). '미루기 버튼' 방지.
    private var showFreeze: Bool { ingredient.freshness == .urgent && ingredient.canFreeze }

    /// 판정 블롭 한 변 — 버튼이 셋이면 72, 둘이면 기본 88.
    /// 가장 좁은 지원 기기(375) 기준 가용 폭은 375 − 외곽 s7×2(64) − 카드 s6×2(56) = **255**인데,
    /// 88×3 + s4×2 = 296이라 41pt가 종이 밖으로 새어 나갔다. 72×3 + s4×2 = 248 ≤ 255로 들어온다
    /// (72도 §7.3 최소 터치 타깃 44를 크게 웃돈다). 두 버튼 경로는 88×2 + s6 = 204라 그대로 둔다.
    private var blobSide: CGFloat { showFreeze ? 72 : 88 }

    /// 세로 폴백의 블롭 한 변 — 행이 최대 셋 쌓이므로 가로 폼보다 작게 잡는다(56 × 3 + s3 × 2 = 192).
    /// 큰 글자에서 제목·문구가 이미 세로를 크게 먹는 커버라, 블롭을 그대로 두면 카드가 화면을 넘긴다.
    /// 56도 §7.3 최소 터치 타깃 44를 넘고, 행 전체가 타깃이라 실제로 눌리는 면은 더 넓다.
    private static let stackedBlobSide: CGFloat = 56

    var body: some View {
        ZStack {
            ReffiColor.scrim.ignoresSafeArea()
                .opacity(shown ? 1 : 0)
                .onTapGesture { close(onCancel) }
                .accessibilityHidden(true)
            card
                // 진입 하한은 0.95다(§7.1) — 0.85는 "멀리서 날아온다"라 종이 카드가 뜨는 게 아니라
                // 던져지는 것으로 읽혔다. 팝 스프링의 오버슈트가 나머지 존재감을 만든다.
                .scaleEffect(shown ? 1 : 0.95)
                .opacity(shown ? 1 : 0)
        }
        .onAppear {
            withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) { shown = true }
        }
        .accessibilityAction(.escape) { close(onCancel) }
    }

    /// 이탈 — 예전엔 부모가 `disablesAnimations`로 커버를 **0프레임에 잘라** 냈다. 뜰 때는 스프링으로
    /// 부풀던 카드가 사라질 때만 한 프레임에 없어지니, 눈이 "무엇이 닫혔는지"를 못 따라가고 판정이
    /// 취소된 것처럼 보였다. §7.1대로 이탈은 진입보다 짧게(dur-1 ease-in) 한 번 흐린 뒤 해체한다.
    /// Reduce Motion이면 그 페이드도 없이 즉시(§7.4).
    ///
    /// 페이드가 도는 0.12초는 **버튼이 두 번 눌릴 수 있는 창**이다 — `closing`으로 잠가 Tossed 직후
    /// Ate가 겹쳐 들어오는 이중 판정을 막는다(부모의 커버 해체는 그 뒤에 한 번만 일어난다).
    private func close(_ finish: @escaping () -> Void) {
        guard !closing else { return }
        guard !reduceMotion else { finish(); return }
        closing = true
        withAnimation(ReffiMotion.exit) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + ReffiMotion.dur1) { finish() }
    }

    private var card: some View {
        VStack(spacing: ReffiSpace.s5) {
            // 묻는 글자는 좌측선, 고르는 버튼 행은 가운데(49차, §9.4) — 카드 축을 하나로 두되
            // 대칭 블롭 행만 스스로 중앙을 선언하는 형태다(조리 티켓의 그림/글자 분해와 같은 처방).
            // 이름은 사용자 데이터라 길이가 가변이고 2줄까지 접히는데, 중앙이면 접히는 순간
            // 시작점이 매번 달라져 같은 카드가 재료마다 다른 자리에서 시작하는 것처럼 읽혔다.
            VStack(alignment: .leading, spacing: ReffiSpace.s0) {
                // 바깥 s7 마진은 카드에 **제안**으로만 전해진다 — 제안을 무시하는 자식(고정 frame·끊기지
                // 않는 긴 낱말)만이 종이를 마진 밖으로 밀어낼 수 있다. 블롭은 위 `blobSide`가 잡았고,
                // 남은 하나가 이 이름이다(냉장고 카드·간편 행도 같은 이유로 이름을 한 줄로 묶는다).
                Text(verbatim: ingredient.displayName).reffiType(.heading).foregroundStyle(ReffiColor.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(ReffiShrink.chrome)
                    .multilineTextAlignment(.leading)
                Text("Did you eat it, or toss it?")
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
            }
            // 안쪽 블록이 제 내용 폭만 잡으면 바깥 center VStack이 그 좁은 덩어리를 도로 가운데로
            // 민다 — 좌측선을 실제로 세우는 것은 이 전폭 프레임이다(§9.4 마지막 항).
            .frame(maxWidth: .infinity, alignment: .leading)
            outcomeRow
            keepIt
        }
        .padding(.horizontal, ReffiSpace.s6)
        .padding(.top, ReffiSpace.s6)
        .padding(.bottom, ReffiSpace.s3)
        .background {
            let shape = PaperRect(cornerRadius: ReffiRadius.xl)
            shape.fill(ReffiColor.canvas).paperEdge(shape)
        }
        .reffiShadow1()
        .padding(.horizontal, ReffiSpace.s7)
    }

    /// 판정 버튼들 — 가로 한 줄이 **들어가면** 지금 그대로, 안 들어가면 세로 세 행으로 접는다.
    /// 큰 글자에서 'Tossed'가 'To…'로 잘리던 자리다(1라운드 이연분): 라벨을 2줄로 풀면 버튼마다
    /// 줄 수가 갈려 블롭 세로 정렬이 어긋나므로, 줄을 늘리는 대신 **배치를 통째로 바꾼다**.
    /// 세로 폼은 블롭 좌 · 라벨 우의 행이라 라벨이 폭을 다투지 않고, 읽는 순서도 그대로 남는다.
    private var outcomeRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: showFreeze ? ReffiSpace.s4 : ReffiSpace.s6) {
                outcomeButtons(size: blobSide, placement: .below)
            }
            VStack(spacing: ReffiSpace.s3) {
                outcomeButtons(size: Self.stackedBlobSide, placement: .trailing)
            }
        }
    }

    /// 두 배치가 **같은 버튼 셋**을 같은 순서로 세운다 — 손으로 두 번 쓰면 한쪽만 조용히 어긋난다.
    @ViewBuilder
    private func outcomeButtons(size: CGFloat, placement: PaperIconLabel.Placement) -> some View {
        PaperIconButton(icon: ReffiIcon.toss, label: "Tossed", intent: .soft,
                        size: size, seed: 0, placement: placement,
                        capsLabelWidth: false) { close { onCommit(false) } }
        if showFreeze {
            PaperIconButton(icon: ReffiIcon.freeze, label: "Freeze", intent: .neutral,
                            size: size, seed: 2, placement: placement,
                            capsLabelWidth: false) { close(onFreeze) }
        }
        PaperIconButton(icon: ReffiIcon.ate, label: "Ate", intent: .primary,
                        size: size, seed: 1, placement: placement,
                        capsLabelWidth: false) { close { onCommit(true) } }
    }

    private var keepIt: some View {
        Button { close(onCancel) } label: {
            Text("Keep it")
                .reffiType(.caption)
                .foregroundStyle(ReffiColor.ink2)
                .frame(minWidth: ReffiChrome.tapMin, minHeight: ReffiChrome.tapMin)
                .contentShape(Rectangle())
        }
        .buttonStyle(.reffiPress)
    }
}
