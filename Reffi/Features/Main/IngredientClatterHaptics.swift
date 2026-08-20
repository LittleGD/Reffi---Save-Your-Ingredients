import CoreHaptics
import UIKit

// MARK: - HD 진동을 iPhone으로 옮기는 원칙 (리서치 요약)
//
// 닌텐도 HD Rumble(스위치)·HD Rumble 2(스위치2)와 iPhone Taptic Engine은 **같은 부품 계열**이다 —
// 둘 다 선형 공진 액추에이터(LRA)로, 스프링에 매단 자성 질량을 보이스코일이 한 축으로 민다.
// 회전 추 모터(ERM)와 달리 한 사이클 안에 최대 출력에 도달하고 밀리초 단위로 서고, 여러 주파수를
// 하나의 파형으로 섞어 낼 수 있다. 그래서 "재질이 다르게 느껴지는" 촉감이 성립한다.
//
// 조이콘 프로토콜(리버스 엔지니어링 문서)이 드러낸 HD Rumble의 실체는 **밴드 2개 × (주파수, 진폭)**이다:
//   · 저역(LF) 40.9 ~ 626.3 Hz — 무게·바닥. 몸통이 느끼는 '쿵'.
//   · 고역(HF) 320 ~ 1252.6 Hz — 어택·질감. 손끝이 읽는 '탁'.
// 두 밴드를 **동시에** 다른 진폭으로 구동해 하나의 파형으로 합성한다. "구슬이 컵 안에서 구른다",
// "얼음이 잔에 부딪힌다" 같은 시그니처는 전부 이 합성의 결과다. 스위치2의 HD Rumble 2는 새 물성이
// 아니라 **같은 원리의 해상도 개선**이다 — 주파수 대역 확대, 응답 속도 향상, 하우징·댐핑·펌웨어를
// 다시 짜서 최대 음압은 낮추고 미세한 고·저역을 살렸다(작은 진폭에서도 디테일이 또렷하다).
//
// iPhone 대응:
//   · `.hapticTransient`  ≈ 고역 어택 한 방. sharpness는 밝기(저역통과 필터 성격).
//   · `.hapticContinuous` ≈ 밴드 구동. **연속 이벤트에서만 sharpness가 실제 주파수에 대응한다**
//     (iPhone 8 실측 공개치: 0.0 ≈ 80Hz, 1.0 ≈ 230Hz, 최대 출력은 0.73 ≈ 공진 160Hz 부근).
//   · `CHHapticParameterCurve` = 시간 엔벨로프. 세기 커브 = 진폭 감쇠, **날카로움 커브 = 주파수 스윕**.
//   · 한 패턴 안의 이벤트는 겹칠 수 있고 하드웨어가 합성한다 = 조이콘의 밴드 믹싱과 같은 자리.
//
// **재현 가능한 것**: 재질별 공명(주파수 베이스 + 감쇠), 충돌 세기의 연속 변조, 저/고역 동시 구동,
//   충돌 뒤 주파수 하강 스윕, 구름 질감의 지속 변조.
// **하드웨어 한계로 재현 불가능한 것**: ① 액추에이터가 **하나**다(조이콘은 좌·우 2개 = 공간 정위 불가).
//   ② 주파수 범위가 좁다(≈80~230Hz vs 조이콘 40~1250Hz) — 저역의 묵직함도 고역의 쨍함도 압축된다.
//   ③ 밴드를 **독립 주소로** 지정할 수 없다. sharpness는 하나뿐이라 저역·고역을 동시에 다른 값으로
//      주려면 **이벤트를 겹쳐서** 근사해야 한다(아래 `play`가 하는 일).
//   ④ 파형 샘플 스트리밍이 없다 — 이벤트·커브 문법 안에서만 논다.

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
///
/// **구름 텍스처(연속 계열)는 이 관문을 타지 않는다** — 별도 관문(`TextureGate`)이다. 두 계열이
/// 같은 관문을 공유하면 구르는 동안 텍스처가 충돌 예산을 먹어 부딪힘이 사라진다.
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
    /// transient 세기 0...1 — '툭'의 크기. HD Rumble의 **고역 어택** 자리다.
    var intensity: Float
    /// transient 날카로움 0...1 — 1이면 쨍한 '클링', 0이면 뭉툭한 '퍽'.
    var sharpness: Float
    /// 공명 꼬리 — **큰 충돌에만** 붙는다. nil이면 transient 한 방으로 끝.
    var tail: Tail?

    /// '툭' 뒤(또는 큰 충돌에서는 '툭'과 **동시에**) 울리는 연속 밴드.
    /// 연속 이벤트에서만 sharpness가 실제 주파수에 대응하므로, HD Rumble의 **저역 밴드**를
    /// 흉내 내는 유일한 자리다. intensity는 커브의 기준값이고 엔진이 0까지 끌어내린다.
    struct Tail: Equatable {
        /// 어택 대비 시작 지연(초). 약한 충돌은 12ms 뒤에 붙어 '툭 → 잔향'으로 읽히고,
        /// **강한 충돌은 0으로 수렴해 어택과 겹친다** — 그 겹침이 곧 저/고역 동시 구동이다.
        var lead: TimeInterval = 0.012
        var duration: TimeInterval
        var intensity: Float
        /// 꼬리 **시작** 날카로움. 여기서 `sweep`만큼 내려간다.
        var sharpness: Float
        /// 꼬리가 끝날 때까지 날카로움이 내려가는 폭 — **주파수 하강 스윕**.
        /// 실제 충돌은 고주파가 먼저 죽고 저주파가 남는다. 0이면 스윕 없음.
        var sweep: Float = 0

        init(lead: TimeInterval = 0.012, duration: TimeInterval,
             intensity: Float, sharpness: Float, sweep: Float = 0) {
            self.lead = lead
            self.duration = duration
            self.intensity = intensity
            self.sharpness = sharpness
            self.sweep = sweep
        }
    }
}

