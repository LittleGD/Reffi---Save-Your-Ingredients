import Accessibility
import Foundation

/// 화면이 **조용히** 바뀐 사실을 VoiceOver에 말로 알린다.
///
/// 포커스가 따라가지 않는 변화 — 위에서 내려오는 되돌리기 토스트, 스캔 단계 전환처럼 사용자가
/// 손대지 않은 자리에서 일어나는 일 — 은 고지가 없으면 보조기술 사용자에게 **일어나지 않은 것과 같다**.
/// 화면에 남기는 것(§7)과 짝이 되는 소리 쪽 규칙이라 앱 공통 자리에 둔다.
///
/// 우선순위를 `.high`로 고정한 것은 취향이 아니다: 기본 우선순위 발화는 VoiceOver가 다른 말을 하는
/// 중이면 **그냥 버려진다**. 여기로 오는 문장은 전부 창이 닫히기 전에 닿아야 하는 것들이다.
enum ReffiAnnounce {
    static func say(_ message: String) {
        var text = AttributedString(message)
        text.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(text).post()
    }
}
