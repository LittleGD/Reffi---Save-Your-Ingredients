import Testing
import Foundation
@testable import Reffi

/// 이번 주 소비 집계 — History 히어로(고리 + 요일 블롭)가 읽는 규칙.
/// 모든 케이스가 **고정 날짜 + 고정 캘린더**(타임존·주 시작일 명시)라 러너의 로케일에 흔들리지 않는다.
struct ConsumptionWeekTests {

    /// 2026-08-16(일) ~ 08-22(토)가 한 주가 되는 기준 캘린더. 요일 심볼 단언 때문에 로케일도 고정한다.
    private func calendar(firstWeekday: Int = 1,
                          timeZone: String = "Asia/Seoul") -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: timeZone)!
        cal.firstWeekday = firstWeekday
        cal.locale = Locale(identifier: "en_US")
        return cal
    }

    private func date(_ cal: Calendar, _ y: Int, _ m: Int, _ d: Int,
                      _ hour: Int = 12, _ minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour, minute: minute))!
    }

    private func log(_ when: Date, wasted: Bool, via: String? = nil, name: String = "Item") -> RemovalLog {
        RemovalLog(name: name, glyph: .generic, removedAt: when, wasted: wasted, via: via)
    }

    // MARK: 주 경계

    /// 주 시작일은 `Calendar.firstWeekday`가 정하고, 창은 **[주 시작 자정, 다음 주 시작 자정)** 이다.
    /// 하루 전날 밤과 다음 주 첫날은 창 밖이라 한 건도 세지 않는다.
    @Test func weekWindowIsHalfOpenAndFollowsFirstWeekday() {
        let cal = calendar()                                    // 일요일 시작
        let now = date(cal, 2026, 8, 19)                        // 수요일
        let logs = [
            log(date(cal, 2026, 8, 15, 23, 59), wasted: false),  // 토 — 지난 주(경계 1분 전)
            log(date(cal, 2026, 8, 16, 0, 0), wasted: false),    // 일 — 창의 첫 순간(포함)
            log(date(cal, 2026, 8, 19), wasted: false),          // 수 — 오늘
            log(date(cal, 2026, 8, 23, 0, 0), wasted: false),    // 다음 주 일요일(제외)
        ]
        let week = ConsumptionWeek.summary(of: logs, calendar: cal, now: now)

        #expect(ConsumptionWeek.weekStart(calendar: cal, now: now) == date(cal, 2026, 8, 16, 0, 0))
        #expect(week.days.count == 7)
        #expect(week.removed == 2)
        #expect(week.eaten == 2)
        #expect(week.days.map(\.eaten) == [1, 0, 0, 1, 0, 0, 0])
        // 화면에서 눈으로 검산되는 불변식: 요일 칸의 합 = 고리의 분자.
        #expect(week.days.reduce(0) { $0 + $1.eaten } == week.eaten)
    }

    /// 같은 날·같은 로그라도 주 시작일이 월요일이면 지난 일요일은 이번 주가 아니다.
    @Test func mondayStartMovesTheWindow() {
        let cal = calendar(firstWeekday: 2)                     // 월요일 시작
        let now = date(cal, 2026, 8, 19)
        let logs = [
            log(date(cal, 2026, 8, 16), wasted: false),          // 일 — 월요일 시작에선 지난 주
            log(date(cal, 2026, 8, 17), wasted: false),          // 월 — 창의 첫날
        ]
        let week = ConsumptionWeek.summary(of: logs, calendar: cal, now: now)

        #expect(ConsumptionWeek.weekStart(calendar: cal, now: now) == date(cal, 2026, 8, 17, 0, 0))
        #expect(week.removed == 1)
        #expect(week.days.map(\.eaten) == [1, 0, 0, 0, 0, 0, 0])
        #expect(week.days.first?.weekday == 2)                   // 2 = 월요일
    }

    /// 오늘이 곧 주 시작일이면 오프셋은 0이다(음수로 한 주 뒤로 밀지 않는다).
    @Test func weekStartIsTodayWhenTodayIsTheFirstWeekday() {
        let cal = calendar()
        let now = date(cal, 2026, 8, 16, 9)                       // 일요일 오전
        #expect(ConsumptionWeek.weekStart(calendar: cal, now: now) == date(cal, 2026, 8, 16, 0, 0))
    }

    // MARK: 타임존 · 서머타임

    /// 날짜 칸 배정은 **캘린더의 자정**이 정한다. 서머타임이 끝나 하루가 25시간인 주에서,
    /// 초 나눗셈(86400)으로 칸을 나누면 그날 밤 로그가 다음 날로 밀린다.
    /// 2026-11-01(미국 서부 DST 종료) 23:30 PST는 주 시작(같은 날 00:00 PDT)에서 **절대 24.5시간** 뒤다.
    @Test func dayBucketsSurviveDaylightSavingTransition() {
        let cal = calendar(timeZone: "America/Los_Angeles")       // 일요일 시작
        let now = date(cal, 2026, 11, 4)                          // 수요일
        let lateSunday = date(cal, 2026, 11, 1, 23, 30)
        let week = ConsumptionWeek.summary(of: [log(lateSunday, wasted: false)],
                                           calendar: cal, now: now)

        // 절대 경과가 24시간을 넘지만 달력으로는 여전히 일요일이다 — 이 단언이 그 함정을 고정한다.
        #expect(lateSunday.timeIntervalSince(date(cal, 2026, 11, 1, 0, 0)) > 24 * 3600)
        #expect(week.days.map(\.eaten) == [1, 0, 0, 0, 0, 0, 0])
    }

    /// 같은 절대 시각이라도 캘린더의 타임존이 다르면 다른 날에 앉는다 — 로컬 자정이 기준이라는 규약.
    @Test func bucketFollowsCalendarTimeZoneNotAbsoluteSeconds() {
        let seoul = calendar()
        let instant = date(seoul, 2026, 8, 19, 0, 30)             // 서울 수요일 00:30 = UTC 화요일 15:30
        var utc = calendar()
        utc.timeZone = TimeZone(identifier: "UTC")!

        let inSeoul = ConsumptionWeek.summary(of: [log(instant, wasted: false)],
                                              calendar: seoul, now: date(seoul, 2026, 8, 19))
        let inUTC = ConsumptionWeek.summary(of: [log(instant, wasted: false)],
                                            calendar: utc, now: date(seoul, 2026, 8, 19))
        #expect(inSeoul.days.map(\.eaten) == [0, 0, 0, 1, 0, 0, 0])   // 수요일
        #expect(inUTC.days.map(\.eaten) == [0, 0, 1, 0, 0, 0, 0])     // 화요일
    }

    // MARK: 빈 창

    /// 이번 주에 처리한 게 하나도 없으면 비율은 **없다**(0%가 아니다). 0/0을 0%로 내면
    /// "이번 주에 다 버렸다"는 없는 판정이 화면에 뜨고, 나눗셈을 그대로 두면 NaN이 된다.
    @Test func emptyWindowHasNoRateInsteadOfZero() {
        let cal = calendar()
        let now = date(cal, 2026, 8, 19)
        let week = ConsumptionWeek.summary(of: [log(date(cal, 2026, 8, 10), wasted: false),
                                                log(date(cal, 2026, 8, 12), wasted: true)],
                                           calendar: cal, now: now)
        #expect(week.removed == 0)
        #expect(week.eaten == 0)
        #expect(week.eatenRate == nil)
        #expect(week.wasteRate == nil)
        #expect(week.days.allSatisfy { $0.eaten == 0 })
    }

    /// 이력이 아예 비어도 칸 일곱은 그대로 선다(빈 주에도 행은 형태를 유지한다).
    @Test func noLogsStillYieldsSevenDays() {
        let cal = calendar()
        let week = ConsumptionWeek.summary(of: [], calendar: cal, now: date(cal, 2026, 8, 19))
        #expect(week.days.count == 7)
        #expect(week.eatenRate == nil)
    }

    // MARK: 비율 · 발주 소비

    /// 비율은 **처리한 것 중 안 버린 비율**이고, 색이 쓰는 낭비율은 그 여집합이다.
    @Test func rateCountsNotWastedOverEverythingRemoved() {
        let cal = calendar()
        let now = date(cal, 2026, 8, 19)
        let logs = [
            log(date(cal, 2026, 8, 17), wasted: false),
            log(date(cal, 2026, 8, 17), wasted: false),
            log(date(cal, 2026, 8, 18), wasted: false),
            log(date(cal, 2026, 8, 18), wasted: true),
        ]
        let week = ConsumptionWeek.summary(of: logs, calendar: cal, now: now)
        #expect(week.removed == 4)
        #expect(week.eaten == 3)
        #expect(week.eatenRate == 75)
        #expect(week.wasteRate == 25)
        // 버린 줄은 요일 칸에 서지 않는다 — 칸은 "먹은 개수"다.
        // 8/17(월, 칸 1)에 둘, 8/18(화, 칸 2)에 하나. 8/18의 버림 한 건은 어느 칸에도 안 선다.
        #expect(week.days.map(\.eaten) == [0, 2, 1, 0, 0, 0, 0])
    }

    /// 발주(레시피 조리)로 소비된 줄도 먹은 것이다 — `via`가 붙었다고 빠지면 요리한 주가 가장 나쁜
    /// 주로 보인다.
    @Test func recipeConsumptionCountsAsEaten() {
        let cal = calendar()
        let now = date(cal, 2026, 8, 19)
        let logs = [
            log(date(cal, 2026, 8, 18), wasted: false, via: "Bibimbap"),
            log(date(cal, 2026, 8, 18), wasted: false, via: "Bibimbap"),
            log(date(cal, 2026, 8, 19), wasted: true),
        ]
        let week = ConsumptionWeek.summary(of: logs, calendar: cal, now: now)
        #expect(week.eaten == 2)
        #expect(week.eatenRate == 67)                             // 2/3 = 66.67 → 반올림
        #expect(week.days.map(\.eaten) == [0, 0, 2, 0, 0, 0, 0])
    }

    // MARK: 오늘 · 앞으로 올 날

    /// 오늘은 정확히 한 칸이고, 그 뒤는 전부 "아직 오지 않은 날"이다(0으로 판정하지 않는다).
    @Test func todayIsExactlyOneCellAndLaterDaysAreFuture() {
        let cal = calendar()
        let now = date(cal, 2026, 8, 19, 23)                       // 수요일 늦은 밤
        let week = ConsumptionWeek.summary(of: [], calendar: cal, now: now)

        #expect(week.days.filter(\.isToday).count == 1)
        #expect(week.days[3].isToday)                              // 일(0)…수(3)
        #expect(week.days.map(\.isFuture) == [false, false, false, false, true, true, true])
    }

    /// 주의 마지막 날이 오늘이면 앞으로 올 날은 없다.
    @Test func lastDayOfWeekLeavesNoFutureCells() {
        let cal = calendar()
        let week = ConsumptionWeek.summary(of: [], calendar: cal, now: date(cal, 2026, 8, 22))
        #expect(week.days[6].isToday)
        #expect(week.days.allSatisfy { !$0.isFuture })
    }

    // MARK: 요일 이름

    /// 화면 머리글자와 접근성 이름이 **같은 칸**에서 나온다(둘이 갈리면 한 칸이 두 이름을 갖는다).
    @Test func weekdaySymbolsComeFromTheCalendarLocale() {
        let cal = calendar()
        let week = ConsumptionWeek.summary(of: [], calendar: cal, now: date(cal, 2026, 8, 19))
        #expect(ConsumptionWeek.initial(of: week.days[0], calendar: cal) == "S")
        #expect(ConsumptionWeek.name(of: week.days[0], calendar: cal) == "Sunday")
        #expect(ConsumptionWeek.name(of: week.days[1], calendar: cal) == "Monday")
        #expect(ConsumptionWeek.name(of: week.days[6], calendar: cal) == "Saturday")
    }
}
