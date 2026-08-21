import Testing
import Foundation
@testable import Reffi

/// 이번 주 소비 집계 — History 히어로(숫자 헤드라인 + 추세 문장 + 종이 칩 일곱)가 읽는 규칙.
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
    /// 하루 전날 밤은 **지난 주** 칸으로 가고(이번 주에는 안 센다), 다음 주 첫날은 두 창 어디에도 없다.
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
        // 화면에서 눈으로 검산되는 불변식: 칸 일곱의 합 = 헤드라인의 분자.
        #expect(week.days.reduce(0) { $0 + $1.eaten } == week.eaten)
        // 경계 1분 전 로그는 사라지지 않는다 — 지난 주 총계로 넘어간다(추세 문장이 읽는 값).
        #expect(week.previousRemoved == 1)
        #expect(week.previousEaten == 1)
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
        // 두 로그(8/10·8/12)는 **지난 주** 창에 있다. 지난 주 비율은 나오지만 이번 주가 비었으므로
        // 추세 문장은 서지 않는다 — 한쪽만 있는 비교는 비교가 아니다.
        #expect(week.previousRemoved == 2)
        #expect(week.previousEatenRate == 50)
        #expect(week.trend == nil)
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
        // 버린 줄은 **먹은 칸**에 서지 않는다 — 칸의 숫자는 "먹은 개수"다.
        // 8/17(월, 칸 1)에 둘, 8/18(화, 칸 2)에 하나.
        #expect(week.days.map(\.eaten) == [0, 2, 1, 0, 0, 0, 0])
        // 대신 **같은 칸의 다른 채널**로 남는다(칩 모서리의 빨간 조각) — 하루는 먹은 날이면서
        // 동시에 버린 날일 수 있어야 하고, 8/18이 정확히 그 날이다.
        #expect(week.days.map(\.tossed) == [0, 0, 1, 0, 0, 0, 0])
        #expect(week.days[2].eaten == 1 && week.days[2].tossed == 1)
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

    // MARK: 지난 주 창 — 추세 문장의 분모

    /// 지난 주 창은 **[이번 주 시작 −7일, 이번 주 시작)** 이다. 두 창은 붙어 있고 겹치지 않는다:
    /// 이번 주 시작 자정 로그는 이번 주에만, 그 1초 전 로그는 지난 주에만 선다.
    @Test func previousWeekIsTheSevenDaysImmediatelyBeforeThisWeek() {
        let cal = calendar()                                    // 일요일 시작
        let now = date(cal, 2026, 8, 19)                        // 수요일
        let logs = [
            log(date(cal, 2026, 8, 8, 23, 59), wasted: false),   // 지지난 주(제외)
            log(date(cal, 2026, 8, 9, 0, 0), wasted: false),     // 지난 주 첫 순간(포함)
            log(date(cal, 2026, 8, 13), wasted: true),           // 지난 주
            log(date(cal, 2026, 8, 15, 23, 59), wasted: false),  // 지난 주 마지막 순간
            log(date(cal, 2026, 8, 16, 0, 0), wasted: false),    // 이번 주 첫 순간
        ]
        let week = ConsumptionWeek.summary(of: logs, calendar: cal, now: now)

        #expect(ConsumptionWeek.previousWeekStart(calendar: cal, now: now) == date(cal, 2026, 8, 9, 0, 0))
        #expect(week.previousRemoved == 3)
        #expect(week.previousEaten == 2)
        #expect(week.previousEatenRate == 67)                    // 2/3 = 66.67 → 반올림
        #expect(week.removed == 1)
        #expect(week.eaten == 1)
        // 지난 주 로그는 이번 주 칸에 한 건도 새지 않는다.
        #expect(week.days.map(\.eaten) == [1, 0, 0, 0, 0, 0, 0])
        #expect(week.days.allSatisfy { $0.tossed == 0 })
    }

    /// **해가 바뀌는 경계.** 지난 주가 12월, 이번 주가 1월이어도 두 창은 그대로 붙어 있다 —
    /// 달력 주차(`weekOfYear`)로 되짚었다면 `minimumDaysInFirstWeek` 때문에 로케일에 따라 한 주가
    /// 밀리는 지점이다. 2027-01-03(일)이 이번 주 시작이면 지난 주는 2026-12-27(일)부터다.
    @Test func previousWeekCrossesTheYearBoundary() {
        let cal = calendar()
        let now = date(cal, 2027, 1, 6)                          // 수요일
        let logs = [
            log(date(cal, 2026, 12, 26, 23, 59), wasted: false), // 지지난 주(제외)
            log(date(cal, 2026, 12, 27, 0, 0), wasted: false),   // 지난 주 첫날
            log(date(cal, 2026, 12, 31), wasted: true),          // 지난 주(해가 안 바뀐 쪽)
            log(date(cal, 2027, 1, 1), wasted: false),           // 지난 주(해가 바뀐 쪽)
            log(date(cal, 2027, 1, 4), wasted: false),           // 이번 주 월요일
        ]
        let week = ConsumptionWeek.summary(of: logs, calendar: cal, now: now)

        #expect(ConsumptionWeek.weekStart(calendar: cal, now: now) == date(cal, 2027, 1, 3, 0, 0))
        #expect(ConsumptionWeek.previousWeekStart(calendar: cal, now: now) == date(cal, 2026, 12, 27, 0, 0))
        #expect(week.previousRemoved == 3)
        #expect(week.previousEaten == 2)
        #expect(week.removed == 1)
        #expect(week.days.map(\.eaten) == [0, 1, 0, 0, 0, 0, 0])
    }

    /// **지난 주 시작도 달력이 정한다.** 서머타임이 끝나는 주(2026-11-01 미국 서부)를 지난 주로 두면
    /// 그 주는 절대 시간으로 **169시간**이다. `이번 주 시작 − 7 × 86400초`로 되짚으면 지난 주 시작이
    /// 한 시간 늦어져, 그 주 첫날 새벽 로그가 두 창 어디에도 안 남고 조용히 사라진다.
    @Test func previousWeekStartSurvivesDaylightSavingTransition() {
        let cal = calendar(timeZone: "America/Los_Angeles")      // 일요일 시작
        let now = date(cal, 2026, 11, 11)                        // 수요일
        let weekStart = date(cal, 2026, 11, 8, 0, 0)
        let previousStart = date(cal, 2026, 11, 1, 0, 0)
        // 그 주가 실제로 168시간이 아니라는 사실부터 못 박는다(이 단언이 깨지면 픽스처가 무의미하다).
        #expect(weekStart.timeIntervalSince(previousStart) == 169 * 3600)

        let logs = [
            log(date(cal, 2026, 11, 1, 0, 30), wasted: false),    // 지난 주 첫날 새벽(초 나눗셈이면 유실)
            log(date(cal, 2026, 11, 7, 23, 30), wasted: true),    // 지난 주 마지막 밤
            log(date(cal, 2026, 11, 8, 0, 30), wasted: false),    // 이번 주 첫날 새벽
        ]
        let week = ConsumptionWeek.summary(of: logs, calendar: cal, now: now)

        #expect(ConsumptionWeek.previousWeekStart(calendar: cal, now: now) == previousStart)
        #expect(week.previousRemoved == 2)
        #expect(week.previousEaten == 1)
        #expect(week.removed == 1)
        #expect(week.days.map(\.eaten) == [1, 0, 0, 0, 0, 0, 0])
    }

    /// 같은 절대 시각이라도 캘린더의 타임존이 다르면 다른 창에 앉는다 — 이번 주 칸과 같은 규약이
    /// 지난 주 경계에도 걸린다. 서울 일요일 00:30은 UTC로는 아직 토요일이라 **지난 주**다.
    @Test func previousWeekBoundaryFollowsCalendarTimeZone() {
        let seoul = calendar()
        var utc = calendar()
        utc.timeZone = TimeZone(identifier: "UTC")!
        let instant = date(seoul, 2026, 8, 16, 0, 30)            // 서울 일요일 00:30 = UTC 토요일 15:30
        let now = date(seoul, 2026, 8, 19)

        let inSeoul = ConsumptionWeek.summary(of: [log(instant, wasted: false)], calendar: seoul, now: now)
        let inUTC = ConsumptionWeek.summary(of: [log(instant, wasted: false)], calendar: utc, now: now)
        #expect(inSeoul.removed == 1 && inSeoul.previousRemoved == 0)
        #expect(inUTC.removed == 0 && inUTC.previousRemoved == 1)
    }

    // MARK: 추세 — 지난 주와의 비교

    /// 이번 주가 더 많이 먹었으면 `.better`, 덜 먹었으면 `.worse`. 축은 낭비율과 같은 방향이다.
    @Test func trendComparesThisWeekAgainstLastWeek() {
        let cal = calendar()
        let now = date(cal, 2026, 8, 19)
        // 지난 주 2/4 = 50%, 이번 주 3/3 = 100%.
        let better = [
            log(date(cal, 2026, 8, 10), wasted: false), log(date(cal, 2026, 8, 11), wasted: false),
            log(date(cal, 2026, 8, 12), wasted: true), log(date(cal, 2026, 8, 13), wasted: true),
            log(date(cal, 2026, 8, 17), wasted: false), log(date(cal, 2026, 8, 18), wasted: false),
            log(date(cal, 2026, 8, 19), wasted: false),
        ]
        let up = ConsumptionWeek.summary(of: better, calendar: cal, now: now)
        #expect(up.eatenRate == 100 && up.previousEatenRate == 50)
        #expect(up.trend == .better)

        // 같은 픽스처의 판정을 뒤집으면 방향도 뒤집힌다(같은 두 창, 반대 결과).
        let worse = better.map { log($0.removedAt, wasted: !$0.wasted) }
        let down = ConsumptionWeek.summary(of: worse, calendar: cal, now: now)
        #expect(down.eatenRate == 0 && down.previousEatenRate == 50)
        #expect(down.trend == .worse)
    }

    /// `sameBand`(3%p) 안쪽은 `.same`이다. 4/5 = 80%와 7/9 = 78%는 2%p 차라 "비슷한 주"다 —
    /// 정수 반올림만으로도 최대 1%p가 흔들리는 값이라, 이 폭 안의 차이는 판정이 아니라 잡음이다.
    @Test func trendTreatsSmallGapsAsTheSameWeek() {
        let cal = calendar()
        let now = date(cal, 2026, 8, 22)                          // 토요일 — 이번 주 7칸이 다 지났다
        var logs: [RemovalLog] = []
        // 지난 주(8/9~8/15): 9건 중 7건 먹음 = 78%
        for i in 0..<9 { logs.append(log(date(cal, 2026, 8, 9 + i % 7, 10 + i), wasted: i >= 7)) }
        // 이번 주(8/16~8/22): 5건 중 4건 먹음 = 80%
        for i in 0..<5 { logs.append(log(date(cal, 2026, 8, 16 + i), wasted: i >= 4)) }
        let week = ConsumptionWeek.summary(of: logs, calendar: cal, now: now)

        #expect(week.previousEatenRate == 78)
        #expect(week.eatenRate == 80)
        #expect(week.trend == .same)
    }

    /// **폭 3%p의 근거를 그대로 잠근다**: 주당 처리 25건이면 항목 하나의 판정이 비율을 4%p 움직여
    /// 폭 밖으로 나간다 — 즉 `.same`은 "한 항목도 달라지지 않은 주"만 묶는다.
    /// 경계 자체(정확히 3%p)는 안쪽이다.
    @Test func sameBandIsNarrowerThanOneItemAtWeeklyVolume() {
        #expect(ConsumptionWeek.sameBand == 3)
        // 100% vs 96%(25건 중 24건) — 한 항목 차이는 `.same`이 아니다.
        #expect(trend(this: (25, 25), previous: (24, 25)) == .better)
        // 정확히 3%p 차이는 폭 안쪽(경계 포함).
        #expect(trend(this: (100, 100), previous: (97, 100)) == .same)
        #expect(trend(this: (97, 100), previous: (100, 100)) == .same)
        // 4%p부터 방향이 선다.
        #expect(trend(this: (100, 100), previous: (96, 100)) == .better)
        #expect(trend(this: (96, 100), previous: (100, 100)) == .worse)
    }

    /// 비교할 주가 없으면 문장 자체가 서지 않는다 — 없는 지난 주를 지어내지 않는다.
    @Test func trendIsAbsentWhenEitherWindowIsEmpty() {
        let cal = calendar()
        let now = date(cal, 2026, 8, 19)
        let onlyThisWeek = ConsumptionWeek.summary(of: [log(date(cal, 2026, 8, 17), wasted: false)],
                                                   calendar: cal, now: now)
        #expect(onlyThisWeek.eatenRate == 100)
        #expect(onlyThisWeek.previousEatenRate == nil)
        #expect(onlyThisWeek.trend == nil)

        let onlyLastWeek = ConsumptionWeek.summary(of: [log(date(cal, 2026, 8, 11), wasted: false)],
                                                   calendar: cal, now: now)
        #expect(onlyLastWeek.eatenRate == nil)
        #expect(onlyLastWeek.previousEatenRate == 100)
        #expect(onlyLastWeek.trend == nil)

        #expect(ConsumptionWeek.summary(of: [], calendar: cal, now: now).trend == nil)
    }

    /// 두 창의 (먹음, 처리) 쌍만으로 추세를 뽑는 헬퍼 — 날짜 픽스처 없이 임계값만 보는 케이스용.
    private func trend(this: (Int, Int), previous: (Int, Int)) -> ConsumptionWeek.Trend? {
        ConsumptionWeek.Summary(days: [], eaten: this.0, removed: this.1,
                                previousEaten: previous.0, previousRemoved: previous.1).trend
    }
}
