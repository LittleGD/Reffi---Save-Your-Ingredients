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
    /// 이 미만은 무시. 실기기 검증(v1.0 (2)): 6으로는 구르는 중의 잔접촉 대부분이 통과해
    /// "움직이기 시작하면 그냥 일정한 진동"이 됐다 — 촉감은 **또렷한 부딪힘**에만 실려야 하므로
    /// 하한을 확실한 노크 수준으로 올린다. 세기 곡선(`ClatterFeelRule.minImpulse`)도 이 값에서 시작한다.
    var minImpulse: CGFloat = 20
    /// 전역 최소 간격의 **중심값**(초). 11Hz 근처 — 22Hz는 개별 '달그락'이 뭉개져 캐리어 진동처럼
    /// 들렸다(실기기). 달그락은 리듬이 들려야 달그락이다.
    var minInterval: TimeInterval = 0.09
    /// 간격 지터 폭(초, ±). 실기기 3차 피드백 "햅틱이 고정된 느낌"의 절반은 여기 있었다 —
    /// 간격이 **정확히** 90ms면 격렬하게 흔드는 동안 발화가 11Hz 격자에 딱 맞아 떨어져,
    /// 손은 개별 충돌이 아니라 **기계적 클럭**을 읽는다(닌텐도 HD 진동의 반대). 발화 순번에서
    /// 뽑은 결정적 지터로 70~110ms를 오가게 해 격자를 깬다 — 난수가 아니므로 같은 충돌
    /// 시퀀스는 실행마다 같은 리듬이다(QA 재현성 유지).
    var intervalJitter: TimeInterval = 0.02
    /// 같은 쌍이 다시 울릴 수 있기까지의 시간(초) — 두 재료가 비빌 때의 연타 방지.
    var pairCooldown: TimeInterval = 0.26
    /// 쿨다운 테이블 상한 — 오래된 항목을 걷어내 무한 성장 방지.
    var maxPairs = 64

    /// 지금까지 통과시킨 발화 수. 지터 시드이자 **촉감 변주 시드**다 — 씬은 이 값을
    /// `ClatterFeelRule`에 넘겨 충돌마다 미세하게 다른 촉감을 만든다. 같은 충돌 시퀀스면
    /// 같은 순번이 나오므로 실행 간 재현성이 유지된다.
    private(set) var fireCount: UInt64 = 0

    private var lastFire: TimeInterval?
    private var pairLast: [ClatterPair: TimeInterval] = [:]

    /// n번째 발화가 요구하는 전역 간격 — 중심 ± 지터. 순수 함수라 경계를 테스트로 못박는다.
    static func gateInterval(center: TimeInterval, jitter: TimeInterval, sequence: UInt64) -> TimeInterval {
        guard jitter > 0 else { return center }
        return center + ReffiHash.signed("clatter-gap-\(sequence)") * jitter
    }

    /// 이 충돌이 햅틱을 낼 자격이 있나. 통과하면 내부 상태를 갱신한다(같은 now로 두 번 통과 못 함).
    mutating func allow(impulse: CGFloat, pair: ClatterPair, now: TimeInterval) -> Bool {
        guard impulse >= minImpulse else { return false }
        let gate = Self.gateInterval(center: minInterval, jitter: intervalJitter, sequence: fireCount)
        if let last = lastFire, now - last < gate { return false }
        if let last = pairLast[pair], now - last < pairCooldown { return false }
        lastFire = now
        pairLast[pair] = now
        fireCount &+= 1
        if pairLast.count > maxPairs {
            pairLast = pairLast.filter { now - $0.value < pairCooldown }
        }
        return true
    }

    /// 재료가 갈렸거나 씬이 다시 살아날 때 — 묵은 쿨다운을 버린다.
    /// `fireCount`는 **리셋하지 않는다**: 리듬·촉감 변주의 순번일 뿐이고, 0으로 되돌리면
    /// 탭을 오갈 때마다 같은 지터 패턴이 처음부터 반복돼 규칙성이 되살아난다.
    mutating func reset() {
        lastFire = nil
        pairLast.removeAll()
    }
}

/// 충돌 하나가 손끝에 만들 촉감 — CoreHaptics 이벤트로 굳기 **직전**의 순수 값.
/// 엔진과 분리해 둬야 변조 규칙을 시뮬레이터에서도 단위 테스트할 수 있다(햅틱은 실기기 전용).
struct ClatterFeel: Equatable {
    /// transient 세기 0...1 — '툭'의 크기.
    var intensity: Float
    /// transient 날카로움 0...1 — 1이면 쨍한 '클링', 0이면 뭉툭한 '퍽'.
    var sharpness: Float
    /// 감쇠 꼬리 — **큰 충돌에만** 붙는다. nil이면 transient 한 방으로 끝.
    var tail: Tail?

