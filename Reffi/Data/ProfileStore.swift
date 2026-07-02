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

    // 알림(§2.1) — 임박 기준일·알림 시간.
    var notifyEnabled: Bool { didSet { save() } }
    var leadDays: Int       { didSet { save() } }   // D-N 임박 기준(1/2/3/5/7)
    var notifyHour: Int     { didSet { save() } }
    var notifyMinute: Int   { didSet { save() } }

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
        notifyEnabled = defaults.object(forKey: Key.notifyEnabled) as? Bool ?? true
        leadDays   = defaults.object(forKey: Key.leadDays) as? Int ?? 3
        notifyHour = defaults.object(forKey: Key.notifyHour) as? Int ?? 8
        notifyMinute = defaults.object(forKey: Key.notifyMinute) as? Int ?? 0
    }

    /// 임박 기준 선택지(§2.1.1).
    static let leadDayOptions = [1, 2, 3, 5, 7]

    /// 알림 시간 텍스트 — "오전 8:00" 형식.
    var notifyTimeText: String {
        var c = DateComponents(); c.hour = notifyHour; c.minute = notifyMinute
        let date = Calendar.current.date(from: c) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
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
        notifyEnabled = true
        leadDays = 3
        notifyHour = 8
        notifyMinute = 0
    }

    private func save() {
        defaults.set(nickname, forKey: Key.nickname)
        defaults.set(cuisines.map(\.rawValue), forKey: Key.cuisines)
        defaults.set(favorites, forKey: Key.favorites)
        defaults.set(disliked, forKey: Key.disliked)
        defaults.set(allergies, forKey: Key.allergies)
        defaults.set(household.rawValue, forKey: Key.household)
        defaults.set(notifyEnabled, forKey: Key.notifyEnabled)
        defaults.set(leadDays, forKey: Key.leadDays)
        defaults.set(notifyHour, forKey: Key.notifyHour)
        defaults.set(notifyMinute, forKey: Key.notifyMinute)
    }

    private enum Key {
        static let nickname = "profile.nickname"
        static let cuisines = "profile.cuisines"
        static let favorites = "profile.favorites"
        static let disliked = "profile.disliked"
        static let allergies = "profile.allergies"
        static let household = "profile.household"
        static let notifyEnabled = "profile.notifyEnabled"
        static let leadDays = "profile.leadDays"
        static let notifyHour = "profile.notifyHour"
        static let notifyMinute = "profile.notifyMinute"
    }
}
