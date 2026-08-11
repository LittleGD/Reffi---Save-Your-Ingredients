import CoreMotion
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
    private var dragGrabOffset: CGPoint = .zero   // 잡은 지점 - 칩 중심(놓을 때 토크 암으로 회전 유도)

    /// 외부 일시정지(탭 전환·커버 가림) — idle과 합성해 isPaused를 만든다. isPaused는 절대
    /// 직접 대입하지 않고 refreshPaused()만 만진다(SSOT). 외부에서 이 값만 바꾼다.
    /// 가려진 동안엔 모션 갱신도 멈춘다(안 보이는 씬 때문에 자이로를 돌릴 이유가 없다).
    var externallyPaused = false {
        didSet { if externallyPaused != oldValue { refreshPaused(); syncMotionUpdates() } }
    }
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
    private var foregroundObserver: NSObjectProtocol?      // 블록 옵저버라 명시 해제 필요
    private var memoryWarningObserver: NSObjectProtocol?   // 텍스처 캐시 비우기 — 동일 패턴

    // 기울임 중력 — CMDeviceMotion.gravity로 물리 중력을 돌린다(§13.4). 매핑·데드밴드 판정은
    // 순수 계산(GravityMapper)이라 테스트로 고정, 씬은 수명주기와 씬 상태 결합만 책임진다.
    private let motionManager = CMMotionManager()
    private var lastAppliedGravity = GravityMapper.fallback
    /// 무방향 대역(기기를 눕힘) 히스테리시스의 유일한 상태 — 판정은 GravityMapper가 순수 계산으로 한다.
    private var gravityDirectionless = false

    // 착지 임팩트 — 충돌 임펄스를 질량으로 나눈 근사 속도변화(pt/s)로 판정한다. calmSpeed(40)·
    // settleBand(80)와 **같은 단위**라 기존 안착 튜닝과 임계가 일관된다.
    private let squashImpact: CGFloat = 30       // 이 이상이면 눈에 보이는 착지 — 스쿼시
    private let hapticImpact: CGFloat = 90       // settleBand 위 — 쌓이는 더미의 잔접촉엔 안 울린다
    private let hapticImpactMax: CGFloat = 260   // 이 이상은 최대 세기(자유낙하·던지기)
    private let hapticInterval: TimeInterval = 0.12   // 연쇄 충돌이 진동으로 번지지 않게
    private var lastHapticAt: TimeInterval = 0
    private lazy var impactHaptic = UIImpactFeedbackGenerator(style: .light)

    /// 충돌 카테고리 — 접촉 콜백을 받으려면 마스크가 필요하다. collisionBitMask는 기본값(전체)을
    /// 유지해 **충돌 거동은 그대로**이고, contactTest만 새로 켠다.
    private enum Category {
        static let chip: UInt32 = 1 << 0
        static let wall: UInt32 = 1 << 1
    }

    // 컬러 스킴 — SpriteKit은 동적 UIColor를 트레이트 변화에 따라 다시 해석하지 않고,
    // ImageRenderer도 명시하지 않으면 항상 라이트로 렌더한다. 스킴을 씬이 직접 들고 있다가
    // 바뀌면 텍스처를 다시 굽는다(SKView의 trait 변경을 구독 — SwiftUI 쪽 배선 불필요).
    private var interfaceStyle: UIUserInterfaceStyle = .light
    private var traitRegistration: (any UITraitChangeRegistration)?

    /// 짧은 탭 = 판정 묻기(Ate/Tossed).
    var onRemove: ((UUID) -> Void)?
    /// 제스처 판정(§13.6 B) — 칩을 존에 끌어다 놓으면 (id, wasted). 탭 오버레이는 접근성 경로로 유지.
    var onDecide: ((UUID, Bool) -> Void)?
    /// Reduce Motion이면 기울임 중력을 끄고 상수 중력으로 되돌린다(예측 불가한 화면 움직임 제거, §7.4).
    var reduceMotion = false {
        didSet { if reduceMotion != oldValue { syncMotionUpdates(); wake() } }
    }

    // 판정 바스켓 — 드래그 중에만 나타나는 휴지통(좌상)·냄비(우상) 종이 블롭.
    // 손가락이 근처에 오면 재료가 자석처럼 끌려 들어간다(마그네틱 캡처).
    private var tossZone: SKSpriteNode?
    private var ateZone: SKSpriteNode?
    private let zoneSide: CGFloat = 86
    private let magnetRadius: CGFloat = 88

    // 던지기 회전 — 토크 암 계수(작을수록 잘 돈다)와 각속도 상한(rad/s).
    private let spinArm: CGFloat = 0.25
    private let spinCap: CGFloat = 6

    private var chipSide: CGFloat { chipSideFor(size) }
    private func chipSideFor(_ s: CGSize) -> CGFloat { min(max(124, s.width * 0.42), 188) }
    private var floorY: CGFloat { max(6, size.height * 0.03) }

    // MARK: - 컨테인먼트 경계 (§13.4)

    /// 좌·우 벽을 화면 끝이 아니라 **이만큼 안쪽**에 세운다.
    /// 칩 스프라이트는 s×s지만 실제로 그려지는 건 알파 bbox뿐이고, 충돌체는 다시 그 bbox의 **90%** 다
    /// (`bodyMetrics`). 그래서 바디가 화면 끝 벽에 닿아도 **그림은 계속 바깥으로 삐져나가** 잘려 보인다.
    /// 삐져나가는 양 = bbox반폭 - 바디반폭 = 바디폭 × (1/0.9 - 1) / 2 ≈ 바디폭 × 0.056.
    /// 표의 최대 바디폭이 0.68s이므로 약 0.038s. 테이블이 버린 가로 중심 오프셋(`dx`)과 회전 여유까지
    /// 얹어 0.09s로 잡았다.
    private var wallInset: CGFloat { max(2, chipSide * 0.09) }
    /// 밀폐 천장 — 가시 영역의 위끝. 벽·회수 목표·드래그 클램프가 모두 이 선을 쓴다.
    /// 밀폐되면 상자가 가시 영역과 일치해 **어느 중력 방향에서도** 재료가 화면 밖으로 안 샌다.
    private var sealedCeiling: CGFloat { max(1, size.height) - wallInset }
    /// 스폰 천장 — 재료는 화면 위에서 떨어져 들어오므로(§13) 낙하 중엔 천장을 스폰 위치 위로 올려 둔다.
    /// 값은 기존 `boxTop`(+700)을 그대로 유지한다 — 스폰 클램프가 이 값을 읽어 낙하 스태거 구성이
    /// 정해지므로, 낮추면 런치 캐스케이드의 그림이 통째로 달라진다.
    private var spawnCeiling: CGFloat { size.height + 700 }
    /// 천장이 지금 밀폐돼 있나 — 낙하가 끝나면 true가 되어 상자가 가시 영역과 일치한다.
    private var ceilingSealed = false
    /// 천장이 열린 채 흘러간 시간의 기준점(아래 maintainCeiling의 타임아웃용).
    private var unsealedSince: TimeInterval?
    /// 열린 천장을 이 시간 넘게 유지하지 않는다 — 낙하 도중 중력이 옆·위로 향하면 칩이 보이지 않는
    /// 위쪽에 갇혀 영원히 안 내려온다. 지나면 강제로 끌어내리고 밀폐한다.
    /// 값은 **런치 캐스케이드(스폰 +599pt에서 화면까지)를 넉넉히 넘도록** 잡은 안전값이다 —
    /// 짧게 잡으면 정상적으로 내려오는 중인 칩을 순간이동시킨다. 실낙하 시간은 계산식(v_term = g/λ)이
    /// 아니라 기기 실측(tiltLab 도입 후)으로 다시 유도해야 한다. TODO: 실측 후 재조정.
    private let sealTimeout: TimeInterval = 6.0

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        // 기본 = 상수 중력(적당히 — 가볍게 떨어지되 둥둥 뜨진 않게). 기기 모션이 붙으면 여기서 회전만 한다.
        physicsWorld.gravity = GravityMapper.fallback
        lastAppliedGravity = GravityMapper.fallback
        physicsWorld.contactDelegate = self   // 착지 스쿼시·햅틱
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true   // 칩 z가 전부 달라(§안착 z-순서) 순서 결정적 — 안전
        // 칩·존을 굽기 **전에** 현재 스킴을 확정한다(첫 렌더부터 올바른 팔레트로).
        applyInterfaceStyle(view.traitCollection.userInterfaceStyle)
        if traitRegistration == nil {
            traitRegistration = view.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (v: SKView, _) in
                self?.applyInterfaceStyle(v.traitCollection.userInterfaceStyle)
            }
        }
        buildWalls()
        layoutZones()
        sync(pending)
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
        // 메모리 경고 — 텍스처 캐시는 통째로 버린다(살아 있는 칩은 노드가 텍스처를 직접 붙들고 있어
        // 화면이 깨지지 않고, 다음 재료 변화에서 필요한 것만 다시 굽는다).
        if memoryWarningObserver == nil {
            memoryWarningObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
            ) { [weak self] _ in
                self?.textureCache.removeAll()
            }
        }
        syncMotionUpdates()
    }

    /// 프레젠테이션 해제 — 옵저버를 여기서 풀어 SpriteView 재구성 시 중복 등록·누수를 막는다
    /// (didMove가 다시 등록). deinit은 안전망.
    override func willMove(from view: SKView) {
        stopMotionUpdates()
        if let o = foregroundObserver {
            NotificationCenter.default.removeObserver(o)
            foregroundObserver = nil
        }
        if let o = memoryWarningObserver {
            NotificationCenter.default.removeObserver(o)
            memoryWarningObserver = nil
        }
        if let r = traitRegistration {
            view.unregisterForTraitChanges(r)
            traitRegistration = nil
        }
        super.willMove(from: view)
    }

    deinit {
        if let o = foregroundObserver { NotificationCenter.default.removeObserver(o) }
        if let o = memoryWarningObserver { NotificationCenter.default.removeObserver(o) }
        motionManager.stopDeviceMotionUpdates()   // 안전망(willMove가 정상 경로)
    }

    // MARK: - 기울임 중력 (CoreMotion)

    /// 모션 갱신 on/off를 씬 상태에서 **파생**시킨다 — 표시 중 + 안 가려짐 + Reduce Motion 아님 + 기기 지원.
    /// 조건이 하나라도 깨지면 즉시 멈춘다(시뮬레이터는 deviceMotion 미지원 → 항상 상수 중력).
    private func syncMotionUpdates() {
        let wanted = view != nil && !externallyPaused && !reduceMotion && motionManager.isDeviceMotionAvailable
        if wanted { startMotionUpdates() } else { stopMotionUpdates() }
    }

    private func startMotionUpdates() {
        guard !motionManager.isDeviceMotionActive else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        // 콜백을 메인 큐로 받아 씬 상태(중력·wake)를 렌더 스레드와 같은 큐에서만 만진다.
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let g = motion?.gravity else { return }
            self.applyDeviceGravity(x: g.x, y: g.y)
        }
    }

    /// 모션 중단 — 중력은 상수 폴백으로 되돌려 놓는다(기울인 채 탭을 벗어나도 다음 표시가 정상 감각).
    /// 중력이 **실제로 바뀌었으면 깨운다** — 기울인 채 잠든 더미는 기울어진 배치 그대로 얼어붙어 있어,
    /// 상수 중력만 되돌려 놓고 재우면 다음에 봤을 때 비스듬히 굳은 더미가 그대로 보인다.
    private func stopMotionUpdates() {
        if motionManager.isDeviceMotionActive { motionManager.stopDeviceMotionUpdates() }
        gravityDirectionless = false
        guard physicsWorld.gravity != GravityMapper.fallback else { return }
        physicsWorld.gravity = GravityMapper.fallback
        lastAppliedGravity = GravityMapper.fallback
        wake()   // calm 카운터·스냅샷 리셋 + idle 해제 → 복원된 중력으로 다시 굴러 재안착
    }

    /// 측정 중력 반영. 휴면 중엔 **깨울 만한 기울임**(wakeAngle)일 때만 적용한다 —
    /// 데드밴드(2°)로 야금야금 갱신하면 느린 회전이 영원히 wake 임계를 못 넘어 더미가 굳는다.
    /// 적용할 때마다 calm 창을 리셋해 안착 판정이 새 중력에서 다시 검증되게 한다.
    private func applyDeviceGravity(x: Double, y: Double) {
        // 인플라이트 콜백 방어 — 모션 콜백은 메인 큐에 이미 실려 있을 수 있어, stopMotionUpdates()
        // 직후에도 한 번 더 도착한다. 그대로 받으면 방금 가려진(또는 뷰를 떠난) 씬을 다시 기울이고 깨운다.
        guard view != nil, !externallyPaused else { return }
        let sample = GravityMapper.sample(x: x, y: y, wasDirectionless: gravityDirectionless)
        gravityDirectionless = sample.directionless
        let candidate = sample.gravity
        if idle {
            guard GravityMapper.shouldWake(sample, lastApplied: lastAppliedGravity) else { return }
            physicsWorld.gravity = candidate
            lastAppliedGravity = candidate
            wake()   // calm 카운터·스냅샷 리셋 포함
        } else {
            guard GravityMapper.shouldApply(candidate, lastApplied: lastAppliedGravity) else { return }
            physicsWorld.gravity = candidate
            lastAppliedGravity = candidate
            calmFrames = 0
            calmSnapshot.removeAll()
            // 이 경로는 일부러 wake()를 안 부른다(이미 깨어 있다) — 감쇠 유예는 여기서 직접 갱신한다.
            dampSuppression = dampSuppressionFrames
        }
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
        tuckStraysUnderCeiling()   // 천장이 내려오면 그 위에 남은 칩은 즉시 회수(스스로 못 들어온다)
        layoutZones()
        wake()   // 리사이즈로 레이아웃이 바뀌었으니 한 번 굴려 재안착
    }

    /// 드래그 중인 재료를 손가락 쪽으로 **스프링처럼 끌어당긴다**(텔레포트 아님).
    /// 거리 비례 목표 속도 + 가속 제한 → 약간의 딜레이·관성(실감, §13.4). 동적 바디라 이웃을
    /// 부드럽게 밀 뿐 튕겨내지 않는다. 속도 상한으로 과격한 밀침을 막는다.
    override func update(_ currentTime: TimeInterval) {
        maintainCeiling(currentTime)   // 낙하 끝나면 밀폐, 위쪽에 갇힌 칩은 회수(§13.4 컨테인먼트)
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
        // 깎여 **종단 2pt/s**에 갇히고, 정착한 더미는 기울여도 꿈쩍 않는다(기울임이 아예 안 보인다).
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
        for node in chips.values {
            node.physicsBody?.usesPreciseCollisionDetection = false
            // 스쿼시 액션이 남은 채 pause되면 눌린 모양으로 얼어붙는다 — 여기서 끊고 배율을 1로 굳힌다.
            node.removeAction(forKey: "squash")
            node.setScale(1)
        }
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
        impactHaptic.prepare()   // 곧 물리 이벤트가 온다 — 첫 착지 진동의 지연을 없앤다
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
        let y = size.height - zoneSide * 0.5 - 12
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
        walls.physicsBody?.contactTestBitMask = Category.chip   // 바닥 착지도 임팩트로 친다
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
        // 갇힌 칩 회수 — 천장 바로 아래로 내려놓고 속도를 죽인 뒤 상자를 닫는다.
        tuckStraysUnderCeiling()
        unsealedSince = nil
        ceilingSealed = true
        buildWalls()
        wake()
    }

    /// 천장 **위**에 남은 칩을 상자 안으로 끌어들인다.
    ///
    /// 밀폐된 상자 바깥(위)에 놓인 칩은 스스로 못 들어온다 — 위로 기울인 상태면 그대로 떠올라
    /// 감쇠(`jitterDamp`)에 얼어붙고, 그러면 씬이 안착으로 판정해 잠들어(`forceSettle`) `maintainCeiling`의
    /// 타임아웃이 **영영 돌지 않는다**(재료가 화면 밖에서 사라진 것처럼 보였다).
    /// 그래서 `maintainCeiling`의 지연 회수와 별개로, 천장이 내려오는 순간에도 즉시 회수한다.
    private func tuckStraysUnderCeiling() {
        let ceiling = sealedCeiling
        for node in chips.values where node.position.y > ceiling {
            node.position.y = ceiling - chipSide * 0.5
            node.physicsBody?.velocity = .zero
            node.physicsBody?.angularVelocity = 0
        }
    }

    /// 표시용 실루엣 텍스처(종이 그림자 포함)를 캐시한다. 충돌체는 이 텍스처 알파가 아니라
    /// 실측 폴리곤(`makeBody`)이라, 여기선 표시용(shadowed: true)만 쓴다(shadowless는 진단용 잔존).
    /// 무효화 경로 셋: 리사이즈(didChangeSize의 removeAll — 키에 side가 박혀 있다),
    /// 동기화 직후 미사용분 제거(`evictUnusedTextures`), 메모리 경고(전량 removeAll).
    private func texture(for ing: Ingredient, side: CGFloat, shadowed: Bool) -> SKTexture? {
        let key = Self.textureKey(for: ing, side: side, shadowed: shadowed)
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

    /// 캐시 키 — 캐시에 넣는 쪽과 청소하는 쪽이 **같은 식**을 쓰도록 한 곳에 둔다.
    /// 스킴은 없다 — PaperSilhouette 팔레트는 전량 고정색이라 라이트/다크가 픽셀 동일.
    /// 신선도는 들어간다 — 같은 글리프라도 시듦(채도·명도·스쿼시·기울임)이 달라 픽셀이 다르다.
    private static func textureKey(for ing: Ingredient, side: CGFloat, shadowed: Bool) -> String {
        "\(ing.glyph.rawValue)@\(Int(side))@\(WiltStyle.for(ing.freshness).token)" + (shadowed ? "" : "#body")
    }

    /// 캐시 상한 — 키에 (글리프·변·시듦)이 들어가 재료가 바뀌거나 날이 넘어갈 때마다 새 키가 생긴다.
    /// 방치하면 세션 내내 단조 증가하므로(시듦 3단계가 글리프당 키를 3배로 불린다), 동기화 직후
    /// **지금 화면에 있는 칩이 실제로 쓰는 키만** 남긴다. 변은 칩 노드의 실측을 쓴다 — 리사이즈 전에
    /// 만들어진 칩은 옛 변을 그대로 갖고 있어(rewilt가 그 변으로 다시 굽는다) 현재 chipSide와 다를 수 있다.
    private func evictUnusedTextures() {
        guard !textureCache.isEmpty else { return }
        var live = Set<String>()
        for ing in pending {
            let side = chips[ing.id]?.size.width ?? chipSide
            live.insert(Self.textureKey(for: ing, side: side, shadowed: true))
            live.insert(Self.textureKey(for: ing, side: side, shadowed: false))
        }
        // live에는 아직 굽지 않은 키(#body 진단 변형)도 섞이므로 개수 비교로 건너뛰지 않는다 — 항상 훑는다.
        textureCache = textureCache.filter { live.contains($0.key) }
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
                } else if (node.userData?["wilt"] as? String) != WiltStyle.for(ing.freshness).token {
                    // 날짜가 넘어가 신선도만 바뀐 경우 — 칩을 다시 떨어뜨리지 않고 제자리에서 시들게 한다.
                    rewilt(node, ing)
                }
            } else {
                addChip(ing, order: i, count: ingredients.count)
            }
        }
        evictUnusedTextures()   // 칩 확정 후 — 더 이상 아무도 안 쓰는 텍스처를 버린다(캐시 상한)
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
        node.userData = ["name": ing.name, "wilt": WiltStyle.for(ing.freshness).token]
        body.restitution = 0.12          // 살짝 통통 — 가벼운 느낌
        body.friction = 0.55
        body.linearDamping = 0.2         // 둥둥 뜨진 않게, 빨리 안착
        body.angularDamping = 0.85       // 자연스럽게 기울며 안착하되 무한 회전은 억제
        body.allowsRotation = true       // 자연스러운 물리 — 기울고 굴러 빈틈에 안착
        // 질량은 실측 바디 면적비에서 파생 — 큰 칩이 작은 칩을 밀어내는 게 눈에 보인다.
        // 드래그 추종·던지기 상한은 **속도를 직접 조종**하므로 질량과 무관하다(감각 불변).
        // 즉 질량 차이는 충돌·밀침에서만 드러난다.
        body.mass = Self.mass(for: ing.glyph)
        body.categoryBitMask = Category.chip
        body.contactTestBitMask = Category.chip | Category.wall   // collisionBitMask는 기본값 유지
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
            // 위에서 스태거 낙하 → 더미. 스폰은 항상 **스폰 천장** 아래로 클램프하고, 밀폐돼 있으면
            // 먼저 연다 — 밀폐된 채로 화면 위에 놓으면 칩이 천장 **위**에 얹혀 영영 안 보인다.
            openCeiling()
            let y = min(size.height + s * (0.4 + CGFloat(order) * 0.85), spawnCeiling - s * 0.6)
            node.position = CGPoint(x: x, y: y)
        }
        addChild(node)
        chips[ing.id] = node
    }

    /// 신선도 변화(날짜 롤오버·소비기한 편집) 반영 — **텍스처만** 다시 구워 쌓인 자리를 지킨 채 시들게 한다.
    /// 물리 바디는 일부러 그대로 둔다: 충돌체는 `.fresh` 기준 실측(`GlyphBodyMetrics`) 폴리곤이고
    /// 시듦은 3~7% 시각 스쿼시라, 콜라이더를 같이 줄이면 이미 안착한 더미가 통째로 재정렬되며
    /// 무너진다(쌓임·무게 튜닝도 전부 흔들린다). 시각-충돌 오차 3~7%는 허용한다.
    private func rewilt(_ node: SKSpriteNode, _ ing: Ingredient) {
        if let t = texture(for: ing, side: node.size.width, shadowed: true) {
            node.texture = t
            node.colorBlendFactor = 0    // 폴백 단색이었다면 텍스처가 틴트에 먹히지 않게 해제
        } else {
            node.color = resolvedUIColor(ing.freshness.main)   // 렌더 실패 시 폴백 틴트만 갱신
        }
        node.userData?["wilt"] = WiltStyle.for(ing.freshness).token
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

    /// 바디 면적(폭비×높이비)의 전체 평균 — 질량비의 기준. 타원 면적의 π/4는 비율에서 약분된다.
    private static let meanFootprint: CGFloat = {
        let areas = bodyMetrics.values.map { $0.w * $0.h }
        return areas.isEmpty ? 1 : areas.reduce(0, +) / CGFloat(areas.count)
    }()

    /// 글리프별 질량 — 기준 0.7에 면적비를 곱하고 [0.45, 1.1]로 클램프한다.
    /// 클램프가 없으면 납작한 글리프(고구마·버터)가 깃털처럼 튕겨 나가고 큰 글리프가 불도저가 된다.
    private static func mass(for glyph: FoodGlyph) -> CGFloat {
        let m = bodyMetrics[glyph] ?? (0.62, 0.60, 0)
        let ratio = (m.w * m.h) / meanFootprint
        return min(max(0.7 * ratio, 0.45), 1.1)
    }

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

    // MARK: - 착지 임팩트 (스쿼시 + 햅틱)

    /// 접촉 시작 — 임펄스를 질량으로 나눠 **근사 속도변화(pt/s)**로 환산한 뒤 판정한다.
    /// 임펄스 절대값은 질량 스케일에 딸려 다니지만, 나눈 값은 calmSpeed·settleBand와 같은 축이라
    /// "쌓이는 더미의 잔접촉"과 "실제 착지"를 기존 튜닝과 같은 기준으로 가른다.
    func didBegin(_ contact: SKPhysicsContact) {
        guard !idle, !externallyPaused else { return }
        let impulse = contact.collisionImpulse
        guard impulse > 0 else { return }
        var strongest: CGFloat = 0
        for body in [contact.bodyA, contact.bodyB] where body.categoryBitMask & Category.chip != 0 {
            let dv = impulse / max(0.2, body.mass)
            strongest = max(strongest, dv)
            guard dv >= squashImpact, let node = body.node as? SKSpriteNode else { continue }
            squash(node, strength: min(1, (dv - squashImpact) / (hapticImpactMax - squashImpact)))
        }
        if strongest >= hapticImpact { fireImpactHaptic(strongest) }
    }

    /// 착지 눌림 — 가로로 퍼지고 세로로 눌렸다가 복귀(최대 6%). 배율은 **정확히 1로** 되돌린다.
    /// 드래그 중인 칩과 Reduce Motion·휴면은 제외(손끝 추종이 흔들리지 않게, §7.4).
    private func squash(_ node: SKSpriteNode, strength: CGFloat) {
        guard !reduceMotion, !idle, node !== dragged else { return }
        guard node.action(forKey: "squash") == nil else { return }   // 연쇄 접촉으로 겹쳐 실행 금지
        let amt = 0.03 + 0.03 * min(1, max(0, strength))
        let d = ReffiMotion.dur2
        let press = SKAction.scaleX(to: 1 + amt, y: 1 - amt, duration: d * 0.35)
        press.timingMode = .easeOut
        let back = SKAction.scaleX(to: 1, y: 1, duration: d * 0.65)
        back.timingMode = .easeOut
        // 마지막에 한 번 더 확정 대입 — 중간에 액션이 끊겨도 배율 잔차가 남지 않는다.
        node.run(.sequence([press, back, .run { [weak node] in node?.setScale(1) }]), withKey: "squash")
    }

    /// 임팩트 진동 — 세기는 임팩트에 비례, 최소 간격을 둬 더미가 안착할 때 드르륵 울리지 않게 한다.
    private func fireImpactHaptic(_ dv: CGFloat) {
        let now = CACurrentMediaTime()
        guard now - lastHapticAt >= hapticInterval else { return }
        lastHapticAt = now
        let t = min(1, (dv - hapticImpact) / (hapticImpactMax - hapticImpact))
        impactHaptic.impactOccurred(intensity: 0.35 + 0.65 * t)
        impactHaptic.prepare()
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
        dragGrabOffset = CGPoint(x: loc.x - node.position.x, y: loc.y - node.position.y)
        setZones(visible: true)
        node.removeAction(forKey: "squash")   // 잡는 순간 눌림 연출은 끊고 배율 원복
        node.setScale(1)
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
        // 던질 때 회전 — 중심에서 벗어난 지점을 잡을수록 크게 돈다(토크 암). ω ≈ (r × v) / (side²·k),
        // side로 정규화해 칩 크기가 달라져도 감각이 같다. 잡을 때 각속도를 0으로 만든 뒤라 순수 발사 회전.
        let v = body.velocity
        let torque = dragGrabOffset.x * v.dy - dragGrabOffset.y * v.dx
        let s = chipSide
        let spin = torque / (s * s * spinArm)
        body.angularVelocity = min(max(spin, -spinCap), spinCap)
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
