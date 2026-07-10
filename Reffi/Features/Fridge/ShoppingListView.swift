import SwiftUI

/// 사야 할 식재료 — 자주 쓰는데(이력) 지금 냉장고에 없는 항목이 자동으로 채워진다.
/// Add를 누르면 이름이 채워진 입력 폼이 열려 냉장고에 재입고(restock)된다.
struct ShoppingListView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private struct Restock: Identifiable { let name: String; var id: String { name } }
    @State private var restocking: Restock?

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
        .sheet(item: $restocking) {
            AddIngredientSheet(prefillName: $0.name)   // presentationDetents는 시트 내부에서 적용
        }
    }

    private var header: some View {
        CoverHeader(title: "To buy",
                    subtitle: "Restock what you use often",
                    onClose: { dismiss() })
    }

    private var listCard: some View {
        let shape = ReceiptShape(tooth: 7)
        return VStack(alignment: .leading, spacing: ReffiSpace.s3) {
            Text("Ran out — based on what you use often")
                .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
            ForEach(items, id: \.name) { item in
                HStack(spacing: ReffiSpace.s3) {
                    PaperSilhouette(glyph: item.glyph, fresh: .fresh).frame(width: 36, height: 36)
                    Text(verbatim: item.name).reffiType(.body).foregroundStyle(ReffiColor.ink)
                    Spacer()
                    Button {
                        restocking = Restock(name: item.name)
                    } label: {
                        Text("Add")
                            .font(.custom("Pretendard-SemiBold", size: 14, relativeTo: .subheadline))
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
                            .font(.custom("Pretendard-SemiBold", size: 14, relativeTo: .subheadline))
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
