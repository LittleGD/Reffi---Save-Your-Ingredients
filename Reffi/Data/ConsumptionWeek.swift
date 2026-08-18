import Foundation

/// 이번 주 소비 집계 — History 히어로(고리 + 요일 블롭)가 읽는 **유일한** 규칙.
///
/// 뷰가 이력을 직접 훑으면 고리의 분모와 요일 칸의 숫자가 조용히 갈린다(옛 도넛이 링과 가운데 숫자에
/// 서로 다른 분모를 놓았던 그 사고다, §13.9). 두 값을 **한 번의 순회**에서 함께 내고, 요일 칸의 합이
/// 곧 고리의 분자가 되게 묶는다 — 화면에서 눈으로 검산할 수 있다.
///
/// 창(window)은 **이번 주**다. 정산서의 30일이 아니라 이번 주인 이유: 바로 아래 요일 행이 이번 주
/// 7일이라, 고리만 30일이면 한 블록 안에서 두 개의 다른 책을 읽게 된다. 30일 수치는 그대로 아래
/// 정산서가 자기 라벨("Tally · past 30 days")과 함께 말한다.
///
/// 시간 계산은 전부 `Calendar`를 지난다 — 초 나눗셈(86400)은 서머타임이 낀 주에서 하루를 밀어낸다.
enum ConsumptionWeek {

    /// 요일 한 칸.
    struct Day: Identifiable, Equatable {
        /// 그날 자정(로컬 캘린더 기준).
        let start: Date
        /// `Calendar`의 요일 번호(1 = 일요일) — 표시 심볼·접근성 이름을 뽑는 키.
        let weekday: Int
        /// 그날 **먹은**(wasted == false) 항목 수. 발주로 소비된 줄(`via != nil`)도 먹은 것이다.
        let eaten: Int
        let isToday: Bool
        /// 오늘 이후 — 아직 오지 않은 날. 0이 아니라 **비어 있어야** 한다(0은 "안 먹었다"는 판정이다).
        let isFuture: Bool

        var id: Date { start }
    }

    /// 히어로가 한 번에 읽는 값.
    struct Summary: Equatable {
        /// 주 시작일부터 7칸(항상 7개).
        var days: [Day]
        /// 이번 주 먹은 수 = `days`의 `eaten` 합.
        var eaten: Int
        /// 이번 주 처리한 전체(먹음 + 버림) = 비율의 분모.
        var removed: Int

        /// 처리한 것 중 **안 버린** 비율(%). 처리가 0건이면 `nil`이다 —
        /// 0/0을 0%로 내면 "이번 주에 다 버렸다"는 없는 판정이 화면에 뜬다(NaN도 마찬가지).
        var eatenRate: Int? {
            guard removed > 0 else { return nil }
            return Int((Double(eaten) / Double(removed) * 100).rounded())
        }

        /// 같은 창의 낭비율(%) — `HistoryContent.rateColor`가 기대하는 축이다.
        /// 고리는 "먹은 비율"을 보여 주지만 **색은 낭비율의 색**이라야 앱 전체에서 뜻이 하나로 남는다
        /// (초록 = 덜 버렸다). 여기서 뒤집지 않으면 링이 조용히 반대 색을 입는다.
        var wasteRate: Int? { eatenRate.map { 100 - $0 } }
    }

    /// 이번 주의 첫날 자정 — `Calendar.firstWeekday` 기준으로 **오늘 이전(포함) 가장 가까운 주 시작일**.
    ///
    /// `dateInterval(of: .weekOfYear:)`를 쓰지 않는 이유: 그쪽은 `minimumDaysInFirstWeek`가 걸려
    /// 연말·연초에 "이번 주"가 한 주 밀리는 로케일이 있다. 히어로가 말하는 이번 주는 달력의 주차가
    /// 아니라 **지난 주 시작일부터 오늘까지**라, 요일 오프셋으로 직접 되짚는 쪽이 정의와 일치한다.
    static func weekStart(calendar: Calendar = .current, now: Date = Date()) -> Date {
        let today = calendar.startOfDay(for: now)
        let offset = (calendar.component(.weekday, from: today) - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -offset, to: today) ?? today
    }

    /// 이번 주 집계 — 로그 순서·중복에 무관하고, 창 밖 로그는 세지 않는다.
    static func summary(of logs: [RemovalLog],
                        calendar: Calendar = .current,
                        now: Date = Date()) -> Summary {
        let start = weekStart(calendar: calendar, now: now)
        let today = calendar.startOfDay(for: now)
        // 8칸(0...7)을 미리 만든다 — 마지막은 창의 열린 끝(다음 주 시작 자정)이다.
        // 로그마다 `date(byAdding:)`를 부르면 이력이 길어질수록 달력 연산이 그만큼 늘어난다.
        var bounds: [Date] = []
        bounds.reserveCapacity(8)
        for i in 0...7 { bounds.append(calendar.date(byAdding: .day, value: i, to: start) ?? start) }
        let end = bounds[7]

        var eatenPerDay = [Int](repeating: 0, count: 7)
        var eaten = 0
        var removed = 0
        for log in logs {
            guard log.removedAt >= start, log.removedAt < end else { continue }
            // 칸 배정도 달력이 한다(위 주석과 같은 이유).
            guard let index = calendar.dateComponents([.day],
                                                      from: start,
                                                      to: calendar.startOfDay(for: log.removedAt)).day,
                  (0..<7).contains(index) else { continue }
            removed += 1
            if !log.wasted {
                eatenPerDay[index] += 1
                eaten += 1
            }
        }

        let days = (0..<7).map { i in
            Day(start: bounds[i],
                weekday: calendar.component(.weekday, from: bounds[i]),
                eaten: eatenPerDay[i],
                isToday: bounds[i] == today,
                isFuture: bounds[i] > today)
        }
        return Summary(days: days, eaten: eaten, removed: removed)
    }

    // MARK: 요일 이름 — 로케일이 정한다(표시와 접근성이 같은 곳에서 나와야 한 칸이 두 이름을 갖지 않는다)

    /// 칸 머리글자(en "M" · ko "월") — 화면에 찍히는 짧은 이름.
    static func initial(of day: Day, calendar: Calendar = .current) -> String {
        symbol(day, calendar.veryShortStandaloneWeekdaySymbols)
    }

    /// 요일 전체 이름(en "Monday" · ko "월요일") — 접근성 라벨용.
    static func name(of day: Day, calendar: Calendar = .current) -> String {
        symbol(day, calendar.standaloneWeekdaySymbols)
    }

    private static func symbol(_ day: Day, _ symbols: [String]) -> String {
        guard !symbols.isEmpty else { return "" }
        return symbols[((day.weekday - 1) % symbols.count + symbols.count) % symbols.count]
    }
}
