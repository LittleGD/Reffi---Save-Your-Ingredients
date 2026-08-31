import SwiftUI

/// 사야 할 식재료 — 자주 쓰는데(이력) 지금 냉장고에 없는 항목이 자동으로 채워지고, 습관이 못 잡는 품목은
/// 하단 "Add item"으로 직접 담는다(§13.5 To buy 예외 — **재고 추가가 아니라 장보기 메모**다).
/// Bought = 시트 없이 **즉시 재입고** — 직전 이력 스냅샷(보관·구매처·수량, 냉동이었다면 냉장으로)과
/// 사전 기본 기한으로 바로 store에 채워 넣는다(§13.6 재입고 경로 — AddIngredientSheet 의존 없음).
///
/// 빼기는 **행을 왼쪽으로 밀어서** 한다(21차) — 행에는 파란 Bought 알약 하나만 서고, 밀면 그 뒤에서
/// 빨간 종이 조각이 드러난다. 밀기는 보조기술에 존재하지 않으므로 같은 동작을 행의 **커스텀 접근성
/// 액션**으로도 낸다. 오발이 잦은 어포던스라 되돌리기 토스트를 짝지었다(`FridgeStore.skipBuyUndoable`).
///
/// **커버 크롬(헤더·닫기)을 갖지 않는 임베더블 본문**이다 — 지금 호출부는 냉장고 To buy 탭
/// (`FridgeView.pane`) 하나뿐이고, 그 자리는 헤더 대신 `ctaBottomInset`만 넘긴다. 커버가 다시
/// 필요해지면 **이 본문을 감싸는 래퍼**를 세운다(옛 `ShoppingListView` 커버가 그 형태였다).
/// 목록·재입고·빼기·검색 시트 같은 실제 동작은 **여기 한 곳**에 산다(두 표면이 같은 규칙을 각자
/// 적으면 조용히 갈린다).
struct ShoppingListContent: View {
    /// 하단 도킹 CTA 아래로 남길 여백 — 커버는 기본값(`s3`), 떠 있는 캡슐 네비가 있는 탭 패인은
    /// 그 자리(`ReffiChrome.navReserve`)를 비운다.
    var ctaBottomInset: CGFloat = ReffiSpace.s3

    @Environment(FridgeStore.self) private var store
    @Environment(ProfileStore.self) private var profile
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var restockHaptic = 0
    /// 메모에서 빼기는 §7.6의 **판정·확정**이다(Ate/Tossed와 같은 결의 "이번엔 안 사기") — `.impact(.light)`.
    /// 라벨 "Skip"(~18차) → 조용한 ✕(19차) → **밀어서 삭제**(21차)로 어포던스가 두 번 바뀌는 동안
    /// **햅틱은 한 번도 안 바뀌었다**: §7.6의 매핑 기준은 어포던스가 아니라 **의미**이고, 부르는 액션이
    /// 여전히 "이번엔 안 사기"(`skipBuy` 계열)라 의미도 그대로다.
    /// 사서 채우는 Bought 쪽이 성공 완료(`.success`)이므로 두 동작이 다른 의미로 갈린다.
    @State private var skipHaptic = 0
    @State private var showSearch = false
    /// 지금 열려 있는(빨간 조각이 드러난) 행 — **한 번에 하나**다. 여러 줄이 동시에 열리면 어느 것을
    /// 지우는지가 흐려지고, 닫는 방법도 사라진다(바깥 탭을 받을 자리가 없다).
    @State private var revealedKey: String?
    /// 진행 중인 드래그의 행과 이동량 — 축이 수평으로 갈린 뒤에만 채워진다.
    @State private var dragKey: String?
    @State private var dragX: CGFloat = 0

    // MARK: - 밀기 어포던스 힌트(28차)

    /// 첫 행이 한 번 밀렸다 돌아오는 힌트를 **이미 보여 줬는가**. 설치당 한 번이라 `@AppStorage`다
    /// (`fridge.compact`·`fridge.sort`와 같은 점 구분 네임스페이스 규약).
    ///
    /// 값의 뜻은 "재생을 끝까지 마쳤다"이지 "재생을 시도했다"가 아니다 — 그래서 아래 `startSwipeHint`는
    /// 힌트가 **되돌아오는 순간**에만 이 값을 세운다. 시작 시점에 세우면 사용자가 손을 대 중간에 걷힌
    /// 재생이나 시트에 덮인 재생이 유일한 기회를 조용히 소진한다.
    @AppStorage("toBuy.swipeHintSeen") private var swipeHintSeen = false
    /// 힌트가 첫 행에 얹는 가로 이동량 — **손끝의 이동량과 더해지지만 섞이지는 않는다**(`row` 참고).
    @State private var peekX: CGFloat = 0
    /// 예약된 힌트 단계(시작·복귀)를 무효화하는 세대 토큰 — `MainView.coverGeneration`과 같은 장치다.
    /// 취소가 값을 올리면 이미 큐에 들어간 두 클로저가 자기 세대와 어긋나 그대로 반환한다.
    @State private var peekGeneration = 0
    /// 이 등장에서 사용자가 **이미 행을 만졌는가**(가로로 밀었거나, 뺐거나). 한 번 참이 되면 이 등장
    /// 동안 힌트는 다시 예약되지 않는다 — 이미 아는 동작을 가르치는 연출은 방해일 뿐이다.
    @State private var userSwiped = false

    /// 드러나는 빨간 조각의 폭. 44pt 히트(§7.3)에 좌우 여백을 더한 값이다.
    private static let revealWidth: CGFloat = 84
    /// 끝까지 밀기(full swipe) 커밋 거리 — **예측 종점** 기준. 드러내기(84)의 두 배가 넘어야
    /// "열려다 만 것"과 "끝까지 민 것"이 손끝에서 갈린다.
    private static let commitDistance: CGFloat = 200
    /// 드래그가 끌고 갈 수 있는 최대 거리 — 커밋 거리 너머로는 더 밀리지 않는다(고무줄 대신 정지).
    private static let maxTravel: CGFloat = 260

    /// 힌트가 첫 행을 미는 거리. **드러내기 폭(84)의 1/4**이라 빨간 조각의 둥근 끝만 얇게 보이고
    /// 휴지통 글리프(조각 폭 76의 한가운데)는 나오지 않는다 — "여기 뭔가 숨어 있다"까지만 말하고
    /// 무엇인지는 손으로 밀어 확인하게 남긴다. 열림 판정(−42)의 절반이라 "열려다 만 것"으로도 오해되지 않는다.
    private static let peekDistance: CGFloat = 20
    /// 탭·커버 전환이 끝난 뒤에 시작한다 — 착지와 같은 프레임에 얹으면 전환 애니메이션에 묻혀
    /// 의도한 연출이 아니라 렌더 결함으로 읽힌다(`-toBuy.search`가 0.6초를 두는 것과 같은 이유).
    private static let peekLeadIn: Double = 0.5
    /// 밀린 채 머무는 시간 — 눈이 빨간 조각을 인지하기엔 충분하고, 손을 붙잡아 두기엔 짧다.
    static let defaultPeekHold: Double = 0.4

    /// 힌트를 지금 낼 것인가 — 뷰 상태에서 떼어 낸 **순수 판정**이라 유닛 테스트가 다섯 갈래를
    /// 전부 고정한다(`FridgeTab.initial(from:)`·`MainView.fireDismissDelay(from:)` 선례).
    ///
    /// **모션 축소면 플래그를 남기지 않는다**(§7.4). 이 함수가 거짓을 돌려주면 호출부는 재생도 기록도
    /// 하지 않으므로, 나중에 사용자가 모션 축소를 끄면 힌트가 그때 처음 뜬다. 반대로 축소 상태에서
    /// 플래그를 세우면 **아무것도 못 본 채로** 단 한 번의 기회가 사라진다.
    static func shouldPeek(rowCount: Int, seen: Bool, reduceMotion: Bool,
                           userSwiped: Bool, sheetUp: Bool, forced: Bool) -> Bool {
        guard rowCount > 0 else { return false }          // 빈 목록엔 가르칠 행이 없다
        guard !reduceMotion else { return false }         // §7.4 — 기록도 남기지 않는다
        guard !userSwiped else { return false }           // 이미 아는 동작을 다시 가르치지 않는다
        guard !sheetUp else { return false }              // 시트에 덮이면 재생이 통째로 낭비된다
        return forced || !seen                            // QA 강제는 플래그를 무시한다
    }

