import SwiftUI
import UIKit
import PhosphorSwift

/// 식재료 대분류(장바구니 표준). 카드·필터의 카테고리 단위.
/// 아이콘은 디자이너 제공 에셋(`cat-<raw>`)을 우선 쓰고, 없으면 Phosphor 폴백.
enum IngredientCategory: String, CaseIterable {
    case vegetables, fruit, meat, seafood, dairy, grains, other

    /// 자유 입력·구버전 문자열을 표준 분류로 흡수. 미상은 .other.
    init(raw: String) {
        switch raw.lowercased() {
        case "veg", "vegetable", "vegetables", "veggie", "produce":
            self = .vegetables
        case "fruit", "fruits":
            self = .fruit
        case "meat", "poultry", "chicken", "beef", "pork":
            self = .meat
        case "seafood", "fish", "shellfish":
            self = .seafood
        case "dairy", "egg", "eggs", "dairy & eggs":
            self = .dairy
        case "grain", "grains", "bread", "rice", "pasta", "carb", "carbs":
            self = .grains
        default:
            self = .other
        }
    }

    /// 카드에 표기하는 라벨.
    var label: String {
        switch self {
        case .vegetables: return "Vegetables"
        case .fruit:      return "Fruit"
        case .meat:       return "Meat"
        case .seafood:    return "Seafood"
        case .dairy:      return "Dairy & Eggs"
        case .grains:     return "Grains"
        case .other:      return "Other"
        }
    }

    /// 디자이너 제공 에셋 이름(Assets.xcassets). 이 이미지셋이 번들에 있으면 그걸 쓴다.
    var iconAsset: String { "cat-\(rawValue)" }

    /// 에셋이 아직 없을 때의 Phosphor 폴백(§5 라인·currentColor 상속).
    /// 품목이 아니라 "카테고리 일반 상징"을 쓴다(채소=잎, 곡물=낱알…).
    /// 육류는 Phosphor에 raw-meat/steak 글리프가 없어 hamburger(고기)로 근사 — 커스텀 에셋으로 대체 예정.
    var fallbackIcon: Ph {
        switch self {
        case .vegetables: return .leaf       // 채소 — 잎
        case .fruit:      return .cherries   // 과일
        case .meat:       return .hamburger  // 육류 — 고기(steak 글리프 부재)
        case .seafood:    return .fish       // 해산물
        case .dairy:      return .cheese     // 유제품 — 치즈
        case .grains:     return .grains     // 곡물 — 낱알
        case .other:      return .forkKnife  // 기타
        }
    }
}

/// 카테고리 아이콘 — 디자이너 에셋(`cat-*`)이 번들에 있으면 그 벡터를 template로,
/// 없으면 Phosphor 폴백을 같은 크기로 렌더. 색은 호출부의 `.foregroundStyle`이 정한다.
struct CategoryIcon: View {
    let category: IngredientCategory
    var size: CGFloat = 22
    var weight: Ph.IconWeight = .bold

    var body: some View {
        if UIImage(named: category.iconAsset) != nil {
            // 디자이너 제공 벡터 — template 렌더링으로 currentColor 틴트(§5).
            Image(category.iconAsset)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            category.fallbackIcon.reffi(size, weight)
        }
    }
}
