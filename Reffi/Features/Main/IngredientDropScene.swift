import SpriteKit
import SwiftUI
import os

/// 재료 낙하 씬(§13) — **진짜 물리 엔진**(SpriteKit, 레퍼런스 École Vision의 gravity-based). 재료가 위에서
/// 떨어져 충돌·바운스하며 **쌓여서 그대로 남는다**(사라지지 않음). 끌어서 던질 수 있고, 짧게 탭하면 판정을 묻는다.
/// 재료 식별·신선도는 실루엣 + 아래 뱃지 행이 전달한다(씬 위 이름 라벨 없음, §13.4).
/// 바닥은 씬 하단보다 위(요리시작 버튼 충돌 마진). 터치는 **한 손가락만** 추적해 멀티터치에 상태가 안 꼬인다.
final class IngredientDropScene: SKScene, SKPhysicsContactDelegate {
    private var chips: [UUID: SKSpriteNode] = [:]
    private var textureCache: [String: SKTexture] = [:]
    private var pending: [Ingredient] = []

    private var dragTouch: UITouch?          // 추적 중인 단일 터치 — 나머지 손가락은 무시
    private var dragged: SKSpriteNode?
    private var dragTarget: CGPoint = .zero
    private var dragStart: CGPoint = .zero   // 탭 판정은 시작점 기준 누적 이동으로(느린 드래그 오판 방지)
    private var dragMoved = false

    /// 외부 일시정지(탭 전환·커버 가림) — idle과 합성해 isPaused를 만든다. isPaused는 절대
    /// 직접 대입하지 않고 refreshPaused()만 만진다(SSOT). 외부에서 이 값만 바꾼다.
    var externallyPaused = false { didSet { if externallyPaused != oldValue { refreshPaused() } } }
    /// 모든 칩이 정착하면 씬을 스스로 재운다 — 유휴 프레임에서 물리·렌더 비용 0.
    private var idle = false
    // 강제 안착(force-settle) — 알파 텍스처의 오목 충돌체는 접촉 해소 지터(v 4~30pt/s)가 영원히
    // 안 죽어 '완전 정지' 판정이 성립하지 않는다. 조용함(calm) 대역 + 변위 검증으로 판정하고
    // 통과하면 속도를 0으로 굳혀 재운다.
    private var calmFrames = 0                       // calm 연속 프레임(임계 도달 시 변위 검증)
    private let calmThreshold = 30                   // ≈0.5s(60fps)
    private let calmSpeed: CGFloat = 40              // 이 미만이면 '조용' — 지터 대역을 포함
    private let settleDrift: CGFloat = 4             // calm 창 동안 이보다 덜 움직였으면 진짜 안착
    private var calmSnapshot: [UUID: CGPoint] = [:]  // calm 창 시작 시점의 칩 위치
    private let settleBand: CGFloat = 80             // 이 미만 = 착지 후 잔여 운동(자유낙하·던지기 아님)
    private let jitterDamp: CGFloat = 0.8            // 잔여 운동의 프레임당 곱셈 감쇠 — 접촉 임펄스를 이긴다
    /// 중력 변화 직후 jitterDamp를 쉬게 할 프레임 수(≈1.5s) — 기울임에 더미가 반응할 시간을 준다.
    private var dampSuppression = 0
    private let dampSuppressionFrames = 90
    private var foregroundObserver: NSObjectProtocol?   // 블록 옵저버라 명시 해제 필요

    // 컬러 스킴 — SpriteKit은 동적 UIColor를 트레이트 변화에 따라 다시 해석하지 않고,
    // ImageRenderer도 명시하지 않으면 항상 라이트로 렌더한다. 스킴을 씬이 직접 들고 있다가
    // 바뀌면 텍스처를 다시 굽는다(SKView의 trait 변경을 구독 — SwiftUI 쪽 배선 불필요).
    private var interfaceStyle: UIUserInterfaceStyle = .light
    private var traitRegistration: (any UITraitChangeRegistration)?

    /// 짧은 탭 = 판정 묻기(Ate/Tossed).
    var onRemove: ((UUID) -> Void)?
    /// 제스처 판정(§13.6 B) — 칩을 존에 끌어다 놓으면 (id, wasted). 탭 오버레이는 접근성 경로로 유지.
    var onDecide: ((UUID, Bool) -> Void)?
    var reduceMotion = false { didSet { if reduceMotion != oldValue { wake() } } }

    // MARK: - 기울기 중력 (CoreMotion)

    /// 중력 세기 — **물속 튜닝**. 물에 잠긴 듯한 부력감을 위해 42에서 28로 낮췄다(부력이 중력을
    /// 상쇄한 만큼의 유효 중력). 실제 감속의 주역은 클래스별 `linearDamping`(= 점성)이고, 이 값은
    /// 전체 스케일을 잡는다. 기울기는 **방향만** 바꾸고 세기는 건드리지 않는다.
    /// (SpriteKit 기본치 9.8은 이 씬의 칩 크기 조합에선 너무 느슨해 채택하지 않았다.)
    private static let gravityMagnitude: CGFloat = 28
    /// 세워 든 기본 자세의 중력. 기울기를 못 읽는 환경(시뮬레이터 등)은 계속 이 값이다.
    private static var defaultGravity: CGVector { CGVector(dx: 0, dy: -gravityMagnitude) }

    /// 단일 CMMotionManager 소유자 — 씬이 하나뿐(MainView.SceneBox)이라 앱 전체에서도 하나다.
    private let tilt = IngredientTiltMotion()

    /// 기울기 반응 on/off. 수명주기 판단(홈 탭 표시 중 · 포그라운드 · 가림 없음 · Reduce Motion 꺼짐)은
    /// MainView가 하고 여기엔 결과만 들어온다. 끄면 센서를 멈추고 기본 중력으로 되돌린다.
    var tiltEnabled = false {
        didSet {
            guard tiltEnabled != oldValue else { return }
            refreshTilt()
            refreshClatter()   // 달그락 엔진도 같은 수명주기(§배터리)
        }
    }

    /// 중력 방향이 이만큼(씬 중력 단위) 달라졌을 때만 씬을 깨운다 — 약 5도 기울임에 해당.
    /// 손떨림 수준의 미세 변화까지 깨우면 안착 후 휴면(유휴 비용 0)이 성립하지 않는다.
    private let tiltWakeDelta: CGFloat = 4
    /// 눕힘 판정 문턱 — 평면 성분이 이보다 약하면 기본 아래 방향을 섞는다(아래 applyTiltDirection).
    private let tiltFlatFloor: CGFloat = 0.30

    #if DEBUG
    /// `-tiltLab` 주입 중력 방향(정규화 x, y) — 있으면 CoreMotion보다 우선한다.
    /// 시뮬레이터엔 자이로가 없어 기울기 QA는 이 경로로만 가능하다.
    var debugTilt: CGVector? {
        didSet {
            guard let d = debugTilt else { refreshTilt(); return }
            tilt.stop()
            applyTiltDirection(d.dx, d.dy)
        }
    }
    #endif

    /// tiltEnabled 반영 — 켜면 센서 갱신 시작, 끄면 정지하고 기본 중력 복귀.
    private func refreshTilt() {
        #if DEBUG
        // -tiltLab 주입이 정본 — 센서를 끄고 주입값을 **다시 적용**한다.
        // 여기서 그냥 return하면 didMove의 `gravity = defaultGravity`가 주입을 덮은 채로 남는다
        // (프레젠트 전에 주입된 경우: 슬라이더 표시값은 y=1인데 더미는 아래로 떨어지던 버그).
        if let d = debugTilt { tilt.stop(); applyTiltDirection(d.dx, d.dy); return }
        #endif
        guard tiltEnabled else {
            tilt.stop()
            setGravity(Self.defaultGravity)
            return
        }
        // 시뮬레이터처럼 deviceMotion이 없는 환경은 기본 중력(아래)으로 정지 상태를 유지한다.
        guard tilt.isAvailable else {
            setGravity(Self.defaultGravity)
            return
        }
        tilt.start { [weak self] sample in
            guard let self else { return }
            self.applyTiltDirection(sample.gravityX, sample.gravityY)   // 저역 = 중력 방향
            self.applyShake(sample.shakeX, sample.shakeY)               // 고역 = 흔들기 에너지
        }
    }