/// 촉감 계산이 재료에서 필요로 하는 축만 뽑은 입력 — 씬의 물성 클래스(`ChipMaterial`)에서 넘어온다.
/// 물성 전체를 넘기지 않는 건 물리 축(마찰·각감쇠·반발)이 촉감 규칙에 새어 들지 않게 하기 위해서다.
///
/// **재질 공명 프로필**이 이 세 축이다 — HD Rumble의 "재질이 주파수를, 물리량이 진폭을 정한다"를
/// 그대로 옮긴 것: `sharpness`가 공명 주파수, `scale`이 진폭, `decay`가 감쇠 곡선.
struct ClatterMaterial: Equatable {
    /// 재료 기준 날카로움 — 임펄스 변조의 **중심**이 된다(= 공명 주파수 베이스).
    var sharpness: Float
    /// 세기 배율 — 여린 재료(잎·두부)는 같은 임펄스라도 약하게 친다.
    var scale: Float
    /// 감쇠 **속도** 0...1 — 1이면 즉시 죽고(단단한 것의 짧은 '탁'), 0이면 길게 끈다(무른 것의 '푹').
    /// 0.5가 중립이라 이 값을 안 주면 예전 꼬리 길이가 그대로다.
    var decay: Float = 0.5

    static let neutral = ClatterMaterial(sharpness: 0.5, scale: 0.8)
}

