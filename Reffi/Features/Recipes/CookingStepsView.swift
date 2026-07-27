import SwiftUI
import PhosphorSwift
import UIKit

/// 단계별 레시피(§13.6) — 발주 직후, 그리고 메인의 Cooking now 카드에서 열리는 조리 화면.
/// 발주된 티켓 한 장이 그대로 조리 체크리스트가 된다: 단계를 탭해 체크, 완료로 세션을 닫는다.
/// 진행 상태(체크·시작 시각)는 store에 영속화되어 앱을 껐다 켜도 이어진다.
struct CookingStepsView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    var onClose: () -> Void

    @State private var finishHaptic = 0
    @State private var showFinishSheet = false
    @State private var showCancelConfirm = false
    @State private var leftovers: Set<UUID> = []   // '조금 남았어요'로 표시한 재료
    @State private var shareImage: Image?   // 공유 카드 오프스크린 렌더 결과 — 세션당 1회(체크 상태와 무관)

    /// 예약된 재료(아직 냉장고에 있는 것) — 완료 확인 시트의 목록.
    private var reservedIngredients: [Ingredient] {
        guard let ids = store.activeCook?.usedIDs else { return [] }
        let byID = Dictionary(store.ingredients.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return ids.compactMap { byID[$0] }
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
                // 공유 카드는 레시피+스텝 스냅샷이라 체크 상태와 무관 — recipeName이 바뀔 때(새 세션)만 다시 렌더.
                .task(id: cook.recipeName) {
                    shareImage = renderShareImage(for: cook)
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
                    .background((left ? ReffiColor.soonLight : ReffiColor.freshLight), in: Capsule())
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
        let steps = cook.steps ?? []
        let done = Set(cook.completedSteps ?? [])
        return VStack(alignment: .leading, spacing: ReffiSpace.s3) {
            // 헤더 — 오더 티켓과 같은 모노 크롬.
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: "ORDER · FIRED")
                    .reffiType(.monoTicketLabel).foregroundStyle(ReffiColor.urgentDark)
                Spacer()
                Text("\(cook.count) used")
                    .reffiType(.metaText)
                    .foregroundStyle(ReffiColor.ink2)
            }

            Text(verbatim: cook.recipeName)
                .reffiType(.menuName).foregroundStyle(ReffiColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            DashedRule()

            Text(verbatim: "STEPS")
                .reffiType(.sectionLabel).foregroundStyle(ReffiColor.ink2)

            if steps.isEmpty {
                Text("No steps on this ticket. Cook it your way.")
                    .reffiType(.body).foregroundStyle(ReffiColor.ink2)
                    .padding(.vertical, ReffiSpace.s3)
            } else {
                VStack(alignment: .leading, spacing: ReffiSpace.s1) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                        stepRow(index: i, text: step, done: done.contains(i))
                    }
                }
            }

            DashedRule()
                .padding(.top, ReffiSpace.s2)

            // 요리 예시 참고 — 레시피명으로 유튜브 검색을 열거나 레시피를 영수증 카드 이미지로 공유한다. 종이컷 아이콘 버튼 쌍(§13.5).
            HStack(spacing: ReffiSpace.s5) {
                PaperIconButton(icon: ReffiIcon.youtube, label: "YouTube", intent: .soft, size: 64, seed: 3) {
                    openURL(youtubeSearchURL(for: cook.recipeName))
                }
                .accessibilityLabel(Text("Watch examples on YouTube"))
                .accessibilityHint(Text("Opens YouTube in your browser"))

                if let shareImage {
                    ShareLink(
                        item: shareImage,
                        preview: SharePreview(Text(verbatim: cook.recipeName), image: shareImage)
                    ) {
                        PaperIconLabel(icon: ReffiIcon.share, label: "Share", intent: .neutral, size: 64, seed: 4)
                    }
                    .buttonStyle(.paperPress)
                    .accessibilityLabel(Text("Share"))
                    .accessibilityHint(Text("Opens the share sheet"))
                } else {
                    // 렌더 완료 전 짧은 순간의 비활성 플레이스홀더(크래시·빈 공유 방지) — 렌더는 즉시 끝나 실사용엔 티 안 남.
                    PaperIconLabel(icon: ReffiIcon.share, label: "Share", intent: .neutral, size: 64, seed: 4)
                        .opacity(0.4)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity)

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

    /// 단계 한 줄 — 탭 = 체크 토글(진행 저장). 체크되면 줄이 그어진다.
    private func stepRow(index: Int, text: String, done: Bool) -> some View {
        Button {
            withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) {
                store.toggleCookStep(index)
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: ReffiSpace.s3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(done ? ReffiColor.freshDark : ReffiColor.muted, lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    if done {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(ReffiColor.freshDark).frame(width: 20, height: 20)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
                    }
                }
                Text(verbatim: "\(index + 1).")
                    .font(.reffiNum(14, relativeTo: .body)).foregroundStyle(ReffiColor.ink2)
                Text(verbatim: text)
                    .reffiType(.checklistItem)
                    .foregroundStyle(done ? ReffiColor.muted : ReffiColor.ink)
                    .strikethrough(done, color: ReffiColor.muted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.vertical, ReffiSpace.s2)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.reffiPress)
        .accessibilityLabel(Text(verbatim: text))
        .accessibilityValue(done ? Text("Done") : Text(verbatim: ""))
    }

    /// 유튜브 검색 URL — 레시피명 + "recipe"를 퍼센트 인코딩. 인코딩·URL 생성 실패 시 유튜브 홈으로 폴백.
    private func youtubeSearchURL(for recipeName: String) -> URL {
        let fallback = URL(string: "https://www.youtube.com")!
        guard let encoded = "\(recipeName) recipe"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return fallback }
        return URL(string: "https://www.youtube.com/results?search_query=\(encoded)") ?? fallback
    }

    /// 공유 카드 이미지 렌더 — `RecipeShareCard`를 레티나 스케일로 오프스크린 래스터라이즈한다. 실패하면 nil.
    @MainActor
    private func renderShareImage(for cook: FridgeStore.CookSession) -> Image? {
        let card = RecipeShareCard(recipeName: cook.recipeName, steps: cook.steps ?? [], count: cook.count)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3   // 레티나
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
}
