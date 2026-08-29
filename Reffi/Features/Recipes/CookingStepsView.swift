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
/// 조용한 톤(`kind: .secondary`)의 종이 버튼("See the cooking details?", 41차 — 39차의 밑줄 링크를
/// 대체)이 서고, 탭하면 `KitchenCopySheet`가 하단에서 올라온다. 영상 CTA는 이 버튼의 유무와 무관하게
/// 항상 조리법의 1차 경로를 맡는다(§videoButton) — 톤만 낮췄을 뿐 자리가 없어지는 게 아니다.
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
    /// 커버 헤더의 실측 높이 — 티켓 상단 여백이 여기서 파생된다(형제 `RecipeMemoCarousel`과 같은 규칙).
    /// 기본 글자 크기의 `CoverHeader`는 s4(16) + 44 + s1(6) + 경과 시간 한 줄(≈16) + s3(12) ≈ 94이라
    /// 초기값도 94지만, 큰 글씨에서 타이틀이 두 줄로 접히면 그만큼 자란다 — 고정값으로 두면 헤더가
    /// 티켓의 크라운·메뉴명을 덮고, 그 둘은 티켓 최상단이라 스크롤로도 되돌릴 수 없다.
    @State private var headerHeight: CGFloat = 94

    /// 예약된 재료(아직 냉장고에 있는 것) — 완료 확인 시트의 목록.
    private var reservedIngredients: [Ingredient] {
        guard let ids = store.activeCook?.usedIDs else { return [] }
        let byID = Dictionary(store.ingredients.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return ids.compactMap { byID[$0] }
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
                     ingredientNames: reservedIngredients.map(\.displayName),
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
    private let ticketInset = ReffiGrid.margin + 8

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
                            // 헤더 아래 s5 — 냉장고 화면의 "헤더 ↔ 콘텐츠" 경계와 같은 값(고정값 금지).
                            .padding(.top, headerHeight + ReffiSpace.s5)
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
                topBar
            }
        }
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
        // 주방 전표(39차) — 티켓 안 "See the cooking details?" 링크가 연다. 체크는 store에 바로
        // 반영되므로(`toggleCookStep`) 시트를 닫았다 열어도, 앱을 껐다 켜도 유지된다.
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
        // 뒷배경 탭 = Keep cooking(질문형 안전 기본값, §14.7).
        .paperDialog(isPresented: $showCancelConfirm,
                     title: "Put ingredients back?",
                     message: "Nothing is logged. Reserved ingredients return to the fridge.",
                     backdropDismisses: true,
                     primary: PaperDialogAction("Cancel cooking", role: .destructive) {
                         withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) {
                             store.cancelCooking()
                         }
                     },
                     secondary: PaperDialogAction("Keep cooking") {})
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
                // 종이 버튼화(2026-08, 35차) — 예전엔 캡션 텍스트 한 줄이라 버튼으로 읽히지 않았고
                // 라벨도 길었다. `QuietButton`(면 없는 텍스트 버튼 — ProfileView의 "Reset all data"·
                // "Delete account"와 같은 문법, `tint: urgentDark`로 파괴 성향의 잉크색만 준다)으로
                // 바꾸고 라벨은 "Cancel cooking"(다이얼로그 실행 버튼과 같은 키)으로 줄인다 — "재료를
                // 되돌린다"는 세부는 화면에서 지워지지 않고 다이얼로그 메시지 + 아래 접근성 힌트에
                // 그대로 남는다. 파랑 "Finish cooking"과 경쟁하지 않도록 면 없는 조용한 등급을 유지한다.
                QuietButton(title: "Cancel cooking", tint: ReffiColor.urgentDark) {
                    showCancelConfirm = true
                }
                .accessibilityHint(Text("Nothing is logged. Reserved ingredients return to the fridge."))
            }
        }
    }

    // MARK: - 완료 확인 시트 (소비 확정 지점)

    private var finishSheet: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s4) {
            VStack(alignment: .leading, spacing: 2) {
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
                Text(verbatim: ing.displayName)
                    .reffiType(.body).foregroundStyle(ReffiColor.ink).lineLimit(1)
                Spacer(minLength: ReffiSpace.s2)
                Text(left ? "Some left" : "Used it all")
                    .reffiType(.pillLabel)
                    .foregroundStyle(left ? ReffiColor.soonDark : ReffiColor.freshDark)
                    .padding(.horizontal, ReffiSpace.s3)
                    .padding(.vertical, ReffiSpace.s1 + 1)
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

    /// 커버 헤더 — 단일 공급원 `CoverHeader`(§14.2: 풀스크린 커버 = 중앙 타이틀 + 종이 X).
    /// 경과 시간은 accessory 슬롯에 둔다 — `style: .relative`라 시스템이 알아서 라이브 갱신한다.
    private var topBar: some View {
        CoverHeader(title: "Cooking now",
                    closeHint: "Keeps cooking in progress",   // 닫아도 세션은 남는다는 결과 예고
                    onClose: onClose) {
            if let cook = store.activeCook {
                // 한 구(句)를 두 role로 쪼개지 않는다 — "Started"가 caption(14/자간 +0.14),
                // 바로 옆 경과 시간이 metaText(13/자간 0)라 같은 문장 안에서 1pt·자간만 어긋나
                // 위계가 아니라 어색한 이격으로만 보였다. 데이터형 메타 하나로 묶는다(§3.5).
                HStack(spacing: 4) {
                    Text("Started")
                    // 상대 시간 표기는 기기 로케일을 따른다(38차 결정 — 앱 언어와 분리, 아래 근거).
                    Text(cook.startedAt, style: .relative)
                        .environment(\.locale, .autoupdatingCurrent)
                }
                .reffiType(.metaText).foregroundStyle(ReffiColor.ink2)
            }
        }
        // 헤더가 실제로 차지한 높이를 티켓 상단 여백으로 되돌린다(`headerHeight` 주석 참고).
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
    }

    // MARK: - 조리 티켓

    /// - Parameter ticketWidth: 영수증 종이의 실측 폭 — 히어로 아이콘이 그 절반으로 선다.
    private func ticket(_ cook: FridgeStore.CookSession, ticketWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s3) {
            // 헤더 — 오더 티켓과 같은 모노 크롬. 공유 카드(RecipeShareCard)와 같은 규칙으로
            // 셀 게 없으면(count 0) 수치를 아예 빼, 두 종이가 서로 다른 말을 하지 않게 한다.
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: "ORDER · FIRED")
                    .reffiType(.monoTicketLabel).foregroundStyle(ReffiColor.urgentDark)
                Spacer()
                if cook.count > 0 {
                    Text("\(cook.count) used")
                        .reffiType(.metaText)
                        .foregroundStyle(ReffiColor.ink2)
                }
            }

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
            VStack(spacing: ReffiSpace.s2) {
                RecipeHeroIconView(icon: heroIcon(for: cook))
                    .frame(width: ticketWidth * 0.5, height: ticketWidth * 0.5)

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
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                        // UI 테스트 훅 — 소개 문구를 테스트에 하드코딩하지 않고 집는다
                        // (`ticket.menuName` 선례). 라벨은 그대로라 VoiceOver는 문장을 읽는다.
                        .accessibilityIdentifier("cook.intro")
                }
            }
            .frame(maxWidth: .infinity)   // leading VStack 안에서 가운데로
            .padding(.vertical, ReffiSpace.s2)

            // 상세 링크 → 종이컷 버튼(2026-08, 41차 owner decision) — 옛 밑줄 텍스트 링크를 걷어내고
            // 요리 아이콘 바로 아래, 영상·공유 행보다 먼저 서는 `PaperButton`(§13.5 변형)으로 올린다.
            // **단계가 있을 때만** 선다(대부분의 커스텀 레시피는 없다 — §KitchenCopySheet). 화면엔
            // 이제 종이 버튼이 셋(디테일·영상·Finish cooking)이라 위계는 톤으로 가른다 — 영상 CTA는
            // 강조 톤(urgentLight/urgentDark 커스텀 면)을 그대로 유지하고, 이 버튼은 `kind: .secondary`
            // (sub 면 + ink 잉크, "Maybe later"·`PaperDialog` 보조 버튼과 같은 등급)로 눌러 셋 중
            // 가장 조용하게 읽히게 한다 — 자리는 먼저 만나지만 톤은 낮다.
            // **39차-b**: 스냅샷만 보면 39차 이전에 발주된 구세션은 `cook.steps`가 nil이라 이 링크가
            // 실제 단계 있는 레시피에서도 안 섰다(실기기 리포트) — `resolvedSteps(for:)`가 스냅샷 →
            // 원본 레시피 순으로 폴백해 게이트와 시트 콘텐츠가 항상 같은 답을 보게 한다.
            if let steps = resolvedSteps(for: cook) {
                PaperButton(title: "See the cooking details?", kind: .secondary, seed: 6) {
                    showKitchenCopy = true
                }
                .accessibilityHint(Text("Opens the full list of cooking steps"))
            }

            // 조리법의 1차 경로 — 레시피명으로 유튜브 검색을 연다. 아이콘+라벨 와이드 CTA(아이콘 단독 아님).
            // 공유는 그 옆의 보조 행동이라 조용한 종이컷 아이콘(§13.5)으로 남긴다.
            HStack(spacing: ReffiSpace.s4) {
                videoButton(for: cook.recipeName)
                if let shareImage {
                    ShareLink(
                        item: shareImage,
                        preview: SharePreview(Text(verbatim: cook.recipeName), image: shareImage)
                    ) {
                        PaperIconLabel(icon: ReffiIcon.share, label: "Share", intent: .neutral, size: 52, seed: 4)
                    }
                    .buttonStyle(.paperPress)
                    .accessibilityLabel(Text("Share"))
                    .accessibilityHint(Text("Opens the share sheet"))
                } else {
                    // 렌더 완료 전 짧은 순간의 비활성 플레이스홀더(크래시·빈 공유 방지) — 렌더는 즉시 끝나 실사용엔 티 안 남.
                    PaperIconLabel(icon: ReffiIcon.share, label: "Share", intent: .neutral, size: 52, seed: 4)
                        .opacity(ReffiOpacity.disabled)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.horizontal, ReffiSpace.s5)
        .padding(.vertical, ReffiSpace.s5 + 2)
        .background(ReceiptShape(tooth: ReffiTooth.ticket).fill(ReffiColor.paper))
        .overlay(ReceiptShape(tooth: ReffiTooth.ticket).stroke(ReffiColor.paperEdge, lineWidth: 1))
        .reffiShadow1()
    }

    /// 조리법 1차 CTA — 레시피명으로 유튜브 검색을 연다. `PaperButton`은 텍스트 전용이라
    /// 같은 종이컷 표면(§13.5)에 아이콘+라벨을 직접 얹는다. 면은 blush 틴트(urgentLight) —
    /// 하단 파랑 Finish CTA와 색으로 역할이 갈리고, 예전 YouTube 아이콘 버튼(intent .soft)의 결을 잇는다.
    private func videoButton(for recipeName: String) -> some View {
        Button { openURL(youtubeSearchURL(for: recipeName)) } label: {
            HStack(spacing: ReffiSpace.s2) {
                ReffiIcon.youtube.reffi(20, .fill).foregroundStyle(ReffiColor.urgentDark)
                // 라벨은 짧게(2026-08, 41차 owner 요청) — 화면 라벨은 "Videos"로 줄이고,
                // 전체 뜻("Open recipe videos")은 accessibilityLabel(아래)이 그대로 맡는다.
                Text("Videos")
                    .font(ReffiTextRole.subhead.font)
                    .tracking(ReffiTextRole.subhead.tracking)
                    .foregroundStyle(ReffiColor.urgentDark)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s4)
            .background {
                let shape = PaperCutRect(seed: 3)
                shape.fill(ReffiColor.urgentLight)
                    .overlay(PaperGrain(seed: 14).clipShape(shape))
                    .paperEdge(shape, tint: ReffiColor.paperEdgeAccent(ReffiColor.urgentDark))
                    .compositingGroup()
                    .reffiShadow1()
            }
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel(Text("Open recipe videos"))
        .accessibilityHint(Text("Opens YouTube in your browser"))
    }

    /// 유튜브 검색 URL — 조립은 `RecipeVideoSearch`(단일 공급원)가 한다. 티켓 덱의 영상 브리지와
    /// 같은 규칙을 쓰려고 여기서 다시 만들지 않는다(동작은 이전과 동일: 레시피명 + " recipe").
    private func youtubeSearchURL(for recipeName: String) -> URL {
        RecipeVideoSearch.url(query: "\(recipeName) recipe")
    }

    /// 공유 카드 이미지 렌더 — `RecipeShareCard`를 레티나 스케일로 오프스크린 래스터라이즈한다. 실패하면 nil.
    /// 재료 이름은 예약 재료(=지금 냉장고에 있는 그 재료)에서 읽는다 — 세션 스냅샷에 이름을 또 박지 않는다.
    @MainActor
    private func renderShareImage(for cook: FridgeStore.CookSession, icon: RecipeHeroIcon) -> Image? {
        // 공유 이미지는 물리 산출물(인쇄된 영수증)이라 기기 다크모드와 무관하게 항상 라이트 종이로 렌더한다.
        // ImageRenderer는 환경을 명시하지 않으면 항상 라이트로 해석하지만, 명시적으로 고정해 의도를 문서화한다.
        let card = RecipeShareCard(recipeName: cook.recipeName,
                                   ingredientNames: reservedIngredients.map(\.displayName),
                                   minutes: cook.minutes,
                                   count: cook.count,
                                   icon: icon)
            .environment(\.colorScheme, .light)
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