/// 임펄스 + 재료 → 촉감. **순수 계산기**다(`GravityMapper`·셰이크 킥과 같은 규율).
///
/// v1.0 (5)까지는 모든 충돌이 *같은 파형의* transient 단발이었다 — 세기만 변하고 날카로움은
/// 재료별 상수, 리듬은 11Hz 격자. 손은 그걸 "잘 만든 진동 하나를 반복 재생하는 것"으로 읽고,
/// 실기기 3차 피드백이 "딱딱하고 인위적·고정된 느낌"이라고 불렀다. HD 진동의 자연스러움은 다섯 겹이다:
///   ① **연속 변조** — 세기뿐 아니라 날카로움도 충돌 세기를 따라 움직인다(세게 치면 더 쨍하다).
///   ② **감쇠 꼬리** — 큰 충돌엔 '툭' 뒤에 잔향이 남았다가 0으로 죽는다.
///   ③ **비반복성** — 같은 세기의 두 충돌도 완전히 같지는 않다(±8% 미세 변주).
///   ④ **재질 감쇠** — 같은 세기라도 캔은 짧게 끊기고 고깃덩이는 길게 끌린다(`ClatterMaterial.decay`).
///   ⑤ **저/고역 동시 구동 + 주파수 하강** — 강한 충돌일수록 꼬리가 어택 쪽으로 당겨져 겹치고
///      (= 두 밴드가 동시에 울린다), 꼬리가 진행하며 저역으로 떨어진다(`sweep`).
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
    /// 꼬리 길이 범위(초) — **중립 재료 기준**(decay 0.5). 임계에서 40ms, 최대 충돌에서 70ms.
    var tailShortest: TimeInterval = 0.040
    var tailLongest: TimeInterval = 0.070
    /// 재질 감쇠가 꼬리 길이를 흔드는 폭(±, 비율). decay 1(단단) → ×0.65, decay 0(무름) → ×1.35.
    var decaySwing: Float = 0.35
    /// 꼬리 시작 세기 = 본 타격의 이 비율. 꼬리가 타격만큼 세면 두 번 친 것으로 들린다.
    var tailLevel: Float = 0.42
    /// 꼬리는 본 타격보다 이만큼 뭉툭하다 — 잔향은 고주파가 먼저 죽는다.
    var tailDull: Float = 0.28
    /// **약한** 충돌에서 꼬리가 어택 뒤로 밀리는 시간(초). 강한 충돌에서는 0으로 수렴해
    /// 어택과 겹치고, 그 겹침이 HD Rumble의 저/고역 동시 구동을 근사한다.
    var tailLead: TimeInterval = 0.012
    /// 꼬리가 진행하며 날카로움이 떨어지는 폭(주파수 하강 스윕)의 **최대치**.
    /// 세게 칠수록 더 깊이 저역으로 떨어진다(약: ×0.55, 최대: ×1.0).
    var tailSweep: Float = 0.45

    /// 임펄스 → 0...1. 관문 아래는 0, 상한 위는 1.
    func normalized(_ impulse: CGFloat) -> Float {
        let span = ceilingImpulse - minImpulse
        guard span > 0 else { return 1 }
        return Float(min(1, max(0, (impulse - minImpulse) / span)))
    }

    /// 재질 감쇠 → 꼬리 길이 배율. 0.5가 중립(1.0)이라 `decay`를 안 주면 예전 길이 그대로다.
    func decayFactor(_ decay: Float) -> TimeInterval {
        TimeInterval(1 + decaySwing * (1 - 2 * min(1, max(0, decay))))
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
            // u = 꼬리 구간 안에서의 세기(0 = 갓 임계, 1 = 최대 충돌). 길이·겹침·스윕이 전부 여기 매달린다.
            let u = tailOnset < 1 ? TimeInterval((t - tailOnset) / (1 - tailOnset)) : 1
            let span = tailShortest + u * (tailLongest - tailShortest)
            tail = ClatterFeel.Tail(
                // 강할수록 어택 쪽으로 당겨 붙는다 — 최대 충돌에서 0이면 저역이 어택과 **동시에** 울린다.
                lead: tailLead * (1 - u),
                duration: span * decayFactor(material.decay),
                intensity: Self.clamp01(intensity * tailLevel),
                sharpness: Self.clamp01(sharpness - tailDull),
                // 세게 칠수록 더 깊이 저역으로 떨어진다. 실제 충돌은 고주파가 먼저 죽는다.
                sweep: tailSweep * Float(0.55 + 0.45 * u))
        }
        return ClatterFeel(intensity: intensity, sharpness: sharpness, tail: tail)
    }

    private static func clamp01(_ v: Float) -> Float { min(1, max(0, v)) }
}

// MARK: - 구름/미끄러짐 텍스처 (HD Rumble의 구슬 시그니처)

/// 접촉을 유지한 채 구르는 동안 손끝에 깔리는 **지속** 촉감. 충돌 촉감(`ClatterFeel`)이 사건이라면
/// 이쪽은 상태다 — 값이 매 프레임 갱신되고, 엔진은 재생을 끊지 않은 채 세기·날카로움만 바꾼다.
struct RollTexture: Equatable {
    /// 전체 세기 0...1 — 속도에 비례한다.
    var intensity: Float
    /// 목표 날카로움 0...1(절대값). 엔진이 베이스 대비 **시프트**로 변환해 보낸다.
    var sharpness: Float
}

