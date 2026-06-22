import SwiftUI

/// 음식 카테고리. 추천을 이 기준으로 거른다.
enum FoodCategory: String, CaseIterable, Identifiable, Hashable {
    case all = "All"
    case korean = "Korean"
    case western = "Western"
    case asian = "Asian"
    case vegan = "Vegan"

    var id: String { rawValue }
}

/// 가로 스크롤 카테고리 필터 칩. 선택 = Blue/흰 글자, 비선택 = neutral-200/ink (§2.6).
struct CategorySelector: View {
    @Binding var selected: FoodCategory
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s2) {
                ForEach(FoodCategory.allCases) { category in
                    chip(category)
                }
            }
        }
        .scrollClipDisabled()
    }

    private func chip(_ category: FoodCategory) -> some View {
        let isOn = category == selected
        return Button {
            withAnimation(reduceMotion ? nil : ReffiMotion.easeStd) { selected = category }
        } label: {
            Text(category.rawValue)
                .reffiText(ReffiType.caption)
                .foregroundStyle(isOn ? .white : ReffiColor.ink)
                .padding(.horizontal, Space.s3)
                .padding(.vertical, Space.s2)
                .background(isOn ? ReffiColor.blue : ReffiColor.neutral200)
                .clipShape(RoundedRectangle(cornerRadius: Radius.xs, style: .continuous))
        }
        .buttonStyle(ReffiPressStyle())
        .frame(minHeight: 44)            // §7.3 최소 터치 타깃(시각 칩은 작아도 히트영역 44)
        .contentShape(Rectangle())
    }
}
