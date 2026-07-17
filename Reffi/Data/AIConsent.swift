import Foundation

/// AI 레시피 생성의 **동의·사용량 상태**(§Apple 5.1.2 / MVP). 여기엔 상태만 있고,
/// 동의 화면·토글 UI는 후속 에이전트가 이 키(`cloudConsentKey`)에 배선한다.
///
/// - 온디바이스 생성은 재료가 기기를 떠나지 않아 **동의가 필요 없다**.
/// - 클라우드 프록시(재료 외부 전송)만 **명시 동의 게이트**(`cloudEnabled`). 기본 꺼짐.
/// - 일일 캡은 클라이언트 미러(서버 캡은 별도) — 초과 시 엔진 호출 자체를 스킵해 과금·과호출을 막는다.
enum AIConsent {
    /// 클라우드(외부 전송) 생성 동의 — @AppStorage 키(SSOT). 기본 false. 후속 UI 토글이 이 키를 쓴다.
    static let cloudConsentKey = "ai.cloudConsent"
    /// 하루 AI 생성 호출 상한(클라이언트 미러).
    static let dailyCap = 5

    private static let usageCountKey = "ai.usageCount"
    private static let usageDayKey = "ai.usageDay"

    private static var defaults: UserDefaults { .standard }

    /// 클라우드 전송 동의 여부(읽기/쓰기 — 후속 UI 토글이 set).
    static var cloudEnabled: Bool {
        get { defaults.bool(forKey: cloudConsentKey) }
        set { defaults.set(newValue, forKey: cloudConsentKey) }
    }

    /// 오늘 이미 사용한 생성 횟수 — 저장된 일자가 오늘이 아니면 0(자정 롤오버).
    static var usageToday: Int {
        guard defaults.integer(forKey: usageDayKey) == today else { return 0 }
        return defaults.integer(forKey: usageCountKey)
    }

    /// 오늘 남은 생성 횟수(0 이상).
    static var remainingToday: Int { max(0, dailyCap - usageToday) }

    /// 오늘 생성 여력이 있나 — 엔진 호출 전 게이트.
    static var canGenerateToday: Bool { remainingToday > 0 }

    /// 생성 1회 소비 기록(일자 롤오버 포함). 엔진 호출이 실제 결과를 낸 뒤 호출.
    static func recordUsage() {
        if defaults.integer(forKey: usageDayKey) != today {
            defaults.set(today, forKey: usageDayKey)
            defaults.set(0, forKey: usageCountKey)
        }
        defaults.set(defaults.integer(forKey: usageCountKey) + 1, forKey: usageCountKey)
    }

    /// 사용량 리셋(회원 탈퇴·데이터 초기화용).
    static func resetUsage() {
        defaults.removeObject(forKey: usageCountKey)
        defaults.removeObject(forKey: usageDayKey)
    }

    /// 동의·사용량 전면 리셋 — 계정 전환·탈퇴 시 소유자 데이터 와이프와 **원자적으로** 호출한다.
    /// 클라우드 동의(cloudEnabled)와 일일 사용량은 계정에 귀속되므로(다른 사용자에게 새면 안 됨),
    /// 냉장고·프로필 초기화와 한 묶음으로 되돌린다. 이 진입점을 두 와이프 호출부가 공유한다.
    static func resetAll() {
        cloudEnabled = false
        resetUsage()
    }

    /// 로컬 달력 기준 일련 일자(yyyyMMdd 정수) — 자정 롤오버 판정 키.
    private static var today: Int {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return (c.year ?? 0) * 10000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }
}
