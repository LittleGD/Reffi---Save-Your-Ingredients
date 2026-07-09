import Foundation

/// 가구 인원 — 레시피 양·쇼핑 수량 조절의 근거(타겟: 1인 가구·맞벌이, 명세 §1 개요).
/// rawValue는 UserDefaults 영속화용 안정 키.
enum HouseholdSize: String, CaseIterable, Identifiable, Codable {
    case one, two, family, large

    var id: String { rawValue }

    /// 칩 라벨 — 저장값은 영문 식별자 그대로, 표시만 로컬라이즈.
    var label: String {
        switch self {
        case .one:    String(localized: "Just me")
        case .two:    String(localized: "2 people")
        case .family: String(localized: "3–4")
        case .large:  String(localized: "5+")
        }
    }

    /// 레시피 양 계산용 대표 인원수(추천 연동 시 사용).
    var servings: Int {
        switch self {
        case .one: 1
        case .two: 2
        case .family: 4
        case .large: 6
        }
    }
}