/// 물리량 → 구름 텍스처. 순수 계산기라 씬 없이 테스트된다.
///
/// **접촉을 직접 묻지 않는다.** `allContactedBodies()`는 칩마다 매 프레임 부르기엔 비싸고, 이 씬은
/// 사방이 막힌 상자라 "쉬지 않는 칩 = 무언가에 닿아 구르는 칩"이 거의 항상 참이다. 유일한 예외인
/// **낙하 중**은 속도로 갈린다 — 중력 42(=6300pt/s²)에서 자유낙하는 순식간에 수백 pt/s를 넘고,
/// 더미 위를 구르는 칩은 그 아래에 머문다. 그래서 `flightSpeed` 위는 "날고 있다"로 보고 텍스처를 끈다.
struct RollTextureRule {
    /// 이 각속도(rad/s) 미만은 구름이 아니다 — 미끄러짐만으로도 결은 나지만, 솔버 잔차까지 통과하면
    /// 정지한 더미가 다시 웅웅댄다(이 기능 전체가 처음 고치려던 실패 모드).
    var minSpin: CGFloat = 0.85
    /// 각속도가 이 이상이면 회전 축은 포화.
    var spinCeiling: CGFloat = 8.5
    /// 이 병진 속도(pt/s) 미만은 제자리 회전 — 결이 지나가지 않으므로 텍스처도 없다.
    var minSpeed: CGFloat = 14
    /// 병진 속도 포화점.
    var speedCeiling: CGFloat = 240
    /// 이 위는 **접촉 없이 날고 있다**고 본다 — 낙하·던지기에 텍스처를 깔면 허공에서 지지직거린다.
    var flightSpeed: CGFloat = 360
    /// 텍스처 최대 세기 — 충돌 촉감을 덮으면 안 되므로 낮게 유지한다(부딪힘이 주인공이다).
    var maxIntensity: Float = 0.32
    /// 재료 날카로움 대비 텍스처가 낮게 깔리는 폭 — 구름은 부딪힘보다 뭉툭하다.
    var textureDull: Float = 0.22
    /// 속도가 올라가면 결이 더 촘촘·밝게 지나간다(날카로움 가산 폭).
    var speedBrighten: Float = 0.24

    /// 구름 신호 0...1 — 히스테리시스 관문(`TextureGate`)의 입력이자 세기의 원천.
    /// 회전과 병진을 **곱**한다: 둘 중 하나라도 0이면 구름이 아니다(제자리 회전·미끄러짐 없는 이동).
    func level(speed: CGFloat, spin: CGFloat) -> Float {
        guard speed < flightSpeed else { return 0 }
        let s = Self.ramp(abs(speed), minSpeed, speedCeiling)
        let w = Self.ramp(abs(spin), minSpin, spinCeiling)
        guard s > 0, w > 0 else { return 0 }
        // 제곱근으로 펴 준다 — 곱만 쓰면 둘 다 중간일 때 신호가 0.25로 주저앉아 손에 안 잡힌다.
        return (s * w).squareRoot()
    }

    /// 신호 + 재료 → 실제 텍스처 값. 세기는 재료 배율을 그대로 타고(잎사귀는 굴러도 거의 무음),
    /// 날카로움은 재료 공명 베이스에서 낮게 깔되 속도가 오르면 조금 밝아진다.
    func texture(level: Float, material: ClatterMaterial) -> RollTexture {
        let l = min(1, max(0, level))
        return RollTexture(
            intensity: min(1, max(0, l * maxIntensity * material.scale)),
            sharpness: min(1, max(0, material.sharpness - textureDull + speedBrighten * l)))
    }

    private static func ramp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> Float {
        guard hi > lo else { return v >= hi ? 1 : 0 }
        return Float(min(1, max(0, (v - lo) / (hi - lo))))
    }
}

/// 지속 촉감의 **개폐 히스테리시스**. 켜는 문턱이 끄는 문턱보다 높아야 경계에서 여닫히지 않고,
/// 끌 때는 유예를 둬야 한 프레임짜리 dip으로 끊기지 않는다 — 둘 중 하나만 빠져도 "지직거리며
/// 여닫히는" 실패 모드가 그대로 돌아온다(스폰 하늘 개폐에서 이미 겪은 것과 같은 구조).
/// 순수 상태 기계라 씬 없이 테스트된다.
struct TextureGate {
    /// 이 신호 이상이면 켠다.
    var onLevel: Float = 0.20
    /// 이 신호 미만으로 떨어져야 끄기 유예가 시작된다(`onLevel`보다 **낮아야** 한다).
    var offLevel: Float = 0.09
    /// 끄기 유예(초) — 이만큼 연속으로 조용해야 실제로 끈다.
    var holdOff: TimeInterval = 0.14

    private(set) var isOn = false
    private var quietSince: TimeInterval?