    /// 기기 중력 방향(정규화 x, y) → 씬 중력. 세기는 gravityMagnitude로 고정하고 **방향만** 따른다.
    /// 폰을 테이블에 눕히면 중력이 z축으로 빠져 (x, y)가 0에 수렴한다 — 그대로 쓰면 무중력이 되어
    /// 더미가 흩어지므로, 평면 성분이 약할수록 기본 아래 방향을 섞고 마지막에 다시 정규화한다
    /// (섞는 동안 세기가 약해지지 않게).
    private func applyTiltDirection(_ gx: CGFloat, _ gy: CGFloat) {
        let planar = hypot(gx, gy)
        let blend = min(1, planar / tiltFlatFloor)      // 0 = 완전히 누움, 1 = 충분히 세움
        let ux = planar > 0.0001 ? gx / planar : 0
        let uy = planar > 0.0001 ? gy / planar : -1
        var dx = ux * blend
        var dy = uy * blend - (1 - blend)               // 나머지는 아래 방향으로 채운다
        let n = hypot(dx, dy)
        if n > 0.0001 { dx /= n; dy /= n }
        setGravity(CGVector(dx: dx * Self.gravityMagnitude, dy: dy * Self.gravityMagnitude))
    }

    // MARK: - 달그락 햅틱 (충돌 구동)

    /// 충돌 카테고리 — contact 테스트용 태그일 뿐, `collisionBitMask`는 기본값(전부 충돌) 그대로라
    /// **물리 거동은 하나도 바뀌지 않는다**.
    private enum Category {
        static let chip: UInt32 = 1 << 0
        static let wall: UInt32 = 1 << 1
    }

    private let clatter = IngredientClatterHaptics()
    private var clatterThrottle = ClatterThrottle()
    /// 임펄스가 이 값이면 최대 세기 — 이 위는 전부 1.0으로 포화(클램프 곡선의 상한).
    private let clatterImpulseCeiling: CGFloat = 90
    /// 스로틀 판정용 현재 시각 — `didBegin`엔 시간 인자가 없어 update에서 받아 둔다.
    private var lastUpdateTime: TimeInterval = 0
    /// QA 계측용 — 햅틱이 실제로 발화할 때마다 호출된다(TILT LAB 카운터).
    var onClatter: (() -> Void)?

    /// 달그락 on/off — 기울기와 같은 수명주기(`tiltEnabled`)를 탄다. 끄면 엔진까지 내린다.
    private func refreshClatter() {
        if tiltEnabled {
            clatter.start()
        } else {
            clatter.stop()
            clatterThrottle.reset()
        }
    }

    /// 두 바디 중 촉감을 대표할 물성 — 칩-벽이면 그 칩, 칩-칩이면 **무거운 쪽**이 소리를 주도한다.
    private func clatterMaterial(_ a: SKPhysicsBody, _ b: SKPhysicsBody) -> ChipMaterial {
        let mats = [a, b].compactMap { body -> ChipMaterial? in
            guard let raw = body.node?.userData?["glyph"] as? String,
                  let glyph = FoodGlyph(rawValue: raw) else { return nil }
            return Self.material(for: glyph)
        }
        return mats.max(by: { $0.mass < $1.mass }) ?? .standard
    }

    /// 임펄스 → 세기. 임계값에서 0.18로 시작해 상한에서 1.0으로 포화한다.
    /// 바닥을 0이 아니라 0.18로 둔 이유 — 통과한 충돌은 '느껴져야' 의미가 있다. 0 근처면 헛발질이다.
    private func clatterIntensity(_ impulse: CGFloat) -> Float {
        let span = clatterImpulseCeiling - clatterThrottle.minImpulse
        let t = span > 0 ? (impulse - clatterThrottle.minImpulse) / span : 1
        return Float(min(1, max(0, t))) * 0.82 + 0.18
    }

    /// 충돌 발생 — 세 관문(임펄스·전역간격·쌍 쿨다운)을 통과한 것만 촉감을 낸다.
    func didBegin(_ contact: SKPhysicsContact) {
        guard tiltEnabled else { return }
        let pair = ClatterPair(ObjectIdentifier(contact.bodyA).hashValue,
                               ObjectIdentifier(contact.bodyB).hashValue)
        guard clatterThrottle.allow(impulse: contact.collisionImpulse,
                                    pair: pair, now: lastUpdateTime) else { return }
        let mat = clatterMaterial(contact.bodyA, contact.bodyB)
        clatter.play(intensity: clatterIntensity(contact.collisionImpulse) * mat.hapticScale,
                     sharpness: mat.sharpness)
        onClatter?()
    }

    // MARK: - 흔들기 에너지 주입

    /// 이 G 미만은 손떨림·걷기 — 무시한다.
    private let shakeThreshold: CGFloat = 0.35
    /// 킥 사이 최소 간격(초) — 매 프레임 밀면 흔들기가 아니라 연속 가속이 된다.
    private let shakeInterval: TimeInterval = 0.09
    /// 킥 하나가 줄 수 있는 최대 속도 변화(pt/s). **벽 터널링 방지 상한** — 60fps에서 프레임당
    /// 3.5pt라 두께 0인 edge loop도 못 뚫는다(게다가 wake로 CCD가 켜진 상태다).
    private let shakeMaxDeltaV: CGFloat = 210
    private let shakeGain: CGFloat = 150
    private var lastShakeTime: TimeInterval = 0

    /// `userAcceleration`(중력 제외 고역) → 칩들에 임펄스 킥. 이게 있어야 "흔들면 달그락"이 성립한다.
    /// 중력 벡터만으론 흔들기가 전달되지 않는다(저역 신호라 흔드는 동안에도 거의 안 변한다).
    private func applyShake(_ ax: CGFloat, _ ay: CGFloat) {
        let mag = hypot(ax, ay)
        guard mag > shakeThreshold else { return }
        guard lastUpdateTime - lastShakeTime >= shakeInterval else { return }
        lastShakeTime = lastUpdateTime
        kickChips(angle: atan2(ay, ax),
                  deltaV: min((mag - shakeThreshold) * shakeGain, shakeMaxDeltaV))
    }

    /// 칩들을 한 방향으로 밀되 **칩마다 각도·세기를 흩는다** — 똑같이 밀면 나란히 움직여서
    /// 서로 부딪히지 않고, 부딪히지 않으면 달그락도 없다.
    private func kickChips(angle: CGFloat, deltaV: CGFloat) {
        guard !chips.isEmpty else { return }
        for (id, node) in chips {
            guard let body = node.physicsBody else { continue }
            let j = Self.stableJitter(id)                 // 0..1 결정적
            let a = angle + (j - 0.5) * 1.3               // ±0.65rad 흩뿌림
            let dv = deltaV * (0.65 + 0.7 * j)
            body.applyImpulse(CGVector(dx: cos(a) * dv * body.mass,
                                       dy: sin(a) * dv * body.mass))
            body.applyAngularImpulse((j - 0.5) * 0.02 * body.mass)
        }
        wake()   // CCD 복구 + 감쇠 유예 — 킥이 감쇠에 바로 먹히지 않게
    }

    /// QA용 셰이크 버스트 — 시뮬레이터엔 자이로가 없어 손으로 흔들 수 없다.
    /// TILT LAB의 SHAKE 버튼과 `-tiltLab.shake`가 이걸 부른다.
    /// 실제 흔들기는 **왕복 운동**이라 한 번 미는 것으론 재현이 안 된다 — 방향을 바꿔 3연타를 넣는다.
    func shakeBurst() {
        wake()   // 휴면 중이면 먼저 깨운다(멈춘 씬은 SKAction도 안 돈다)
        kickChips(angle: .pi * 0.5, deltaV: shakeMaxDeltaV * 0.9)
        let followUps: [CGFloat] = [-.pi * 0.35, .pi * 0.8]
        for (i, angle) in followUps.enumerated() {
            run(.sequence([
                .wait(forDuration: 0.13 * Double(i + 1)),
                .run { [weak self] in
                    guard let self else { return }
                    self.kickChips(angle: angle, deltaV: self.shakeMaxDeltaV * 0.75)
                },
            ]))
        }
    }

    /// physicsWorld.gravity의 유일한 세터 — **의미 있는** 변화일 때만 씬을 깨운다.
    /// (휴면 중이면 값만 저장되고, 다음 wake에서 그대로 적용된다.)
    private func setGravity(_ g: CGVector) {
        let old = physicsWorld.gravity
        physicsWorld.gravity = g
        if hypot(g.dx - old.dx, g.dy - old.dy) > tiltWakeDelta { wake() }
    }