    /// '툭' 뒤에 남는 짧은 잔향. intensity는 시작값이고 파라미터 커브가 0까지 끌어내린다.
    struct Tail: Equatable {
        var duration: TimeInterval
        var intensity: Float
        var sharpness: Float
    }
}

/// 촉감 계산이 재료에서 필요로 하는 두 축만 뽑은 입력 — 씬의 물성 클래스(`ChipMaterial`)에서 넘어온다.
/// 물성 전체를 넘기지 않는 건 물리 축(마찰·각감쇠·반발)이 촉감 규칙에 새어 들지 않게 하기 위해서다.
struct ClatterMaterial: Equatable {
    /// 재료 기준 날카로움 — 임펄스 변조의 **중심**이 된다.
    var sharpness: Float
    /// 세기 배율 — 여린 재료(잎·두부)는 같은 임펄스라도 약하게 친다.
    var scale: Float

    static let neutral = ClatterMaterial(sharpness: 0.5, scale: 0.8)
}

/// 임펄스 + 재료 → 촉감. **순수 계산기**다(`GravityMapper`·셰이크 킥과 같은 규율).
///
/// v1.0 (5)까지는 모든 충돌이 *같은 파형의* transient 단발이었다 — 세기만 변하고 날카로움은
/// 재료별 상수, 리듬은 11Hz 격자. 손은 그걸 "잘 만든 진동 하나를 반복 재생하는 것"으로 읽고,
/// 실기기 3차 피드백이 "딱딱하고 인위적·고정된 느낌"이라고 불렀다. HD 진동의 자연스러움은 세 겹이다:
///   ① **연속 변조** — 세기뿐 아니라 날카로움도 충돌 세기를 따라 움직인다(세게 치면 더 쨍하다).
///   ② **감쇠 꼬리** — 큰 충돌엔 '툭' 뒤에 40~70ms 잔향이 남았다가 0으로 죽는다.
///   ③ **비반복성** — 같은 세기의 두 충돌도 완전히 같지는 않다(±8% 미세 변주).
/// ③은 `Double.random`이 아니라 발화 순번 해시로 만든다 — 같은 충돌 시퀀스는 같은 촉감이어야
/// 튜닝을 비교할 수 있고, 스크린샷·계측 QA가 실행마다 흔들리지 않는다.
struct ClatterFeelRule {
    /// 세기 곡선의 시작점 — 스로틀의 임펄스 관문과 **같은 값이어야** 한다(테스트로 못박음).
    var minImpulse: CGFloat = 20
    /// 이 임펄스면 최대 세기 — 위는 전부 포화.
    var ceilingImpulse: CGFloat = 90
    /// 최소 세기. 0.18 → 0.10으로 낮췄다 — 바닥이 높으면 약한 충돌과 강한 충돌의 차이가
    /// 손에 5:1이 아니라 2:1로 도착해 "전부 같은 세기"로 뭉개진다. 다이내믹 레인지가
    /// 자연스러움의 8할이다. 0으로 두지 않는 건 통과한 충돌은 느껴져야 하기 때문(헛발질 금지).
    var intensityFloor: Float = 0.10
    /// 날카로움의 임펄스 변조 폭(±). 재료 기준값에서 약한 충돌은 −0.12, 최대 충돌은 +0.12.
    /// 재료 성격(두부는 뭉툭·캔은 쨍)은 유지한 채 "세게 부딪히면 더 쨍하다"만 얹는다.
    var sharpnessSwing: Float = 0.12
    /// 결정적 미세 변주 폭(±, 비율). 세기·날카로움에 각각 독립으로 걸어 두 축이 나란히 움직이지 않게 한다.
    var variation: Float = 0.08
    /// 꼬리가 붙기 시작하는 정규화 세기 — 상위 1/3만. 모든 충돌에 꼬리를 붙이면
    /// 잔향이 겹쳐 결국 '웅웅'으로 되돌아간다(이 기능이 처음 고치려던 실패 모드).
    var tailOnset: Float = 0.67
    /// 꼬리 길이 범위(초) — 임계에서 40ms, 최대 충돌에서 70ms.
    var tailShortest: TimeInterval = 0.040
    var tailLongest: TimeInterval = 0.070
    /// 꼬리 시작 세기 = 본 타격의 이 비율. 꼬리가 타격만큼 세면 두 번 친 것으로 들린다.
    var tailLevel: Float = 0.42
    /// 꼬리는 본 타격보다 이만큼 뭉툭하다 — 잔향은 고주파가 먼저 죽는다.
    var tailDull: Float = 0.28

