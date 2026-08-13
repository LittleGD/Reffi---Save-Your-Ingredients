import CoreHaptics
import UIKit

/// 충돌 쌍 식별자 — 같은 두 물체가 비비며 매 프레임 접촉을 올릴 때 햅틱을 도배하지 않게 쿨다운 키로 쓴다.
/// 물리 객체가 아니라 `Int` 두 개로 두어 스로틀 로직만 따로 단위 테스트할 수 있다.
struct ClatterPair: Hashable {
    let a: Int
    let b: Int
    /// 순서 무관 — (칩A, 칩B)와 (칩B, 칩A)는 같은 쌍이다.
    init(_ x: Int, _ y: Int) {
        a = min(x, y)
        b = max(x, y)
    }
}

/// 충돌 → 햅틱 발화 스로틀. **이 기능의 품질은 사실상 전부 필터링에서 갈린다** — 정지한 더미에서
/// 미세 접촉마다 진동이 울리면(웅웅) 즉시 싸구려로 느껴지므로, 세 관문을 모두 통과한 충돌만 발화한다.
///   ① 임펄스 임계값 — 안착 중 맞닿음·스치는 접촉 걸러내기
///   ② 전역 최소 간격 — 액추에이터가 못 따라가 뭉개지는 것 방지
///   ③ 같은 쌍 쿨다운 — 두 재료가 비빌 때의 연타 방지
/// 순수 로직이라 씬 없이 테스트된다(`ClatterThrottleTests`).
struct ClatterThrottle {
    /// 이 미만은 무시. 안착 직전의 잔여 접촉 임펄스가 대략 이 아래에 깔린다.
    var minImpulse: CGFloat = 6
    /// 전역 최소 간격(초). 22Hz 상한 — 이보다 촘촘하면 개별 '달그락'이 뭉개져 연속 진동으로 들린다.
    var minInterval: TimeInterval = 0.045
    /// 같은 쌍이 다시 울릴 수 있기까지의 시간(초).
    var pairCooldown: TimeInterval = 0.14
    /// 쿨다운 테이블 상한 — 오래된 항목을 걷어내 무한 성장 방지.
    var maxPairs = 64

    private var lastFire: TimeInterval?
    private var pairLast: [ClatterPair: TimeInterval] = [:]

    /// 이 충돌이 햅틱을 낼 자격이 있나. 통과하면 내부 상태를 갱신한다(같은 now로 두 번 통과 못 함).
    mutating func allow(impulse: CGFloat, pair: ClatterPair, now: TimeInterval) -> Bool {
        guard impulse >= minImpulse else { return false }
        if let last = lastFire, now - last < minInterval { return false }
        if let last = pairLast[pair], now - last < pairCooldown { return false }
        lastFire = now
        pairLast[pair] = now
        if pairLast.count > maxPairs {
            pairLast = pairLast.filter { now - $0.value < pairCooldown }
        }
        return true
    }

    /// 재료가 갈렸거나 씬이 다시 살아날 때 — 묵은 쿨다운을 버린다.
    mutating func reset() {
        lastFire = nil
        pairLast.removeAll()
    }
}

/// 달그락 햅틱 재생기 — **충돌 이벤트마다** transient 햅틱을 하나씩 친다.
///
/// 이 앱의 기존 햅틱은 전부 SwiftUI `.sensoryFeedback`(§7.6 의미별 매핑)인데, 여기선 쓸 수 없다.
///   ① 세기·날카로움 파라미터가 없어 **재료별 촉감**을 만들 수 없다.
///   ② trigger 값 변경 구동이라 초당 20회 발화하면 그만큼 SwiftUI가 뷰를 다시 그린다(물리 필드까지).
/// 그래서 이 촉감 계열만 CoreHaptics를 직접 쓴다. §7.6의 **의미별 매핑은 그대로 두고**(판정·성공·파괴),
/// 물리 질감이라는 새 계열을 옆에 추가하는 것이다 — 기존 호출부는 하나도 건드리지 않았다.
///
/// 햅틱 하드웨어가 없는 환경(시뮬레이터 등)에선 엔진을 아예 만들지 않고 조용히 무시한다.
final class IngredientClatterHaptics {
    private var engine: CHHapticEngine?
    private var running = false
    private var failed = false   // 한 번 실패하면 재시도·로그를 반복하지 않는다(콘솔 폭주 방지)

    /// 기기에 햅틱 액추에이터가 있나. 시뮬레이터·비지원 기기는 false.
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    /// 엔진 기동. 씬이 활성일 때만 부른다(엔진은 켜져 있는 동안 전력을 쓴다).
    func start() {
        guard supportsHaptics, !failed, !running else { return }
        do {
            let e = try engine ?? CHHapticEngine()
            e.playsHapticsOnly = true
            e.isAutoShutdownEnabled = true          // 유휴 시 시스템이 알아서 내린다
            // 인터럽션(전화·시스템) 후 자동 복구 — 없으면 한 번 끊기고 영영 무음이 된다.
            // 두 핸들러는 **CoreHaptics 내부 큐**에서 불린다. `running`·엔진 수명주기는 그 밖에서
            // 전부 메인 스레드(start/stop/play)가 만지므로, 여기서 바로 건드리면 동기화 없는
            // 교차 스레드 변이가 된다(백그라운드 진입 = stoppedHandler와 stop()이 정면 충돌).
            // 메인 큐로 넘겨 모든 상태 전이가 한 스레드에서 직렬화되게 한다.
            e.resetHandler = { [weak self] in
                DispatchQueue.main.async {
                    guard let self, self.running else { return }
                    try? self.engine?.start()
                }
            }
            e.stoppedHandler = { [weak self] _ in
                DispatchQueue.main.async { self?.running = false }
            }
            try e.start()
            engine = e
            running = true
        } catch {
            failed = true   // 조용히 포기 — 달그락은 부가 연출이라 없다고 기능이 깨지지 않는다
        }
    }

    /// 정지 — 탭을 벗어나거나 백그라운드로 갈 때.
    func stop() {
        guard running else { return }
        running = false
        engine?.stop()
    }

    /// 충돌 하나의 촉감을 친다. `intensity`·`sharpness`는 0...1.
    /// sharpness가 클수록 쨍한 '클링', 작을수록 둔탁한 '툭'.
    func play(intensity: Float, sharpness: Float) {
        guard supportsHaptics, !failed, let engine else { return }
        // 유휴 자동 종료(.idleTimeout) 뒤엔 stoppedHandler가 running을 내린다. 여기서 재기동하지
        // 않으면 첫 정적 이후 세션 내내 무음이 된다 — stop()으로 내려간 경우엔 didBegin 자체가
        // 게이트(씬 pause)로 막히므로 이 지연 재기동이 의도치 않게 켜질 일은 없다.
        if !running {
            do { try engine.start(); running = true } catch { return }
        }
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: max(0, min(1, intensity))),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: max(0, min(1, sharpness))),
        ], relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            // 개별 재생 실패는 무시 — 여기서 로그를 찍으면 충돌마다 콘솔이 폭주한다.
        }
    }

    deinit { engine?.stop() }
}