    #if DEBUG
    /// `-toBuy.search` 자동 오픈을 **런치당 한 번**으로 묶는다 — 탭 패인은 커버와 달리 오갈 때마다
    /// `onAppear`가 다시 도는데, 그때마다 시트가 튀어나오면 QA 세션에서 다른 탭을 볼 수가 없다.
    /// `@State`가 아니라 **타입 스코프**다: 패인은 `switch tab` 분기라 탭을 떠나면 뷰째 해체돼
    /// `@State`가 초기화된다 — 그러면 "런치당 한 번"이 "탭 진입마다 한 번"이 된다.
    @MainActor private static var searchArgHandled = false

    /// `-toBuy.swipeHint [초]` 파싱 결과 — 강제 여부와(선택) 넓힌 유지 시간.
    struct SwipeHintOverride: Equatable {
        var forced: Bool
        var hold: Double
    }

    /// `-toBuy.swipeHint` — 힌트를 **플래그와 무관하게** 강제한다(스크린샷·QA용). 뒤에 양수를 붙이면
    /// 유지 시간이 그 값으로 넓어진다: 기본 0.4초는 XCUITest가 "지금 밀려 있다"를 프레임 조회로 잡기엔
    /// 너무 좁다(런치·`waitForExistence`만으로 그 창을 넘긴다). `-fireDismissDelay <초>`가 같은 이유로
    /// 같은 모양을 하고 있다.
    ///
    /// 강제 경로는 **플래그를 쓰지 않는다** — QA가 한 번 돌릴 때마다 실사용자의 일회성 상태가
    /// 소진되면 같은 인자를 두 번 쓸 수 없고, 그 설치는 되돌릴 방법이 없다(`-myRecipesPreview`가
    /// 영속 저장으로 남긴 경고가 그 사례다). 반대로 "플래그가 서 있으면 안 뜬다"를 재현할 때는
    /// UserDefaults 인자 `-toBuy.swipeHintSeen YES`를 쓴다(`-fridge.compact YES` 선례).
    ///
    /// 뷰에서 분기를 늘리는 대신 **순수 함수**로 떼어 유닛 테스트가 고정한다. 값 파싱은 `arguments`
    /// 직접 순회다 — 다음 토큰이 숫자가 아니면(다른 플래그거나 없으면) 소비하지 않고 기본값으로 둔다.
    static func swipeHintConfig(from arguments: [String]) -> SwipeHintOverride {
        guard let i = arguments.firstIndex(of: "-toBuy.swipeHint") else {
            return SwipeHintOverride(forced: false, hold: defaultPeekHold)
        }
        guard i + 1 < arguments.count, let value = Double(arguments[i + 1]), value > 0 else {
            return SwipeHintOverride(forced: true, hold: defaultPeekHold)
        }
        return SwipeHintOverride(forced: true, hold: value)
    }

    /// 프로세스당 한 번만 파싱 — 등장마다 `ProcessInfo.arguments`를 다시 훑지 않게(`tiltLabConfig` 선례).
    private static let swipeHint = swipeHintConfig(from: ProcessInfo.processInfo.arguments)
    #endif

    /// 힌트 강제 여부 — 릴리스엔 이 경로가 없다.
    private var peekForced: Bool {
        #if DEBUG
        return Self.swipeHint.forced
        #else
        return false
        #endif
    }

    /// 힌트 유지 시간 — 릴리스는 항상 기본값이다.
    private var peekHold: Double {
        #if DEBUG
        return Self.swipeHint.hold
        #else
        return Self.defaultPeekHold
        #endif
    }

    private typealias Row = (name: String, glyph: FoodGlyph, manual: Bool, key: String)

    /// 화면에 세우는 목록 — **직접 담은 것만**(2026-08 owner decision). 이력에서 파생된 "자주 쓰는데
    /// 떨어진 것" 제안 구역을 걷어냈다: 장보기 메모는 내가 적은 것이어야 하고, 앱이 추측해 채워 넣은
    /// 줄이 그 위에 섞이면 목록이 내 것이 아니게 된다.
    ///
    /// **`store.toBuy`가 아니라 `manualToBuy`를 직접 읽는다.** `toBuy`의 수동 절반은 `manualToBuy`의
    /// 1:1 사상이라 결과가 같고, `toBuy`를 부르면 안 쓰는 파생 절반(이력 전체 그룹핑+정렬, 최대
    /// 2000건)까지 렌더마다 계산해 버린다. 파생 모델 자체는 살려 둔다 — 흡수 의미론(수동이 같은
    /// 키의 제안을 먹는다)·`skipBuy`의 두 갈래·로케일 매칭이 전부 그 절반 위에서 검증되고 있고,
    /// 덱의 "부족 재료 담기"(`addMissingToBuy`)가 그 규약을 그대로 탄다.
    private var items: [Row] {
        // 이름은 `displayName(for:)`로 다시 그린다 — 저장 표기가 사전 표제어와 일치할 때만 **지금
        // 로케일**의 표제어로 바꾸는 함수라, 한국어에서 담은 "양파"가 영어 UI에서도 "Onion"으로
        // 선다(자유 표기는 그대로). 이걸 우회하면 같은 화면의 검색 시트 타일·undo 토스트와 표기가
        // 갈린다. `toBuy`의 수동 절반이 쓰는 함수와 동일하다(항목당 사전 조회 1회 — 파생 절반의
        // 이력 그룹핑을 안 도는 이득은 그대로).
        store.manualToBuy.map { (name: FridgeStore.displayName(for: $0),
                                 glyph: $0.glyph, manual: true, key: $0.matchKey) }
    }

