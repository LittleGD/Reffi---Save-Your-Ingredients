import Foundation

/// 수량 단위 — 같은 차원(무게/부피) 안에서만 환산한다. 개수 단위(개·팩·모…)는 서로 환산하지 않는다.
/// rawValue는 저장 식별자(영문), 표시는 로컬라이즈.
enum IngredientUnit: String, Codable, CaseIterable, Identifiable {
    case piece = "ea"
    case gram = "g"
    case kilogram = "kg"
    case milliliter = "ml"
    case liter = "L"
    case pack = "pack"
    case bunch = "bunch"
    case slice = "slice"
    case block = "block"
    case bottle = "bottle"

    var id: String { rawValue }

    enum Dimension { case mass, volume, count }

    var dimension: Dimension {
        switch self {
        case .gram, .kilogram: .mass
        case .milliliter, .liter: .volume
        default: .count
        }
    }

    /// 기준 단위(g/ml) 대비 배율 — 개수 차원은 1(환산 없음).
    var baseFactor: Double {
        switch self {
        case .kilogram: 1000
        case .liter: 1000
        default: 1
        }
    }

    /// 표시 라벨 — g/kg/ml/L은 만국 공통 기호라 그대로, 개수 단위만 로컬라이즈.
    var label: String {
        switch self {
        case .gram, .kilogram, .milliliter, .liter: rawValue
        default: String(localized: String.LocalizationValue(rawValue))
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = IngredientUnit(rawValue: raw) ?? .piece
    }
}

/// 수량 — 수치 + 단위. 부분 소비(반 남음)와 단위 환산이 모델 차원에서 가능하다.
struct Quantity: Codable, Equatable {
    var value: Double
    var unit: IngredientUnit

    /// 같은 차원의 다른 단위로 환산. 차원이 다르면 nil(개수↔무게 등은 환산 불가).
    func converted(to target: IngredientUnit) -> Quantity? {
        guard unit.dimension == target.dimension else { return nil }
        guard unit.dimension != .count || unit == target else { return unit == target ? self : nil }
        let base = value * unit.baseFactor
        return Quantity(value: base / target.baseFactor, unit: target)
    }

    /// 절반 — "조금 남았어요" 처리용. 0.25 미만으로는 내려가지 않는다(잔량 표시 유지).
    var halved: Quantity { Quantity(value: max(0.25, value / 2), unit: unit) }

    /// 표시 문자열 — 정수는 소수점 없이, 0.5는 ½로.
    var text: String {
        let v: String
        if value == 0.5 { v = "½" }
        else if value == 0.25 { v = "¼" }
        else if value.truncatingRemainder(dividingBy: 1) == 0 { v = String(Int(value)) }
        else { v = String(format: "%.1f", value) }
        return "\(v) \(unit.label)"
    }

    /// 레거시 자유 문자열("300 g", "2 ea", "½모 남음", "1 L") 최선 파싱 — v1 → v2 마이그레이션.
    /// 못 읽으면 1개로 폴백(표시 정보는 잃지만 판정·통계 로직은 살아남는다).
    static func parseLegacy(_ raw: String) -> Quantity {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !s.isEmpty else { return Quantity(value: 1, unit: .piece) }

        var value: Double? = nil
        var rest = s
        if s.hasPrefix("½") { value = 0.5; rest = String(s.dropFirst()) }
        else if s.hasPrefix("¼") { value = 0.25; rest = String(s.dropFirst()) }
        else if let match = s.range(of: #"^[0-9]+([.,][0-9]+)?"#, options: .regularExpression) {
            value = Double(s[match].replacingOccurrences(of: ",", with: "."))
            rest = String(s[match.upperBound...])
        }
        guard let v = value else { return Quantity(value: 1, unit: .piece) }

        let unitToken = rest.trimmingCharacters(in: .whitespaces)
        // 긴 키 우선 — 접두 매칭이라 "loaf"가 "l"(리터)보다 먼저 와야 "½ loaf"가 리터로 오파싱되지 않는다.
        let unitMap: [(key: String, unit: IngredientUnit)] = [
            ("bottle", .bottle), ("bunch", .bunch), ("block", .block), ("slice", .slice),
            ("pack", .pack), ("loaf", .block), ("ea", .piece), ("kg", .kilogram),
            ("ml", .milliliter), ("봉지", .pack), ("묶음", .bunch), ("덩이", .block),
            ("팩", .pack), ("봉", .pack), ("단", .bunch), ("줌", .bunch), ("장", .slice),
            ("쪽", .slice), ("모", .block), ("병", .bottle), ("통", .bottle),
            ("개", .piece), ("알", .piece), ("g", .gram), ("l", .liter),
        ]
        for entry in unitMap where unitToken.hasPrefix(entry.key) {
            return Quantity(value: v, unit: entry.unit)
        }
        return Quantity(value: v, unit: .piece)
    }
}
