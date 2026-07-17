import SwiftUI

/// 사야 할 식재료 — 자주 쓰는데(이력) 지금 냉장고에 없는 항목이 자동으로 채워진다.
/// Add = 시트 없이 **즉시 재입고** — 직전 이력 스냅샷(보관·구매처·수량, 냉동이었다면 냉장으로)과
/// 사전 기본 기한으로 바로 store에 채워 넣는다(§13.6 재입고 경로 — AddIngredientSheet 의존 없음).
struct ShoppingListView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(ProfileStore.self) private var profile
    @Environment(\.dismiss) private var dismiss

    @State private var restockHaptic = 0

    private var items: [(name: String, glyph: FoodGlyph)] { store.toBuy }

    var body: some View {
        ZStack {
            LiquidGlassBackground(accent: ReffiColor.blue.opacity(0.5))
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: ReffiSpace.s4) {
                        if items.isEmpty {
                            emptyCard
                        } else {
                            listCard
                        }
                    }
                    .padding(.horizontal, ReffiGrid.margin)
                    .padding(.bottom, ReffiSpace.s6)
                }
            }
        }
        .sensoryFeedback(.success, trigger: restockHaptic)
    }

    /// 직전 이력 스냅샷이 있으면 보관·구매처·수량을 복원(냉동이었다면 냉장으로 — 재구매는 냉동 상태가
    /// 아니다), 없으면 사전 기본값으로 새로 채운다. 소비기한은 항상 그 보관의 사전 기본값으로 재계산.
    /// 가구 인원 배율은 **스냅샷이 없는 폴백 경로에만** 적용한다 — 스냅샷이 있으면 사용자가 이미 그
    /// 수량을 한 번 결정한 값이라 존중하고 그대로 복원한다(재입고 때마다 배율이 누적되지 않게).
    private func restock(name: String, glyph: FoodGlyph) {
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
        restockHaptic += 1
    }

    private var header: some View {
        CoverHeader(title: "To buy",
                    subtitle: "Restock what you use often",
                    onClose: { dismiss() })
    }

    private var listCard: some View {
        let shape = ReceiptShape(tooth: 7)
        return VStack(alignment: .leading, spacing: ReffiSpace.s3) {
            Text("Ran out, based on what you use often")
                .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
            ForEach(items, id: \.name) { item in
                HStack(spacing: ReffiSpace.s3) {
                    PaperSilhouette(glyph: item.glyph, fresh: .fresh).frame(width: 36, height: 36)
                    Text(verbatim: item.name).reffiType(.body).foregroundStyle(ReffiColor.ink)
                    Spacer()
                    Button {
                        withAnimation(ReffiMotion.settle) { restock(name: item.name, glyph: item.glyph) }
                    } label: {
                        Text("Add")
                            .reffiType(.pillLabel)
                            .foregroundStyle(ReffiColor.blueDark)
                            .padding(.horizontal, ReffiSpace.s3 + 2)
                            .padding(.vertical, ReffiSpace.s1 + 1)
                            .background {
                                let s = PaperRect(cornerRadius: ReffiRadius.pill, seed: 1)
                                s.fill(ReffiColor.blueLight).paperEdge(s, tint: ReffiColor.ink.opacity(0.06))
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.paperPress)
                    .accessibilityLabel(Text("Restock \(item.name)"))
                    Button {
                        withAnimation(ReffiMotion.settle) { store.skipBuy(item.name) }
                    } label: {
                        Text("Skip")
                            .reffiType(.pillLabel)
                            .foregroundStyle(ReffiColor.ink2)
                            .padding(.horizontal, ReffiSpace.s3 + 2)
                            .padding(.vertical, ReffiSpace.s1 + 1)
                            .background {
                                let s = PaperRect(cornerRadius: ReffiRadius.pill, seed: 2)
                                s.fill(ReffiColor.sub).paperEdge(s, tint: ReffiColor.ink.opacity(0.06))
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.paperPress)
                    .accessibilityLabel(Text("Skip \(item.name) this time"))
                }
            }
        }
        .padding(.horizontal, ReffiSpace.s5)
        .padding(.vertical, ReffiSpace.s5 + 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReffiColor.oklch(0.985, 0.004, 90), in: shape)
        .paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
        .shadow(color: ReffiColor.ink.opacity(0.06), radius: 5, x: 0, y: 2)
    }

    private var emptyCard: some View {
        let shape = ReceiptShape(tooth: 7)
        return VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            Text("All stocked up").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
            Text("Nothing you regularly use has run out.")
                .reffiType(.body).foregroundStyle(ReffiColor.ink2)
        }
        .padding(.horizontal, ReffiSpace.s5)
        .padding(.vertical, ReffiSpace.s5 + 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReffiColor.oklch(0.985, 0.004, 90), in: shape)
        .paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
    }
}