    // 판정 바스켓 — 드래그 중에만 나타나는 휴지통(좌상)·냄비(우상) 종이 블롭.
    // 손가락이 근처에 오면 재료가 자석처럼 끌려 들어간다(마그네틱 캡처).
    private var tossZone: SKSpriteNode?
    private var ateZone: SKSpriteNode?
    private let zoneSide: CGFloat = 86
    private let magnetRadius: CGFloat = 88

    private var chipSide: CGFloat { chipSideFor(size) }
    private func chipSideFor(_ s: CGSize) -> CGFloat { min(max(124, s.width * 0.42), 188) }
    // MARK: - 좌표계: 물리 영역 vs 가려지지 않는 영역

    /// 헤더·배너가 씬 위를 덮는 높이 — MainView가 실측해 넣어준다.
    ///
    /// 씬은 이제 **화면 전체 배경**이라 위쪽 일부가 헤더·MORNING ALERTS 배너에 가려진다.
    /// 물리 경계(`sealedCeiling`)는 그 가려진 데까지 열어 두어 기울이면 재료가 배너 **뒤로** 굴러
    /// 올라가지만, 스폰·판정 존처럼 **사용자가 봐야 하는 것**은 이 인셋 아래(가려지지 않는 영역)에 둔다.
    /// 그래서 런치 캐스케이드가 헤더 텍스트 위를 가로지르지 않고 구도가 종전과 같다.
    var overlayTopInset: CGFloat = 0 {
        didSet {
            guard abs(overlayTopInset - oldValue) > 0.5 else { return }
            layoutZones()
            wake()
        }
    }

    /// 가려지지 않는 영역의 높이 — 확장 전의 필드 높이와 같다. 바닥·존·스폰의 기준.
    private var clearHeight: CGFloat { max(1, size.height - overlayTopInset) }
    /// 가려지지 않는 영역의 위끝 — 확장 전 `sealedCeiling`과 같은 자리.
    private var clearCeiling: CGFloat { clearHeight - wallInset }
    /// 바닥은 **확장 전 위치 그대로**(배지 행 위). 씬이 위로 커져도 안 따라 올라가게
    /// 전체 높이가 아니라 가려지지 않는 높이에 비례시킨다.
    private var floorY: CGFloat { max(6, clearHeight * 0.03) }

    // MARK: - 컨테인먼트 경계 (§13.4)

