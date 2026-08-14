import SwiftUI
import PhosphorSwift
import UIKit

/// 조리 세션 티켓(§13.6) — 발주 직후, 그리고 메인의 Cooking now 카드에서 열리는 조리 화면.
/// 발주된 티켓 한 장이 그대로 조리 중 상태판이 된다: 무엇을 몇 개로 굽고 있는지, 언제 시작했는지,
/// 그리고 **어떻게 만드는지는 영상**이 맡는다(앱은 단서까지, 디테일은 유튜브).
/// 세션(시작 시각·예약 재료)은 store에 영속화되어 앱을 껐다 켜도 이어진다.
///
/// 단계 체크리스트는 없앴다 — 텍스트 단계를 따라가는 건 실제 조리 중에 아무도 하지 않고,
/// 영상 한 번이 단계 열 줄보다 정확하다. 파일명은 진입점 참조가 흩어져 있어 그대로 둔다.
struct CookingStepsView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    var onClose: () -> Void

    @State private var finishHaptic = 0
    @State private var showFinishSheet = false
    @State private var showCancelConfirm = false
    @State private var leftovers: Set<UUID> = []   // '조금 남았어요'로 표시한 재료
    @State private var shareImage: Image?   // 공유 카드 오프스크린 렌더 결과 — 아래 ShareCardKey가 바뀔 때만 갱신

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
                     ingredientNames: reservedIngredients.map(\.name),
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

    var body: some View {
        ZStack(alignment: .top) {
            ReffiColor.paperPass.ignoresSafeArea()
            if let cook = store.activeCook {
                ScrollView {
                    ticket(cook)
                        .padding(.horizontal, ReffiGrid.margin + 8)
                        .padding(.top, 104)
                        .padding(.bottom, ReffiSpace.s6)
                }
                // 공유 카드에 인쇄되는 값(메뉴명·예약 재료 이름·시간·개수)이 바뀔 때만 다시 렌더한다.
                // 새 세션은 물론, 조리 중 예약 재료가 사라지는 경우까지 이 키가 덮는다.
                .task(id: shareCardKey(for: cook)) {
                    shareImage = renderShareImage(for: cook, icon: heroIcon(for: cook))
                }
            }
            topBar
        }
        .sensoryFeedback(.success, trigger: finishHaptic)
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
        .confirmationDialog(Text("Put ingredients back?"), isPresented: $showCancelConfirm,
                            titleVisibility: .visible) {
            Button("Cancel cooking", role: .destructive) {
                withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) {
                    store.cancelCooking()
                }
            }
            Button("Keep cooking", role: .cancel) {}
        } message: {
            Text("Nothing is logged. Reserved ingredients return to the fridge.")
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
                    .frame(width: 32, height: 32)
                Text(verbatim: ing.name)
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
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.reffiPress)
        .accessibilityLabel(Text("\(ing.name)"))
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
                HStack(spacing: 4) {
                    Text("Started")
                        .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                    Text(cook.startedAt, style: .relative)
                        .reffiType(.metaText)
                        .foregroundStyle(ReffiColor.ink2)
                }
            }
        }
    }

    // MARK: - 조리 티켓

    private func ticket(_ cook: FridgeStore.CookSession) -> some View {
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

            // 메뉴명 + 요리 아이콘 — 오더 티켓(`OrderMemoCard`)과 **같은 자리·같은 크기**로 둔다.
            // 발주 전후로 아이콘이 움직이면 같은 티켓이 조리 티켓이 됐다는 연결이 끊긴다.
            HStack(alignment: .top, spacing: ReffiSpace.s3) {
                Text(verbatim: cook.recipeName)
                    .reffiType(.menuName).foregroundStyle(ReffiColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: ReffiSpace.s2)
                RecipeHeroIconView(icon: heroIcon(for: cook))
                    .frame(width: ReffiDishIcon.ticket, height: ReffiDishIcon.ticket)
            }

            DashedRule()

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

            // 기대치 정렬 — 앱은 단서까지, 디테일은 영상. 단계가 사라진 자리를 설명하는 한 줄.
            Text("Cook it your way. The video has the details.")
                .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                .fixedSize(horizontal: false, vertical: true)

            DashedRule()
                .padding(.top, ReffiSpace.s2)

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
            .padding(.top, ReffiSpace.s2)

            // 조리 포기 — 예약을 해제하고 재료를 되돌린다(기록 없음). fire의 안전한 반대 방향.
            Button { showCancelConfirm = true } label: {
                Text("Cancel cooking, put ingredients back")
                    .reffiType(.caption)
                    .foregroundStyle(ReffiColor.ink2)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.reffiPress)
        }
        .padding(.horizontal, ReffiSpace.s5)
        .padding(.vertical, ReffiSpace.s5 + 2)
        .background(ReceiptShape(tooth: 9).fill(ReffiColor.paper))
        .overlay(ReceiptShape(tooth: 9).stroke(ReffiColor.ink.opacity(0.07), lineWidth: 1))
        .reffiShadow1()
    }

    /// 조리법 1차 CTA — 레시피명으로 유튜브 검색을 연다. `PaperButton`은 텍스트 전용이라
    /// 같은 종이컷 표면(§13.5)에 아이콘+라벨을 직접 얹는다. 면은 blush 틴트(urgentLight) —
    /// 하단 파랑 Finish CTA와 색으로 역할이 갈리고, 예전 YouTube 아이콘 버튼(intent .soft)의 결을 잇는다.
    private func videoButton(for recipeName: String) -> some View {
        Button { openURL(youtubeSearchURL(for: recipeName)) } label: {
            HStack(spacing: ReffiSpace.s2) {
                ReffiIcon.youtube.reffi(20, .fill).foregroundStyle(ReffiColor.urgentDark)
                Text("Open recipe videos")
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
                    .paperEdge(shape, tint: ReffiColor.urgentDark.opacity(0.18))
                    .compositingGroup()
                    .reffiShadow1()
            }
        }
        .buttonStyle(.paperPress)
        .accessibilityHint(Text("Opens YouTube in your browser"))
    }

    /// 유튜브 검색 URL — 레시피명 + "recipe"를 퍼센트 인코딩. 인코딩·URL 생성 실패 시 유튜브 홈으로 폴백.
    private func youtubeSearchURL(for recipeName: String) -> URL {
        let fallback = URL(string: "https://www.youtube.com")!
        guard let encoded = "\(recipeName) recipe"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return fallback }
        return URL(string: "https://www.youtube.com/results?search_query=\(encoded)") ?? fallback
    }

    /// 공유 카드 이미지 렌더 — `RecipeShareCard`를 레티나 스케일로 오프스크린 래스터라이즈한다. 실패하면 nil.
    /// 재료 이름은 예약 재료(=지금 냉장고에 있는 그 재료)에서 읽는다 — 세션 스냅샷에 이름을 또 박지 않는다.
    @MainActor
    private func renderShareImage(for cook: FridgeStore.CookSession, icon: RecipeHeroIcon) -> Image? {
        // 공유 이미지는 물리 산출물(인쇄된 영수증)이라 기기 다크모드와 무관하게 항상 라이트 종이로 렌더한다.
        // ImageRenderer는 환경을 명시하지 않으면 항상 라이트로 해석하지만, 명시적으로 고정해 의도를 문서화한다.
        let card = RecipeShareCard(recipeName: cook.recipeName,
                                   ingredientNames: reservedIngredients.map(\.name),
                                   minutes: cook.minutes,
                                   count: cook.count,
                                   icon: icon)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3   // 레티나
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
}
