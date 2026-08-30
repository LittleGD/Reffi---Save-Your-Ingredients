import Foundation

/// 보관 위치 — 신선도 시계(냉동 유예)·기본 소비기한·알림이 이 값에 따라 달라진다.
/// rawValue는 기존 저장 파일(v1)의 문자열("Fridge" 등)과 일치해 그대로 디코딩된다.
/// 미지의 값(구버전·외부 입력)은 `.fridge`로 폴백한다.
enum StorageLocation: String, Codable, CaseIterable, Identifiable {
    case fridge = "Fridge"
    case freezer = "Freezer"
    case pantry = "Pantry"
    case room = "Room"

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = StorageLocation(rawValue: raw) ?? .fridge
    }

    /// 표시 라벨 — 저장값은 영문 식별자 그대로, 표시만 로컬라이즈(기존 xcstrings 키 재사용).
    var label: String { AppLanguage.localizedNow(String.LocalizationValue(rawValue)) }
}
