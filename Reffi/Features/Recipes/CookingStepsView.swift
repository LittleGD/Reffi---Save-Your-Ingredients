import SwiftUI
import PhosphorSwift
import UIKit

/// 조리 세션 티켓(§13.6) — 발주 직후, 그리고 메인의 Cooking now 카드에서 열리는 조리 화면.
/// 발주된 티켓 한 장이 그대로 조리 중 상태판이 된다: 무엇을 몇 개로 굽고 있는지, 언제 시작했는지,
/// 그리고 **어떻게 만드는지는 여전히 영상이 1차 경로**다(앱은 단서까지, 디테일은 유튜브).
/// 세션(시작 시각·예약 재료)은 store에 영속화되어 앱을 껐다 켜도 이어진다.
///
/// **점진적 공개로 단계가 돌아왔다(2026-08, 39차 — 33c8861 오너 테제의 부분 반전).** 티켓 본문
/// 자체엔 여전히 단계 텍스트가 한 글자도 없다 — 대신 단계가 있는 레시피에만 요리 아이콘 바로 아래
/// 조용한 톤(`kind: .secondary`)의 종이 버튼("How to cook", 48차 — "Steps"(44차)가 내용이 와닿지
/// 않는다는 피드백으로 교체. 41차엔 39차의 밑줄 링크를 대체)이
/// 서고, 탭하면 `KitchenCopySheet`가 하단에서 올라온다. 영상 CTA는 이 버튼의 유무와 무관하게
/// 항상 조리법의 1차 경로를 맡는다(§actions) — 자리가 없어지는 게 아니다.
/// **49차**: 단계·영상·공유 셋이 한 문법(종이컷 secondary)으로 모였다 — 위계는 색이 아니라 순서와 폭이다.
/// 파일명은 진입점 참조가 흩어져 있어 그대로 둔다.
struct CookingStepsView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    var onClose: () -> Void

    @State private var finishHaptic = 0
    @State private var showFinishSheet = false
    @State private var showCancelConfirm = false
    /// 주방 전표 시트 열림(39차). 단계가 없으면 이 값을 켤 링크 자체가 안 서므로 방어적 nil 처리가
    /// 필요 없다 — 시트 콘텐츠는 그 시점의 `store.activeCook`에서 다시 읽는다(진행 중 세션의 체크
    /// 상태가 store에 바로 반영되므로, 여기 로컬 스냅샷을 따로 들지 않는다).
    @State private var showKitchenCopy = false
    @State private var leftovers: Set<UUID> = []   // '조금 남았어요'로 표시한 재료
    @State private var shareImage: Image?   // 공유 카드 오프스크린 렌더 결과 — 아래 ShareCardKey가 바뀔 때만 갱신

    /// 예약된 재료(아직 냉장고에 있는 것) — 완료 확인 시트의 목록.
    private var reservedIngredients: [Ingredient] {
        guard let ids = store.activeCook?.usedIDs else { return [] }
        let byID = Dictionary(store.ingredients.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return ids.compactMap { byID[$0] }
    }

    /// 예약 재료의 표시 이름 — 대체 투입(세션 `subNotes`)이면 "생크림 (우유 대신)"처럼 대신한 줄을
    /// 함께 말한다. 완료 시트·공유 카드가 같은 해석을 쓴다(오더 티켓 `ticketLine`과 한 문구).
    private func reservedName(_ ing: Ingredient) -> String {
        store.activeCook?.subNotes?[ing.id.uuidString]
            .map { Ingredient.substitutionLabel(stockName: ing.displayName, lineName: $0) }
            ?? ing.displayName
    }

    /// 공유 카드 재렌더 키 — **카드에 인쇄되는 값 전부**를 담는다. 재료 이름은 세션 스냅샷이 아니라
    /// 라이브 재고에서 파생되므로(`reservedIngredients`), 조리 중에 예약 재료를 버리거나 지우면
    /// 화면은 갱신되는데 이미지만 옛 이름을 그대로 들고 있게 된다. 키를 이름 목록까지 넓혀 막는다.
    /// `icon`도 같은 이유다 — 조리 중 원본 레시피가 삭제되면 화면 아이콘은 세션 폴백으로 갈아타는데
    /// 이미지가 옛 그림을 들고 있으면 화면과 공유 이미지가 다른 요리를 보인다.
    /// 항목을 늘릴 땐 `RecipeShareCard`의 입력과 1:1을 유지할 것.
    /// `.task(id:)`는 Equatable만 요구한다 — `RecipeHeroIcon`에 Hashable을 더할 필요가 없다.
    /// 테스트가 키 조합을 직접 잠그므로 internal(`DishGlyphTests.CookingShareCardKeyTests`).
    struct ShareCardKey: Equatable {
        var recipeName: String
        var ingredientNames: [String]
        var minutes: Int?
        var count: Int
        var icon: RecipeHeroIcon
    }

    private func shareCardKey(for cook: FridgeStore.CookSession) -> ShareCardKey {
        ShareCardKey(recipeName: cook.recipeName,
                     ingredientNames: reservedIngredients.map(reservedName),
                     minutes: cook.minutes,
                     count: cook.count,
                     icon: heroIcon(for: cook))
    }

    /// 세션의 히어로 아이콘 — 발주 때 남긴 레시피 id로 **원본 레시피를 되찾아** 오더 티켓과 같은
    /// `heroIcon` 체인을 탄다. 카탈로그를 직접 부르면 커스텀 "김밥"이 티켓에선 손으로 그린 김밥,
    /// 여기선 아무 색 롤로 갈린다.
    /// 레시피가 지워졌거나 id가 없는 구버전 세션이면 이름만으로 폴백한다(빈 아이콘은 나오지 않는다).
    private func heroIcon(for cook: FridgeStore.CookSession) -> RecipeHeroIcon {
        if let id = cook.recipeID, let recipe = store.recipes.first(where: { $0.id == id }) {
            return recipe.heroIcon
        }
        return .session(name: cook.recipeName, id: cook.recipeID)
    }

    /// 참고 단계 — 판정 자체는 `FridgeStore.CookSession.resolvedSteps(snapshot:recipeID:in:)`(순수 규칙,
    /// 유닛 테스트로 고정)에 위임한다. 여기서는 그 규칙에 `store.recipes`를 넘기기만 한다.
    /// 링크 게이트(`if let steps = resolvedSteps(...)`)와 시트 콘텐츠가 **이 함수 하나만** 부르므로,
    /// 시트가 렌더하는 배열과 `completedSteps`가 가리키는 배열이 항상 같다 — 인덱스가 어긋날 길이 없다.
    private func resolvedSteps(for cook: FridgeStore.CookSession) -> [String]? {
        FridgeStore.CookSession.resolvedSteps(snapshot: cook.steps, recipeID: cook.recipeID, in: store.recipes)
    }

    /// 세션의 요리 소개 — 히어로 아이콘과 **같은 체인**으로 원본 레시피를 되찾아 한 줄을 읽는다.
    /// 아이콘과 달리 폴백이 없다: 조리 중 레시피가 지워졌거나(id 유실) 소개가 없는 커스텀 레시피면
    /// nil이고, 그 자리엔 아무것도 그리지 않는다. 세션 스냅샷에 소개문을 또 박지 않는 이유도 같다 —
    /// 원본이 사라진 뒤에도 옛 문장을 들고 있으면 화면이 없는 레시피를 설명하게 된다.
    private func intro(for cook: FridgeStore.CookSession) -> String? {
        guard let id = cook.recipeID else { return nil }
        return store.recipes.first(where: { $0.id == id })?.displayIntro
    }

    /// 티켓 좌우 인셋 — 영수증 종이의 폭을 정하는 유일한 값(히어로 아이콘 크기가 여기서 파생된다).
    ///
    /// 아래 `ticketWidth`는 `geo.size.width`에서 이 인셋만 빼고 **좌우 safe area는 빼지 않는다**.
    /// `GeometryReader.size`는 safe area를 제외해 주지 않기 때문에(형제 `RecipeMemoCarousel`이
    /// 세로 계산에서 `geo.safeAreaInsets`를 직접 빼는 이유가 그것이다) 원칙적으로는 빼야 맞지만,
    /// 앱이 `Info.plist`에서 **세로 고정**이라 세로 아이폰의 좌우 인셋은 항상 0이다 — 지금은 같은 값이다.
    /// 가로 모드나 iPad를 지원하게 되면 여기도 `geo.safeAreaInsets.leading/.trailing`을 빼야 한다.
    private let ticketInset = ReffiGrid.margin + ReffiSpace.s2   // 24 — 티켓 계열 공통 인셋(§9.2)

    /// 공유 카드를 굽기까지의 유예(초) — 풀스크린 커버 전환(§7.1 dur-3, 0.24s)이 끝나고도 한 박자
    /// 남는 값이다. 짧게 잡으면 전환 마지막 프레임과 겹치고, 길게 잡으면 공유를 바로 누른 손이
    /// 비활성 플레이스홀더를 본다(카드 한 장 렌더는 그 뒤 곧바로 끝난다).
    private static let shareBakeDelay: Double = 0.5

    var body: some View {
        // 히어로 아이콘 크기가 **영수증 폭에 비례**하므로 컨테이너 폭을 실측해야 한다.
        // GeometryReader는 ScrollView **바깥**에 둔다 — 안에 두면 스크롤 콘텐츠 높이가 무너진다.
        // 폭은 평범한 인자로 아래로 흘린다(`RecipeMemoCarousel`이 cardHeight를 넘기는 선례).
        GeometryReader { geo in
            ZStack(alignment: .top) {
                ReffiColor.paperPass.ignoresSafeArea()
                if let cook = store.activeCook {
                    ScrollView {
                        ticket(cook, ticketWidth: max(0, geo.size.width - ticketInset * 2))
                            .padding(.horizontal, ticketInset)
                            // 상단 여백은 **여기서 주지 않는다.** 헤더가 `safeAreaInset`으로 제 높이를
                            // 가져가고 그 아래 s6 페이드 띠까지 스스로 붙이므로, 티켓은 페이드가 끝나는
                            // 지점에서 시작한다(헤더 하단 s3 + 페이드 s6 = 40 — 덱의 `deckGap` 계산과
                            // 같은 값으로 수렴한다). 여기에 값을 더하면 그 40에 이중으로 얹힌다.
                            .padding(.bottom, ReffiSpace.s6)
                    }
                    // 공유 카드에 인쇄되는 값(메뉴명·예약 재료 이름·시간·개수)이 바뀔 때만 다시 렌더한다.
                    // 새 세션은 물론, 조리 중 예약 재료가 사라지는 경우까지 이 키가 덮는다.
                    //
                    // **전환이 끝난 뒤에 굽는다.** `ImageRenderer(scale: 3)`는 카드 한 장을 통째로
                    // 레이아웃하고 래스터라이즈하는 동기 작업인데, `.task`는 커버가 올라오는 그
                    // 프레임에 붙어 있어 발주 → 조리 화면 전환 한복판에서 메인 스레드를 물었다
                    // (공유는 이 화면의 보조 행동이고, 도달까지는 최소 한 번의 탭이 더 남아 있다).
                    // 재료를 지우는 등으로 키가 바뀌면 이 대기부터 다시 시작한다 — 취소가 곧 최신화다.
                    .task(id: shareCardKey(for: cook)) {
                        try? await Task.sleep(for: .seconds(Self.shareBakeDelay))
                        guard !Task.isCancelled else { return }
                        shareImage = renderShareImage(for: cook, icon: heroIcon(for: cook))
                    }
                }
            }
        }
        // **상단도 하단과 같은 규칙으로 도킹한다(50차 오너).** 헤더는 `safeAreaInset`으로 제 높이를
        // 스스로 가져가고, 그 뒤에는 `topBar`가 붙인 불투명 면 + 페이드 띠가 깔린다.
        //
        // 옛 배치는 헤더를 ZStack 맨 위에 겹쳐 놓고 실측 높이를 아래 콘텐츠의 상단 패딩으로 되먹였다.
        // 두 가지가 동시에 깨져 있었다: ① 헤더에 면이 없어(=투명한 글자 덩어리) 화면 전체를 차지한
        // ScrollView의 티켓이 "Cooking now" 위를 그대로 통과했다 — 패딩은 **정지 위치**만 정할 뿐
        // 스크롤 이동을 막지 못한다 ② 실측이 도착하기 전 첫 프레임이 근사 초기값으로 그려져 큰 글씨에서
        // 티켓이 한 번 내려앉았다. 인셋으로 옮기면 ②가 구조적으로 사라지고, ①은 아래 `topBar`의
        // 불투명 면이 맡는다 — 둘은 세트다(`safeAreaInset`은 콘텐츠를 인셋 뷰 **밑으로 흘리는** 것이
        // 본래 동작이고, `dockedCTA`가 그 위에 면을 까는 이유가 정확히 그것이다).
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        // 확정 액션은 티켓 안이 아니라 화면 하단에 도킹한다(§13.6) — 티켓이 짧아도 CTA가 화면 중턱에
        // 뜨지 않고, 메인·시트의 하단 CTA 관례와 같은 자리에서 엄지로 닿는다. 본문(티켓)만 스크롤한다.
        .dockedCTA(over: ReffiColor.paperPass) { bottomBar }
        .reffiFeedback(.success, trigger: finishHaptic)
        #if DEBUG
        // `-cookTicket.kitchenCopy` — 주방 전표 시트를 곧장 연다(39차, `-cookTicket` 선례를 그대로
        // 잇는 점 네임스페이스 플래그). `-cookTicket`이 이미 seed 레시피로 발주하고(전량 단계 보유)
        // 이 화면을 여니, 여기선 시트 하나만 더 올리면 된다 — 화면이 자리 잡을 짧은 유예 후에.
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-cookTicket.kitchenCopy") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showKitchenCopy = true }
            }
        }
        #endif
        // 완료·취소(또는 발주 undo)로 세션이 사라지면 자동으로 닫힌다.
        .onChange(of: store.activeCook == nil) { _, gone in
            if gone { onClose() }
        }
        // 완료 확인 — 재료별 '다 썼어요(기본)/조금 남았어요' 원탭. 여기서 소비가 확정된다.
        .sheet(isPresented: $showFinishSheet) {
            finishSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)   // 룰④ — 하단 시트는 dragIndicator(핸들) 필수, 닫기 신호 확보
        }
        // 주방 전표(39차) — 티켓 안 "How to cook"(48차) 링크가 연다.
        // 체크는 store에 바로 반영되므로(`toggleCookStep`) 시트를 닫았다 열어도, 앱을 껐다 켜도 유지된다.
        .sheet(isPresented: $showKitchenCopy) {
            if let cook = store.activeCook {
                KitchenCopySheet(recipeName: cook.recipeName,
                                  steps: resolvedSteps(for: cook) ?? [],
                                  completedSteps: Set(cook.completedSteps ?? [])) { index in
                    store.toggleCookStep(index)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)   // 룰④
            }
        }
        // 종이 확인으로 전환(2026-08, 35차 사용자 결정) — design_system.md §14.7이 조리 취소를
        // "그대로 시스템" 목록에서 뺀 경우다. primary에 `role: .destructive`를 줘 `PaperDialog`가
        // 파랑 대신 urgentDark 솔리드로 그리게 한다(파괴 행동에 파랑을 쓰지 않는다).
        // 뒷배경 탭 = Keep(질문형 안전 기본값, §14.7). "Cancel"을 파괴 확정에 쓰지 않는 근거(42차)는
        // 그대로다 — 다른 다이얼로그 전부에서 Cancel은 "안전하게 빠져나감"(secondary)이다.
        .paperDialog(isPresented: $showCancelConfirm,
                     title: "Put ingredients back?",
                     message: "Nothing is logged.\nReserved ingredients return to the fridge.",
                     backdropDismisses: true,
                     primary: PaperDialogAction("Stop", role: .destructive) {
                         withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) {
                             store.cancelCooking()
                         }
                     },
                     secondary: PaperDialogAction("Keep") {})
    }

    // MARK: - 하단 도킹 CTA

    /// 확정 액션 한 쌍 — 파랑 "Finish cooking"(완료) + 조용한 "조리 취소" 텍스트 버튼.
    /// 티켓에서 떼어 왔지만 **순서·문법은 그대로**다: 확정이 위, 되돌리는 길이 아래.
    /// 세션이 없으면(닫히는 프레임) 아무것도 그리지 않아 빈 바가 남지 않는다.
    @ViewBuilder private var bottomBar: some View {
        if store.activeCook != nil {
            VStack(spacing: 0) {
                PaperButton(title: "Finish cooking") {
                    // 예약 재료가 있으면 확인 시트에서 확정(남은 재료 원탭), 없으면(구버전 세션) 바로 종료.
                    if reservedIngredients.isEmpty {
                        finishHaptic += 1
                        withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) {
                            store.finishCooking()
                        }
                    } else {
                        leftovers = []
                        showFinishSheet = true
                    }
                }

                // 조리 포기 — 예약을 해제하고 재료를 되돌린다(기록 없음). fire의 안전한 반대 방향.
                // 종이 버튼화(2026-08, 35차) 후 42차에서 라벨을 "Put ingredients back"으로 —
                // 다이얼로그 제목("Put ingredients back?")과 같은 동사를 쓴다. 실행 버튼은 pr20의
                // 한 단어 규칙(§14.7)으로 "Stop"이고, "Cancel"이라는 낱말은 앱 전역에서
                // secondary(안전한 빠져나감) 전용으로 예약한다.
                // 파랑 "Finish cooking"과 경쟁하지 않도록 면 없는 조용한 등급은 유지한다.
                QuietButton(title: "Put ingredients back", tint: ReffiColor.urgentDark) {
                    showCancelConfirm = true
                }
                .accessibilityHint(Text("Nothing is logged."))
            }
        }
    }

    // MARK: - 완료 확인 시트 (소비 확정 지점)

    private var finishSheet: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s4) {
            VStack(alignment: .leading, spacing: ReffiSpace.s0) {
                Text("Anything left over?").reffiType(.heading).foregroundStyle(ReffiColor.ink)
                Text("Leftovers stay in the fridge at half the amount.")
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
            }
            ScrollView {
                VStack(spacing: ReffiSpace.s2) {
                    ForEach(reservedIngredients) { ing in
                        leftoverRow(ing)
                    }
                }
            }
            PaperButton(title: "Confirm & finish") {
                finishHaptic += 1
                showFinishSheet = false
                withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) {
                    store.finishCooking(leftovers: leftovers)
                }
            }
        }
        .padding(ReffiSpace.s5)
        .background(ReffiColor.canvas)
    }

    /// 재료 한 줄 — 탭으로 '다 썼어요 ↔ 조금 남았어요' 토글. 기본은 다 씀(마찰 0).
    private func leftoverRow(_ ing: Ingredient) -> some View {
        let left = leftovers.contains(ing.id)
        return Button {
            if left { leftovers.remove(ing.id) } else { leftovers.insert(ing.id) }
        } label: {
            HStack(spacing: ReffiSpace.s3) {
                PaperSilhouette(glyph: ing.glyph, fresh: ing.freshness)
                    .frame(width: ReffiFoodIcon.rowMini, height: ReffiFoodIcon.rowMini)
                Text(verbatim: reservedName(ing))
                    .reffiType(.body).foregroundStyle(ReffiColor.ink).lineLimit(1)
                Spacer(minLength: ReffiSpace.s2)
                Text(left ? "Some left" : "Used it all")
                    .reffiType(.pillLabel)
                    .foregroundStyle(left ? ReffiColor.soonDark : ReffiColor.freshDark)
                    .padding(.horizontal, ReffiSpace.s3)
                    .padding(.vertical, ReffiSpace.s1)
                    // §13.1 종이컷 8각형(캡슐 금지) — 행동 표면의 상태 칩도 종이 문법을 따른다.
                    .background((left ? ReffiColor.soonLight : ReffiColor.freshLight), in: PaperCutRect(seed: 5))
            }
            .padding(.horizontal, ReffiSpace.s3)
            .padding(.vertical, ReffiSpace.s2)
            .frame(minHeight: ReffiChrome.tapMin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.reffiPress)
        .accessibilityLabel(Text(verbatim: ing.displayName))   // 재료명은 데이터 — 번역 키가 아니다(§i18n)
        .accessibilityValue(left ? Text("Some left") : Text("Used it all"))
        .accessibilityHint(Text("Toggles whether some is left over"))
    }

    /// 커버 헤더 — 단일 공급원 `CoverHeader`(§14.2) + **상단 도킹 면**.
    /// 경과 시간은 accessory 슬롯에 둔다 — `style: .relative`라 시스템이 알아서 라이브 갱신한다.
    ///
    /// 배경은 `PaperButton.dockedCTA`를 **위아래 뒤집은 것**이다: 불투명 면이 노치까지 이어지고,
    /// 아래쪽 `s6` 띠만 화면 바탕색으로 페이드한다. 스크롤한 티켓이 헤더 글자 밑에서 사라지되
    /// 직선에서 뚝 끊기지 않는다(끊기면 그 자리가 다시 '층'으로 읽힌다 — 46차 히어로 밴드 판정).
    /// 46차의 "배경은 단색"은 *화면 바탕*에 대한 규칙이고, 이 띠는 §13.6이 하단 도킹 바에 이미
    /// 명문화한 같은 장치라 충돌하지 않는다.
    ///
    /// 이 조립이 `dockedCTA` 옆의 `dockedHeader`가 아니라 여기 있는 이유: 50차 시점에 상단을 도킹하는
    /// 커버가 이 화면 하나뿐이다(덱은 `ScrollView`가 아니라 면이 필요 없다). **두 번째 호출부가
    /// 생기면 그때 `PaperButton`의 `dockedCTA` 옆으로 올릴 것** — 손으로 두 벌을 유지하면 페이드
    /// 높이가 화면별로 갈린다.
    private var topBar: some View {
        CoverHeader(title: "Cooking now",
                    closeHint: "Keeps cooking in progress",   // 닫아도 세션은 남는다는 결과 예고
                    onClose: onClose) {
            if let cook = store.activeCook {
                // 한 구(句)를 두 role로 쪼개지 않는다 — "Started"가 caption(14/자간 +0.14),
                // 바로 옆 경과 시간이 metaText(13/자간 0)라 같은 문장 안에서 1pt·자간만 어긋나
                // 위계가 아니라 어색한 이격으로만 보였다. 데이터형 메타 하나로 묶는다(§3.5).
                HStack(spacing: ReffiSpace.s0) {
                    Text("Started")
                    // 상대 시간 표기는 기기 로케일을 따른다(38차 결정 — 앱 언어와 분리, 아래 근거).
                    Text(cook.startedAt, style: .relative)
                        .environment(\.locale, .autoupdatingCurrent)
                }
                .reffiType(.metaText).foregroundStyle(ReffiColor.ink2)
            }
        }
        .padding(.bottom, ReffiSpace.s6)   // 페이드 띠 높이와 같다 — 티켓은 띠가 끝나는 지점에서 시작한다
        .background {
            VStack(spacing: 0) {
                ReffiColor.paperPass       // 불투명 — 노치·상태바까지 이어진다
                LinearGradient(colors: [ReffiColor.paperPass, ReffiColor.paperPass.opacity(0)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: ReffiSpace.s6)
            }
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)       // 면은 그림일 뿐 — X 버튼 밖의 탭을 삼키지 않는다
        }
    }

    // MARK: - 조리 티켓

    /// - Parameter ticketWidth: 영수증 종이의 실측 폭 — 히어로 아이콘이 그 절반으로 선다.
    private func ticket(_ cook: FridgeStore.CookSession, ticketWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s3) {
            // 헤더 — 오더 티켓과 같은 모노 크롬. "N used" 수치는 조리 화면에서 뺐다(2026-08, 42차)
            // — 공유 카드(RecipeShareCard)는 별도 표면이라 그대로 둔다.
            Text(verbatim: "ORDER · FIRED")
                .reffiType(.monoTicketLabel).foregroundStyle(ReffiColor.urgentDark)

            // 메뉴명 — 조리 티켓에선 이름만 한 줄로 둔다. 아이콘은 아래 히어로 블록이 맡는다.
            Text(verbatim: cook.recipeName)
                .reffiType(.menuName).foregroundStyle(ReffiColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            ReffiRule(.ticket)

            // 요리 아이콘 — **조리 티켓의 중심**이다. 오더 티켓은 여러 장을 훑어 고르는 단서 카드라
            // 그림이 오른쪽 여백에 얹힌 68pt 식별자지만(§13.5), 여기는 이미 고른 한 요리를 붙들고
            // 서 있는 화면이라 "지금 무엇을 만들고 있나"에 종이 한복판을 내준다.
            // 크기는 영수증 폭의 절반 — 고정 pt를 박으면 기기·글자 크기에 따라 여백 비율이 갈린다.
            // 두 실루엣 모두 Canvas라 어느 크기에서도 같은 그림이고, 장식이라 VoiceOver엔 뜨지 않는다
            // (읽히는 정보는 위 메뉴명이 맡는다 — 옛 자리에서 그대로 이어지는 규칙).
            // 그림과 그 한 줄 설명은 **한 덩어리**다 — 사이를 s2로 좁혀 붙이고, 바깥 s2로 위아래를
            // 띄운다(캡션과 영상 CTA 사이는 s2+VStack s3 = 20이라 CTA에 붙어 보이지 않는다).
            // 일러스트는 **텍스트가 아니라 그림**이라 종이 한복판을 쓴다(§9.4 정렬 원칙의 예외 ③).
            // 아래 소개문과 한 덩어리로 묶어 가운데 정렬하던 것을 49차에 풀었다 — 그 묶음 때문에
            // 카드 안에 좌측선(크라운·메뉴명·버튼)과 중앙선(소개문) 둘이 서서, 설명이 어디에도
            // 걸리지 않고 떠 보였다(오너 지적). 그림만 가운데 남기고 글자는 전부 좌측선으로 돌린다.
            RecipeHeroIconView(icon: heroIcon(for: cook))
                .frame(width: ticketWidth * 0.5, height: ticketWidth * 0.5)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                // 요리 소개 — 무엇이고 어느 나라 음식인가. 시드 레시피에만 있고, 없으면
                // **아무것도 그리지 않는다**(빈 자리표시는 티켓을 늘리기만 한다).
                if let intro = intro(for: cook) {
                    // **2줄로 자르지 않는다.** 시드 80종을 번들 폰트로 실측하면 기본 크기·SE에서
                    // 1종, xxLarge에서 43종, xxxLarge에서 70종이 2줄을 넘긴다(한국어는 0종 —
                    // 영문만 깨진다). 잘린 소개는 "무엇이고 어느 나라 음식인가"라는 이 줄의 유일한
                    // 일을 못 한다. 3줄까지 흐르게 두고 그 뒤로만 축소한다 — 히어로 아래 캡션이라
                    // 세로로 조금 자라도 아래 CTA를 밀어내지 않는다.
                    Text(verbatim: intro)
                        .reffiType(.caption)
                        .foregroundStyle(ReffiColor.ink2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(3)
                        .minimumScaleFactor(ReffiShrink.subtle)
                        .fixedSize(horizontal: false, vertical: true)
                        // UI 테스트 훅 — 소개 문구를 테스트에 하드코딩하지 않고 집는다
                        // (`ticket.menuName` 선례). 라벨은 그대로라 VoiceOver는 문장을 읽는다.
                        .accessibilityIdentifier("cook.intro")
                }

                // 정보와 행동을 절취선으로 가른다(49차) — 영수증의 기존 어휘 그대로다. 소개문이
                // 아래 버튼 무리에 곧장 이어지면 설명인지 버튼 캡션인지가 흐려져, 그 모호함이
                // "설명이 붕 떠 있다"로 읽힌다. 선 하나가 그 아래를 행동 구역으로 선언한다.
                ReffiRule(.ticket)

                // 조리법 두 경로(단계·영상)와 공유 — **셋이 한 문법**이다(49차). 예전엔 단계 버튼만
                // 정본 `PaperButton`이고 영상은 손조립 틴트 면, 공유는 블롭+아래 라벨이라 한 무리
                // 안에서 표면이 셋으로 갈렸다. 전부 같은 종이컷 secondary 면으로 통일하고 위계는
                // **순서와 폭**으로만 준다 — 파란 솔리드는 이 화면에 이미 하나뿐이다(하단 Finish, §2.4).
                actions(for: cook)
            }

        }
        .padding(.horizontal, ReffiSpace.s5)
        .padding(.vertical, ReffiSpace.ticketTop)
        .background(ReceiptShape(tooth: ReffiTooth.ticket).fill(ReffiColor.paper))
        .overlay(ReceiptShape(tooth: ReffiTooth.ticket).stroke(ReffiColor.paperEdge, lineWidth: 1))
        .reffiShadow1()
    }

    /// 티켓의 행동 구역 — 조리법 두 경로(단계·영상)와 공유가 **한 문법·한 등급**으로 선다(49차).
    ///
    /// 셋 다 `PaperButton` 계열 secondary(카드 위라 `onCard`)다. 예전에는 영상 버튼이 콜사이트에서
    /// 표면을 손으로 재조립해(틴트 면 + 강조 아웃라인 + 그레인) 앱 어디에도 없는 네 번째 CTA 재질을
    /// 만들었고, 공유만 블롭 아래에 라벨을 달아 행 안에서 혼자 키가 달랐다. 표면을 정본 하나로 모으면
    /// 위계를 색으로 지어낼 필요가 없어진다 — **순서**(깊은 것부터)와 **폭**(주행동이 넓다)이 대신한다.
    ///
    /// 행 구성: 조리 단계는 있을 때만 서므로 전폭 한 줄로 먼저 두고, 영상·공유는 성격이 갈리는
    /// 한 쌍이라 같은 줄에 넓은 것과 좁은 것으로 앉힌다.
    private func actions(for cook: FridgeStore.CookSession) -> some View {
        // 한 줄에 들어가면 칩 행, 넘치면 전폭 스택 — 후보 둘이 **같은 하위 뷰**를 공유해 한쪽만
        // 조용히 어긋나는 경로를 구조로 막는다(판정 3버튼·알림 배너가 쓰는 그 처세).
        // 큰 글자·긴 번역에서 칩 세 개가 안 들어가면 자동으로 옛 스택 배치로 내려간다.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: ReffiSpace.s3) { actionButtons(for: cook, compact: true) }
            VStack(spacing: ReffiSpace.s3) { actionButtons(for: cook, compact: false) }
        }
    }

    /// 티켓의 보조 행동 셋 — 두 배치가 **같은 버튼 셋**을 같은 순서로 세운다.
    @ViewBuilder
    private func actionButtons(for cook: FridgeStore.CookSession, compact: Bool) -> some View {
        // **39차-b**: 스냅샷만 보면 39차 이전에 발주된 구세션은 `cook.steps`가 nil이라 이 버튼이
        // 실제 단계 있는 레시피에서도 안 섰다(실기기 리포트) — `resolvedSteps(for:)`가 스냅샷 →
        // 원본 레시피 순으로 폴백해 게이트와 시트 콘텐츠가 항상 같은 답을 보게 한다.
        if resolvedSteps(for: cook) != nil {
            PaperButton(title: "How to cook", kind: .secondary, fullWidth: !compact, seed: 6,
                        icon: ReffiIcon.recipe, onCard: true, compact: compact) {
                showKitchenCopy = true
            }
            // accessibilityLabel 제거(48차) — "How to cook"은 이미 서술적이라 별도 라벨은 이중화만 남긴다.
            .accessibilityHint(Text("Opens the full list of cooking steps"))
        }

        // 영상 — 라벨은 짧게(41차 owner), 전체 뜻은 accessibilityLabel이 맡는다.
        PaperButton(title: "Videos", kind: .secondary, fullWidth: !compact, seed: 3,
                    icon: ReffiIcon.youtube, iconWeight: .fill, onCard: true, compact: compact) {
            openURL(youtubeSearchURL(for: cook.recipeName))
        }
        .accessibilityLabel(Text("Open recipe videos"))
        .accessibilityHint(Text("Opens YouTube in your browser"))

        shareButton(for: cook, compact: compact)
    }

    /// 공유 — `ShareLink`는 `Button`이 아니라서 같은 표면을 `PaperButtonLabel`로 직접 씌운다
    /// (그 프리미티브가 존재하는 이유가 이것이다). 폭은 내용에 맞춰 줄여 옆 영상 버튼이 넓게 서고,
    /// 라벨은 면 **안**에 있다 — 블롭 아래 라벨은 이 행에서 혼자 두 줄 높이를 만들던 옛 형태다.
    @ViewBuilder
    private func shareButton(for cook: FridgeStore.CookSession, compact: Bool) -> some View {
        if let shareImage {
            ShareLink(item: shareImage,
                      preview: SharePreview(Text(verbatim: cook.recipeName), image: shareImage)) {
                shareLabel(compact: compact)
            }
            .buttonStyle(.paperPress)
            .accessibilityLabel(Text("Share"))
            .accessibilityHint(Text("Opens the share sheet"))
        } else {
            // 렌더 완료 전 짧은 순간의 비활성 플레이스홀더(크래시·빈 공유 방지) — 렌더는 즉시 끝나 실사용엔 티 안 남.
            shareLabel(compact: compact)
                .opacity(ReffiOpacity.disabled)
                .accessibilityHidden(true)
        }
    }

    /// `ShareLink`는 `Button`이 아니라서 같은 표면을 `PaperButtonLabel`로 직접 씌운다
    /// (그 프리미티브가 존재하는 이유가 이것이다). 히트 하한도 여기서 함께 건다 — `PaperButton`이
    /// 자기 안에서 하는 일을 이 경로에서는 호출부가 대신해야 두 폼의 타깃이 같아진다.
    private func shareLabel(compact: Bool) -> some View {
        PaperButtonLabel(title: "Share", kind: .secondary, fullWidth: !compact, seed: 4,
                         icon: ReffiIcon.share, onCard: true, compact: compact)
            .frame(minHeight: compact ? ReffiChrome.tapMin : nil)
            .contentShape(Rectangle())
    }

    /// 유튜브 검색 URL — 조립은 `RecipeVideoSearch`(단일 공급원)가 한다. 티켓 덱의 영상 브리지와
    /// 같은 규칙을 쓰려고 여기서 다시 만들지 않는다.
    private func youtubeSearchURL(for recipeName: String) -> URL {
        RecipeVideoSearch.urlForRecipe(recipeName)
    }

    /// 공유 카드 이미지 렌더 — `RecipeShareCard`를 레티나 스케일로 오프스크린 래스터라이즈한다. 실패하면 nil.
    /// 재료 이름은 예약 재료(=지금 냉장고에 있는 그 재료)에서 읽는다 — 세션 스냅샷에 이름을 또 박지 않는다.
    @MainActor
    private func renderShareImage(for cook: FridgeStore.CookSession, icon: RecipeHeroIcon) -> Image? {
        // 공유 이미지는 물리 산출물(인쇄된 영수증)이라 기기 다크모드와 무관하게 항상 라이트 종이로 렌더한다.
        // ImageRenderer는 환경을 명시하지 않으면 항상 라이트로 해석하지만, 명시적으로 고정해 의도를 문서화한다.
        let card = RecipeShareCard(recipeName: cook.recipeName,
                                   ingredientNames: reservedIngredients.map(reservedName),
                                   minutes: cook.minutes,
                                   count: cook.count,
                                   icon: icon)
            .environment(\.colorScheme, .light)
            // 언어도 색처럼 명시 고정(42차) — 렌더 계층은 루트의 `.environment(\.locale)`을 물려받지
            // 못해, 앱 언어를 바꾼 사용자의 공유 이미지 라벨만 기기 언어로 나갔다.
            .environment(\.locale, AppLanguage.current.resolvedLocale)
        let renderer = ImageRenderer(content: card)
        // 레티나 3x. **2로 내리지 않는다**(2026-08 재검토): 카드 폭이 340pt라 3x는 1020px인데,
        // 받는 쪽은 메시지 앱에서 이 이미지를 화면 폭으로 연다 — 3x 아이폰의 세로 폭이 1170~1290px라
        // 2x(680px)면 그 자리에서 곧장 확대돼 톱니와 모노 라벨이 뭉갠다. 비용 쪽 걱정은 스케일이
        // 아니라 **타이밍**이었고, 그건 위 `.task`의 유예가 가져갔다.
        renderer.scale = 3
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
}