    /// 이번 프레임의 신호를 먹이고 "지금 켜져 있어야 하나"를 돌려준다.
    mutating func update(level: Float, now: TimeInterval) -> Bool {
        if isOn {
            if level >= offLevel {
                quietSince = nil
            } else if let since = quietSince {
                if now - since >= holdOff { isOn = false; quietSince = nil }
            } else {
                quietSince = now
            }
        } else if level >= onLevel {
            isOn = true
            quietSince = nil
        }
        return isOn
    }

    /// 씬이 멈추거나 재료가 갈릴 때 — 상태를 즉시 닫는다(유예 없이).
    mutating func reset() {
        isOn = false
        quietSince = nil
    }
}

/// 제스처 순간의 고정 촉감 — 물리에서 파생되지 않으므로 규칙이 아니라 **상수**다.
/// §7.6의 의미별 매핑(`.impact`/`.success`/`.warning`)과 겹치지 않는 자리만 쓴다:
/// 잡기·자석 붙음은 판정이 아니라 **물리 사건**이고, 판정 확정 햅틱은 손을 뗄 때 따로 울린다.
enum ClatterAccent {
    /// 잡는 순간 — "집혔다". 가볍고 짧게, 꼬리 없이.
    static let pick = ClatterFeel(intensity: 0.34, sharpness: 0.62, tail: nil)

    /// 마그네틱 캡처 진입(§13.4) — 자석에 **딱 붙는** 스냅. 판정이 확정될 자리에 들어왔다는 신호라
    /// 잡기보다 세고, 짧은 저역 꼬리를 어택과 **동시에**(lead 0) 얹어 "붙었다"는 무게를 준다.
    static let captureSnap = ClatterFeel(
        intensity: 0.62, sharpness: 0.84,
        tail: ClatterFeel.Tail(lead: 0, duration: 0.045, intensity: 0.24, sharpness: 0.30, sweep: 0.22))

    /// 존 위에 떠 있는 동안의 미세 텍스처 — 자석이 붙들고 있다는 **지속** 신호.
    /// 구름 텍스처와 같은 채널을 쓴다(드래그 중엔 구름 스캔이 돌지 않아 서로 배타적이다).
    static let hover = RollTexture(intensity: 0.085, sharpness: 0.58)
}

