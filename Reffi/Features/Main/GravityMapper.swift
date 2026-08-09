import CoreGraphics
import Foundation

/// 기기 기울임 → 씬 중력 매핑(§13.4). CoreMotion 타입에 의존하지 않는 **순수 계산**이라
/// 시뮬레이터·유닛테스트에서 그대로 검증된다(씬은 CMDeviceMotion.gravity의 x·y만 넘긴다).
///
/// 앱이 **포트레이트 고정**이라 디바이스 프레임의 (x, y)가 곧 씬 축이다(SpriteKit +y = 위,
/// CoreMotion도 화면 위쪽이 +y) — 인터페이스 방향 보정이 필요 없다. 세로로 똑바로 들면
/// gravity = (0, -1)이므로 매핑 결과가 기존 상수 중력과 정확히 일치한다(회귀 안전).
enum GravityMapper {
    /// 기준 중력 크기 — 낙하감의 정본. 바꾸면 스폰 높이·calm 대역 튜닝이 전부 흔들린다.
    static let base: CGFloat = 42
    /// 모션 불가(시뮬레이터)·Reduce Motion 폴백 = 기존 상수 중력 그대로.
    static let fallback = CGVector(dx: 0, dy: -base)

    /// 기기를 눕히면 (x, y)가 0에 수렴한다 — 중력이 0이면 칩이 영원히 안 멈추고 force-settle도
    /// 성립하지 않으므로 하한을 둔다(살짝 흐르다 안착). 상한은 정직한 1G.
    static let minTilt: CGFloat = 0.35
    static let maxTilt: CGFloat = 1.0

    /// 재적용 데드밴드 — 손떨림 수준의 미세 변화로 중력을 계속 갈아끼우면 calm 창이
    /// 매 프레임 리셋되어 force-settle(배터리 최적화)이 무력화된다.
    static let applyAngle: CGFloat = 2 * .pi / 180
    static let applyMagnitudeRatio: CGFloat = 0.05
    /// 휴면 중 깨우기 임계 — 데드밴드보다 훨씬 크게 잡아, 실제로 기기를 기울였을 때만 다시 굴린다.
    static let wakeAngle: CGFloat = 6 * .pi / 180

    /// **무방향 대역(히스테리시스)** — 기기를 책상에 눕히면 평면 성분 hypot(x, y)가 0.01 안팎으로
    /// 내려앉고, 남는 건 센서 노이즈뿐이라 방향이 사실상 난수다. 그 상태에서 정규화하면 각도가 매
    /// 프레임 크게 흔들려 2° 데드밴드·6° 깨우기 임계를 계속 넘고, calm 창이 리셋되어 force-settle이
    /// 성립하지 않는다(SKView가 영원히 60fps). 그래서 **크기 하한 아래에서는 방향이 없다고 본다**:
    /// 중력을 곧장 아래로 접고 크기는 minTilt로 고정해 매 프레임 같은 값이 나오게 만든다.
    /// 진입(0.06)/이탈(0.10)을 벌려 경계에서 깜빡이지 않는다.
    static let flatEnter: CGFloat = 0.06
    static let flatExit: CGFloat = 0.10
    /// 무방향일 때 적용할 중력 — 아래로, 크기는 하한(살짝 흐르다 안착).
    static let flatGravity = CGVector(dx: 0, dy: -base * minTilt)

    /// 한 프레임 판정 결과 — 적용할 중력 + 다음 프레임에 되먹일 무방향 상태(히스테리시스의 유일한 상태).
    /// 값 타입으로 넘겨 매핑 자체는 순수하게 남긴다(씬 없이 테스트 가능).
    struct Sample: Equatable {
        let gravity: CGVector
        /// 평면 성분이 노이즈 수준이라 **방향이 없다**고 판정한 프레임.
        let directionless: Bool
    }

    /// 디바이스 중력 벡터(단위 G) → 씬에 적용할 중력.
    /// 방향 = normalize(x, y), 크기 = base × clamp(hypot(x, y), minTilt, maxTilt).
    /// 무방향 대역 판정은 포함하지 않는다 — 히스테리시스가 필요한 실사용 경로는 `sample(x:y:wasDirectionless:)`.
    static func mapped(x: Double, y: Double) -> CGVector {
        let gx = CGFloat(x), gy = CGFloat(y)
        let tilt = hypot(gx, gy)
        let magnitude = base * min(max(tilt, minTilt), maxTilt)
        // 완전 수평(화면이 하늘/바닥을 봄) → 평면 방향이 미정의. 아래로 접어 기존 감각을 유지한다.
        guard tilt > 1e-4 else { return CGVector(dx: 0, dy: -magnitude) }
        return CGVector(dx: gx / tilt * magnitude, dy: gy / tilt * magnitude)
    }

    /// 무방향 대역 판정 — 들어가 있으면 flatExit를 **넘어야** 나오고, 밖이면 flatEnter **아래로** 내려가야 들어간다.
    static func isDirectionless(rawMagnitude: CGFloat, wasDirectionless: Bool) -> Bool {
        wasDirectionless ? rawMagnitude <= flatExit : rawMagnitude < flatEnter
    }

    /// 실사용 경로 — 원시 평면 크기로 무방향 대역을 먼저 가른 뒤 매핑한다.
    /// 무방향 구간에선 노이즈와 무관하게 **항상 같은 벡터**(flatGravity)라, 데드밴드가 재적용을 한 번만 통과시킨다.
    static func sample(x: Double, y: Double, wasDirectionless: Bool) -> Sample {
        let raw = hypot(CGFloat(x), CGFloat(y))
        let flat = isDirectionless(rawMagnitude: raw, wasDirectionless: wasDirectionless)
        return Sample(gravity: flat ? flatGravity : mapped(x: x, y: y), directionless: flat)
    }

    /// 두 벡터 사이 각(0…π). 0 벡터는 들어오지 않는다(크기 하한 보장).
    static func angle(_ a: CGVector, _ b: CGVector) -> CGFloat {
        abs(atan2(a.dx * b.dy - a.dy * b.dx, a.dx * b.dx + a.dy * b.dy))
    }

    /// 데드밴드 통과 여부 — 방향이 applyAngle 넘게 돌았거나 크기가 5% 넘게 달라졌을 때만 재적용.
    static func shouldApply(_ candidate: CGVector, lastApplied: CGVector) -> Bool {
        if angle(candidate, lastApplied) > applyAngle { return true }
        let m0 = hypot(lastApplied.dx, lastApplied.dy)
        guard m0 > 1e-4 else { return true }
        let m1 = hypot(candidate.dx, candidate.dy)
        return abs(m1 - m0) / m0 > applyMagnitudeRatio
    }

    /// 휴면 중 깨울지 — **마지막으로 적용된** 중력 기준 각차만 본다(누적 드리프트로 몰래 눕는 것 방지).
    static func shouldWake(_ candidate: CGVector, lastApplied: CGVector) -> Bool {
        angle(candidate, lastApplied) > wakeAngle
    }

    /// 휴면 중 깨울지(샘플 버전) — **무방향 구간에선 절대 깨우지 않는다**. 눕혀 둔 기기의 센서 노이즈로
    /// 잠든 씬이 되살아나면(그리고 다시 잠들면) 배터리 최적화가 통째로 무너진다.
    static func shouldWake(_ sample: Sample, lastApplied: CGVector) -> Bool {
        guard !sample.directionless else { return false }
        return shouldWake(sample.gravity, lastApplied: lastApplied)
    }
}