    /// 임펄스 → 0...1. 관문 아래는 0, 상한 위는 1.
    func normalized(_ impulse: CGFloat) -> Float {
        let span = ceilingImpulse - minImpulse
        guard span > 0 else { return 1 }
        return Float(min(1, max(0, (impulse - minImpulse) / span)))
    }

    /// 충돌 하나의 촉감. `sequence`는 스로틀의 발화 순번(`ClatterThrottle.fireCount`).
    func feel(impulse: CGFloat, material: ClatterMaterial, sequence: UInt64) -> ClatterFeel {
        let t = normalized(impulse)
        let vi = 1 + Float(ReffiHash.signed("clatter-i-\(sequence)")) * variation
        let vs = 1 + Float(ReffiHash.signed("clatter-s-\(sequence)")) * variation
        let intensity = Self.clamp01((intensityFloor + t * (1 - intensityFloor)) * material.scale * vi)
        let sharpness = Self.clamp01((material.sharpness + sharpnessSwing * (2 * t - 1)) * vs)
        var tail: ClatterFeel.Tail?
        if t >= tailOnset {
            let u = tailOnset < 1 ? TimeInterval((t - tailOnset) / (1 - tailOnset)) : 1
            tail = ClatterFeel.Tail(duration: tailShortest + u * (tailLongest - tailShortest),
                                    intensity: Self.clamp01(intensity * tailLevel),
                                    sharpness: Self.clamp01(sharpness - tailDull))
        }
        return ClatterFeel(intensity: intensity, sharpness: sharpness, tail: tail)
    }

    private static func clamp01(_ v: Float) -> Float { min(1, max(0, v)) }
}

/// 달그락 햅틱 재생기 — 충돌 이벤트 하나를 `ClatterFeel`이 시킨 대로 친다
/// (transient 한 방, 큰 충돌이면 그 뒤에 감쇠 꼬리 하나를 **같은 패턴**에 붙여서).
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

    /// 꼬리가 transient보다 이만큼(초) 늦게 시작한다. 0으로 붙이면 두 이벤트가 겹쳐 타격이
    /// 뭉툭해진다 — 한 프레임 남짓 띄워야 '툭 → 잔향' 순서로 읽힌다.
    private static let tailLead: TimeInterval = 0.012

    /// 충돌 하나의 촉감을 친다. 세기·날카로움·꼬리는 전부 순수 계산기(`ClatterFeelRule`)가 정한다.
    func play(_ feel: ClatterFeel) {
        guard supportsHaptics, !failed, let engine else { return }
        // 유휴 자동 종료(.idleTimeout) 뒤엔 stoppedHandler가 running을 내린다. 여기서 재기동하지
        // 않으면 첫 정적 이후 세션 내내 무음이 된다 — stop()으로 내려간 경우엔 didBegin 자체가
        // 게이트(씬 pause)로 막히므로 이 지연 재기동이 의도치 않게 켜질 일은 없다.
        if !running {
            do { try engine.start(); running = true } catch { return }
        }
        var events = [CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: Self.clamp01(feel.intensity)),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: Self.clamp01(feel.sharpness)),
        ], relativeTime: 0)]
        var curves: [CHHapticParameterCurve] = []
        if let tail = feel.tail, tail.duration > 0 {
            let start = Self.tailLead
            events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: Self.clamp01(tail.intensity)),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: Self.clamp01(tail.sharpness)),
            ], relativeTime: start, duration: tail.duration))
            // 이벤트 세기는 커브의 **기준값**이고 커브가 1 → 0을 곱한다. 커브가 없으면 꼬리가
            // 끝에서 뚝 잘려 두 번째 타격처럼 들린다 — 잔향은 사라져야 잔향이다.
            curves.append(CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
                CHHapticParameterCurve.ControlPoint(relativeTime: start, value: 1),
                CHHapticParameterCurve.ControlPoint(relativeTime: start + tail.duration, value: 0),
            ], relativeTime: 0))
        }
        do {
            // 두 이벤트를 **한 패턴**으로 낸다 — 따로 재생하면 플레이어 두 개의 시작 시각이
            // 프레임 지터만큼 어긋나 꼬리가 타격보다 먼저 도착하는 경우가 생긴다.
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            // 개별 재생 실패는 무시 — 여기서 로그를 찍으면 충돌마다 콘솔이 폭주한다.
        }
    }

    private static func clamp01(_ v: Float) -> Float { min(1, max(0, v)) }

    deinit { engine?.stop() }
}
