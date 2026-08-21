import SwiftUI

/// 촉각·기울임 사용자 설정(§7.6 · §13.4)의 **단일 진실 소스**.
/// 프로필 "감각" 영수증의 토글 두 개가 쓰는 `@AppStorage` 키를 여기 모으고, 뷰가 아닌 곳
/// (씬·재생기)에서 현재 값을 읽는 정적 접근자를 함께 둔다 — 알림 설정 키를 `ExpiryNotifier`에
/// 모아 둔 것과 같은 규율이다(키 문자열이 화면마다 흩어지면 조용히 어긋난다).
///
/// **시스템 접근성 설정이 우선이고, 이 토글은 그 위에 얹히는 사용자 선택이다** — Reduce Motion이
/// 켜져 있으면 기울임 중력은 이 토글과 무관하게 꺼지고(§7.4), 시스템 진동 끔은 CoreHaptics·
/// `.sensoryFeedback`이 알아서 존중한다. 토글은 "시스템 설정은 그대로 두고 이 앱에서만 빼 달라"는
/// 자리다(예: Reduce Motion은 안 쓰지만 폰이 흔들리는 건 싫은 사람).
enum ReffiFeedback {
    /// 충돌 진동(달그락·판정·발주 등 앱 전체 햅틱) 스위치. 기본 켬.
    static let hapticsKey = "haptics.enabled"
    /// 기울임 중력(자이로) 스위치. 기본 켬.
    static let tiltKey = "tilt.enabled"

    /// 뷰 밖에서 읽는 현재 값.
    static var hapticsEnabled: Bool { flag(hapticsKey) }
    static var tiltEnabled: Bool { flag(tiltKey) }

    /// 미설정 = 켬. `UserDefaults.bool(forKey:)`는 미설정을 false로 접어 **첫 실행을 조용히 무음**으로
    /// 만들기 때문에, `@AppStorage`의 기본값(true)과 같은 의미가 되도록 object로 읽는다.
    private static func flag(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }
}

extension View {
    /// 프로필 "충돌 진동" 토글을 존중하는 `.sensoryFeedback`(§7.6 의미별 매핑은 그대로).
    /// 앱의 의미 햅틱은 **전부 이 경로**로 낸다 — 호출부마다 토글을 읽으면 한 군데를 빠뜨린 채
    /// 껐는데도 울리는 화면이 남는다.
    func reffiFeedback<T: Equatable>(_ feedback: SensoryFeedback, trigger: T) -> some View {
        modifier(ReffiFeedbackModifier(feedback: feedback, trigger: trigger))
    }
}

/// 끄면 피드백을 `nil`로 돌려 **발화 자체를 막는다**. 모디파이어를 조건부로 떼는 방식은 쓰지 않는다 —
/// 붙였다 뗐다 하면 SwiftUI가 trigger의 직전 값을 잃어, 다시 켜는 프레임에 밀린 한 번이 울린다.
private struct ReffiFeedbackModifier<T: Equatable>: ViewModifier {
    /// `@AppStorage`라 토글이 바뀌면 이 모디파이어가 곧바로 다시 평가된다(재시작 불요).
    @AppStorage(ReffiFeedback.hapticsKey) private var enabled = true
    let feedback: SensoryFeedback
    let trigger: T

    func body(content: Content) -> some View {
        content.sensoryFeedback(trigger: trigger) { _, _ in enabled ? feedback : nil }
    }
}