    /// 좌·우 벽을 화면 끝이 아니라 **이만큼 안쪽**에 세운다.
    /// 칩 스프라이트는 s×s지만 실제로 그려지는 건 알파 bbox뿐이고, 충돌체는 다시 그 bbox의 **90%** 다
    /// (`bodyMetrics`). 그래서 바디가 화면 끝 벽에 닿아도 **그림은 계속 바깥으로 삐져나가** 잘려 보인다.
    /// 삐져나가는 양 = bbox반폭 - 바디반폭 = 바디폭 × (1/0.9 - 1) / 2 ≈ 바디폭 × 0.056.
    /// 표의 최대 바디폭이 0.68s이므로 약 0.038s. 테이블이 버린 가로 중심 오프셋(`dx`)과 회전 여유까지
    /// 얹어 0.09s로 잡았다(0.06s로는 실측 여백이 1.7pt까지 좁아져 사실상 닿아 보였다 — 스크린샷 계측).
    private var wallInset: CGFloat { max(2, chipSide * 0.09) }
    /// 밀폐 천장 — **씬(= 화면) 최상단**. 헤더·배너 뒤까지가 물리 영역이므로 여기까지 열어 두되,
    /// 그 위로는 절대 못 나간다. 배너는 물리적 장애물이 아니라 그냥 위에 그려진 UI일 뿐이다.
    private var sealedCeiling: CGFloat { size.height - wallInset }
    /// 스폰 천장 — 재료는 화면 위에서 떨어져 들어오므로(§13) 낙하 중엔 천장을 스폰 위치 위로 올려 둔다.
    private var spawnCeiling: CGFloat { size.height + spawnHeadroom }
    /// 물속 튜닝으로 종단 속도가 크게 떨어져(§물성) 예전 700pt 낙하는 십수 초가 걸린다.
    /// 스폰을 화면 가까이 끌어내려 **보이지 않는 구간의 낙하 시간**을 줄인다(체감 정착 3초 목표).
    /// 칩 크기에 비례시켜 기기 폭이 달라져도 아래 스태거가 상한에 잘리지 않게 한다.
    private var spawnHeadroom: CGFloat { chipSide * 1.3 }
    /// 스폰 깊이(칩 변 대비, 밀폐 천장 **아래**) — 물속 스폰은 가시 영역 **안쪽** 상단에서 시작한다.
    /// 예전엔 화면 위 0.4s에서 0.85s씩 띄워 떨어뜨렸는데, 물속 속도(v_term 62~140)에선 그 안 보이는
    /// 구간을 내려오는 데만 몇 초가 걸렸다. 특히 **기울인 채 실행하면** 칩이 안 보이는 위쪽에서 벽에
    /// 눌린 채 미끄러져 **첫 3초간 화면이 텅 비었다**(시계열 계측으로 확인). 안쪽에서 시작하면
    /// 첫 프레임부터 재료가 보이고, 느린 침강을 **보이는 구간에서** 온전히 보여준다.
    private let spawnDepth: CGFloat = 0.33
    /// 스폰 세로 간격 — 가시 영역 안에 6개를 나눠 놓을 만큼만.
    private let spawnStagger: CGFloat = 0.16
    /// 천장이 지금 밀폐돼 있나 — 낙하가 끝나면 true가 되어 상자가 가시 영역과 일치한다.
    private var ceilingSealed = false
    /// 천장이 열린 채 흘러간 시간의 기준점(아래 maintainCeiling의 타임아웃용).
    private var unsealedSince: TimeInterval?
    /// 열린 천장을 이 시간 넘게 유지하지 않는다 — 낙하 도중 중력이 옆·위로 향하면 칩이 보이지 않는
    /// 위쪽에 갇혀 영원히 안 내려온다(이번 버그의 본체). 지나면 강제로 끌어내리고 밀폐한다.
    /// 물속 튜닝 후 상향. 가장 가벼운 재료의 종단 속도가 ~100pt/s라 스폰 지점에서 가시 영역까지
    /// 내려오는 데만 1.7초가 걸린다 — 1.6초로 두면 **정상적으로 천천히 내려오는 칩을 순간이동**시킨다.
    /// 진짜로 갇힌 경우(수평 중력)만 걸리도록 넉넉히 잡았다.
    private let sealTimeout: TimeInterval = 4.0

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        physicsWorld.gravity = Self.defaultGravity   // 적당히 — 가볍게 떨어지되 둥둥 뜨진 않게
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true   // 칩 z가 전부 달라(§안착 z-순서) 순서 결정적 — 안전
        // 칩·존을 굽기 **전에** 현재 스킴을 확정한다(첫 렌더부터 올바른 팔레트로).
        applyInterfaceStyle(view.traitCollection.userInterfaceStyle)
        if traitRegistration == nil {
            traitRegistration = view.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (v: SKView, _) in
                self?.applyInterfaceStyle(v.traitCollection.userInterfaceStyle)
            }
        }
        physicsWorld.contactDelegate = self   // 달그락 햅틱은 충돌 이벤트가 원천이다
        buildWalls()
        layoutZones()
        sync(pending)
        refreshTilt()   // 프레젠트 전에 켜진 tiltEnabled를 여기서 실제 센서 시작으로 옮긴다
        refreshClatter()
        // 프레젠트 전(view == nil)에 설정된 externallyPaused를 뷰에 반영 — 표시 중 경로에선
        // false·false라 첫 프레임 전에 pause되지 않는다.
        refreshPaused()
        // 포그라운드 복귀 시 시스템이 SKView를 자동 재개해 idle 정지화면을 다시 60fps로
        // 그린다 — pause를 재적용한다. 시스템 재개보다 늦게 돌도록 한 틱 미룬다.
        if foregroundObserver == nil {
            foregroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                DispatchQueue.main.async { self?.refreshPaused() }
            }
        }
    }

    /// 프레젠테이션 해제 — 옵저버를 여기서 풀어 SpriteView 재구성 시 중복 등록·누수를 막는다
    /// (didMove가 다시 등록). deinit은 안전망.
    override func willMove(from view: SKView) {
        tilt.stop()      // 화면에서 내려가면 센서부터 끈다(배터리)
        clatter.stop()   // 햅틱 엔진도 함께 내린다
        if let o = foregroundObserver {
            NotificationCenter.default.removeObserver(o)
            foregroundObserver = nil
        }
        if let r = traitRegistration {
            view.unregisterForTraitChanges(r)
            traitRegistration = nil
        }
        super.willMove(from: view)
    }

    deinit {
        if let o = foregroundObserver { NotificationCenter.default.removeObserver(o) }
    }

    // MARK: - 컬러 스킴 (라이트/다크)

    /// 스킴 확정 — 바뀌었으면 적응형 색을 쓰는 표면(판정 존, 폴백 칩 틴트)만 다시 굽는다.
    /// 실루엣 텍스처 캐시는 **비우지 않는다** — PaperSilhouette 팔레트는 전량 고정색(물성 원칙)이라
    /// 스킴과 무관하게 픽셀 동일, 비우면 전환 순간 메인 스레드 재렌더 히치만 생긴다.
    /// `.unspecified`는 라이트로 접는다(SKView가 항상 구체 스타일을 주긴 하지만 방어).
    private func applyInterfaceStyle(_ style: UIUserInterfaceStyle) {
        let resolved: UIUserInterfaceStyle = (style == .dark) ? .dark : .light
        guard resolved != interfaceStyle else { return }
        interfaceStyle = resolved
        retintForCurrentStyle()
    }

    /// 동적 색을 현재 스킴으로 **명시 해석**. SpriteKit 노드는 동적 UIColor를 보관만 할 뿐
    /// 트레이트 변화에 재해석하지 않아, 넣는 순간의 값(기본 라이트)으로 굳어버린다.
    private func resolvedUIColor(_ color: Color) -> UIColor {
        UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: interfaceStyle))
    }

    /// 스킴 전환 반영 — 적응형 색을 쓰는 표면만 다시 렌더한다.
    /// 실루엣 칩은 스킴 불변(캐시 유지)이라 폴백 틴트 사각형만 재해석하면 된다.
    private func retintForCurrentStyle() {
        for ing in pending {
            guard let node = chips[ing.id], node.colorBlendFactor == 1 else { continue }
            node.color = resolvedUIColor(ing.freshness.main)   // 폴백 칩(텍스처 실패)만 적응형
        }
        // 존은 렌더된 텍스처라 다시 만들어야 팔레트가 갱신된다(드래그 중이면 보이는 상태 유지).
        let wasVisible = (tossZone?.alpha ?? 0) > 0
        tossZone?.removeFromParent(); tossZone = nil
        ateZone?.removeFromParent();  ateZone = nil
        layoutZones()
        if wasVisible { setZones(visible: true) }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 1 else { return }
        // 칩 변이 실제로 달라졌으면 텍스처 캐시를 버린다(캐시 키에 side가 박혀 있음).
        if chipSideFor(oldSize) != chipSide { textureCache.removeAll() }
        buildWalls()
        layoutZones()
        wake()   // 리사이즈로 레이아웃이 바뀌었으니 한 번 굴려 재안착
    }

    /// 드래그 중인 재료를 손가락 쪽으로 **스프링처럼 끌어당긴다**(텔레포트 아님).
    /// 거리 비례 목표 속도 + 가속 제한 → 약간의 딜레이·관성(실감, §13.4). 동적 바디라 이웃을
    /// 부드럽게 밀 뿐 튕겨내지 않는다. 속도 상한으로 과격한 밀침을 막는다.
    override func update(_ currentTime: TimeInterval) {
        lastUpdateTime = currentTime   // didBegin엔 시간 인자가 없어 여기서 받아 둔다(햅틱 스로틀용)
        maintainCeiling(currentTime)   // 낙하가 끝나면 상자를 가시 영역에 밀폐(컨테인먼트의 핵심)
        if let node = dragged, let body = node.physicsBody {
            // 마그네틱 캡처 — 손가락이 바스켓 근처면 추종 목표가 바스켓 중심으로 스냅되어
            // 재료가 자석처럼 끌려 들어간다. 손가락이 벗어나면 다시 손가락을 따른다.
            let captured = captureZone(near: dragTarget)
            let goal = captured?.position ?? dragTarget
            let to = CGVector(dx: goal.x - node.position.x, dy: goal.y - node.position.y)
            let follow: CGFloat = captured != nil ? 13 : 9   // 캡처 중엔 더 민첩하게 착 붙게
            let maxSpeed: CGFloat = 820      // 추종 속도 상한 → 이웃을 과격하게 안 밀침
            var vx = to.dx * follow, vy = to.dy * follow
            let m = hypot(vx, vy)
            if m > maxSpeed { vx *= maxSpeed / m; vy *= maxSpeed / m }
            let inertia: CGFloat = 0.24      // 0~1, 클수록 가볍게(덜 묵직) 따라옴
            let v = body.velocity
            body.velocity = CGVector(dx: v.dx + (vx - v.dx) * inertia,
                                     dy: v.dy + (vy - v.dy) * inertia)
            highlight(tossZone, hovering: captured === tossZone)
            highlight(ateZone, hovering: captured === ateZone)
            return   // 드래그 중엔 절대 휴면 안 함
        }
        // 잔여 운동 능동 감쇠 — 볼록 폴리곤 바디라 오목 알파 지터는 없지만, 강한 중력의 접촉 해소
        // 임펄스로 착지 직후 미세 요동이 남을 수 있다. settleBand 미만(= 자유낙하·던지기 아님)만
        // 프레임당 20% 곱셈 감쇠 → 수 프레임 내 calm 대역으로 수렴. 고속 칩은 안 건드려 낙하·던지기의
        // 묵직함(§13.4)은 그대로.
        // 중력이 막 바뀐 직후(= 기울이는 중)엔 이 감쇠를 쉰다. 안 그러면 느린 가속이 매 프레임 20%씩
        // 깎여 **종단 2pt/s**에 갇히고, 정착한 더미는 기울여도 꿈쩍 않는다(물속 표류가 아예 안 보인다).
        // 손을 멈추면 카운터가 소진되며 평소의 감쇠·안착 동작으로 돌아간다.
        if dampSuppression > 0 {
            dampSuppression -= 1
        } else {
            for node in chips.values {
                guard let b = node.physicsBody else { continue }
                if hypot(b.velocity.dx, b.velocity.dy) < settleBand {
                    b.velocity = CGVector(dx: b.velocity.dx * jitterDamp, dy: b.velocity.dy * jitterDamp)
                    b.angularVelocity *= jitterDamp
                }
            }
        }
        // 드래그가 없을 때만 정착 판정 — 지터 때문에 '완전 정지'는 영원히 안 오므로,
        // calm 창(전 칩 v<calmSpeed 연속 0.5s) + 변위 검증(<settleDrift)으로 안착을 판정한다.
        // 변위 검증이 스폰 직후의 느린 낙하를 걸러낸다(v≈20은 calm 대역이지만 0.5s에 10pt+ 이동).
        if allChipsCalm() {
            if calmFrames == 0 { calmSnapshot = chips.mapValues(\.position) }
            calmFrames += 1
            if calmFrames >= calmThreshold {
                if chipsHeldStill() {
                    forceSettle()
                } else {
                    calmFrames = 0   // 아직 흐르는 중 — 창 재시작(스냅샷은 0→1 전이에서 갱신)
                }
            }
        } else {
            calmFrames = 0
            #if DEBUG
            logRestlessChipsIfNeeded(currentTime)
            #endif
        }
    }

    #if DEBUG
    private var lastRestlessLog: TimeInterval = 0
    /// 진단 — calm 진입을 막는 칩의 속도/각속도를 1초에 한 번만 로그(콘솔 폭주 방지).
    private func logRestlessChipsIfNeeded(_ now: TimeInterval) {
        guard now - lastRestlessLog > 1 else { return }
        lastRestlessLog = now
        for (id, node) in chips {
            guard let b = node.physicsBody else { continue }
            let speed = hypot(b.velocity.dx, b.velocity.dy)
            if speed >= calmSpeed {
                Logger(subsystem: "com.reffi.app", category: "scene")
                    .debug("restless \(id.uuidString.prefix(6)): v=\(speed, format: .fixed(precision: 1)) w=\(b.angularVelocity, format: .fixed(precision: 3))")
            }
        }
    }
    #endif

    /// 물리 시뮬레이션 직후 — 안착 z-순서를 y로 결정한다. 아래(작은 y) 재료가 더 앞에 그려져
    /// 자연스러운 더미가 된다. 상한 29로 클램프(존 z=30·popOut z=50보다 항상 아래).
    override func didSimulatePhysics() {
        for node in chips.values where node.physicsBody != nil {
            node.zPosition = min(29, 10 + (size.height - node.position.y) * 0.01)
        }
    }

    /// 모든 칩이 조용한가 — 지터(v 4~30)를 포함하는 넉넉한 대역. 진짜 안착은 변위 검증이 가른다.
    private func allChipsCalm() -> Bool {
        for node in chips.values {
            guard let b = node.physicsBody else { continue }
            if hypot(b.velocity.dx, b.velocity.dy) >= calmSpeed { return false }
        }
        return true
    }

    /// calm 창 시작 대비 모든 칩 변위 < settleDrift — 느린 낙하·미끄러짐(계속 흐르는 중)을 걸러낸다.
    private func chipsHeldStill() -> Bool {
        for (id, node) in chips {
            guard let p0 = calmSnapshot[id] else { return false }   // 창 도중 생긴 칩 → 안착 아님
            if hypot(node.position.x - p0.x, node.position.y - p0.y) >= settleDrift { return false }
        }
        return true
    }

    /// 변위 검증 통과 → 강제 안착(freeze). 지터로 요동하던 미세 속도를 그 자리에서 0으로 굳혀
    /// 시각적 '꿈틀'까지 없애고 재운다. 물리 파라미터는 건드리지 않는다.
    private func forceSettle() {
        for node in chips.values {
            node.physicsBody?.velocity = .zero
            node.physicsBody?.angularVelocity = 0
        }
        settleToIdle()
    }

    /// 정착 → idle. 정밀 충돌은 '움직일 가능성이 있는 동안'만이라 여기서 전부 내린다(B6).
    private func settleToIdle() {
        for node in chips.values { node.physicsBody?.usesPreciseCollisionDetection = false }
        idle = true
        refreshPaused()
        #if DEBUG
        Logger(subsystem: "com.reffi.app", category: "scene")
            .debug("force-settled after calm window (chips: \(self.chips.count), viewPaused: \(self.view?.isPaused ?? false))")
        #endif
    }

    /// 씬을 깨운다 — idle 해제 + calm 카운터·스냅샷 리셋. 재접촉 시 터널링 방지로 CCD를 다시 켠다.
    private func wake() {
        calmFrames = 0
        calmSnapshot.removeAll()
        dampSuppression = dampSuppressionFrames   // 기울임 반응 창 — idle 여부와 무관하게 갱신
        guard idle else { return }
        idle = false
        for node in chips.values { node.physicsBody?.usesPreciseCollisionDetection = true }
        refreshPaused()
    }

    /// isPaused의 **유일한** 세터 — 외부 일시정지 또는 자체 휴면이면 멈춘다(SSOT).
    /// 씬만 멈추면 SKView 렌더 루프(60fps 재드로우)가 계속 돌아 유휴 CPU가 남는다 —
    /// 뷰까지 함께 멈춰 마지막 프레임이 정지화면으로 남는다. 표시 중 경로에선 항상 첫 프레임
    /// 이후에만 pause되고(터치는 paused여도 UIKit으로 전달 → touchesBegan의 wake()가 재개),
    /// 가려진 채 프레젠트될 때만 즉시 멈춘다(안 보이므로 무해).
    private func refreshPaused() {
        isPaused = externallyPaused || idle
        view?.isPaused = isPaused
    }

    /// 손가락 위치 기준 캡처 바스켓(반경 내 가장 가까운 것).
    private func captureZone(near p: CGPoint) -> SKSpriteNode? {
        var best: (zone: SKSpriteNode, d: CGFloat)?
        for z in [tossZone, ateZone].compactMap({ $0 }) {
            let d = hypot(p.x - z.position.x, p.y - z.position.y)
            if d < magnetRadius, d < (best?.d ?? .infinity) { best = (z, d) }
        }
        return best?.zone
    }

    // MARK: - 판정 존 (§13.6 B)

    /// 존 스프라이트 — PaperBlob + 채운 아이콘을 텍스처로 렌더. 평소엔 숨김(alpha 0).
    private func makeZone(toss: Bool) -> SKSpriteNode {
        let tint = toss ? ReffiColor.urgentDark : ReffiColor.blueDark
        let view = ZStack {
            PaperBlob(sides: 9, seed: toss ? 3 : 6)
                .fill(toss ? ReffiColor.urgentLight : ReffiColor.blueLight)
            PaperBlob(sides: 9, seed: toss ? 3 : 6)
                .stroke(tint.opacity(0.35), lineWidth: 1.5)
            (toss ? ReffiIcon.toss : ReffiIcon.ate).reffi(30, .fill)
                .foregroundStyle(tint)
        }
        .frame(width: zoneSide, height: zoneSide)
        // ImageRenderer는 환경을 명시하지 않으면 항상 라이트로 해석한다 — 적응형 토큰이 든 뷰엔 필수.
        .environment(\.colorScheme, interfaceStyle == .dark ? .dark : .light)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        let node = SKSpriteNode(texture: renderer.uiImage.map { SKTexture(image: $0) },
                                size: CGSize(width: zoneSide, height: zoneSide))
        node.alpha = 0
        node.zPosition = 30
        return node
    }

    private func layoutZones() {
        guard size.width > 1 else { return }
        if tossZone == nil { let z = makeZone(toss: true); tossZone = z; addChild(z) }
        if ateZone == nil { let z = makeZone(toss: false); ateZone = z; addChild(z) }
        // 상단 모서리 — 더미(바닥)와 겹치지 않고, 들어 올려서 넣는 제스처가 자연스럽다.
        // 존은 **가려지지 않는 영역** 위끝에 — 배너 뒤로 올라가면 드래그 타깃이 안 보인다.
        let y = clearHeight - zoneSide * 0.5 - 12
        tossZone?.position = CGPoint(x: zoneSide * 0.5 + 14, y: y)
        ateZone?.position = CGPoint(x: size.width - zoneSide * 0.5 - 14, y: y)
    }

    /// 드래그 시작/끝에만 보인다 — 평소엔 물리 필드를 어지럽히지 않는다.
    private func setZones(visible: Bool) {
        let fade = SKAction.fadeAlpha(to: visible ? 0.96 : 0, duration: 0.15)
        tossZone?.run(fade)
        ateZone?.run(fade)
        if !visible {
            tossZone?.setScale(1)
            ateZone?.setScale(1)
        }
    }

    private func highlight(_ zone: SKSpriteNode?, hovering: Bool) {
        guard let z = zone else { return }
        let target: CGFloat = hovering ? 1.14 : 1.0
        if abs(z.xScale - target) > 0.01 { z.run(.scale(to: target, duration: 0.1)) }
    }

    /// 바닥(요리시작 버튼 마진) + 좌·우 벽 + 천장으로 **완전히 닫힌 상자**.
    /// 좌·우는 `wallInset`만큼 안쪽이라 그림까지 화면 안에 남고, 천장은 낙하 중에만 열려 있다
    /// (`ceilingSealed`). 밀폐되면 상자가 가시 영역과 일치해 **어느 중력 방향에서도** 재료가 안 샌다.
    private func buildWalls() {
        guard size.width > 1, size.height > 1 else { return }
        childNode(withName: "walls")?.removeFromParent()
        let top = ceilingSealed ? sealedCeiling : spawnCeiling
        let rect = CGRect(x: wallInset, y: floorY,
                          width: max(1, size.width - wallInset * 2), height: max(1, top - floorY))
        let walls = SKNode()
        walls.name = "walls"
        walls.physicsBody = SKPhysicsBody(edgeLoopFrom: rect)   // 닫힌 루프(상자)
        walls.physicsBody?.friction = 0.7
        walls.physicsBody?.categoryBitMask = Category.wall
        walls.physicsBody?.contactTestBitMask = Category.chip   // 벽에 부딪히는 것도 달그락이다
        addChild(walls)
    }

    /// 천장을 연다 — 새 재료가 화면 위에서 떨어져 들어오기 직전에 부른다.
    /// 밀폐된 채로 스폰하면 칩이 천장 **위**에 얹혀 영영 안 보인다.
    private func openCeiling() {
        guard ceilingSealed else { return }
        ceilingSealed = false
        buildWalls()
    }

    /// 천장 관리(매 프레임) — 모든 칩이 가시 영역 안으로 들어오면 밀폐하고, 낙하 중이면 열어 둔다.
    /// 열린 채 `sealTimeout`이 지나면(= 기울기 탓에 위쪽에 갇힌 칩이 있다는 뜻) 강제로 끌어내리고 밀폐해
    /// "화면 밖으로 나가서 안 돌아옴"을 구조적으로 불가능하게 만든다.
    private func maintainCeiling(_ now: TimeInterval) {
        guard size.width > 1, size.height > 1 else { return }
        let strays = chips.values.filter { $0.position.y > sealedCeiling }
        guard !strays.isEmpty else {
            unsealedSince = nil
            if !ceilingSealed { ceilingSealed = true; buildWalls() }
            return
        }
        openCeiling()
        let since = unsealedSince ?? now
        unsealedSince = since
        guard now - since > sealTimeout else { return }
        // 갇힌 칩 회수 — 가시 영역 상단 바로 아래로 내려놓고 속도를 죽인 뒤 상자를 닫는다.
        for node in strays {
            node.position.y = sealedCeiling - chipSide * 0.5
            node.physicsBody?.velocity = .zero
            node.physicsBody?.angularVelocity = 0
        }
        unsealedSince = nil
        ceilingSealed = true
        buildWalls()
        wake()
    }

    /// 표시용 실루엣 텍스처(종이 그림자 포함)를 캐시한다. 충돌체는 이 텍스처 알파가 아니라
    /// 실측 폴리곤(`makeBody`)이라, 여기선 표시용(shadowed: true)만 쓴다(shadowless는 진단용 잔존).
    /// 캐시 키에 side가 들어가 리사이즈로 변이 달라지면 자동 무효(캐시 removeAll은 didChangeSize).
    private func texture(for ing: Ingredient, side: CGFloat, shadowed: Bool) -> SKTexture? {
        // 캐시 키에 스킴은 없다 — PaperSilhouette 팔레트는 전량 고정색이라 라이트/다크가 픽셀 동일.
        let key = "\(ing.glyph.rawValue)@\(Int(side))" + (shadowed ? "" : "#body")
        if let t = textureCache[key] { return t }
        let view = PaperSilhouette(glyph: ing.glyph, fresh: ing.freshness, shadowed: shadowed)
            .frame(width: side, height: side)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        guard let img = renderer.uiImage else { return nil }
        let t = SKTexture(image: img)
        textureCache[key] = t
        return t
    }

    func sync(_ ingredients: [Ingredient]) {
        pending = ingredients
        guard size.width > 1 else { return }
        wake()   // 재료 추가·제거·재생성은 새 물리 이벤트 — 휴면이면 깨운다
        let ids = Set(ingredients.map(\.id))
        // 빠진 재료는 뿅 사라짐(스프링 팝). 새 재료는 추가.
        for (id, node) in chips where !ids.contains(id) {
            popOut(node, id: id)
        }
        for (i, ing) in ingredients.enumerated() {
            if let node = chips[ing.id] {
                // 이름이 편집됐으면(글리프도 바뀔 수 있음) 칩을 다시 만든다.
                if (node.userData?["name"] as? String) != ing.name {
                    popOut(node, id: ing.id)
                    addChip(ing, order: i, count: ingredients.count)
                }
            } else {
                addChip(ing, order: i, count: ingredients.count)
            }
        }
    }

    /// 제거 연출 — 살짝 커졌다(easeOut) → 뿅 줄며 사라짐(easeIn). Reduce Motion이면 빠른 페이드만.
    /// 제거 중인 노드는 이름을 지워 다시 잡히지 않게 하고, 드래그 중이었다면 드래그 상태도 정리한다.
    private func popOut(_ node: SKSpriteNode, id: UUID) {
        chips[id] = nil
        node.name = nil          // 사라지는 중엔 히트 대상에서 제외
        node.physicsBody = nil   // 물리 정지(충돌에서 제외)
        node.zPosition = 50
        if node === dragged { dragged = nil; dragTouch = nil }

        if reduceMotion {
            node.run(.sequence([.fadeOut(withDuration: 0.12), .removeFromParent()]))
        } else {
            let grow = SKAction.scale(to: node.xScale * 1.25, duration: 0.13); grow.timingMode = .easeOut
            let pop = SKAction.scale(to: 0.0, duration: 0.17); pop.timingMode = .easeIn
            let fade = SKAction.fadeOut(withDuration: 0.17)
            node.run(.sequence([grow, .group([pop, fade]), .removeFromParent()]))
        }
    }

    private func addChip(_ ing: Ingredient, order: Int, count: Int) {
        let s = chipSide
        let node: SKSpriteNode
        if let disp = texture(for: ing, side: s, shadowed: true) {
            node = SKSpriteNode(texture: disp, size: CGSize(width: s, height: s))
        } else {
            // 폴백 단색 — 동적 UIColor를 그대로 주면 라이트 값으로 굳으므로 현재 스킴으로 해석해 넣는다.
            node = SKSpriteNode(color: resolvedUIColor(ing.freshness.main), size: CGSize(width: s, height: s))
        }
        // 충돌체 = **실측 알파 bbox 기반 볼록 폴리곤**(makeBody). 오목 알파 텍스처 바디는 접촉 해소
        // 지터가 영원히 안 죽고(브로콜리 겹침·요동의 원인) 비용도 크다 — 실측으로 실루엣에 딱 맞춘
        // 볼록 바디가 겹침 없이 안정적으로 쌓인다.
        let body = makeBody(for: ing.glyph, side: s)
        node.physicsBody = body
        node.name = "chip:\(ing.id.uuidString)"
        // glyph는 충돌 시 촉감(sharpness·세기)을 되찾기 위해 함께 싣는다.
        node.userData = ["name": ing.name, "glyph": ing.glyph.rawValue]
        // 달그락용 contact 태그. collisionBitMask는 기본값 그대로라 물리 거동은 안 바뀐다.
        body.categoryBitMask = Category.chip
        body.contactTestBitMask = Category.chip | Category.wall
        // 물성은 글리프 종류별 차등(아래 ChipMaterial) — 같은 크기라도 소고기는 묵직하게 눌러앉고
        // 잎채소는 가볍게 튀며, 계란은 기울이면 데굴데굴 굴러간다.
        let mat = Self.material(for: ing.glyph)
        body.mass = mat.mass
        body.restitution = mat.restitution
        body.friction = mat.friction
        // 침강 속도에 ±10% 결정적 지터 — 같은 클래스끼리도 미묘하게 다른 속도로 내려온다.
        let jitter = 0.9 + 0.2 * Self.stableJitter(ing.id)
        body.linearDamping = mat.linearDamping * jitter
        body.angularDamping = mat.angularDamping
        body.allowsRotation = true       // 자연스러운 물리 — 기울고 굴러 빈틈에 안착
        body.usesPreciseCollisionDetection = true

        // 가운데 좁은 밴드로 모아 떨어뜨려 **한 더미로 쌓이게** 한다(좌우로 흩지 않음).
        let n = max(1, count)
        let frac = n == 1 ? 0.5 : CGFloat(order) / CGFloat(n - 1)        // 0..1
        let band = min(size.width * 0.66, s * 2.1)                      // 더미 밑변 폭(가운데로 모으되 탑처럼 쌓지 않게)
        let x = size.width / 2 + (frac - 0.5) * band
        node.zRotation = (order % 2 == 0) ? 0.16 : -0.18
        if reduceMotion {
            node.position = CGPoint(x: x, y: floorY + s * (0.45 + CGFloat(order % 3) * 0.5))
        } else {
            // 물속 스폰 — 가시 영역 안쪽 상단에 스태거로 놓고 천천히 가라앉힌다.
            // 상자 밖에서 시작하지 않으므로 천장을 열 필요가 없다(컨테인먼트가 계속 밀폐 상태).
            // 스폰은 **가려지지 않는 영역** 기준 — 씬이 화면 전체로 커졌다고 스폰까지 올리면
            // 런치 캐스케이드가 헤더·배너 텍스트 위를 가로질러 올라간다. 확장된 위쪽은
            // 기울기·셰이크로 굴러 올라갈 때만 쓰는 공간이다.
            let y = clearCeiling - s * (spawnDepth + CGFloat(order) * spawnStagger)
            node.position = CGPoint(x: x, y: max(floorY + s * 0.3, y))
        }
        addChild(node)
        chips[ing.id] = node
    }

    // MARK: - 재료 물성 (§13.4)

    /// 칩 하나의 물성. **질량**은 충돌에서 누가 누구를 미는지를(중력 가속도는 질량과 무관하므로
    /// 낙하 속도는 안 바뀐다), **반발**은 튀는 정도를, **마찰·각감쇠**는 기울였을 때 미끄러지는지
    /// 구르는지를 가른다. 드래그 추종은 속도를 직접 대입하므로(update) 질량과 무관하다.
    private struct ChipMaterial {
        let mass: CGFloat
        let restitution: CGFloat       // 0 = 안 튐, 클수록 통통
        let friction: CGFloat          // 클수록 안 미끄러짐
        let linearDamping: CGFloat     // 클수록 빨리 멈춤
        let angularDamping: CGFloat    // 작을수록 잘 구른다
        /// 달그락 햅틱의 날카로움 — 1에 가까울수록 쨍한 '클링'(캔·병), 0에 가까울수록 둔탁한 '툭'(고기).
        var sharpness: Float = 0.5
        /// 달그락 햅틱의 세기 배율 — 여린 재료(잎·두부)는 같은 임펄스라도 약하게 친다.
        var hapticScale: Float = 0.8

        // ── 물속 튜닝 (수중 부력감) ─────────────────────────────────────────
        // 설계 축은 **종단 속도**(v_term ≈ gravityMagnitude / linearDamping)다. 점성 매질에선
        // 물체가 곧 종단 속도에 도달해 **일정한 속도로 가라앉는다** — 그게 물속처럼 보이는 핵심이다.
        // 클래스마다 v_term을 다르게 줘 "물속 밀도"를 표현하고, 그 차이가 곧 **시차 침강**이 되어
        // 재료가 한 덩어리로 우르르 몰리지 않게 한다(가장 무거운 쪽이 가장 가벼운 쪽의 2.2배 속도).
        // restitution은 전부 거의 0 — 물이 바운스를 흡수한다. angularDamping도 올려 회전은 하늘하늘.
        //
        //   heavy 140 > container 122 > rolling 100 > standard 88 > soft 74 > light 62  (pt/s)
        //
        // 이 값들은 스크린샷 시계열로 튜닝했다. 1차 시도(v_term 100~224)는 기본 낙하가 1.5초 만에
        // 끝나 "물속"으로 안 읽혀서 감쇠를 일괄 1.6배로 올렸다. 지금은 체감 정착 ~2.5초.

        /// 기본 — 대부분의 채소·과일. 중간 밀도로 가라앉는다. (v_term 88)
        static let standard = ChipMaterial(mass: 0.70, restitution: 0.02, friction: 0.58,
                                           linearDamping: 0.32, angularDamping: 0.94)
        /// 가벼움 — 잎채소·버섯·빵. **거의 중성 부력**이라 가장 느리게 표류하듯 내려온다. (v_term 62)
        /// 촉감: 여린 '틱' — 잎사귀가 스치는 정도라 세기를 크게 낮춘다.
        static let light = ChipMaterial(mass: 0.40, restitution: 0.03, friction: 0.66,
                                        linearDamping: 0.45, angularDamping: 0.90,
                                        sharpness: 0.55, hapticScale: 0.42)
        /// 잘 구름 — 계란·토마토·사과처럼 둥글고 매끈한 것. 중간보다 조금 빨리 가라앉되,
        /// 마찰·각감쇠가 낮아 바닥에 닿으면 물살에 밀리듯 데굴데굴 굴러간다. (v_term 100)
        /// 촉감: 또각 — 단단한 껍질이 부딪히는 중간 날카로움.
        static let rolling = ChipMaterial(mass: 0.80, restitution: 0.04, friction: 0.30,
                                          linearDamping: 0.28, angularDamping: 0.78,
                                          sharpness: 0.68, hapticScale: 0.85)
        /// 묵직함 — 소고기·연어 등 덩어리 단백질. **가장 먼저 바닥에 가라앉아** 더미의 토대가 된다.
        /// 안 튀고, 기울여도 굼뜨게 미끄러지며 가벼운 재료를 밀어낸다. (v_term 140)
        /// 촉감: 둔탁한 '툭' — 살덩이가 떨어지는 소리. 세기는 크되 날카로움은 최소.
        static let heavy = ChipMaterial(mass: 1.40, restitution: 0.01, friction: 0.70,
                                        linearDamping: 0.20, angularDamping: 0.96,
                                        sharpness: 0.18, hapticScale: 1.0)
        /// 용기 — 우유갑·소스병·캔. 무겁고 표면이 매끈해 빨리 가라앉고 잘 미끄러진다. (v_term 122)
        /// 촉감: 쨍한 '클링' — 캔·유리병끼리 부딪히는 금속성. 이 계열이 달그락의 주인공이다.
        static let container = ChipMaterial(mass: 1.15, restitution: 0.02, friction: 0.46,
                                            linearDamping: 0.23, angularDamping: 0.92,
                                            sharpness: 0.95, hapticScale: 1.0)
        /// 물렁함 — 두부·밥·면·만두. 물을 머금은 듯 느리게 내려와 닿은 자리에 착 붙는다. (v_term 74)
        /// 촉감: 퍽 — 물먹은 덩어리라 거의 촉감이 없다(가장 약하고 가장 뭉툭).
        static let soft = ChipMaterial(mass: 0.75, restitution: 0.01, friction: 0.82,
                                       linearDamping: 0.38, angularDamping: 0.98,
                                       sharpness: 0.10, hapticScale: 0.50)
    }

    /// 글리프 → 물성. 51종을 하나씩 손으로 매기면 유지도 안 되고 의도도 흐려져,
    /// 손에 잡히는 느낌 6종으로 묶었다. **표에 없는 글리프는 전부 `.standard`**(= 기존 값)로 떨어진다
    /// (뿌리채소·오이·고추·가지·고구마·생강·새우·옥수수 등 무난한 중간 물성 재료들).
    private static let materials: [FoodGlyph: ChipMaterial] = [
        // 가벼움 — 잎·해조·버섯·빵
        .leaf: .light, .cabbage: .light, .seaweed: .light, .mushroom: .light,
        .broccoli: .light, .pea: .light, .bread: .light,
        // 잘 구름 — 둥글고 매끈
        .egg: .rolling, .tomato: .rolling, .apple: .rolling, .citrus: .rolling, .grape: .rolling,
        .berry: .rolling, .potato: .rolling, .onion: .rolling, .garlic: .rolling, .mango: .rolling,
        // 묵직함 — 덩어리 단백질·큰 과채
        .meat: .heavy, .fish: .heavy, .poultry: .heavy, .sausage: .heavy, .bacon: .heavy,
        .crab: .heavy, .squid: .heavy, .clam: .heavy,
        .pumpkin: .heavy, .watermelon: .heavy, .pineapple: .heavy,
        // 용기 — 갑·병·캔·유제품
        .milk: .container, .sauceBottle: .container, .can: .container, .honey: .container,
        .yogurt: .container, .butter: .container, .cheese: .container,
        // 물렁함 — 눌러 붙는 것
        .tofu: .soft, .rice: .soft, .noodles: .soft, .dumpling: .soft,
        .avocado: .soft, .banana: .soft,
    ]

    private static func material(for glyph: FoodGlyph) -> ChipMaterial {
        materials[glyph] ?? .standard
    }

    /// 락스텝 방지용 결정적 지터 0..1 — 같은 클래스 재료끼리도 침강 속도를 ±10% 흩어
    /// 완전히 같은 속도로 나란히 움직이는 "판박이 이동"을 없앤다.
    /// `Hasher`/`hashValue`는 프로세스마다 시드가 달라 재현되지 않으므로(스크린샷 QA가 흔들린다)
    /// UUID 바이트를 직접 접는 djb2로 **실행 간 동일한 값**을 만든다.
    private static func stableJitter(_ id: UUID) -> CGFloat {
        let u = id.uuid
        let bytes = [u.0, u.1, u.2, u.3, u.4, u.5, u.6, u.7,
                     u.8, u.9, u.10, u.11, u.12, u.13, u.14, u.15]
        var h: UInt64 = 5381
        for b in bytes { h = (h &* 33) &+ UInt64(b) }
        return CGFloat(h % 1000) / 1000
    }

    /// 글리프별 볼록 폴리곤 충돌체 — **실측 알파 bbox 기반**(`GlyphBodyMetrics`, `-glyphMetrics`로 재측정).
    /// (폭비·높이비) = 알파 bbox의 **90%**(시각보다 살짝 작게 → 겹쳐 보임 방지 + 아주 살짝 nestle),
    /// dy = 그려진 영역(bbox) 중심의 **시각 정렬 오프셋**(+ = 위, side 프랙션) — 상/하로 치우친 글리프
    /// (브로콜리·양파·국수 그릇 등)의 바디를 실제 그림에 맞춰 빈틈·겹침을 없앤다.
    /// 오목 알파 바디가 아니라 **볼록 폴리곤**이라 접촉 해소 지터가 원천적으로 없다.
    private func makeBody(for glyph: FoodGlyph, side s: CGFloat) -> SKPhysicsBody {
        let m = Self.bodyMetrics[glyph] ?? (0.62, 0.60, 0)
        return Self.ovalBody(s * m.w, s * m.h, dy: s * m.dy)
    }

    /// 실측 바디 파라미터 (폭비, 높이비, y오프셋[+위]) — `-glyphMetrics` 계측값(알파 bbox×0.9 + bbox중심 정렬).
    private static let bodyMetrics: [FoodGlyph: (w: CGFloat, h: CGFloat, dy: CGFloat)] = [
        .leaf: (0.52, 0.68, 0.00),  .root: (0.27, 0.67, -0.01), .squash: (0.35, 0.59, 0.03),
        .onion: (0.52, 0.65, -0.05), .tomato: (0.56, 0.60, 0.00), .pepper: (0.55, 0.64, -0.01),
        .mushroom: (0.59, 0.54, 0.02), .broccoli: (0.56, 0.62, 0.01), .potato: (0.59, 0.46, 0.00),
        .garlic: (0.46, 0.58, -0.03), .cucumber: (0.60, 0.59, 0.01), .pea: (0.59, 0.36, 0.06),
        .cabbage: (0.62, 0.59, -0.02), .chili: (0.30, 0.70, 0.00), .pumpkin: (0.60, 0.54, -0.02),
        .apple: (0.61, 0.67, 0.02),  .citrus: (0.60, 0.45, 0.00), .berry: (0.46, 0.61, -0.01),
        .avocado: (0.44, 0.62, 0.00), .banana: (0.61, 0.35, 0.05), .egg: (0.54, 0.59, 0.01),
        .tofu: (0.68, 0.42, -0.02),  .meat: (0.62, 0.47, 0.01),  .poultry: (0.42, 0.59, 0.01),
        .fish: (0.67, 0.40, 0.00),   .shrimp: (0.48, 0.57, -0.01), .milk: (0.41, 0.62, 0.00),
        .cheese: (0.62, 0.45, -0.04), .bread: (0.56, 0.54, -0.03), .rice: (0.54, 0.49, -0.03),
        .noodles: (0.56, 0.48, -0.06), .corn: (0.46, 0.59, 0.01), .sauceBottle: (0.30, 0.65, -0.01),
        .can: (0.45, 0.47, 0.00),
        // v2 신규 17종 — `-glyphMetrics` 실측(알파 bbox×0.9 + 질량중심 정렬).
        .eggplant: (0.35, 0.63, 0.03), .sweetPotato: (0.55, 0.28, 0.01), .ginger: (0.49, 0.40, 0.03),
        .seaweed: (0.51, 0.58, 0.00), .grape: (0.42, 0.54, 0.01), .watermelon: (0.63, 0.51, -0.02),
        .pineapple: (0.38, 0.65, 0.04), .mango: (0.52, 0.48, 0.00), .sausage: (0.57, 0.52, -0.02),
        .bacon: (0.67, 0.36, 0.00), .crab: (0.61, 0.54, 0.06), .squid: (0.29, 0.61, 0.03),
        .clam: (0.56, 0.43, 0.09), .yogurt: (0.44, 0.61, 0.01), .butter: (0.64, 0.33, 0.07),
        .honey: (0.43, 0.61, 0.07), .dumpling: (0.54, 0.32, 0.06),
        .generic: (0.60, 0.56, 0.01),
    ]

    /// 볼록 N각형 타원 바디(dy로 중심 오프셋) — SpriteKit `polygonFrom`은 볼록만 허용해 끼임·진동이 없다.
    private static func ovalBody(_ w: CGFloat, _ h: CGFloat, dy: CGFloat = 0, sides: Int = 14) -> SKPhysicsBody {
        let path = CGMutablePath()
        for i in 0..<sides {
            let a = CGFloat(i) / CGFloat(sides) * 2 * .pi
            let p = CGPoint(x: cos(a) * w / 2, y: sin(a) * h / 2 + dy)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return SKPhysicsBody(polygonFrom: path)
    }

    // MARK: - Drag / throw / tap (단일 터치 추적)

    /// 터치 지점의 재료 칩.
    private func chip(at p: CGPoint) -> SKSpriteNode? {
        for node in nodes(at: p) {
            guard let name = node.name else { continue }
            if name.hasPrefix("chip:"), let sprite = node as? SKSpriteNode { return sprite }
        }
        return nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // 씬이 휴면(paused)이어도 터치는 UIKit 리스폰더로 도착한다 — 여기서 먼저 깨워야
        // 이후 update()의 드래그 추종이 돈다. wake()가 calm 카운터·스냅샷도 리셋한다.
        wake()
        guard dragTouch == nil, let t = touches.first else { return }   // 이미 드래그 중이면 추가 손가락 무시
        let loc = t.location(in: self)
        guard let node = chip(at: loc) else { return }
        dragTouch = t
        dragged = node
        dragMoved = false
        dragStart = loc
        dragTarget = clampToBox(loc)
        setZones(visible: true)
        if let body = node.physicsBody {
            body.affectedByGravity = false   // 잡는 동안 중력 off → 손가락 추종(동적 유지)
            body.angularVelocity = 0
            body.usesPreciseCollisionDetection = true   // 던지기 터널링 방지(안착하면 다시 자동 false)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = dragTouch, touches.contains(t), dragged != nil else { return }
        let raw = t.location(in: self)
        // 탭/드래그 판정은 시작점 기준 **누적** 이동 — 아무리 천천히 끌어도 탭으로 오판하지 않는다.
        if hypot(raw.x - dragStart.x, raw.y - dragStart.y) > 8 { dragMoved = true }
        dragTarget = clampToBox(raw)   // 상자 밖으론 못 끌게 → 새지 않음. 실제 추종은 update()의 스프링.
    }

    /// 끌고 있는 재료의 중심을 상자 내부(반지름 마진)로 제한. 화면 위로도 못 끈다.
    private func clampToBox(_ p: CGPoint) -> CGPoint {
        let r = chipSide * 0.42
        let minX = wallInset + r, maxX = max(wallInset + r, size.width - wallInset - r)
        let minY = floorY + r,    maxY = max(floorY + r, sealedCeiling - r)
        return CGPoint(x: min(max(p.x, minX), maxX), y: min(max(p.y, minY), maxY))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = dragTouch, touches.contains(t) else { return }
        defer { dragTouch = nil; dragged = nil; setZones(visible: false) }
        guard let node = dragged, let body = node.physicsBody else { return }
        body.affectedByGravity = true   // 놓으면 중력 복귀 — 현재 속도 그대로 자연스럽게 던져짐
        let cap: CGFloat = 1000
        let m = hypot(body.velocity.dx, body.velocity.dy)
        if m > cap { body.velocity = CGVector(dx: body.velocity.dx * cap / m,
                                              dy: body.velocity.dy * cap / m) }
        let id = node.name.flatMap { UUID(uuidString: String($0.dropFirst(5))) }
        // 캡처된 채 놓으면 제스처 판정 — 휴지통 = Tossed, 냄비 = Ate.
        if dragMoved, let id, let zone = captureZone(near: dragTarget) {
            onDecide?(id, zone === tossZone)
            return
        }
        if !dragMoved, let id {
            onRemove?(id)   // 짧은 탭 = 판정 묻기
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = dragTouch, touches.contains(t) else { return }
        dragged?.physicsBody?.affectedByGravity = true
        dragTouch = nil
        dragged = nil
        setZones(visible: false)
    }
}