    var body: some View {
        ScrollView {
            // 헤드라인 ↔ 카드는 s3(12) — 위의 탭 행과는 s5(24, `FridgeView.fridgeHeader`가 준다)다.
            // 2:1이라 헤드라인이 **아래 카드에 붙어** 읽힌다(제목은 자기가 이름 붙이는 것 쪽에 살아야 한다).
            VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                headline
                if items.isEmpty {
                    emptyCard
                } else {
                    listCard
                }
            }
            .padding(.horizontal, ReffiGrid.margin)
            .padding(.bottom, ReffiSpace.s6)
        }
        // 직접 담기 진입은 목록 꼬리가 아니라 화면 하단에 도킹한다(§13.5) — 목록이 짧든 길든 같은
        // 자리에 있고, 커버·시트·메인이 공유하는 하단 CTA 관례와 어긋나지 않는다.
        //
        // **`over:`는 이 패인의 실제 바탕색과 반드시 같은 토큰이어야 한다.** `dockedCTA`는
        // `[surface.opacity(0) → surface]` 페이드 + `surface` 솔리드를 깔기 때문에, 넘긴 색이
        // 실제 배경과 다르면 화면 아래 ~1/6이 **다른 톤의 띠**로 읽힌다. 한동안 정확히 그 상태였다
        // (이 자리는 `canvas`인데 패인 배경은 컬러 블롭 + 글래스 프로스트였다). 지금은 배경이
        // `PaperCanvasBackground`(= `canvas` 단색)라 둘이 같은 값이고, 그래서 이 인자는 장식이
        // 아니라 **불변식**이다 — 패인 배경을 바꾸는 사람은 이 줄도 같이 바꿔야 한다.
        .dockedCTA(over: ReffiColor.canvas, bottomInset: ctaBottomInset) { addItemButton }
        .reffiFeedback(.success, trigger: restockHaptic)
        .reffiFeedback(.impact(weight: .light), trigger: skipHaptic)
        .sheet(isPresented: $showSearch) { ToBuySearchSheet() }
        // 밀기 어포던스 힌트(28차) — **등장할 때 한 번만** 건다. 등장 중에 목록이 비었다가 차는
        // 경우(빈 화면에서 방금 담은 직후)에는 걸지 않는다: 그 순간 사용자는 시트를 막 닫았고
        // 담김 연출이 아직 흐르는 중이라, 거기 힌트를 얹으면 방금 한 일의 피드백과 겹쳐 읽힌다.
        // 다음 등장(탭을 오가면 패인은 뷰째 새로 선다)에서 목록이 차 있으면 그때 뜬다.
        .onAppear { startSwipeHint() }
        .onDisappear { cancelSwipeHint() }
        // 검색 시트가 올라오면 힌트는 자리를 비운다 — 덮인 채 재생되면 플래그만 소진된다.
        .onChange(of: showSearch) { _, up in if up { cancelSwipeHint() } }
        #if DEBUG
        // `-toBuy.search` — 검색 시트 자동 오픈(스크린샷·QA용). 탭 착지 자체는 `FridgeView`가 한다.
        // 탭 전환·커버 전환과 같은 프레임에 시트를 올리면 프레젠테이션이 씹히므로 전환 뒤로 미룬다.
        .onAppear {
            guard !Self.searchArgHandled,
                  ProcessInfo.processInfo.arguments.contains("-toBuy.search") else { return }
            Self.searchArgHandled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showSearch = true }
        }
        #endif
    }

    /// 직전 이력 스냅샷이 있으면 보관·구매처·수량을 복원(냉동이었다면 냉장으로 — 재구매는 냉동 상태가
    /// 아니다), 없으면 사전 기본값으로 새로 채운다. 소비기한은 항상 그 보관의 사전 기본값으로 재계산.
    /// 가구 인원 배율은 **스냅샷이 없는 폴백 경로에만** 적용한다 — 스냅샷이 있으면 사용자가 이미 그
    /// 수량을 한 번 결정한 값이라 존중하고 그대로 복원한다(재입고 때마다 배율이 누적되지 않게).
    /// 직접 담은 항목이었다면 메모도 함께 내린다(샀으니 목록에 남을 이유가 없다) — 내리는 키는
    /// **행 자신의 키**다. `store.add` 쪽 자동 내리기는 냉장고 재료의 캐논 키로 비교하므로, 자유
    /// 입력 줄(캐논 없음, 키 = 친 문자열)은 그쪽에서 절대 안 내려가고 같은 캐논의 다른 줄이 대신
    /// 내려갈 수 있다(`FridgeStore.clearToBuy(key:)` 주석 참고).
    private func restock(name: String, glyph: FoodGlyph, key: String) {
        let lex = IngredientLexicon.shared
        if let last = store.lastSnapshot(named: name) {
            let storage = last.storage == .freezer ? .fridge : last.storage
            let expiresAt = lex.defaultExpiry(for: name, storage: storage) ?? Ingredient.day(offset: 3)
            store.add(Ingredient(name: name, category: glyph.categoryLabel, expiresAt: expiresAt,
                                 quantity: last.quantity, glyph: glyph, place: last.place, storage: storage))
        } else {
            let expiresAt = lex.defaultExpiry(for: name, storage: .fridge) ?? Ingredient.day(offset: 3)
            // 폴백 기본 수량(1개)은 개수 차원이라 가구 인원 배율을 그대로 곱한다.
            let quantity = Quantity(value: max(1, profile.household.quantityMultiplier.rounded()), unit: .piece)
            store.add(Ingredient(name: name, category: glyph.categoryLabel, expiresAt: expiresAt,
                                 quantity: quantity, glyph: glyph))
        }
        store.clearToBuy(key: key)
        restockHaptic += 1
    }

    /// 패인 헤드라인 — **영수증 카드 밖**에 선다. 이 화면이 무엇인지는 카드 안의 캡션이 아니라
    /// 카드를 이름 붙이는 제목이 말해야 한다(카드 안에 있으면 목록의 첫 줄처럼 읽힌다).
    ///
    /// role이 `.heading`(24)인 근거는 **구조 층위**다. §3.2의 역할 정의가 그대로 답이다:
    /// `display`=워드마크(화면 제목 "Fridge") · `heading`=제목 · `subhead`=소제목·**카드 이름**.
    /// 이건 카드 하나가 아니라 **패인 전체**를 이름 붙이는 제목이라 `heading`이고, History의
    /// "Tally · past 30 days"가 `subhead`인 것과 어긋나지 않는다 — 그건 카드 **안**에서 그 카드를
    /// 이름 붙이는 줄이라 한 층 아래다. 즉 둘은 같은 규칙의 다른 층이다(display 34 → heading 24 → subhead 18).
    ///
    /// `subhead`(18)를 쓰지 않은 실질적 이유도 있다: 빈 상태 카드의 제목이 이미 `subhead`라,
    /// 헤드라인까지 18이면 "Grocery memo" 바로 아래 "Nothing on the list"가 같은 굵기로 붙어
    /// 어느 쪽이 제목인지가 사라진다.
    private var headline: some View {
        Text("Grocery memo")
            .reffiType(.heading)
            .foregroundStyle(ReffiColor.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    /// 목록 카드 — 구역도 캡션도 하나뿐이다. 옛 이력 제안 구역("Ran out, based on what you use often")과
    /// 두 구역을 가르던 절취선(`ReffiRule(.ticket)`)은 16차에, 카드 안 `Added by you` 캡션은 17차에
    /// 사라졌다 — 카드 밖 헤드라인이 그 이름표 역할을 가져갔고, 캡션이 남으면 제목이 두 번 선다.
    ///
    /// **행 사이에 절취선이 돌아왔다(28차, 사용자 요청).** 16차가 걷은 것과 같은 `ReffiRule(.ticket)`이지만
    /// 뜻이 다르다: 그때는 두 **구역**(파생 제안 ↔ 직접 담은 것)의 경계였고, 지금은 **행 경계**다.
    /// 그 용법의 정본은 `PaperDropdown`이다 — 44pt 행이 이어질 때 행 사이를 `ReffiRule(.ticket)`으로
    /// 가르는 규약이 이미 서 있고, 컴포넌트 문서가 그것을 "드롭다운 행 구분"으로 명시한다. 그래서
    /// 새 어휘를 만들지 않았고, 굵은 쪽(`.ticket`)을 쓴 것도 `.receipt`(헤더 아래·구역 마감)와 뜻이
    /// 겹치지 않게 하려는 것이다.
    ///
    /// **여백 재유도**: 옛 리듬은 행 사이 s3(12)의 순수 여백이었다. 선이 가르는 일을 대신 하므로
    /// 간격을 s2(8)로 좁히고 선을 그 한가운데에 놓는다 — 행 얼굴 사이는 8 + 1 + 8 = **17pt**이고
    /// 선은 위아래 어느 행에도 붙지 않아 두 행의 공유 경계로 읽힌다. 행 자체는 여전히 ≥44pt이며
    /// (`rowFace`가 `ReffiChrome.tapMin`을 그대로 쓴다), 인접 타깃 간격 17pt는 §7.3의 하한 8pt를 넉넉히 넘는다.
    ///
    /// **첫 행 위·마지막 행 아래에는 선이 없다** — 카드의 톱니 가장자리가 이미 그 두 경계를 말한다.
    /// 거기까지 그으면 목록이 영수증 **안의 상자**가 되어 27차가 걷어낸 카드 느낌이 선으로 돌아온다.
    private var listCard: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            // `enumerated()`를 쓰면서도 **식별자는 키**다(`\.element.key`) — 인덱스를 id로 삼으면
            // 빼기·되돌리기에서 행이 자리로 식별돼 사라지는 줄과 올라오는 줄이 뒤바뀐다.
            ForEach(Array(items.enumerated()), id: \.element.key) { pair in
                if pair.offset > 0 { ReffiRule(.ticket) }
                row(pair.element, isFirst: pair.offset == 0)
            }
        }
        .receiptSurface()
        // 목록이 바뀌면(샀거나·담았거나) 열려 있던 조각은 닫는다 — 사라진 행의 상태가 남으면
        // 그 자리에 올라온 다음 행이 이유 없이 열린 채로 뜬다.
        .onChange(of: items.count) { _, _ in revealedKey = nil }
    }

    /// 목록 한 줄 — **라벨 붙은 알약 하나 + 조용한 아이콘 하나**다(19차).
    ///
    /// 라벨이 "Add"가 아니라 **"Bought"**인 이유는 이 화면이 장보기 메모이기 때문이다. "Add"는 앱이
    /// 무엇을 하는지(재고에 넣는다)를 말하고, 사용자가 방금 한 일은 **샀다**는 것이다. 메커니즘이 아니라
    /// 행위를 라벨에 세운다 — 동작(`restock`)은 그대로고 바뀐 건 이름뿐이다.
    ///
    /// 반대쪽 빼기는 **버튼에서 제스처로 내려갔다**(21차). 19차가 "Skip" 알약을 면 없는 ✕로 내린 이유가
    /// 위계였는데(행에서 실제로 누르는 건 압도적으로 앞쪽이다), 그 논리의 끝은 **행에서 아예 걷어내는 것**이다.
    /// 이제 행에는 파란 알약 하나만 서고, 빼기는 밀어야 나온다 — 정리 동작이 읽는 리듬을 방해하지 않는다.
    ///
    /// 확인 다이얼로그는 여전히 두지 않는다(§7.6의 파괴 확정은 계정·전체 초기화·재료 삭제 쪽이다).
    /// 대신 **되돌리기 토스트**를 세웠다: 어포던스가 버튼에서 밀기로 바뀌면 오발 가능성이 달라진다
    /// (스크롤하려다, 옆 행을 만지려다). 근거는 `FridgeStore.skipBuyUndoable`에 적었다.
    ///
    /// `isFirst`는 **어포던스 힌트 전용**이다(28차) — 첫 행만 등장 직후 한 번 밀렸다 돌아온다.
    private func row(_ item: Row, isFirst: Bool) -> some View {
        let base: CGFloat = revealedKey == item.key ? -Self.revealWidth : 0
        let live: CGFloat = dragKey == item.key ? dragX : 0
        // **손끝이 만든 이동량과 힌트가 만든 이동량을 가른다.** 그림은 둘을 더한 자리에 그리지만,
        // 빨간 조각이 "열렸다"고 판정하는 축은 손끝 쪽 하나뿐이다. 힌트까지 그 판정에 섞으면
        // 장식 모션이 조각을 접근성 트리에 올리고 히트 테스트를 켠다 — VoiceOver 사용자에게는
        // 아무 조작 없이 버튼이 생겼다 사라지는 일이 되고, 그 사용자를 위한 길은 이미 행의
        // 커스텀 액션이다. 힌트는 끝까지 **보이기만** 한다.
        let userX = max(-Self.maxTravel, min(0, base + live))
        let revealed = userX < -8
        let x = max(-Self.maxTravel, min(0, userX + (isFirst ? peekX : 0)))
        return ZStack(alignment: .trailing) {
            deleteZone(item, revealed: revealed)
            rowFace(item)
                // 행 얼굴은 **불투명 영수증 면**이라야 한다 — 뒤의 빨간 조각은 이 면이 밀려나면서
                // 드러나는 것이지, 알파로 켜지는 것이 아니다(종이 두 장이 겹쳐 있다가 미끄러진다).
                //
                // 색이 카드와 **같은 `receipt` 토큰**인 것도 그래서다: 쉬고 있을 때 이 면은 영수증에
                // 완전히 녹아 목록이 카드 묶음이 아니라 **한 장의 영수증**으로 읽히고, 밀 때만 종이
                // 두 장이었다는 사실이 드러난다. 27차까지 그렇게 읽히지 않았던 이유는 색이 아니라
                // 그림자였다 — `receiptSurface`의 카드 그림자가 자식마다 따로 드리워 이 면에 카드
                // 윤곽을 그려 주고 있었다. 근거와 수정은 `ReceiptSurface`의 `compositingGroup` 주석.
                .background(ReffiColor.receipt)
                .offset(x: x)
                // `simultaneousGesture`인 이유: 이 행은 세로 `ScrollView` 안에 산다. `gesture`로 걸면
                // 행 위에서 시작한 세로 스크롤을 이 제스처가 삼킨다. 동시로 두면 스크롤은 세로를,
                // 이 제스처는 (축이 갈렸을 때만) 가로를 가져가 서로를 막지 않는다.
                .simultaneousGesture(swipe(item, base: base))
        }
        // 밀려난 얼굴은 **행의 폭 안에서** 잘린다 — 안 자르면 종이가 영수증 카드 밖으로, 심하면
        // 화면 밖까지 삐져나가 이름이 잘린 채 허공에 뜬다(첫 캡처에서 실제로 그렇게 보였다).
        // 자르면 "카드 안쪽으로 미끄러져 들어간다"는 종이의 물리가 그대로 읽힌다.
        .clipped()
        // **밀기는 보조기술에 존재하지 않는다.** VoiceOver 사용자에게 같은 동작을 주는 유일한 길이
        // 커스텀 액션이라, 빼기를 제스처로 내린 이 라운드에서는 선택이 아니라 필수다.
        // 세 경로(끝까지 밀기·드러낸 조각 탭·이 액션)가 전부 아래 `remove(_:)` 하나를 부른다.
        .accessibilityAction(named: Text("Remove from the list")) { remove(item) }
    }

    /// 행 얼굴 — 실루엣 + 이름 + 파란 Bought 알약. 19차의 구성에서 ✕만 빠졌다.
    private func rowFace(_ item: Row) -> some View {
        HStack(spacing: ReffiSpace.s3) {
            PaperSilhouette(glyph: item.glyph, fresh: .fresh)
                .frame(width: ReffiFoodIcon.row, height: ReffiFoodIcon.row)
            // 재료 이름은 이 행의 **콘텐츠**다 — 목록을 훑는 눈이 잡는 유일한 값이라 `checklistItem`
            // (SemiBold 16)이고, 냉장고 카드·History 타임라인의 재료명과 같은 층이다. `body`
            // (Regular 16)는 §3.5가 **설정·폼의 라벨**에 준 role이라 여기 오면 같은 재료 이름이
            // 화면마다 다른 굵기로 서고, 오른쪽 'Bought' 알약(SemiBold 13)보다 이름이 가벼워진다.
            Text(verbatim: item.name).reffiType(.checklistItem).foregroundStyle(ReffiColor.ink)
            Spacer()
            Button {
                withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                    restock(name: item.name, glyph: item.glyph, key: item.key)
                }
            } label: {
                Text("Bought")
                    .reffiType(.pillLabel)
                    .fixedSize()   // 이름 열이 길어도 라벨은 꺾이지 않는다 — 폭 경합에선 이름이 접힌다
                    .foregroundStyle(ReffiColor.blueDark)
                    .padding(.horizontal, ReffiSpace.s3)
                    .padding(.vertical, ReffiSpace.s1)
                    .background {
                        let s = PaperRect(cornerRadius: ReffiRadius.pill, seed: 1)
                        s.fill(ReffiColor.blueLight).paperEdge(s)
                    }
                    .frame(minHeight: ReffiChrome.tapMin)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.paperPress)
            .accessibilityLabel(Text("Bought \(item.name)"))
            .accessibilityHint(Text("Puts it back in the fridge and clears it from the list."))
        }
    }

    /// 드러나는 빨간 **종이 조각** — 시스템 빨간 띠가 아니다(§13.1: 이 앱의 면은 전부 오려 낸 종이다).
    /// 행 얼굴 뒤에 늘 앉아 있고 얼굴이 밀려나야 보이므로 알파를 켜고 끄지 않는다.
    ///
    /// 안 드러났을 때는 **보조기술에서도 숨긴다** — 화면 밖 버튼에 포커스가 잡히면 VoiceOver 사용자는
    /// 보이지 않는 컨트롤을 만지게 된다. 그 사용자를 위한 길은 위 행의 커스텀 액션이다.
    private func deleteZone(_ item: Row, revealed: Bool) -> some View {
        Button { remove(item) } label: {
            ReffiIcon.delete.reffi(16, .bold)
                .foregroundStyle(ReffiColor.urgentDark)
                .frame(width: Self.revealWidth - ReffiSpace.s2, height: ReffiChrome.tapMin)   // §7.3
                .background {
                    let s = PaperRect(cornerRadius: ReffiRadius.md, seed: 7)
                    s.fill(ReffiColor.urgentLight).paperEdge(s)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel(Text("Remove \(item.name) from the list"))
        .accessibilityHint(Text("Takes it off the list without buying it."))
        .accessibilityHidden(!revealed)
        .allowsHitTesting(revealed)
    }

    /// 가로 밀기 — 축을 **한 번만** 판별해 고정하는 덱(`RecipeMemoCarousel.frontDrag`)의 규약 그대로다.
    /// |Δx| > |Δy|·1.4일 때만 이 제스처가 행을 잡고, 세로 우세·애매한 구간(대략 35.5°~54.5°)은
    /// 끝까지 잡지 않아 스크롤에 그대로 넘어간다. 매 이벤트 재판정하면 곡선 드래그에서 분기가 바뀌며
    /// 직전 분기가 남긴 이동량이 스테일로 굳는다.
    ///
    /// 왼쪽만 의미가 있다 — 닫힌 행을 오른쪽으로 밀면 `min(0, …)`에 걸려 아무 일도 일어나지 않고,
    /// 열린 행에서는 같은 식이 닫기로 작동한다(부호 하나로 두 방향이 자연히 갈린다).
    private func swipe(_ item: Row, base: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { v in
                if dragKey != item.key {
                    let dx = abs(v.translation.width), dy = abs(v.translation.height)
                    guard dx > dy * 1.4 else { return }   // 아직 안 갈렸거나 세로다 — 스크롤에 양보
                    dragKey = item.key
                    // 축이 갈린 이 순간이 **진짜 밀기**다 — 어포던스 힌트는 여기서 끝난다(28차).
                    // 세로 스크롤은 이 분기에 닿지 않으므로 힌트를 끄지 않는다.
                    userSwiped = true
                    cancelSwipeHint()
                    // 다른 행이 열려 있었다면 닫는다(열린 행은 한 번에 하나).
                    if revealedKey != item.key { revealedKey = nil }
                }
                dragX = v.translation.width
            }
            .onEnded { v in
                guard dragKey == item.key else { return }
                let predicted = base + v.predictedEndTranslation.width
                let settled = base + v.translation.width
                dragKey = nil
                dragX = 0
                if predicted < -Self.commitDistance {
                    remove(item)   // 끝까지 밀기 = 바로 커밋(토스트가 되돌릴 길을 남긴다)
                } else {
                    withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                        // 절반을 넘겼으면 열린 채로 머문다(탭으로 확정), 아니면 제자리로.
                        revealedKey = settled < -Self.revealWidth / 2 ? item.key : nil
                    }
                }
            }
    }

    /// 메모에서 빼기 — **세 경로의 유일한 종점**(끝까지 밀기 · 드러낸 조각 탭 · 접근성 액션).
    /// 한 곳으로 모아 두면 어느 경로로 들어와도 같은 store 호출·같은 햅틱·같은 되돌리기 창이 된다.
    private func remove(_ item: Row) {
        // 세 경로 중 어느 것으로 들어왔든 사용자는 이미 빼기를 해냈다 — 가르칠 것이 없다(28차).
        // 되돌리기 토스트가 뜨는 순간이기도 해서, 힌트를 끄지 않으면 토스트와 행 모션이 겹친다.
        userSwiped = true
        cancelSwipeHint()
        withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
            revealedKey = nil
            dragKey = nil
            dragX = 0
            store.skipBuyUndoable(key: item.key)
        }
        skipHaptic += 1   // §7.6 판정·확정 = .impact (Bought의 .success와 짝)
    }

    /// 밀기 어포던스 힌트(28차) — **첫 행이 20pt 밀렸다가 0.4초 머물고 스프링으로 돌아온다.**
    ///
    /// 21차가 빼기를 버튼에서 제스처로 내리면서 이 화면에는 "밀 수 있다"고 말하는 것이 하나도
    /// 남지 않았다(행에 서는 컨트롤은 파란 Bought 하나뿐이다). 시스템 목록이라면 스와이프가 관례라
    /// 설명이 필요 없지만, 이건 영수증 카드 안의 커스텀 `VStack`이라 그 관례가 자동으로 붙지 않는다.
    /// 그래서 **동작 자체를 한 번 보여 준다** — 문구를 얹지 않은 이유이기도 하다(설명 문장은 목록을
    /// 한 줄 늘리고, 다 읽은 뒤에도 목록에 남는다).
    ///
    /// 두 단계를 각각 예약하고 **세대 토큰**으로 취소한다(`MainView`의 지연 닫기와 같은 장치).
    /// - 나가는 모션은 `enter`(ease-out) — 시연이지 튕김이 아니라 오버슈트를 두지 않는다.
    /// - 돌아오는 모션은 `settle` — **실제 밀기를 놓았을 때와 같은 스프링**이다(`swipe`의 `onEnded`).
    ///   힌트가 흉내 내는 물리와 진짜 물리가 같아야 배운 것이 손끝에서 맞는다.
    private func startSwipeHint() {
        let forced = peekForced
        guard Self.shouldPeek(rowCount: items.count, seen: swipeHintSeen, reduceMotion: reduceMotion,
                              userSwiped: userSwiped, sheetUp: showSearch, forced: forced) else { return }
        let hold = peekHold
        peekGeneration += 1
        let gen = peekGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.peekLeadIn) {
            // 유예 동안 판이 바뀌었을 수 있다(손이 닿았거나·목록이 비었거나·시트가 올라왔거나).
            guard gen == peekGeneration,
                  Self.shouldPeek(rowCount: items.count, seen: swipeHintSeen,
                                  reduceMotion: reduceMotion, userSwiped: userSwiped,
                                  sheetUp: showSearch, forced: forced) else { return }
            withAnimation(ReffiMotion.enter) { peekX = -Self.peekDistance }
            DispatchQueue.main.asyncAfter(deadline: .now() + hold) {
                guard gen == peekGeneration else { return }
                // **끝까지 재생됐을 때만** 봤다고 기록한다. 강제(QA)는 남의 상태를 건드리지 않는다.
                if !forced { swipeHintSeen = true }
                withAnimation(ReffiMotion.settle) { peekX = 0 }
            }
        }
    }

    /// 힌트 중단 — 예약된 단계를 세대 토큰으로 무효화하고, 이미 밀려 있으면 즉시 되돌린다.
    /// 되돌림은 `exit`(§7.1 "이탈은 더 빠르게")다: 손끝이 행을 가져가는 순간이라 힌트는 빠르게
    /// 자리를 비워야 하고, 느린 스프링으로 물러나면 같은 행을 두 힘이 반대로 당기는 것처럼 보인다.
    private func cancelSwipeHint() {
        peekGeneration += 1
        guard peekX != 0 else { return }
        withAnimation(ReffiMotion.gated(ReffiMotion.exit, reduce: reduceMotion)) { peekX = 0 }
    }

    /// 직접 담기 진입 — 하단 도킹 CTA(`dockedCTA`)의 `PaperButton`, **`primary`(파랑)**다(21차).
    ///
    /// 옛 근거("이 화면의 1차 행동은 행마다의 파란 Bought라 파란 와이드 버튼이 위계를 뒤집는다")는
    /// 두 번 무너졌다. ① 16차에 이력 파생 제안이 사라져 **목록의 유일한 소스가 이 버튼**이 됐다 —
    /// 여기서 담지 않으면 화면에 행 자체가 없다. 빈 상태 카피("Tap Add item to jot down what you need.")가
    /// 이미 그렇게 말하고 있는데 버튼만 보조 톤이었다. ② 행의 Bought는 **목록에 이미 있는 줄에만**
    /// 존재하는 반응형 액션이고, 이 버튼은 화면에 늘 있는 **진입**이다. 둘은 같은 축의 1·2등이 아니라
    /// 다른 축이다.
    ///
    /// **파랑이 둘("Bought" 알약과 이 버튼)이라는 긴장은 남는다.** §2.4의 5% 액센트 규율이 겨누는 것은
    /// 같은 화면에서 파랑이 여러 곳에 흩뿌려져 어디가 행동인지 흐려지는 상태인데, 여기서는 파랑이
    /// 정확히 두 종류의 행동에만 쓰이고 **면의 채도로 갈린다**: 행 알약은 연한 면(`blueLight`) + 진한
    /// 글자(`blueDark`)라 목록 안에 앉고, 도킹 CTA는 꽉 찬 파랑 면 + 흰 글자라 화면의 바닥에서 뜬다.
    /// 같은 색의 두 밀도가 위계를 만든다 — 색을 갈랐다면(예: 초록 CTA) 오히려 새 의미를 만들었을 것이다.
    private var addItemButton: some View {
        PaperButton(title: "Add item", kind: .primary, seed: 3) { showSearch = true }
    }

    /// 빈 상태 — 이제 **직접 담은 것이 없을 때** 뜬다(제안 구역이 사라져 목록의 유일한 소스가 수동이다).
    ///
    /// 카피도 함께 바꿨다: 옛 문구("All stocked up" / "Nothing you regularly use has run out.")는
    /// **이력 제안의 언어**였다 — 앱이 소비 이력을 보고 "떨어진 게 없다"고 단언하는 말인데, 그 계산
    /// 결과를 더 이상 이 화면에 세우지 않으므로 그대로 두면 거짓말이 된다. 지금 참인 사실은 하나다:
    /// 아직 아무것도 안 적었다. 그래서 다음 행동(하단 "Add item")을 가리킨다.
    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            Text("Nothing on the list").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
            Text("Tap Add item to jot down what you need.")
                .reffiType(.body).foregroundStyle(ReffiColor.ink2)
        }
        .receiptSurface(elevated: .flat)
    }
}


