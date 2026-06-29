import Foundation

/// 음식 모티프 종류 — 종이컷 실루엣(`PaperSilhouette`)이 이 값으로 단일 쉐입을 그린다.
enum FoodGlyph: CaseIterable {
    // 채소·과일
    case leaf, root, squash, onion, tomato, pepper, mushroom, broccoli, potato, garlic
    case apple, citrus, berry
    // 단백질
    case egg, tofu, meat, poultry, fish, shrimp
    // 유제품·기타
    case milk, cheese, bread
    case generic

    /// 재료명 키워드 → 글리프(영문 + 한글 일부). 미매칭은 `.generic`.
    static func match(_ name: String) -> FoodGlyph {
        let n = name.lowercased()
        func has(_ ks: [String]) -> Bool { ks.contains { n.contains($0) } }
        switch true {
        case has(["tofu", "두부"]):                                              return .tofu
        case has(["egg", "계란", "달걀"]):                                        return .egg
        case has(["beef", "pork", "steak", "bacon", "ham", "meat", "소고기", "쇠고기", "돼지", "고기", "삼겹", "스테이크"]): return .meat
        case has(["chicken", "drumstick", "poultry", "wing", "닭", "치킨"]):       return .poultry
        case has(["shrimp", "prawn", "새우"]):                                    return .shrimp
        case has(["fish", "salmon", "tuna", "mackerel", "cod", "생선", "연어", "고등어", "참치", "회"]): return .fish
        case has(["milk", "cream", "yogurt", "yoghurt", "우유", "크림", "요거트", "요구르트"]): return .milk
        case has(["cheese", "butter", "치즈", "버터"]):                            return .cheese
        case has(["bread", "toast", "bun", "baguette", "빵", "식빵", "토스트"]):    return .bread
        case has(["onion", "scallion", "leek", "양파", "대파", "쪽파", "파"]):      return .onion
        case has(["garlic", "마늘"]):                                            return .garlic
        case has(["tomato", "토마토"]):                                          return .tomato
        case has(["pepper", "paprika", "bell", "chili", "피망", "파프리카", "고추"]): return .pepper
        case has(["mushroom", "shiitake", "버섯"]):                              return .mushroom
        case has(["broccoli", "cauliflower", "브로콜리", "콜리"]):                 return .broccoli
        case has(["potato", "감자"]):                                            return .potato
        case has(["zucchini", "squash", "courgette", "cucumber", "eggplant", "애호박", "호박", "오이", "가지"]): return .squash
        case has(["carrot", "radish", "당근", "무"]):                            return .root
        case has(["apple", "pear", "peach", "사과", "배", "복숭아"]):              return .apple
        case has(["lemon", "lime", "orange", "citrus", "mandarin", "레몬", "라임", "오렌지", "귤", "감귤"]): return .citrus
        case has(["berry", "strawberry", "blueberry", "grape", "베리", "딸기", "블루베리", "포도"]): return .berry
        case has(["spinach", "lettuce", "cabbage", "kale", "greens", "herb", "leaf", "시금치", "상추", "배추", "양배추", "나물", "잎"]): return .leaf
        default:                                                                return .generic
        }
    }
}

/// 재료 카드의 데이터 — 재료 · 소비량 · 대안액션(사용자 스펙).
/// 상세(영수증) 표시용 필드(구매처·보관·구매일)는 기본값을 둬 기존 생성자와 호환.
struct Ingredient: Identifiable {
    let id = UUID()
    var name: String              // "연두부"
    var category: String          // "콩 · 두부"
    var daysLeft: Int             // D-day (음수 = 지남)
    var amount: String            // 소비량 "½모 남음"
    var alternative: AlternativeAction
    var glyph: FoodGlyph
    var place: String = ""        // 구매처(영수증 스캔이 채움). 비면 "—"
    var storage: String = "Fridge" // 보관(냉장/냉동/실온)
    var boughtDaysAgo: Int = 3    // 구매 시점(오늘 - n일)

    var freshness: Freshness { Freshness(daysLeft: daysLeft) }

    /// 남은 일수 라벨(영어). 데이터성 숫자(§3.4).
    var dDayText: String {
        switch daysLeft {
        case ..<0: "Overdue"
        case 0:    "Today"
        default:   "\(daysLeft)d"
        }
    }

    private static func dayText(_ offset: Int) -> String {
        let d = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        return d.formatted(date: .abbreviated, time: .omitted)
    }
    /// 구매일(오늘 - boughtDaysAgo).
    var purchasedText: String { Self.dayText(-boughtDaysAgo) }
    /// 유통기한(오늘 + daysLeft).
    var expiresText: String { Self.dayText(daysLeft) }
    var placeText: String { place.isEmpty ? "—" : place }
}
