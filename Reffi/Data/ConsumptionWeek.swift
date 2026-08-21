import Foundation

/// 이번 주 소비 집계 — History 히어로(숫자 헤드라인 + 추세 문장 + 종이 칩 일곱)가 읽는 **유일한** 규칙.
///
/// 뷰가 이력을 직접 훑으면 헤드라인의 분모와 칩의 숫자가 조용히 갈린다(옛 도넛이 링과 가운데 숫자에
/// 서로 다른 분모를 놓았던 그 사고다, §13.9). 값을 **한 번의 순회**에서 함께 내고, 칩 일곱의 합이
/// 곧 헤드라인의 분자가 되게 묶는다 — 화면에서 눈으로 검산할 수 있다.
///
/// 창(window)은 **이번 주**다. 정산서의 30일이 아니라 이번 주인 이유: 바로 아래 칩 행이 이번 주
/// 7일이라, 헤드라인만 30일이면 한 블록 안에서 두 개의 다른 책을 읽게 된다. 30일 수치는 그대로 아래
/// 정산서가 자기 라벨("Tally · past 30 days")과 함께 말한다.
///
/// **지난 주도 같은 순회에서 센다**(추세 문장용). 문장 하나를 위해 이력을 두 번 훑으면 두 창이
/// 자정을 사이에 두고 서로 다른 주를 가리킬 수 있다 — 한 스냅샷이라야 헤드라인과 문장이 어긋나지 않는다.
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
        /// 그날 **버린**(wasted == true) 항목 수 — 칩 모서리의 빨간 조각이 읽는 값.
        /// 먹은 수와 **다른 채널**이라 한 칸이 둘을 동시에 말할 수 있다(하루에 먹고 버린 주가 흔하다).
        let tossed: Int
        let isToday: Bool
        /// 오늘 이후 — 아직 오지 않은 날. 0이 아니라 **비어 있어야** 한다(0은 "안 먹었다"는 판정이다).
        let isFuture: Bool

        var id: Date { start }
    }

    /// 추세 — 이번 주 먹은 비율을 **지난 주** 같은 비율과 견준 결과.
    enum Trend: Equatable {
        /// 이번 주가 더 많이 먹었다(= 덜 버렸다).
        case better
        case worse
        /// 두 주가 `sameBand` 안에 있다 — 판정이 달라진 게 아니라 반올림·분모 차이다.
        case same
    }

    /// "지난 주와 비슷하다"로 묶는 폭(%p).
    ///
    /// **3인 근거는 한 항목의 무게다.** 화면에 서는 값은 정수로 반올림된 비율이라 양쪽 반올림만으로도
    /// 최대 1%p의 가짜 차이가 생긴다. 그 위로, 한 주의 처리 건수가 25건 이하면 항목 하나의 판정이
    /// 바뀔 때 비율이 최소 `100/25 = 4%p` 움직인다 — 즉 **3%p 안쪽은 실제로 판정이 달라진 주가 아니다**.
    /// (샘플·실사용 모두 주당 처리는 한 자릿수라 25는 현실 범위를 크게 웃도는 상한이다.)
    /// 더 좁히면 반올림 노이즈가 "나아졌다/나빠졌다"로 읽히고, 더 넓히면 진짜 한 항목의 변화가 묻힌다.
    static let sameBand = 3

    /// 히어로가 한 번에 읽는 값.
    struct Summary: Equatable {
        /// 주 시작일부터 7칸(항상 7개).
        var days: [Day]
        /// 이번 주 먹은 수 = `days`의 `eaten` 합.
        var eaten: Int
        /// 이번 주 처리한 전체(먹음 + 버림) = 비율의 분모.
        var removed: Int
        /// 지난 주(이번 주 시작 **직전** 7일) 먹은 수 — 추세 문장 전용이라 요일 칸은 만들지 않는다.
        var previousEaten: Int
        /// 지난 주 처리한 전체 = 지난 주 비율의 분모.
        var previousRemoved: Int

        /// 처리한 것 중 **안 버린** 비율(%). 처리가 0건이면 `nil`이다 —
        /// 0/0을 0%로 내면 "이번 주에 다 버렸다"는 없는 판정이 화면에 뜬다(NaN도 마찬가지).
        var eatenRate: Int? {
            guard removed > 0 else { return nil }
            return Int((Double(eaten) / Double(removed) * 100).rounded())
        }

        /// 지난 주 같은 비율 — 같은 규칙, 같은 반올림.
        var previousEatenRate: Int? {
            guard previousRemoved > 0 else { return nil }
            return Int((Double(previousEaten) / Double(previousRemoved) * 100).rounded())
        }

        /// 같은 창의 낭비율(%) — `HistoryContent.rateColor`가 기대하는 축이다.
        /// 헤드라인은 "먹은 비율"을 보여 주지만 **색은 낭비율의 색**이라야 앱 전체에서 뜻이 하나로 남는다
        /// (초록 = 덜 버렸다). 여기서 뒤집지 않으면 잘한 주가 반대 색을 입는다.
        var wasteRate: Int? { eatenRate.map { 100 - $0 } }

        /// 추세 — **두 창 중 하나라도 비면 `nil`**이다.
        /// 비교할 것이 없는데 "비슷해요"라고 말하면 없는 지난 주를 지어내는 셈이 된다.
        var trend: Trend? {
            guard let now = eatenRate, let before = previousEatenRate else { return nil }
            let diff = now - before
            if diff > ConsumptionWeek.sameBand { return .better }
            if diff < -ConsumptionWeek.sameBand { return .worse }
            return .same
        }
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

    /// 지난 주의 첫날 자정 — 이번 주 시작에서 **정확히 7일 전**(달력 연산).
    ///
    /// 달력 주차(`weekOfYear`)로 되짚지 않는 이유는 `weekStart`와 같다 — 연말·연초에 한 주가 밀리는
    /// 로케일이 있고, 여기서 말하는 지난 주는 "이번 주 바로 앞의 7일"이라 정의가 그쪽이 아니다.
    /// 그 정의라야 12월 말 → 1월 초처럼 해가 바뀌는 경계에서도 창이 붙어서 이어진다.
    static func previousWeekStart(calendar: Calendar = .current, now: Date = Date()) -> Date {
        let start = weekStart(calendar: calendar, now: now)
        return calendar.date(byAdding: .day, value: -7, to: start) ?? start
    }

    /// 이번 주 집계(+ 추세용 지난 주 두 값) — 로그 순서·중복에 무관하고, 두 창 밖 로그는 세지 않는다.
    static func summary(of logs: [RemovalLog],
                        calendar: Calendar = .current,
                        now: Date = Date()) -> Summary {
        let start = weekStart(calendar: calendar, now: now)
        let today = calendar.startOfDay(for: now)
        // 15칸(-7...7)을 미리 만든다 — [0] = 지난 주 시작(`previousWeekStart`와 같은 식),
        // [7] = 이번 주 시작, [14] = 창의 열린 끝(다음 주 시작 자정).
        // 로그마다 `date(byAdding:)`를 부르면 이력이 길어질수록 달력 연산이 그만큼 늘어난다.
        var bounds: [Date] = []
        bounds.reserveCapacity(15)
        for i in -7...7 { bounds.append(calendar.date(byAdding: .day, value: i, to: start) ?? start) }
        let previousStart = bounds[0]
        let end = bounds[14]

        var eatenPerDay = [Int](repeating: 0, count: 7)
        var tossedPerDay = [Int](repeating: 0, count: 7)
        var eaten = 0
        var removed = 0
        var previousEaten = 0
        var previousRemoved = 0
        for log in logs {
            guard log.removedAt >= previousStart, log.removedAt < end else { continue }
            // 지난 주는 총계 둘만 쓴다 — 칸을 만들지 않으므로 달력 연산도 돌리지 않는다.
            if log.removedAt < start {
                previousRemoved += 1
                if !log.wasted { previousEaten += 1 }
                continue
            }
            // 칸 배정도 달력이 한다(위 주석과 같은 이유).
            guard let index = calendar.dateComponents([.day],
                                                      from: start,
                                                      to: calendar.startOfDay(for: log.removedAt)).day,
                  (0..<7).contains(index) else { continue }
            removed += 1
            if log.wasted {
                tossedPerDay[index] += 1
            } else {
                eatenPerDay[index] += 1
                eaten += 1
            }
        }

        let days = (0..<7).map { i in
            Day(start: bounds[7 + i],
                weekday: calendar.component(.weekday, from: bounds[7 + i]),
                eaten: eatenPerDay[i],
                tossed: tossedPerDay[i],
                isToday: bounds[7 + i] == today,
                isFuture: bounds[7 + i] > today)
        }
        return Summary(days: days, eaten: eaten, removed: removed,
                       previousEaten: previousEaten, previousRemoved: previousRemoved)
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