/// 재료 검색 바텀시트 — 정본 사전(`IngredientLexicon`)에서 골라 **장보기 목록에만** 얹는다(냉장고 반입 아님).
/// 검색바 아래는 삭제된 재료 픽커 시트의 **재료 배열 그리드**(`pickerGrid`)가 채우고, 타이핑하면 같은
/// 문법의 결과 그리드(`searchGrid`)로 바뀐다 — 타이핑 전후로 시각 언어가 갈리지 않는다.
/// 연속 추가 UX: 타일을 탭해도 시트는 닫히지 않고 그 타일이 체크로 바뀐다(장보기 메모는 보통 한 번에 여럿 적는다).
/// **직접 입력 담기(`directAddRow`)가 이 시트에 있다** — 사전 밖 이름은 친 그대로 자유 항목으로
/// 담긴다(캐논 해석은 정확 일치까지만, `addTyped` 참고). 냉장고 **반입**용 자유 생성은 여전히 영수증
/// 스캔의 후보 편집(`CandidateEditSheet`)이 정본이다 — 여기 것은 장보기 메모 한정이다.
private struct ToBuySearchSheet: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var searchFocused: Bool

    @State private var query = ""
    @State private var addHaptic = 0
    /// 시트 높이를 코드에서 올리기 위한 바인딩 축(원본 픽커 `detent`와 같은 역할) — 검색 포커스 시 .large.
    @State private var detent: PresentationDetent = .medium

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// 상한 60은 원본 픽커의 값이다(`suggestions(matching:limit: 60)`) — 결과도 타일 그리드로 그리므로
    /// 한 화면에 스무 개 남짓만 남기는 리스트 기준 기본값(20)으로는 배열이 조기에 잘린다.
    private var results: [IngredientLexicon.Entry] {
        IngredientLexicon.shared.search(query: trimmedQuery, limit: 60)
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Add to list", showsClose: true) { dismiss() }
            searchField
                .padding(.horizontal, ReffiGrid.margin)
            ScrollView {
                content
                    .padding(.horizontal, ReffiGrid.margin)
                    .padding(.top, ReffiSpace.s3)
                    .padding(.bottom, ReffiSpace.s5)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(ReffiColor.canvas)
        // 검색 필드 + 목록/그리드 = 중간 목록·폼 버킷(§14.5): .medium은 진입 높이일 뿐이고, 카테고리
        // 섹션까지 쌓이는 재료 배열은 스크롤·.large 승격을 전제한다(Frequent가 늘 첫 화면에 온다).
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationBackground(ReffiColor.canvas)
        .reffiFeedback(.success, trigger: addHaptic)   // 목록에 담김 = 성공 완료(§7.6)
        // 검색 필드 포커스 → 시트를 .large로. 키보드가 떠도 그리드가 가리지 않는다(원본 픽커 P0-2 계승).
        // 진입 자동 포커스는 두지 않는다: 이 시트의 기본 상태는 `content` 주석이 선언한 대로 타이핑 없이
        // 끝나는 재료 배열인데, 자동 포커스는 .medium 높이에서 그 배열을 키보드로 덮어 스스로의 원칙을
        // 무효화했다. `-toBuy.search` QA 인자는 시트를 여는 역할만 하므로(`ShoppingListContent.body`
        // 안의 DEBUG `onAppear`) 그대로 동작하고, 이제 그 스크린샷이 기본 상태(=그리드)를 찍는다.
        .onChange(of: searchFocused) { _, focused in
            if focused, detent != .large {
                withAnimation(ReffiMotion.gated(ReffiMotion.enter, reduce: reduceMotion)) {
                    detent = .large
                }
            }
        }
    }

    /// 원본 픽커 검색 필드(돋보기 + 필드 + 클리어 ×)의 구성을 그대로 되살린다.
    /// 클리어(×)가 필요한 이유: 이 시트의 기본 상태는 재료 배열이고 배열로 돌아가는 유일한 조작이
    /// 쿼리 비우기다 — 전체 선택-삭제밖에 없으면 기본 상태로의 복귀 비용이 배열을 기본으로 둔 설계를
    /// 실사용에서 무너뜨린다. 돋보기도 함께 복원했다: 필드 자체는 사전 *필터*이고, 친 이름을 그대로
    /// 담는 생성은 결과 위의 `directAddRow` 한 곳이 맡는다(필드가 직접 만들지는 않는다).
    private var searchField: some View {
        HStack(spacing: ReffiSpace.s2) {
            ReffiIcon.search.reffi(16).foregroundStyle(ReffiColor.muted)
            TextField("Search ingredients", text: $query,
                      prompt: Text("Search ingredients").foregroundStyle(ReffiColor.ink2))
                .reffiType(.body)
                .foregroundStyle(ReffiColor.ink)
                .focused($searchFocused)
                .submitLabel(.done)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !trimmedQuery.isEmpty {
                Button { query = "" } label: {
                    ReffiIcon.close.reffi(11).foregroundStyle(ReffiColor.muted)
                        .frame(width: 30, height: 30)
                        // 시각은 30pt, 히트 영역은 44pt(§7.3·42차) — History 힌트 X와 같은 처방.
                        .frame(minWidth: ReffiChrome.tapMin, minHeight: ReffiChrome.tapMin)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.reffiPress)   // §7.2 — .plain은 눌림이 없다(앱에서 유일하게 남아 있던 자리)
                .accessibilityLabel(Text("Clear search"))
            }
        }
        // §13.8 필드 한 칸 — 면·그레인·헤어라인·패딩·히트가 한 모디파이어에서 나온다.
        // 이 필드는 종이 카드가 아니라 시트 캔버스 위에 직접 서는 독립 필드라 면을 갖는다
        // (영수증 카드 **안**의 행 필드는 반대로 면 없이 절취선이 나눈다).
        .fieldSurface(seed: 6)
    }

    @ViewBuilder private var content: some View {
        if trimmedQuery.isEmpty {
            // 아직 아무것도 안 친 상태 — 빈 화면 대신 재료 배열(픽커 그리드). 장보기 메모의 대부분은
            // 늘 사는 것들이라 타이핑 없이 끝나는 경로가 기본값이어야 한다(타이핑하면 결과 그리드로 교체).
            pickerGrid
        } else {
            // 사전 검색은 키 입력마다 도는 경로다 — 분기와 그리드에서 `results`를 두 번 평가하지 않게
            // 한 번만 계산해 넘긴다(223종 스캔 x2 → x1).
            let hits = results
            VStack(alignment: .leading, spacing: ReffiSpace.s5) {   // 그리드 섹션 간격과 같은 값
                // 직접 입력 담기는 **결과 위**에 상시 선다 — 결과가 있어도 사용자가 친 표기가 사전
                // 표제어와 다를 수 있고(브랜드·규격), 결과가 없으면 이 행이 곧 빈 결과의 해법이다.
                directAddRow(trimmedQuery)
                if hits.isEmpty { noMatchCard } else { searchGrid(hits) }
            }
        }
    }

    /// 직접 입력 담기 — **친 그대로** 메모에 담는다(사전에 없어도). 사전 픽커가 닿지 못하는 칸을
    /// 사용자가 손으로 채우는 §13.5 To buy 예외의 마지막 조각이다.
    ///
    /// **타일이 아니라 전폭 행**인 이유: 타일은 74~96pt라 "Fish sauce brand X" 같은 자유 입력이
    /// 곧바로 잘린다. 사용자가 무엇을 담게 되는지는 이 행의 유일한 payload라 잘리면 안 된다.
    ///
    /// **담김 판정은 하되 탭을 막지 않는다** — 그리드와 같은 규약이다(`add(name:...)` 주석 참고):
    /// 뷰가 게이팅하면 파생 제안으로만 있던 품목을 수동으로 흡수하는 경로가 UI에서 도달 불가해진다.
    /// 담긴 상태에서는 타일과 **같은 도장**(`GlyphStamp`)이 찍히고 라벨이 'Added'로 바뀐다.
    private func directAddRow(_ query: String) -> some View {
        // 키 유도는 `addTyped`가 실제로 저장할 키와 **같은 식**이다(정확 일치 캐논, 없으면 소문자
        // 이름) — 축이 갈리면 도장과 실제 담김 판정이 어긋난다. 포함 매칭을 쓰면 안 되는 이유는
        // `addTyped` 주석 참고.
        let key = IngredientLexicon.shared.exactCanonicalID(for: query) ?? query.lowercased()
        let listed = store.toBuyKeys.contains(key)
        return Button {
            addTyped(query)
        } label: {
            HStack(spacing: ReffiSpace.s3) {
                ReffiIcon.add.reffi(16, .bold).foregroundStyle(ReffiColor.blueDark)
                Text("Add \"\(query)\"")
                    .reffiType(.body)
                    .foregroundStyle(ReffiColor.ink)
                    .lineLimit(2)                      // 긴 자유 입력도 잘리지 않게(두 줄까지)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: ReffiSpace.s2)
                GlyphStamp(icon: ReffiIcon.check, color: ReffiColor.blueDark, size: 13)
                    .opacity(listed ? 1 : 0)
                    .scaleEffect(listed ? 1 : 0.6)
            }
            .padding(.horizontal, ReffiSpace.s4)
            .padding(.vertical, ReffiSpace.s3)
            .frame(maxWidth: .infinity, minHeight: ReffiChrome.tapMin, alignment: .leading)   // §7.3 터치 타깃
            .background {
                // 그리드 타일과 같은 종이 문법(면 `receipt` + 옅은 그레인 + 헤어라인).
                let s = PaperRect(cornerRadius: ReffiRadius.md, seed: 7)
                s.fill(ReffiColor.receipt)
                    .overlay(PaperGrain(seed: 7, strength: 0.6).clipShape(s))
                    .paperEdge(s)
                    .compositingGroup()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.paperPress)
        // 라벨 문법은 타일과 같다(담김 여부를 라벨이 직접 말한다 — 트레잇만으론 상태가 어긋나 읽힌다).
        .accessibilityLabel(listed ? Text("Added \(query)") : Text("Add \(query)"))
        .accessibilityHint(Text("Adds the name exactly as typed."))
        .accessibilityAddTraits(listed ? [.isSelected] : [])
    }

    /// 직접 입력 담기 실행 — 해석은 **정확 일치까지만** 하고 끝낸다(`canonicalIsFinal`).
    /// 친 이름이 사전 표제어와 정확히 같으면 그 캐논으로 묶이고, 아니면 **친 그대로** 자유 항목이다.
    /// store의 포함 매칭 폴백에 맡기면 안 된다 — "Fish sauce brand X"가 fish에, 자유 표기가 남의
    /// 캐논에 붙어, 그 캐논이 이미 목록에 있으면 **담기가 조용한 no-op**이 된다(43ecb3a가 레시피
    /// 표기에서 막은 그 기전이 자유 입력으로 되살아난다). 글리프만 이름 매칭으로 추측한다(시각 전용).
    /// 애니메이션·햅틱 규약은 타일 담기(`add`)와 같다. 담긴 뒤에도 **시트는 닫히지 않고 검색어도
    /// 그대로 둔다** — 타일과 같은 연속 추가 UX이고, 남은 검색어 덕에 같은 행이 그 자리에서
    /// '담김' 도장으로 뒤집혀 방금 한 일이 눈에 보인다.
    private func addTyped(_ name: String) {
        let canon = IngredientLexicon.shared.exactCanonicalID(for: name)
        let added = withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) {
            store.addToBuy(name: name, canonicalID: canon, canonicalIsFinal: true)
        }
        if added { addHaptic += 1 }
    }

    /// 타일 한 칸의 표시 단위 — `key`는 matchKey(캐논 ID 또는 소문자 이름)로, '이미 담김' 판정과
    /// 종이결 시드와 캐논 해석에 모두 같은 값을 쓴다(축이 갈리면 같은 재료가 두 규칙을 탄다).
    private struct GridTile: Identifiable {
        let id: String
        let name: String
        let glyph: FoodGlyph
        let key: String
    }

    /// 원본 픽커(2026-08-01 삭제)의 열 규격 그대로 — 적응형 74~96pt, 거터 s2.
    private static let gridColumns = [GridItem(.adaptive(minimum: 74, maximum: 96), spacing: ReffiSpace.s2)]

    /// 삭제된 재료 픽커 시트의 **재료 배열 UI**를 그대로 되살린 자리 — 검색어가 비어 있는 동안 이
    /// 그리드가 시트를 채운다. 타일 치수는 원본 그대로다: 적응형 74~96pt 열 + 56pt 실루엣 타일.
    /// **Frequent(빨리 담기 단축키) 한 섹션뿐이다(2026-08, 30차 단순화)** — 원래 그 아래 사전 전체를
    /// `FoodGlyph.categoryOrder`로 묶은 카테고리 섹션(Veg·Dairy·Seafood…)이 이어졌지만, 223종 전체를
    /// 펼친 배열은 스크린샷 한 장이 다 못 담을 만큼 길어 "빨리 담기"라는 시트의 목적과 어긋났다(사용자
    /// 리포트). 사전은 여전히 `directAddRow` + 타이핑 검색(`searchGrid`)으로 전부 닿는다 — 이 배열은
    /// 그 경로를 대체하지 않고, 타이핑 없이 끝내는 흔한 경우만 커버한다. `frequentIngredients()`가
    /// 이력 부족분을 큐레이션 시드로 항상 채우므로(§FridgeStore) 이 섹션이 통째로 비는 일은 없다.
    /// **의미만 To buy 문맥이다**: 탭은 냉장고 반입이 아니라 `addToBuy`(장보기 메모)고, 시트는 닫히지
    /// 않으며, 이미 담긴 타일에는 결과 행과 같은 체크가 남는다.
    private var pickerGrid: some View {
        let listed = store.toBuyKeys      // 섹션당 한 번만 — 타일마다 파생 목록을 다시 계산하지 않게
        let frequent = store.frequentIngredients().map {
            GridTile(id: "freq-\($0.key)", name: $0.name, glyph: $0.glyph, key: $0.key)
        }
        return LazyVStack(alignment: .leading, spacing: ReffiSpace.s5) {
            if !frequent.isEmpty { gridSection("Frequent", tiles: frequent, listed: listed) }
        }
    }

    /// 섹션 = 모노 올캡 라벨 + 타일 그리드(원본 `gridSection`과 같은 문법).
    private func gridSection(_ label: LocalizedStringKey, tiles: [GridTile],
                             listed: Set<String>) -> some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            // 카테고리·Frequent는 **번역되는** 라벨이라 올캡 모노 role(`sectionLabel`)을 쓰지 않는다
            // (§3.5) — 한국어에선 `.textCase(.uppercase)`가 무동작이라 올캡이라는 시각 문법이
            // 사라지고 11pt에 자간 1.4만 남는다. 그 자리를 받는 것은 `caption`이 **아니라**
            // `groupLabel`이다: `caption`(14)은 문장으로 읽는 부제·안내문의 role이라, 이름표에
            // 얹으면 자기가 여는 타일 이름(`metaText` 13)보다 **커진다** — 묶음 이름표가 내용보다
            // 앞에 서는 것이고, 이름표는 자기가 읽히려는 게 아니라 아래를 열어 주는 줄이다.
            // 색이 `muted`인 것도 같은 이유다. 이 시트 바탕은 `canvas`이고 `muted`는 그 면 위에서
            // §2.6 하한을 넘는다(다섯 면 실측 범위는 `ReffiColor.muted` 주석).
            Text(label)
                .reffiType(.groupLabel)
                .foregroundStyle(ReffiColor.muted)
                // 섹션을 로터로 건너뛸 수 있게 — 시각 위계를 내렸으니 의미 위계는 트레잇이 진다.
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: Self.gridColumns, spacing: ReffiSpace.s2) {
                ForEach(tiles) { tile($0, listed: listed.contains($0.key)) }
            }
        }
    }

    /// 그리드 타일 — 종이 면 + 56pt 실루엣 + 이름(원본 픽커 타일 그대로). 담긴 항목엔 우상단 체크.
    /// 이름은 사전 표제어라 길 수 있어 말줄임보다 축소를 먼저 쓴다(원본과 같은 0.8).
    private func tile(_ item: GridTile, listed: Bool) -> some View {
        Button {
            // key는 이미 matchKey다 — 사전 항목이면 그대로 캐논으로 넘기고, 사전 밖 이름이면 nil로 둬
            // store가 이름 기준으로 폴백하게 한다(`dismissKey`와 같은 판별). 이름 역조회를 쓰면 같은
            // 표기를 공유하는 다른 항목에 붙을 수 있다.
            add(name: item.name,
                canonicalID: IngredientLexicon.shared.entry(id: item.key) != nil ? item.key : nil,
                glyph: item.glyph)
        } label: {
            VStack(spacing: ReffiSpace.s1) {
                PaperSilhouette(glyph: item.glyph, fresh: .fresh)
                    .frame(width: ReffiFoodIcon.tile, height: ReffiFoodIcon.tile)
                Text(verbatim: item.name)
                    .reffiType(.metaText)
                    .foregroundStyle(ReffiColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(ReffiShrink.chrome)
            }
            .padding(.vertical, ReffiSpace.s2)
            .padding(.horizontal, ReffiSpace.s1)
            .frame(maxWidth: .infinity, minHeight: ReffiChrome.tapMin)   // §7.3 터치 타깃
            .background {
                // 종이 시드는 `ReffiHash.stable` — `String.hashValue`는 런치마다 시드가 바뀌어 같은 타일이
                // 매번 다른 종이결로 뜨고 스크린샷 회귀가 불가능해진다(요리 아이콘 색과 같은 유틸을 공유한다).
                // 셰입 시드는 `% 4`(PaperRect의 지터 표가 4행)이고 **그레인 시드는 해시 전체**다 —
                // 셰입이 4종으로 겹쳐도 반점·섬유결이 칸마다 달라 12칸이 서로 다른 종이 조각으로 읽힌다.
                let h = ReffiHash.stable(item.key)
                let s = PaperRect(cornerRadius: ReffiRadius.md, seed: Int(h % 4))
                // 면색은 `receipt` — 원본 타일의 인라인 값 oklch(0.985, 0.004, 90)이 곧 이 토큰이고,
                // 같은 시트의 noMatchCard도 receipt라 시트 안 흰 종이가 한 토큰으로 통일된다.
                s.fill(ReffiColor.receipt)
                    // 반복되는 소형 면이라 옅게(§13.5 — 드롭다운 0.6·냉장고 카드 0.7과 같은 대역).
                    .overlay(PaperGrain(seed: h, strength: 0.6).clipShape(s))
                    .paperEdge(s)
                    .compositingGroup()   // overlay 블렌드 그레인을 타일 경계에 가둔다
            }
            .overlay(alignment: .topTrailing) {
                // 담김 = **도장 각인**(§13.5). 체크 글리프만 있으면 어느 앱에나 있는 픽커 체크로 읽혀
                // 이 시트에서 브랜드가 사라진다 — D-day 도장과 같은 문법(기울어진 외곽선 + 잉크)으로
                // 찍어, 담긴 칸이 "도장 찍힌 종이"가 되게 한다.
                GlyphStamp(icon: ReffiIcon.check, color: ReffiColor.blueDark, size: 13)
                    .padding(ReffiSpace.s1)
                    .opacity(listed ? 1 : 0)
                    .scaleEffect(listed ? 1 : 0.6)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.paperPress)
        // 라벨이 담김 상태를 직접 말한다 — `.isSelected` 트레잇만으로는 "사과, 선택됨, 버튼 / Add 사과"
        // 처럼 라벨과 상태가 어긋나 읽힌다. 검색 결과 타일도 이 함수를 쓰므로 수정 지점은 여기 하나다.
        .accessibilityLabel(listed ? Text("Added \(item.name)") : Text("Add \(item.name)"))
        .accessibilityAddTraits(listed ? [.isSelected] : [])
    }

    /// 담기 — **그리드 타일·결과 행 공통**. 탭을 뷰에서 미리 막지 않고 **항상 store로 보낸다**:
    /// 이미 수동으로 담긴 것이면 `addToBuy`가 false를 돌려 자연 no-op이고, 파생 제안으로만 떠 있던
    /// 품목이면 여기서 수동 항목이 되어 그 제안을 흡수한다. 뷰가 `listed`로 게이팅하면 흡수 경로가
    /// UI에서 영영 도달 불가해진다(통합 보고서 §8.3 해소).
    private func add(name: String, canonicalID: String?, glyph: FoodGlyph) {
        let added = withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) {
            store.addToBuy(name: name, canonicalID: canonicalID, glyph: glyph)
        }
        if added { addHaptic += 1 }
    }

    /// 검색 결과 — 원본 픽커와 같은 **같은 타일 그리드**다(영수증 리스트가 아니다). 한 시트 안에서
    /// 타이핑 전후로 시각 언어가 갈리면 안 된다: 쿼리는 배열을 *거르는* 조작이지 다른 화면으로 가는
    /// 조작이 아니고, 결과 타일은 `tile(_:listed:)`를 그대로 재사용해 표현·접근성·담기 규칙이 한 곳이다.
    private func searchGrid(_ hits: [IngredientLexicon.Entry]) -> some View {
        let listed = store.toBuyKeys      // 그리드당 한 번만 — 타일마다 파생 목록을 다시 계산하지 않게
        let tiles = hits.map {
            GridTile(id: "search-\($0.id)", name: $0.displayName,
                     glyph: FoodGlyph(rawValue: $0.glyph) ?? .generic, key: $0.id)
        }
        return LazyVStack(alignment: .leading, spacing: ReffiSpace.s5) {
            LazyVGrid(columns: Self.gridColumns, spacing: ReffiSpace.s2) {
                ForEach(tiles) { tile($0, listed: listed.contains($0.key)) }
            }
        }
    }

    /// 사전에 결과가 없을 때 — "없다"는 사실만 말하고, 해법은 **위의 직접 입력 행**이 쥔다.
    /// 옛 문구("Try another name.")는 이제 나쁜 조언이다: 바로 위에 친 그대로 담는 길이 열려 있는데
    /// 다른 이름을 찾으라고 미는 셈이라, 두 안내가 서로를 부정한다.
    private var noMatchCard: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            Text("No match").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
            Text("Add it as typed, or try another name.")
                .reffiType(.body).foregroundStyle(ReffiColor.ink2)
        }
        .receiptSurface(elevated: .flat)
    }
}
