import Foundation
import UserNotifications

/// 소비기한 임박 로컬 알림 — 매일 아침(설정 시각) 그날 만료(D-0)·내일 만료(D-1) 재료를 묶어 알린다.
/// 스토어가 바뀔 때마다 앞으로 30일 치를 다시 짠다(iOS 대기 알림 한도 64개 내) — 오래 안 열어도
/// 한 달은 임박 알림이 살아 있다. 냉동 재료는 유예 시계(`effectiveExpiresAt`) 기준.
/// 설정은 MyPage의 토글/시각.
enum ExpiryNotifier {
    static let enabledKey = "expiryAlertsEnabled"
    static let hourKey = "expiryAlertHour"
    static let defaultHour = 9
    /// 사전 등록 창 — 미실행 상태에서도 이만큼은 알림이 이어진다.
    static let windowDays = 30

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }
    static var alertHour: Int {
        UserDefaults.standard.object(forKey: hourKey) as? Int ?? defaultHour
    }

    /// 권한 요청 — MyPage에서 토글을 켤 때 호출.
    static func requestAuthorization() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
        return granted
    }

    /// 앞으로 `windowDays`일 치 아침 알림을 재구성. 꺼져 있으면 전부 걷어낸다.
    /// 재료를 만료 오프셋으로 한 번 버킷팅(O(N)) — 31일 루프 × 재료 전수 필터의 중복 캘린더 연산 제거.
    static func reschedule(for ingredients: [Ingredient]) {
        let center = UNUserNotificationCenter.current()
        let ids = (0...windowDays).map { "expiry-day-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard isEnabled, !ingredients.isEmpty else { return }

        let cal = Calendar.current
        let now = Date()
        // 냉동은 유예 시계 기준 — 냉동해 둔 재료가 원래 기한으로 오늘 알림에 섞이지 않는다.
        var buckets: [Int: [Ingredient]] = [:]
        for ing in ingredients {
            let offset = Ingredient.days(from: now, to: ing.effectiveExpiresAt)
            if (0...(windowDays + 1)).contains(offset) { buckets[offset, default: []].append(ing) }
        }
        for offset in 0...windowDays {
            let dueToday = buckets[offset] ?? []
            let dueTomorrow = buckets[offset + 1] ?? []
            guard !(dueToday.isEmpty && dueTomorrow.isEmpty) else { continue }
            let day = Ingredient.day(offset: offset)
            guard let fireDate = cal.date(bySettingHour: alertHour, minute: 0, second: 0, of: day),
                  fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.sound = .default
            let frozenDue = dueToday.filter(\.isFrozen)
            // 이름은 전부 `displayName` — 저장 `name`은 담던 순간의 표기라 로케일이 박제된다
            // (§Ingredient.displayName). 알림은 기기 언어로 오는데 재료만 옛 표기면 문장 하나가 두 언어로 갈린다.
            if dueToday.isEmpty {
                let names = dueTomorrow.prefix(4).map(\.displayName).joined(separator: ", ")
                content.title = String(localized: "Expiring tomorrow",
                                       comment: "Notification title when items expire tomorrow")
                content.body = String(localized: "\(names). Plan a dish before they turn.",
                                      comment: "Notification body listing items expiring tomorrow")
            } else if frozenDue.count == dueToday.count {
                // 오늘 만료분이 전부 냉동 유예 — 해동 리드타임을 반영한 문구.
                let names = frozenDue.prefix(4).map(\.displayName).joined(separator: ", ")
                content.title = String(localized: "Freezer time's up",
                                       comment: "Notification title when frozen items reach grace deadline")
                content.body = String(localized: "\(names). Thaw and cook them today.",
                                      comment: "Notification body listing frozen items to thaw today")
            } else {
                // 제목 카운트와 본문 나열을 '오늘 만료'로 일치시키고, 내일 건은 별도 문장으로.
                let names = dueToday.prefix(4).map(\.displayName).joined(separator: ", ")
                content.title = String(localized: "Use \(dueToday.count) today",
                                       comment: "Notification title with count of items expiring today")
                var body = String(localized: "\(names). Open Reffi and fire a ticket.",
                                  comment: "Notification body listing expiring items")
                if !dueTomorrow.isEmpty {
                    let tomorrowNames = dueTomorrow.prefix(3).map(\.displayName).joined(separator: ", ")
                    body += " " + String(localized: "Tomorrow: \(tomorrowNames)",
                                         comment: "Appended sentence listing items expiring tomorrow")
                }
                content.body = body
            }

            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: "expiry-day-\(offset)",
                                             content: content, trigger: trigger))
        }
    }
}

/// 알림 표시 델리게이트 — 앱이 포그라운드일 때도 배너로 보여준다
/// (아침 알림 시각에 마침 앱을 열어둔 사용자가 놓치지 않게).
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
