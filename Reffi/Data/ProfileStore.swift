import Observation
import Foundation

/// 사용자 프로필·선호도(§5) — 앱의 두 번째 소스(FridgeStore와 병렬).
/// 백엔드가 없는 디자인 빌드라 값은 `UserDefaults`에 로컬 영속한다(CardStyle 선례, §영속화).
/// 각 속성의 `didSet`에서 저장 → 바인딩·칩 토글 어디서 바꿔도 자동 유지.
@Observable
final class ProfileStore {
    var nickname: String            { didSet { save() } }
    var cuisines: Set<CuisineStyle> { didSet { save() } }
    var favorites: [String]         { didSet { save() } }   // 좋아하는 재료(§5.2 선호)
    var disliked: [String]          { didSet { save() } }
    var allergies: [String]         { didSet { save() } }
    var household: HouseholdSize    { didSet { save() } }   // 가구 인원 — 레시피 양 근거

    // 알림 설정(토글·시각)의 SSOT는 `ExpiryNotifier`의 @AppStorage 키(enabledKey/hourKey)로 단일화했다.
    // 프로필의 알림 UI는 그 키를 직접 읽고 실제 스케줄(reschedule)에 반영한다 —
    // ProfileStore에 있던 notifyEnabled/leadDays/notifyHour/notifyMinute는 스케줄에 물리지 않던
    // 죽은 플래그라 제거했다(중복 진실 소스 제거).

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // 초기화 단계 대입은 didSet을 트리거하지 않음 → 로드 중 불필요한 재저장 없음.
        nickname   = defaults.string(forKey: Key.nickname) ?? "Reffi"
        let rawCui = defaults.stringArray(forKey: Key.cuisines) ?? [CuisineStyle.korean.rawValue]
        cuisines   = Set(rawCui.compactMap(CuisineStyle.init(rawValue:)))
        favorites  = defaults.stringArray(forKey: Key.favorites) ?? []
        disliked   = defaults.stringArray(forKey: Key.disliked) ?? []
        allergies  = defaults.stringArray(forKey: Key.allergies) ?? []
        household  = HouseholdSize(rawValue: defaults.string(forKey: Key.household) ?? "") ?? .one
    }

    func toggleCuisine(_ c: CuisineStyle) {
        if cuisines.contains(c) { cuisines.remove(c) } else { cuisines.insert(c) }
    }

    /// 회원 탈퇴(§6.5) — 로컬 프로필 데이터 초기화(백엔드 없으므로 기본값 복구).
    func resetAll() {
        nickname = "Reffi"
        cuisines = [.korean]
        favorites = []
        disliked = []
        allergies = []
        household = .one
    }

    private func save() {
        defaults.set(nickname, forKey: Key.nickname)
        defaults.set(cuisines.map(\.rawValue), forKey: Key.cuisines)
        defaults.set(favorites, forKey: Key.favorites)
        defaults.set(disliked, forKey: Key.disliked)
        defaults.set(allergies, forKey: Key.allergies)
        defaults.set(household.rawValue, forKey: Key.household)
    }

    private enum Key {
        static let nickname = "profile.nickname"
        static let cuisines = "profile.cuisines"
        static let favorites = "profile.favorites"
        static let disliked = "profile.disliked"
        static let allergies = "profile.allergies"
        static let household = "profile.household"
    }
}