/// 달그락 햅틱 재생기 — 두 계열을 낸다.
///   ① **사건**(`play`): 충돌 하나를 `ClatterFeel`이 시킨 대로 친다. 어택 transient + (큰 충돌이면)
///      겹치는 저역 꼬리를 **같은 패턴**에 담고, 세기 커브와 **날카로움 커브**(주파수 하강 스윕)를 건다.
///   ② **상태**(`setTexture`): 구름/호버 질감. 루프하는 advanced 플레이어 하나를 켜 두고
///      `sendParameters`로 세기·날카로움만 실시간 변조한다 — 매번 다시 재생하면 이음매가 들린다.
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

    /// 물리 질감 햅틱 전체 스위치. 기본 켬 — **다음 단계의 프로필 토글이 배선만 하면 되도록** 둔 자리다.
    /// 끄면 엔진까지 내린다(켜 둔 채 무음으로 두면 배터리만 먹는다). 시스템 설정의 진동 끔은
    /// CoreHaptics가 알아서 존중하므로 여기서 따로 읽지 않는다.
    var isEnabled = true {
        didSet {
            guard oldValue != isEnabled else { return }
            if isEnabled { start() } else { stop() }
        }
    }

    /// 엔진 기동. 씬이 활성일 때만 부른다(엔진은 켜져 있는 동안 전력을 쓴다).
    func start() {
        guard isEnabled, supportsHaptics, !failed, !running else { return }
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
                    // 리셋은 플레이어까지 무효화한다 — 옛 핸들에 계속 파라미터를 보내면 조용히 실패한다.
                    self.texturePlayer = nil
                    self.textureOn = false
                    self.sentTexture = nil
                    try? self.engine?.start()
                }
            }
            e.stoppedHandler = { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.running = false
                    self.texturePlayer = nil
                    self.textureOn = false
                    self.sentTexture = nil
                }
            }
            try e.start()
            engine = e
            running = true
        } catch {
            failed = true   // 조용히 포기 — 달그락은 부가 연출이라 없다고 기능이 깨지지 않는다
        }
    }

    /// 정지 — 탭을 벗어나거나 백그라운드로 갈 때. **텍스처를 먼저 끈다** — 루프 플레이어를
    /// 켜 둔 채 엔진만 내리면 다음 기동에서 죽은 핸들에 파라미터를 보내게 된다.
    func stop() {
        stopTexture()
        guard running else { return }
        running = false
        engine?.stop()
    }

    // MARK: - ① 사건: 충돌 하나

    /// 충돌 하나의 촉감을 친다. 세기·날카로움·꼬리는 전부 순수 계산기(`ClatterFeelRule`)가 정한다.
    ///
    /// **저/고역 동시 구동을 이벤트 겹침으로 근사한다.** Taptic Engine은 액추에이터가 하나라
    /// 조이콘처럼 두 밴드를 따로 주소 지정할 수 없다. 대신 한 패턴 안에서 어택 transient(밝은 고역)와
    /// 연속 꼬리(어두운 저역)를 **같은 시각에** 얹으면 하드웨어가 하나의 파형으로 합성한다 —
    /// 이것이 HD Rumble의 밴드 믹싱에 가장 가까운 자리다. 겹침 정도(`tail.lead`)는 충돌 세기가 정한다.
    func play(_ feel: ClatterFeel) {
        guard isEnabled, supportsHaptics, !failed, let engine else { return }
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
            let start = max(0, tail.lead)
            let end = start + tail.duration
            events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: Self.clamp01(tail.intensity)),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: Self.clamp01(tail.sharpness)),
            ], relativeTime: start, duration: tail.duration))
            // 이벤트 세기는 커브의 **기준값**이고 커브가 1 → 0을 곱한다. 커브가 없으면 꼬리가
            // 끝에서 뚝 잘려 두 번째 타격처럼 들린다 — 잔향은 사라져야 잔향이다.
            //
            // 커브는 **플레이어 전역**이라 겹치는 이벤트에 모두 걸린다. 그래서 첫 제어점을 꼬리
            // 시작(= 겹칠 때는 0)에 값 1로 두어 그 시각의 어택 transient가 감쇠되지 않게 한다.
            curves.append(CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
                CHHapticParameterCurve.ControlPoint(relativeTime: start, value: 1),
                CHHapticParameterCurve.ControlPoint(relativeTime: end, value: 0),
            ], relativeTime: 0))
            if tail.sweep > 0 {
                // **주파수 하강 스윕** — 연속 이벤트에서 sharpness는 실제 주파수에 대응하므로,
                // 시간에 따라 내리면 "고주파가 먼저 죽고 저역이 남는" 실제 충돌의 스펙트럼이 된다.
                // `…Control`은 절대값이 아니라 **시프트**(−1...1)라 시작을 0으로 두면 어택은 무영향이다.
                curves.append(CHHapticParameterCurve(parameterID: .hapticSharpnessControl, controlPoints: [
                    CHHapticParameterCurve.ControlPoint(relativeTime: start, value: 0),
                    CHHapticParameterCurve.ControlPoint(relativeTime: end, value: -min(1, max(0, tail.sweep))),
                ], relativeTime: 0))
            }
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

    // MARK: - ② 상태: 구름/호버 텍스처

    private var texturePlayer: CHHapticAdvancedPatternPlayer?
    private var textureOn = false
    /// 텍스처 채널만의 포기 플래그. **`failed`와 나눠 둔다** — 루프 플레이어가 안 만들어져도
    /// 충돌 달그락은 멀쩡히 울려야 한다(질감 하나 때문에 주인공을 함께 끄면 안 된다).
    private var textureFailed = false
    /// 마지막으로 **보낸** 값 — 60fps로 같은 값을 다시 보내지 않으려는 것뿐이다.
    private var sentTexture: RollTexture?

    /// 루프 패턴의 베이스 날카로움. `…Control`이 시프트라서, 목표 절대값에서 이 값을 빼 시프트를 만든다.
    private static let textureBaseSharpness: Float = 0.42
    /// 루프 길이(초). 짧으면 반복 주기가 손에 **클럭**으로 잡힌다 — 달그락 리듬을 격자에서 떼어낸
    /// 것과 같은 이유로 넉넉히 잡는다(0.85s면 결 하나하나가 다시 오기 전에 속도 변조가 먼저 바뀐다).
    private static let textureLoop: TimeInterval = 0.85
    /// 루프 안의 미세 결(구슬이 바닥 결을 넘는 톡톡) 개수.
    private static let textureGrains = 17

    /// 구름 질감의 루프 패턴 — **연속 베드 + 불규칙 미세 결**.
    ///
    /// 매끈한 연속 이벤트 하나만 깔면 그건 질감이 아니라 '웅' 하는 캐리어다. HD Rumble이 구슬을
    /// 표현하는 방식은 저역 베드 위에 고역 알갱이를 얹는 것이고, Core Haptics에서 그에 대응하는
    /// 문법이 연속 이벤트 + 겹친 저강도 transient들이다. 결의 간격·세기·밝기는 `ReffiHash`로 뽑아
    /// **불규칙하되 결정적**이다 — 균등 간격이면 20Hz 톱니로 들리고, 난수면 실행마다 달라진다.
    private static func textureLoopPattern() throws -> CHHapticPattern {
        var events: [CHHapticEvent] = [
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.34),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: textureBaseSharpness),
            ], relativeTime: 0, duration: textureLoop),
        ]
        let step = textureLoop / TimeInterval(textureGrains)
        for i in 0..<textureGrains {
            let jitter = ReffiHash.signed("roll-grain-t-\(i)") * step * 0.44
            let t = min(textureLoop - 0.001, max(0, TimeInterval(i) * step + step * 0.5 + jitter))
            let amp = 0.42 + Float(ReffiHash.unit("roll-grain-a-\(i)")) * 0.58
            let brt = 0.30 + Float(ReffiHash.unit("roll-grain-s-\(i)")) * 0.45
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: amp),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: brt),
            ], relativeTime: t))
        }
        return try CHHapticPattern(events: events, parameterCurves: [])
    }

    /// 이번 프레임의 지속 촉감. nil이면 끈다. **재생을 끊지 않고** 동적 파라미터만 갈아 끼우므로
    /// 속도가 변해도 이음매가 들리지 않는다 — 이게 '구슬이 굴러간다'와 '진동이 껐다 켜진다'를 가른다.
    func setTexture(_ texture: RollTexture?) {
        guard let texture, texture.intensity > 0.001 else { stopTexture(); return }
        guard isEnabled, supportsHaptics, !failed, !textureFailed, let engine else { return }
        if !running {
            do { try engine.start(); running = true } catch { return }
        }
        if texturePlayer == nil {
            do {
                let player = try engine.makeAdvancedPlayer(with: Self.textureLoopPattern())
                player.loopEnabled = true
                player.loopEnd = 0          // 0 = 패턴 전체를 무한 반복
                texturePlayer = player
            } catch {
                textureFailed = true        // 텍스처 채널만 접는다 — 충돌 달그락은 계속 울린다
                return
            }
        }
        guard let player = texturePlayer else { return }
        if !textureOn {
            do { try player.start(atTime: CHHapticTimeImmediate) } catch { return }
            textureOn = true
            sentTexture = nil               // 첫 프레임은 무조건 값을 실어 보낸다
        }
        // 같은 값을 60fps로 다시 보내지 않는다(IPC 낭비). 0.02는 손이 못 느끼는 폭이다.
        if let last = sentTexture,
           abs(last.intensity - texture.intensity) < 0.02,
           abs(last.sharpness - texture.sharpness) < 0.02 { return }
        let shift = min(1, max(-1, texture.sharpness - Self.textureBaseSharpness))
        do {
            try player.sendParameters([
                CHHapticDynamicParameter(parameterID: .hapticIntensityControl,
                                         value: Self.clamp01(texture.intensity), relativeTime: 0),
                CHHapticDynamicParameter(parameterID: .hapticSharpnessControl,
                                         value: shift, relativeTime: 0),
            ], atTime: CHHapticTimeImmediate)
            sentTexture = texture
        } catch {
            // 무시 — 다음 프레임에 다시 시도한다(sentTexture를 갱신하지 않았으므로 자동 재시도).
        }
    }

    /// 텍스처 정지. 플레이어 핸들은 남겨 재사용한다(패턴 컴파일을 매번 다시 하지 않게).
    func stopTexture() {
        guard textureOn else { return }
        textureOn = false
        sentTexture = nil
        try? texturePlayer?.stop(atTime: CHHapticTimeImmediate)
    }

    private static func clamp01(_ v: Float) -> Float { min(1, max(0, v)) }

    deinit {
        try? texturePlayer?.stop(atTime: CHHapticTimeImmediate)
        engine?.stop()
    }
}
