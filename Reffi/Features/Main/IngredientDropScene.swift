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
    // 강제 안착(force-settle) — 알파 텍스처의 오목 충돌체는 접촉 해소 지터(관측 대역 v 4~30pt/s)가
    // 영원히 안 죽어 '완전 정지' 판정이 성립하지 않는다. 조용함(calm) 대역 + 변위 검증으로 판정하고
    // 통과하면 속도를 0으로 굳혀 재운다. 세 상수의 역할이 다르므로 값도 다르다:
    //   calmSpeed 40  — 판정 대역. 지터 상단(30)을 넉넉히 덮는다(여기 걸린다고 감쇠하진 않는다).
    //   jitterFloor 14 — **감쇠** 하한. 지터 대역의 아래 절반만 깎는다(아래 주석 참조).
    //   settleDrift 4  — 순변위 문턱. 진동성 지터(제자리 요동)와 느린 미끄러짐을 여기서 가른다.
    private var calmFrames = 0                       // calm 연속 프레임(임계 도달 시 변위 검증)
    private let calmThreshold = 30                   // ≈0.5s(60fps)
    private let calmSpeed: CGFloat = 40              // 이 미만이면 '조용' — 지터 대역을 포함
    /// **속도 스파이크 관용 프레임 수.** 640g(중력 42 m/s² = 6300pt/s²) 아래서 솔버는 정지한
    /// 더미에도 프레임당 105pt/s의 접촉 임펄스를 걸어야 하고, 그 잔차가 이따금 한 프레임짜리
    /// 스파이크(실측 50~104pt/s)로 튄다. 칩은 **10초에 3pt도 안 움직이는데**(실측) 그 스파이크
    /// 하나가 calm 창을 0으로 되돌려, 창이 30프레임을 영원히 못 채우고 force-settle이 성립하지
    /// 않았다(실측 calm 카운터가 0~6에서 무한 진동). 위치를 안 움직인 1프레임 스파이크는 안착을
    /// 뒤집을 근거가 못 된다 — 연속 breach가 이 수를 넘을 때만 창을 접는다.
    /// 판정의 엄밀함은 변위 검증(`settleDrift` 4pt)이 그대로 지킨다: 진짜 움직였으면 창이 되돌아간다.
    private let calmBreachTolerance = 4
    private var calmBreaches = 0
    private let settleDrift: CGFloat = 4             // calm 창 동안 이보다 덜 움직였으면 진짜 안착
    private var calmSnapshot: [UUID: CGPoint] = [:]  // calm 창 시작 시점의 칩 위치
    /// calm 창이 열린 시점의 중력 — 창을 접을지 판정하는 기준(`GravityMapper.shouldResetCalm`).
    /// 마지막 재적용값이 아니라 **창의 시작값**이어야 한다: 2°씩 야금야금 도는 손떨림을 매번
    /// 새 기준으로 갈아 끼우면 누적 회전이 영원히 문턱을 못 넘어 리셋 판정이 무의미해진다.
    private var calmGravity = GravityMapper.fallback
    /// 이 미만만 감쇠하는 **저속 지터 플로어** — 솔버 접촉 해소가 남기는 미세 요동 대역.
    /// 실기기 검증(v1.0 (2))의 교훈: 이전 설계(settleBand 80 미만 전부 감쇠 + 중력 변화 시 90프레임
    /// 유예)는 손떨림이 2° 데드밴드를 계속 넘겨 유예 창을 무한 리필했고, 감쇠가 영구 정지돼
    /// 더미가 쉼 없이 움찔거렸다. 유예가 끝나는 순간엔 느린 굴림(<80)이 프레임당 20%씩 깎여
    /// 얼었다 홱 움직이는 인위적 움직임이 됐다. 플로어를 낮게 내리고 **항상 켜 두면** 두 문제가
    /// 같이 사라진다 — 진짜 움직임은 이 대역보다 빨라 감쇠를 전혀 받지 않고, 지터는 자세와
    /// 무관하게 몇 프레임 안에 죽는다.
    /// **왜 지터 상단(30)이 아니라 14인가**: 14~40pt/s는 기울임 굴림이 실제로 사는 대역이다
    /// (기울기가 얕으면 칩이 이 속도로 천천히 구른다). 플로어를 30으로 올리면 그 굴림이
    /// 프레임당 20%씩 깎여 다시 '얼었다 홱' 감각으로 돌아간다 — 지터 상단 절반을 감쇠 대상에서
    /// 빼는 것은 의도된 선택이고, 그 대역은 감쇠가 아니라 calm 창 + 변위 검증이 책임진다.
    private let jitterFloor: CGFloat = 14
    private let jitterDamp: CGFloat = 0.8            // 플로어 미만의 프레임당 곱셈 감쇠
    /// **감쇠 하한 — 이 아래는 대입 자체를 생략한다.** 실기기 3차 피드백 ①("가만히 있어도 움찔움찔")의
    /// 구조적 원인이 여기였다: `SKPhysicsBody.velocity`/`angularVelocity`에 값을 넣는 행위는 그 자체로
    /// 바디를 **깨워** 엔진의 수면 타이머를 0으로 되돌린다. v≈0인 바디까지 매 프레임 곱해 다시
    /// 넣으면 솔버가 영원히 그 바디를 계산하고, 접촉 해소가 남기는 미세 진동도 영원히 안 죽는다
    /// (-physLab 실측: 구 코드는 20초 40샘플 240칩 관측 전부 `rest=0`, idle 도달 0회).
    /// 그래서 감쇠는 (jitterRestFloor, jitterFloor) **구간에서만** 곱하고, 그 아래는 손대지 않아
    /// 엔진이 스스로 재우게 둔다(`isResting` 존중). 이 대역은 프레임당 0.35pt 미만 = 보이지 않는다.
    private let jitterRestFloor: CGFloat = 2
    /// 각속도의 같은 규율(rad/s) — 0.05rad/s면 1초에 3°, 눈에 안 보인다.
    private let jitterRestSpin: CGFloat = 0.05
    private var foregroundObserver: NSObjectProtocol?      // 블록 옵저버라 명시 해제 필요
    private var memoryWarningObserver: NSObjectProtocol?   // 텍스처 캐시 비우기 — 동일 패턴

    // 기울임 중력 — CMDeviceMotion.gravity로 물리 중력을 돌린다(§13.4). 매핑·데드밴드 판정은
    // 순수 계산(GravityMapper)이라 테스트로 고정, 씬은 수명주기와 씬 상태 결합만 책임진다.
    // 센서 래퍼(IngredientTiltMotion)는 저역(중력)과 고역(userAcceleration = 흔들기)을 함께 넘긴다 —
    // 중력만으론 흔들기가 전달되지 않는다(저역 신호라 흔드는 동안에도 거의 안 변한다).
    private let tilt = IngredientTiltMotion()
    private var lastAppliedGravity = GravityMapper.fallback
    /// 무방향 대역(기기를 눕힘) 히스테리시스의 유일한 상태 — 판정은 GravityMapper가 순수 계산으로 한다.
    private var gravityDirectionless = false

    // 착지 임팩트 — 충돌 임펄스를 질량으로 나눈 근사 속도변화(pt/s)로 판정한다.
    // 이 축은 **시각(스쿼시) 전용**이다. 햅틱은 질량으로 나누지 않은 **생 임펄스**를 쓴다 —
    // 눌림은 속도의 문제(같은 높이서 떨어진 무거운/가벼운 칩이 같게 눌려야 한다)지만,
    // 촉감은 운동량 전달의 문제(소고기가 잎사귀보다 묵직하게 느껴져야 한다)라 축이 다르다.
    //
    // **임계가 정지 접촉 바닥 아래에 있었다**(실기기 3차 ①·④ "가만히 있어도 움찔움찔"의 정체).
    // 씬 중력 42는 m/s² 단위(SpriteKit 규약, 150pt = 1m) = **6300pt/s²**라, 바닥에 가만히
    // 놓인 칩도 매 프레임 g·dt = 105pt/s를 접촉 임펄스로 상쇄한다. 옛 임계 30은 그 바닥의
    // 1/3이라 **모든 정지 접촉이 통과했고**, 상한 260도 정지 접촉의 관측 최대(≈470)보다 낮아
    // 더미가 **최대 진폭으로 영구히 펄스**했다. -physLab 실측(정지한 더미 20초):
    //   접촉 95회/초 · 스쿼시 20회/초(칩당 쿨다운 상한에 붙어 있음) · Δv 평균 130 최대 470.
    //   진짜 착지(캐스케이드가 바닥을 치는 순간)는 Δv 평균 1074 최대 3104 — 두 대역이 완전히 갈린다.
    // 그래서 임계를 정지 대역 **위**로 올린다. 100pt 자유낙하만 해도 √(2×6300×100) ≈ 1120이라
    // 진짜 착지는 전부 통과하고, 20pt짜리 잔움직임(≈500)은 눌리지 않는다.
    private let squashImpact: CGFloat = 600       // 이 이상이면 눈에 보이는 착지 — 스쿼시
    private let squashImpactMax: CGFloat = 3000   // 이 이상은 최대 눌림(자유낙하·던지기)
    /// 착지 법선 정렬 하한 — |dot(접촉 법선, 중력 단위벡터)|이 이 이상이어야 '착지'로 본다.
    /// v1.0 (3) 실기기 피드백 "크기가 커졌다 작아지는 움찔거림이 심함"의 원인 게이트다:
    /// 기울여 굴릴 때 더미의 **옆접촉**(법선 ⟂ 중력)도 Δv 30을 쉽게 넘겨, 굴리는 내내
    /// 더미 전체가 숨쉬듯 눌렸다 폈다 했다. 실제 착지(바닥·더미 위)는 **어떤 중력 방향에서도**
    /// 법선이 중력축과 나란하므로(기울인 상태 포함) 그대로 통과한다.
    private let squashNormalAlign: CGFloat = 0.55
    /// 칩당 스쿼시 쿨다운(초). `action(forKey:)` 재진입 가드는 애니메이션 길이(~180ms)만 덮어,
    /// 끝나자마자 다음 접촉이 또 눌러 떨림이 이어졌다. 250ms로 한 칩의 눌림 빈도를 묶는다.
    private let squashCooldown: TimeInterval = 0.25

    // 달그락 햅틱(§13.4) — CoreHaptics 직접 구동. 세기·날카로움 두 축이 있어야 재료별 촉감이
    // 생기고, SwiftUI `.sensoryFeedback`은 파라미터가 없어 쓸 수 없다(§7.6 의미별 매핑은 그대로).
    private let clatter = IngredientClatterHaptics()
    private var clatterThrottle = ClatterThrottle()
    /// 임펄스·재료 → 촉감(세기·날카로움·감쇠 꼬리) 변환 규칙. 순수 계산기라 씬 없이 테스트된다.
    private let clatterRule = ClatterFeelRule()
    /// 물리량 → 구름 텍스처(HD Rumble의 구슬 시그니처) 변환 규칙. 역시 순수 계산기.
    private let rollRule = RollTextureRule()
    /// 지속 촉감의 개폐 히스테리시스 — **한 채널**이다. 드래그 중엔 호버, 아니면 구름이 쓰는데
    /// `update`가 드래그 분기에서 곧장 반환하므로 두 용도는 구조적으로 배타적이다.
    private var textureGate = TextureGate()
    /// 마지막으로 낸 구름 텍스처 — 관문 유예 중 한 프레임짜리 dip을 메운다.
    private var lastRollTexture: RollTexture?
    /// 마그네틱 캡처 스냅의 에지 검출 — 존이 **바뀌는** 순간에만 친다.
    private weak var lastCapturedZone: SKSpriteNode?
    /// 캡처 스냅 쿨다운(초) — 반경 경계에서 손가락이 떨면 진입/이탈이 연타된다.
    private let captureSnapCooldown: TimeInterval = 0.18
    private var lastCaptureSnapAt: TimeInterval = -1
    /// 스로틀 판정용 현재 시각 — `didBegin`엔 시간 인자가 없어 update에서 받아 둔다.
    private var lastUpdateTime: TimeInterval = 0
    /// QA 계측용 — 햅틱이 실제로 발화할 때마다 호출된다(TILT LAB 카운터).
    /// **충돌 달그락만 센다** — 이 카운터의 계약은 "달그락 발화율"이고, 텍스처·제스처 액센트까지
    /// 얹으면 지금까지 잡아 온 기준선과 갈린다(발화율 튜닝 기록이 전부 이 축에 매달려 있다).
    var onClatter: (() -> Void)?

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
    /// 정지 캡 높이(홈의 레이아웃 슬롯 실측) — 존 앵커와 무관하게 하늘이 아무리 열려도
    /// 존은 `restHeight + dragFieldHeadroom` 자리에 남는다(오너 결정: "존은 지금 위치가 좋다").
    var restHeight: CGFloat = 0
    /// Reduce Motion이면 기울임 중력을 끄고 상수 중력으로 되돌린다(예측 불가한 화면 움직임 제거, §7.4).
    var reduceMotion = false {
        didSet { if reduceMotion != oldValue { syncMotionUpdates(); wake() } }
    }
    /// 프로필 "기울임 중력" 토글(`ReffiFeedback.tiltKey`). **시스템 Reduce Motion이 우선이고 이건 그 위의
    /// 사용자 선택이다** — 둘 중 하나만 꺼도 자이로는 멈추고 상수 중력으로 되돌아간다(§7.4 · §13.4).
    /// 끄면 센서 갱신 자체를 내려 배터리도 아낀다(`syncMotionUpdates` → `stopMotionUpdates`).
    ///
    /// 초기값을 저장소에서 **직접** 읽는다 — 뷰 주입(`configureScene`)은 `didMove` 뒤에 올 수도 있어,
    /// 기본값 true로 서면 꺼 둔 사람도 홈에 들어서는 한 프레임 동안 센서가 돌아 버린다.
    var tiltEnabled = ReffiFeedback.tiltEnabled {
        didSet { if tiltEnabled != oldValue { syncMotionUpdates(); wake() } }
    }
    /// 프로필 "충돌 진동" 토글(`ReffiFeedback.hapticsKey`). 달그락 엔진까지 내린다 —
    /// 무음으로 켜 둔 CHHapticEngine은 배터리만 먹는다. 켜면 다음 프레임부터 곧장 되돌아온다.
    /// 초기값을 저장소에서 직접 읽는 이유는 `tiltEnabled`와 같다(엔진이 한 프레임 서지 않게).
    var hapticsEnabled = ReffiFeedback.hapticsEnabled {
        didSet { if hapticsEnabled != oldValue { syncClatterEngine() } }
    }

    // 판정 바스켓 — 드래그 중에만 나타나는 휴지통(좌상)·냄비(우상) 종이 블롭.
    // 손가락이 근처에 오면 재료가 자석처럼 끌려 들어간다(마그네틱 캡처).
    private var tossZone: SKSpriteNode?
    private var ateZone: SKSpriteNode?
    private let zoneSide: CGFloat = ReffiJudgeZone.side
    private let magnetRadius: CGFloat = 88

    #if DEBUG
    /// `-zoneLab` — 판정 존을 드래그 없이 **항상 표시**한다. 존은 SpriteKit 노드라 접근성 트리에
    /// 없고 드래그 중에만 보여서, 위치 회귀를 스크린샷으로 잡으려면 강제 표시 경로가 필요하다.
    private let zoneLab = ProcessInfo.processInfo.arguments.contains("-zoneLab")

    /// 회귀 테스트용 존 중심(씬 좌표) — 생성 전이면 nil. `debugTilt` 선례와 같은 QA 주입/관찰구.
    var debugZoneCenters: (toss: CGPoint, ate: CGPoint)? {
        guard let t = tossZone, let a = ateZone else { return nil }
        return (t.position, a.position)
    }

    /// `-physLab` — 물리 진단 모드. SKView의 콜라이더 오버레이(`showsPhysics`, MainView가 켠다)와
    /// **주기 계측 덤프**를 함께 켠다. 콜라이더-일러스트 정합·겹침·정지 움찔은 화면만 봐선 못 가른다:
    /// 오버레이는 "바디가 그림 어디에 서는가", 덤프는 "속도·isResting·쌍별 AABB 관통률"을 준다.
    /// 덤프는 앱 Documents/phys-lab.txt (`xcrun simctl get_app_container booted com.reffi.app data`).
    static let physLab = ProcessInfo.processInfo.arguments.contains("-physLab")
    private var physLabNext: TimeInterval = 0
    private var physLabSamples = 0
    private var physLabLog = ""
    /// 샘플 사이에 발생한 이벤트 수 — 정지한 더미에서 이게 0이 아니면 "누가 더미를 계속 건드리는가"의 답이다.
    private var physLabContacts = 0
    private var physLabSquashes = 0
    private var physLabSeparations = 0
    /// 접촉 Δv(= 임펄스/질량) 분포 — 착지 임계(squashImpact)가 **정지 접촉 바닥** 위에 있는지 보는 눈.
    private var physLabDvMax: CGFloat = 0
    private var physLabDvSum: CGFloat = 0
    private var physLabDvCount = 0
    private let physLabPeriod: TimeInterval = 0.5
    private let physLabMaxSamples = 40
    #endif

    // 던지기 회전 — 토크 암 계수(작을수록 잘 돈다)와 각속도 상한(rad/s).
    private let spinArm: CGFloat = 0.25
    private let spinCap: CGFloat = 6

    private var chipSide: CGFloat { Self.chipSideFor(size) }
    private static func chipSideFor(_ s: CGSize) -> CGFloat { min(max(124, s.width * 0.42), 188) }

    /// 정지 필드가 **한 줄 더미를 자르지 않기 위한 최소 높이** — 홈의 `fieldRestHeight` 캡이 이 하한을 존중한다.
    /// 캡 공식(96×행+28)은 여러 행이 눕고 맞물리는 더미의 실측 피치인데, 한 줄(재료 ≤3)에서는 상자가 124pt로
    /// 떨어져 **칩 하나의 그려지는 높이보다 작아진다** — 밀폐 천장은 칩 "중심"만 지키므로 정착은 정상 처리되고
    /// 일러스트 상단만 조용히 잘렸다(2026-08 실기 재현: milk 게이블이 수평으로 삭제). 그려지는 최대 높이 =
    /// 알파 bbox = 바디/0.9(`bodyMetrics` 계약) → side × maxBodyHeightRatio / 0.9, 여기에 캡 공식과 같은
    /// 바닥·헤드룸 28을 얹는다. 칩 기하의 정본이 씬이라 이 식도 씬에 산다.
    static func minRestFieldHeight(width: CGFloat) -> CGFloat {
        chipSideFor(CGSize(width: width, height: 0)) * (maxBodyHeightRatio / 0.9) + 28
    }

    /// 드래그 중 필드가 추가로 여는 높이 — 정지 캡은 더미를 껴안지만(감사 R3-4), 그 상자 그대로는
    /// **조작이 안 된다**: 더미 상단이 캡 −13pt까지 오는데 드래그 클램프 상한은 캡 −(벽 인셋 + 0.42s)
    /// ≈ 캡 −86pt라, 잡은 칩의 중심이 더미 상단보다 ~73pt 아래에 묶여 더미를 뚫고 밀 수밖에 없고,
    /// 존(캡 −55pt)은 더미 위에 얹힌다. 0.75s(≈127pt @402pt 폭)를 열면 클램프 상한이 더미 위로
    /// ~45pt, 존은 ~72pt 올라와 "들어서 나른다"가 성립한다. 놓으면 도로 닫힌다(캡의 미학은 정지 상태의 것).
    static func dragFieldHeadroom(width: CGFloat) -> CGFloat {
        chipSideFor(CGSize(width: width, height: 0)) * 0.75
    }

    /// 재료 ≥2의 정지 하한 — 행 피치(96)는 **눕고 맞물린** 더미의 실측이라, 칩이 칩 위에 **선** 채
    /// 안착하는 실배치(2026-08-19 실기: 버섯 위에 우유가 서서 상단 잘림)를 못 담는다. 2단 탑의
    /// 상계 = 아래 칩 바디(≤ maxBodyHeightRatio×s) + 위 칩의 그려지는 높이(바디/0.9) + 바닥·헤드룸 28.
    /// 작업대 상한이 6이라 행은 최대 2 — 이 하한이 곧 다행(多行) 캡의 정본이다.
    static func stackedRestFieldHeight(width: CGFloat) -> CGFloat {
        let s = chipSideFor(CGSize(width: width, height: 0))
        return s * maxBodyHeightRatio + s * (maxBodyHeightRatio / 0.9) + 28
    }
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
    /// 스폰 스태거 — order번째 칩은 화면 위 `chipSide × (spawnBase + order × spawnStep)`에서 떨어진다.
    /// **spawnStep은 바디 최대 높이(0.70s = chili)보다 넉넉해야** 이웃한 두 order가 겹쳐 태어나지 않는다.
    /// 순수 함수라 씬 없이 불변식을 고정할 수 있다(SpawnLadderTests).
    static let spawnBase: CGFloat = 0.4
    static let spawnStep: CGFloat = 0.85
    static let spawnHeadroom: CGFloat = 0.6
    static func spawnHeight(order: Int, side s: CGFloat) -> CGFloat {
        s * (spawnBase + CGFloat(max(0, order)) * spawnStep)
    }

    /// Reduce Motion 정적 배치 — 낙하 연출 없이 **처음부터 바닥 근처에** 놓는 자리
    /// (dx = 밴드 중앙 기준 x 오프셋, dy = 바닥 기준 높이, 둘 다 pt).
    ///
    /// 낙하 사다리와 **같은 declump 불변식**을 지켜야 한다. 옛 식은 `0.45 + (order % 3) × 0.5`라
    /// 행 간격이 0.5s로 바디 최대 높이(0.70s)보다 좁아 이웃 order가 겹쳐 태어났다 —
    /// 사다리 쪽만 고치고 이쪽을 두면 Reduce Motion 사용자만 겹친 더미를 본다.
    /// 그래서 **격자**로 놓는다: 한 행에 넣는 개수는 밴드가 **바디 최대 폭 이상** 벌릴 수 있는
    /// 만큼으로 제한하고(같은 행끼리 안 겹침), 행 간격은 사다리와 같은 `spawnStep`(0.85s >
    /// 바디 최대 높이 0.70s)이다(위아래로 안 겹침). 순수 함수 — SpawnLadderTests가 전 쌍을 건다.
    static func staticSlot(order: Int, count: Int, side s: CGFloat, band: CGFloat)
        -> (dx: CGFloat, dy: CGFloat) {
        let n = max(1, count)
        let o = min(max(0, order), n - 1)
        let width = max(1, maxBodyWidthRatio * s)
        let perRow = max(1, min(n, Int(band / width) + 1))
        let row = o / perRow, col = o % perRow
        let inRow = min(perRow, n - row * perRow)   // 마지막 행은 덜 찬다 — 그만큼 더 넓게 벌린다
        let dx = inRow <= 1 ? 0 : (CGFloat(col) / CGFloat(inRow - 1) - 0.5) * band
        return (dx: dx, dy: s * (staticBase + CGFloat(row) * spawnStep))
    }
    /// 정적 배치 첫 행의 높이(칩 변 배수) — 바닥에 붙지 않을 만큼만 띄운다.
    static let staticBase: CGFloat = 0.45

    /// 스폰 천장 — 재료는 화면 위에서 떨어져 들어오므로(§13) 낙하 중엔 천장을 스폰 위치 위로 올려 둔다.
    /// **이번 캐스케이드가 실제로 쓴 최고 스폰 높이의 래칫**이다. 옛 상수 천장(size.height + 700)은
    /// 사다리를 담지 못해(작업대 6개 · s=169면 사다리 꼭대기가 +786pt) order가 큰 칩들을 클램프로
    /// **같은 y에 접어 낳았다** — -physLab 실측: 6개 중 2개가 y 동일, AABB 43.1% 관통.
    /// 그 깊은 관통을 푸느라 솔버가 한 칩을 2050pt/s로 걷어차 두께 0의 벽을 뚫었고(y=-438000까지
    /// 영구 낙하), 살아남은 칩들도 상시 분리 압력에 눌려 영영 안 잤다.
    /// 래칫이라 **재료가 빠져 개수가 줄거나 씬이 리사이즈돼도 비행 중인 칩 위로 천장이 안 내려온다**
    /// (절대 좌표 — 배너가 뜨며 씬 높이가 551→419로 줄던 실측 케이스가 여기서 막힌다).
    private var spawnCeilingMark: CGFloat = 0
    private var spawnCeiling: CGFloat { max(spawnCeilingMark, size.height + chipSide) }
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
        view.ignoresSiblingOrder = true   // 칩 z는 스폰 카운터 기반 **고정 상이값**이라 순서 결정적(§그리기 순서)
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
        // 달그락 엔진도 여기서 내린다 — `syncClatterEngine`의 조건은 `view != nil`인데 willMove
        // 시점엔 아직 view가 붙어 있어, 이 줄이 없으면 씬이 화면을 떠난 뒤에도 CHHapticEngine이
        // 살아 있다(다음 didMove의 syncMotionUpdates가 다시 켠다).
        clatter.stop()
        clatterThrottle.reset()
        textureGate.reset()
        lastCapturedZone = nil
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
        tilt.stop()   // 안전망(willMove가 정상 경로) — 래퍼에도 자체 deinit 안전망이 있다
    }

    // MARK: - 기울임 중력 (CoreMotion)

    #if DEBUG
    /// `-tiltLab` 주입 중력 방향(정규화 x, y) — 있으면 CoreMotion보다 우선한다.
    /// 시뮬레이터엔 자이로가 없어 기울기 QA는 이 경로로만 가능하다.
    ///
    /// **실사용 경로(`applyDeviceGravity`)를 타지 않는다.** 그쪽은 무방향 대역(hypot < 0.06)·
    /// 재적용 데드밴드(2°/5%)·깨우기 임계(6°)를 차례로 통과해야 하는데, 그 필터들이 바로 이 실험실이
    /// **검증하려는 대상**이다. 슬라이더를 원점 근처에 두면 값이 flatGravity로 접히고, 천천히 끌면
    /// 데드밴드에 먹히고, 잠든 씬은 무방향 판정 탓에 영영 안 깨어난다 — 그런 건 실험실이 아니다.
    /// 그래서 여기선 순수 매핑(`GravityMapper.mapped`)을 그대로 쓰고 **무조건** 깨운다.
    var debugTilt: CGVector? {
        didSet { syncMotionUpdates() }
    }

    /// 주입값을 물리 중력에 **직접** 쓴다 — 필터 없이, 무조건 깨워서.
    private func applyDebugTilt(_ d: CGVector) {
        tilt.stop()
        let g = GravityMapper.mapped(x: Double(d.dx), y: Double(d.dy))
        physicsWorld.gravity = g
        lastAppliedGravity = g
        gravityDirectionless = false
        wake()
    }
    #endif

    /// 모션 갱신 on/off를 씬 상태에서 **파생**시킨다 — 표시 중 + 안 가려짐 + Reduce Motion 아님
    /// + 프로필 토글 켬 + 기기 지원.
    /// 조건이 하나라도 깨지면 즉시 멈춘다(시뮬레이터는 deviceMotion 미지원 → 항상 상수 중력).
    private func syncMotionUpdates() {
        #if DEBUG
        // -tiltLab 주입이 정본 — 센서를 끄고 주입값을 **다시 적용**한다. 여기서 그냥 넘어가면
        // didMove의 `gravity = fallback`이 주입을 덮은 채로 남는다(프레젠트 전에 주입된 경우:
        // 슬라이더 표시값은 y=+1인데 더미는 아래로 떨어지던 버그).
        // 다만 프로필 토글(`tiltEnabled`)은 실험실보다 위다 — 시뮬레이터엔 자이로가 없어
        // 토글의 실동작을 눈으로 확인할 수 있는 경로가 이 주입뿐이다(끄면 상수 중력으로 되돌아간다).
        if let d = debugTilt, tiltEnabled {
            applyDebugTilt(d)
            syncClatterEngine()
            return
        }
        #endif
        let wanted = view != nil && !externallyPaused && !reduceMotion && tiltEnabled && tilt.isAvailable
        if wanted { startMotionUpdates() } else { stopMotionUpdates() }
        syncClatterEngine()
    }

    /// 달그락 엔진 수명주기도 같은 자리에서 파생시킨다(별도 채널을 만들지 않는다). 조건은
    /// **보이는 씬 + 프로필 햅틱 토글**이다 — Reduce Motion은 시각 배려지 촉각 배려가 아니고(§7.4),
    /// 자이로가 없는 시뮬레이터·구형 기기에서도 던져서 부딪히는 충돌은 그대로 일어난다.
    /// 안 보이는 씬에서, 그리고 사용자가 진동을 껐을 때만 내린다.
    private func syncClatterEngine() {
        // 재생기 자체의 스위치도 여기서 맞춘다 — 사건(`play`)·텍스처(`setTexture`) 양쪽 가드가
        // 이 플래그를 보므로, 엔진을 내리는 것만으로는 남은 호출이 조용히 되살릴 수 있다.
        clatter.isEnabled = hapticsEnabled
        if hapticsEnabled, view != nil, !externallyPaused {
            clatter.start()
        } else {
            clatter.stop()
            clatterThrottle.reset()
            // 지속 촉감은 **상태**라 씬이 멈추면 스스로 끝나지 않는다 — 관문까지 닫아 두지 않으면
            // 돌아왔을 때 유예가 남은 채 이어져 정지한 화면에서 텍스처가 한 박자 더 울린다.
            textureGate.reset()
            lastCapturedZone = nil
        }
    }

    private func startMotionUpdates() {
        // 콜백은 래퍼가 메인 큐로 받는다 — 씬 상태(중력·wake)를 렌더 스레드와 같은 큐에서만 만진다.
        tilt.start { [weak self] sample in
            guard let self else { return }
            self.applyDeviceGravity(x: Double(sample.gravityX), y: Double(sample.gravityY))
            self.applyShake(sample)
        }
    }

    /// 모션 중단 — 중력은 상수 폴백으로 되돌려 놓는다(기울인 채 탭을 벗어나도 다음 표시가 정상 감각).
    /// 중력이 **실제로 바뀌었으면 깨운다** — 기울인 채 잠든 더미는 기울어진 배치 그대로 얼어붙어 있어,
    /// 상수 중력만 되돌려 놓고 재우면 다음에 봤을 때 비스듬히 굳은 더미가 그대로 보인다.
    private func stopMotionUpdates() {
        tilt.stop()   // 인플라이트 콜백은 래퍼가 onSample을 nil로 만들며 스스로 취소한다
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
            // calm 창은 **진짜 기울임에서만** 접는다. 재적용 데드밴드(2°)로 접던 옛 코드는 손떨림이
            // 창을 무한 리필해 force-settle이 영영 성립하지 않았다(shouldResetCalm 주석).
            if calmFrames > 0, GravityMapper.shouldResetCalm(candidate, calmGravity: calmGravity) {
                calmFrames = 0
                calmSnapshot.removeAll()
            }
            // 이 경로는 일부러 wake()를 안 부른다(이미 깨어 있다). 감쇠는 저속 플로어 방식이라
            // 갱신할 유예 카운터도 없다 — 굴림은 플로어 위 속도라 애초에 감쇠를 받지 않는다.
        }
    }

    // MARK: - 흔들기 에너지 주입

    /// 이 G 미만은 손떨림·걷기 — 무시한다. v1.0 (3) 실기기 피드백("흔들어도 아무 반응 없음")에
    /// 따라 0.35 → 0.25. z축 감지가 들어온 뒤에도 임계가 높아 평범한 손목 흔들기가 자주 미달했다.
    /// 셰이크 3종 상수는 `static let` — 테스트가 리터럴을 다시 적지 않고 **이 심볼을 읽어야**
    /// 값을 되돌렸을 때 빨간불이 든다(ShakeKickTests). 씬 상태와 무관한 순수 튜닝값이라 안전하다.
    static let shakeThreshold: CGFloat = 0.25
    /// 킥 사이 최소 간격(초) — 매 프레임 밀면 흔들기가 아니라 연속 가속이 된다.
    private let shakeInterval: TimeInterval = 0.09
    /// **칩 하나가 킥 한 번에 받는 최대 속도 변화(pt/s)** — 벽 터널링 방지 상한. 60fps에서
    /// 프레임당 3.5pt라 두께 0인 edge loop도 못 뚫는다(게다가 wake로 CCD가 켜진 상태다).
    /// 흩뿌림 배율(최대 1.35배)을 곱한 **뒤**에 적용해야 이 불변식이 실제로 참이 된다 —
    /// 곱하기 전에만 걸었던 v1.0 (4)에서는 실최대가 283.5pt/s(프레임당 4.7pt)로 새어 나갔다.
    static let shakeMaxDeltaV: CGFloat = 210
    /// 초과분(G) → 속도 변화(pt/s) 환산 이득. **150 → 480**(v1.0 (3) 실기기 피드백).
    /// 옛 값 산식: 0.5G 흔들기 → (0.5 − 0.35) × 150 = **22pt/s**. 칩 한 변의 1/3이 1초에 걸쳐
    /// 움직이는 정도라 사실상 보이지 않았고, 그래서 "흔들어도 반응이 없다"로 읽혔다.
    /// 새 값 산식: 0.5G → (0.5 − 0.25) × 480 = **120pt/s**(확실히 보인다). 이 값은 흩뿌림 전의
    /// **공칭 Δv**이고, 칩마다 0.65~1.35배로 흩은 뒤 상한 210에서 잘린다.
    /// 원 튜닝(150)은 중력 28·종단속도 62~140의 수중 씬 값이었다. 우리 중력은 42다.
    static let shakeGain: CGFloat = 480
    private var lastShakeTime: TimeInterval = 0

    /// `userAcceleration`(중력 제외 고역) → 칩들에 임펄스 킥. 이게 있어야 "흔들면 달그락"이 성립한다.
    /// 중력 벡터만으론 흔들기가 전달되지 않는다(저역 신호라 흔드는 동안에도 거의 안 변한다).
    /// Reduce Motion이면 통째로 건너뛴다 — 예측 불가한 화면 움직임을 없애는 것이 그 설정의 요지다(§7.4).
    private func applyShake(_ sample: TiltSample) {
        // applyDeviceGravity와 같은 콜백에서 갈라져 들어오므로 같은 표시 가드를 건다 —
        // 화면에 없는 씬을 in-flight 샘플이 걷어차지 않게.
        guard view != nil, !externallyPaused else { return }
        guard !reduceMotion else { return }
        guard let kick = Self.shakeKick(x: sample.shakeX, y: sample.shakeY, z: sample.shakeZ,
                                        gravity: physicsWorld.gravity,
                                        threshold: Self.shakeThreshold) else { return }
        // 휴면 중엔 update 시계(lastUpdateTime)가 멈춰 있어 실제 단조 시계로 잰다 —
        // 잠든 씬을 흔들어 깨우는 첫 킥이 얼어붙은 시계에 막히면 안 된다.
        let now = CACurrentMediaTime()
        guard now - lastShakeTime >= shakeInterval else { return }
        lastShakeTime = now
        // 여기선 클램프하지 않는다 — 상한은 흩뿌림을 곱한 **칩별 최종값**에 걸어야 터널링
        // 불변식이 참이 된다(kickChips → scatteredDeltaV). 넘기는 값은 공칭 Δv다.
        kickChips(angle: kick.angle, deltaV: kick.excess * Self.shakeGain)
    }

    /// 흔들기 판정의 순수 계산부 — 씬 없이 테스트하기 위해 분리(GravityMapper와 같은 규율).
    /// **z(화면 수직)를 크기에 포함한다**: 화면을 보며 폰을 흔들면 주 가속이 z축이라, 평면만 보면
    /// 실기기에서 흔들기가 거의 감지되지 않았다(v1.0 (2) 검증). 방향은 평면 성분이 충분하면 그쪽,
    /// z가 지배적이면 **중력 반대 방향**(쟁반을 아래에서 턴 느낌 — 더미가 위로 튀며 부딪힌다).
    /// 임계 미만이면 nil.
    static func shakeKick(x: CGFloat, y: CGFloat, z: CGFloat,
                          gravity: CGVector, threshold: CGFloat) -> (angle: CGFloat, excess: CGFloat)? {
        let mag = (x * x + y * y + z * z).squareRoot()
        guard mag > threshold else { return nil }
        let planar = hypot(x, y)
        let angle: CGFloat
        if planar > 0.12 {
            angle = atan2(y, x)
        } else if gravity.dx != 0 || gravity.dy != 0 {
            angle = atan2(-gravity.dy, -gravity.dx)
        } else {
            angle = .pi * 0.5   // 중력이 0인 극단 폴백 — 위로
        }
        return (angle, mag - threshold)
    }

    /// 공칭 Δv에 칩별 흩뿌림(0.65~1.35배)을 곱하고 **터널링 상한에서 자른다**.
    /// 순서가 핵심이다 — 클램프를 곱하기 앞에 두면 상한이 1.35배 새어 나간다(v1.0 (4) 결함).
    /// 씬 없이 테스트하기 위해 순수 함수로 분리(shakeKick과 같은 규율).
    static func scatteredDeltaV(_ deltaV: CGFloat, jitter j: CGFloat) -> CGFloat {
        min(deltaV * (0.65 + 0.7 * j), shakeMaxDeltaV)
    }

    /// 칩들을 한 방향으로 밀되 **칩마다 각도·세기를 흩는다** — 똑같이 밀면 나란히 움직여서
    /// 서로 부딪히지 않고, 부딪히지 않으면 달그락도 없다. 세기는 상한에서 잘리지만 각도는
    /// 안 잘리므로, 포화 구간(0.7G 이상)에서도 칩들이 서로 다른 방향으로 흩어져 부딪힌다.
    private func kickChips(angle: CGFloat, deltaV: CGFloat) {
        guard !chips.isEmpty else { return }
        for (id, node) in chips {
            guard let body = node.physicsBody else { continue }
            let j = Self.stableJitter(id)                 // 0..1 결정적
            let a = angle + (j - 0.5) * 1.3               // ±0.65rad 흩뿌림
            let dv = Self.scatteredDeltaV(deltaV, jitter: j)
            body.applyImpulse(CGVector(dx: cos(a) * dv * body.mass,
                                       dy: sin(a) * dv * body.mass))
            body.applyAngularImpulse((j - 0.5) * 0.02 * body.mass)
        }
        wake()   // 휴면이었으면 기상 + CCD 복구 — 킥은 빠른 이동이라 정밀 충돌이 필요하다
    }

    #if DEBUG
    /// QA용 셰이크 버스트 — 시뮬레이터엔 자이로가 없어 손으로 흔들 수 없다.
    /// TILT LAB의 SHAKE 버튼과 `-tiltLab.shake`가 이걸 부른다.
    /// 실제 흔들기는 **왕복 운동**이라 한 번 미는 것으론 재현이 안 된다 — 방향을 바꿔 3연타를 넣는다.
    func shakeBurst() {
        wake()   // 휴면 중이면 먼저 깨운다(멈춘 씬은 SKAction도 안 돈다)
        kickChips(angle: .pi * 0.5, deltaV: Self.shakeMaxDeltaV * 0.9)
        let followUps: [CGFloat] = [-.pi * 0.35, .pi * 0.8]
        for (i, angle) in followUps.enumerated() {
            run(.sequence([
                .wait(forDuration: 0.13 * Double(i + 1)),
                .run { [weak self] in
                    guard let self else { return }
                    self.kickChips(angle: angle, deltaV: Self.shakeMaxDeltaV * 0.75)
                },
            ]))
        }
    }
    #endif

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
        // 폴백 칩(텍스처 실패) 판별은 **텍스처 유무**로 한다. `colorBlendFactor`로 가르던 옛 조건은
        // 늘 거짓이었다 — `SKSpriteNode(color:size:)`는 blend factor를 기본값 0으로 두고, 이 코드
        // 어디에도 1을 넣는 곳이 없어 재틴트가 한 번도 돌지 않았다(텍스처 없는 스프라이트는 blend
        // factor와 무관하게 `color`를 그대로 칠하므로 대입은 그대로 픽셀에 도달한다).
        for ing in pending {
            guard let node = chips[ing.id], node.texture == nil else { continue }
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
        if Self.chipSideFor(oldSize) != chipSide { textureCache.removeAll() }
        buildWalls()
        // 천장이 내려오면 그 위에 남은 칩은 즉시 회수(스스로 못 들어온다). 단 **밀폐 상태일 때만** —
        // 낙하 캐스케이드 중(천장 열림) 리플로우가 오면, 정상 낙하 중인 칩을 순간이동시키게 된다.
        // 열린 동안의 회수는 maintainCeiling의 상태 기계(sealTimeout 백스톱 포함)가 맡는다.
        if ceilingSealed { tuckStraysUnderCeiling() }
        layoutZones()
        wake()   // 리사이즈로 레이아웃이 바뀌었으니 한 번 굴려 재안착
    }

    /// 드래그 중인 재료를 손가락 쪽으로 **스프링처럼 끌어당긴다**(텔레포트 아님).
    /// 거리 비례 목표 속도 + 가속 제한 → 약간의 딜레이·관성(실감, §13.4). 동적 바디라 이웃을
    /// 부드럽게 밀 뿐 튕겨내지 않는다. 속도 상한으로 과격한 밀침을 막는다.
    override func update(_ currentTime: TimeInterval) {
        // 일시정지 공백은 개봉 시간으로 세지 않는다. `currentTime`은 시스템 시계라 씬이 멈춘
        // 동안에도 계속 흐르는데 `unsealedSince`를 되돌리는 경로가 없어, 탭 전환·백그라운드에서
        // 6초 넘게 머물다 돌아오면 재개 첫 프레임이 곧장 sealTimeout 강제 회수를 돌렸다
        // (낙하 중이던 칩이 천장 밑 한 줄로 순간이동한 뒤 다시 떨어진다). 프레임 간격이
        // 비정상적으로 벌어졌으면 타이머만 접는다 — 회수 자체는 다음 프레임부터 정상적으로 잰다.
        if lastUpdateTime > 0, currentTime - lastUpdateTime > 1.0 { unsealedSince = nil }
        lastUpdateTime = currentTime   // didBegin엔 시간 인자가 없어 여기서 받아 둔다(햅틱 스로틀용)
        #if DEBUG
        if Self.physLab { physLabTick(currentTime) }
        #endif
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
            // 자석에 **막 붙은** 순간의 스냅(§13.4 · 리뷰 F50) — 판정이 확정될 자리에 들어왔다는
            // 촉각 확정이다. 에지에서만 치고, 반경 경계에서 손이 떨 때의 연타는 쿨다운이 막는다.
            if captured !== lastCapturedZone {
                if captured != nil, currentTime - lastCaptureSnapAt >= captureSnapCooldown {
                    clatter.play(ClatterAccent.captureSnap)
                    lastCaptureSnapAt = currentTime
                }
                lastCapturedZone = captured
            }
            // 붙들려 있는 동안의 미세 텍스처 — 자석이 잡고 있다는 지속 신호. 구름과 같은 채널이라
            // 관문도 같은 것을 쓴다(드래그 중엔 아래 구름 스캔이 아예 돌지 않는다).
            let holding = textureGate.update(level: captured != nil ? 1 : 0, now: currentTime)
            clatter.setTexture(holding ? ClatterAccent.hover : nil)
            return   // 드래그 중엔 절대 휴면 안 함
        }
        lastCapturedZone = nil
        // 구름 텍스처의 대표 칩 — 가장 세게 구르는 하나가 채널을 가져간다. 액추에이터가 하나뿐이라
        // 여러 칩의 결을 합치면 그냥 '웅'이 된다(조이콘처럼 좌·우로 나눌 수도 없다).
        var rollBest: (level: Float, node: SKSpriteNode)?
        // 잔여 운동 능동 감쇠 — 강한 중력의 접촉 해소 임펄스가 남기는 미세 요동만 죽인다.
        // 판정은 저속 플로어(`jitterFloor`) 하나: 그 미만이면 지터, 이상이면 진짜 움직임이라
        // 절대 건드리지 않는다. 기울임 굴림·킥·낙하가 감쇠에 먹히지 않으므로 유예 카운터가
        // 필요 없고(실기기에선 손떨림이 유예를 무한 리필해 지터가 영구화됐다 — jitterFloor 주석),
        // 지터는 기기 자세와 무관하게 항상 몇 프레임 안에 calm 대역으로 수렴한다.
        // **잠든 바디·거의 멈춘 바디는 손대지 않는다** — 대입이 곧 기상이라(jitterRestFloor 주석)
        // 여기서 한 번이라도 쓰면 그 칩은 그 프레임에 다시 깨어난다.
        for node in chips.values {
            guard let b = node.physicsBody, !b.isResting else { continue }
            let v = hypot(b.velocity.dx, b.velocity.dy)
            // 구름 신호는 **이미 읽은 속도·각속도**로 잰다 — 이 루프가 매 프레임 도는 유일한 물리
            // 스캔이라, 새 상시 계산을 만들지 않고 여기 얹는다. 감쇠 게이트보다 **앞**이어야 한다:
            // 아래 `guard v < jitterFloor`는 진짜 움직임을 걸러 내보내는데, 구름은 바로 그쪽이다.
            let level = rollRule.level(speed: v, spin: b.angularVelocity)
            if level > (rollBest?.level ?? 0) { rollBest = (level, node) }
            guard v < jitterFloor else { continue }   // 진짜 움직임(굴림·킥·낙하) — 절대 안 건드린다
            if v >= jitterRestFloor {
                b.velocity = CGVector(dx: b.velocity.dx * jitterDamp, dy: b.velocity.dy * jitterDamp)
            }
            if abs(b.angularVelocity) >= jitterRestSpin {
                b.angularVelocity *= jitterDamp
            }
        }
        // 구름 텍스처 — HD Rumble의 구슬 시그니처. 신호가 관문을 열면 재생을 **끊지 않고** 세기·
        // 날카로움만 실시간으로 갈아 끼운다(끊었다 켜면 그건 질감이 아니라 스위치 소리다).
        // 관문은 켬 0.20 / 끔 0.09 + 유예 0.14s — 문턱이 하나면 경계에서 지직거리며 여닫힌다.
        let rolling = textureGate.update(level: rollBest?.level ?? 0, now: currentTime)
        if rolling {
            // 유예 중(신호가 잠깐 꺼진 프레임)에는 **직전 값을 그대로** 다시 낸다. 여기서 0을 보내면
            // 관문이 열려 있는 의미가 없어진다 — 한 프레임 dip에 텍스처가 끊기는 게 유예를 둔 이유다.
            if let best = rollBest {
                lastRollTexture = rollRule.texture(level: best.level,
                                                   material: Self.clatterMaterial(of: best.node))
            }
            clatter.setTexture(lastRollTexture)
        } else {
            lastRollTexture = nil
            clatter.setTexture(nil)
        }
        // 드래그가 없을 때만 정착 판정 — 지터 때문에 '완전 정지'는 영원히 안 오므로,
        // calm 창(전 칩 v<calmSpeed 연속 0.5s) + 변위 검증(<settleDrift)으로 안착을 판정한다.
        // 변위 검증이 스폰 직후의 느린 낙하를 걸러낸다(v≈20은 calm 대역이지만 0.5s에 10pt+ 이동).
        if allChipsCalm() {
            calmBreaches = 0
            if calmFrames == 0 {
                calmSnapshot = chips.mapValues(\.position)
                calmGravity = physicsWorld.gravity   // 이 창의 판정 기준(shouldResetCalm)
            }
            calmFrames += 1
            if calmFrames >= calmThreshold {
                if chipsHeldStill() {
                    // **겹친 채 얼리지 않는다** — 겹침은 forceSettle 안에서 위치로 푼 뒤 굳힌다
                    // (`depenetrateChips`). 여기서 밀고 창을 다시 돌리는 옛 방식은 예산이 말랐다.
                    forceSettle()
                    #if DEBUG
                    driftRetries = 0
                    #endif
                } else {
                    calmFrames = 0   // 아직 흐르는 중 — 창 재시작(스냅샷은 0→1 전이에서 갱신)
                    #if DEBUG
                    // 진단 — calm은 통과하는데 변위 검증만 계속 떨어지는 상태(느린 미끄러짐).
                    // 이 실패 모드는 allChipsCalm()이 true라 logRestlessChipsIfNeeded가 안 돈다.
                    driftRetries += 1
                    if driftRetries % 4 == 0 {
                        Logger(subsystem: "com.reffi.app", category: "scene")
                            .debug("settle retry \(self.driftRetries): calm window passed but chips drifted > \(self.settleDrift, format: .fixed(precision: 0))pt")
                    }
                    #endif
                }
            }
        } else {
            // 한 프레임짜리 솔버 스파이크로는 창을 접지 않는다(calmBreachTolerance 주석).
            // 연속으로 시끄러워야 진짜 움직임 — 그때 창을 접는다.
            calmBreaches += 1
            if calmBreaches > calmBreachTolerance {
                calmFrames = 0
                #if DEBUG
                logRestlessChipsIfNeeded(currentTime)
                #endif
            }
        }
    }

    #if DEBUG
    /// `-physLab` 계측 한 틱 — 씬 상태 + 칩별 운동량/휴면 + 쌍별 AABB 관통률을 파일에 누적한다.
    /// 화면 캡처로는 못 보는 두 가지를 잡으려는 것이다: ① 속도가 0인데도 isResting=false로 남는
    /// (= 엔진이 못 재우는) 바디 ② 눈으로는 한 덩이로 보이는 칩들의 실제 관통 깊이.
    private func physLabTick(_ now: TimeInterval) {
        guard physLabSamples < physLabMaxSamples else { return }
        if physLabNext == 0 { physLabNext = now }
        guard now >= physLabNext else { return }
        physLabNext = now + physLabPeriod
        physLabSamples += 1
        let g = physicsWorld.gravity
        var out = String(format: "t=%.2f idle=%d calm=%d sealed=%d g=(%.1f,%.1f) side=%.0f scene=%.0fx%.0f contacts=%d squash=%d sep=%d\n",
                         now, idle ? 1 : 0, calmFrames, ceilingSealed ? 1 : 0,
                         g.dx, g.dy, chipSide, size.width, size.height,
                         physLabContacts, physLabSquashes, physLabSeparations)
        out += String(format: "  DV n=%d max=%.0f mean=%.0f (gravity floor g·dt=%.0f)\n",
                      physLabDvCount, physLabDvMax,
                      physLabDvCount > 0 ? physLabDvSum / CGFloat(physLabDvCount) : 0,
                      hypot(g.dx, g.dy) * 150 / 60)
        physLabContacts = 0; physLabSquashes = 0; physLabSeparations = 0
        physLabDvMax = 0; physLabDvSum = 0; physLabDvCount = 0
        let items = chips.sorted { $0.key.uuidString < $1.key.uuidString }
        for (id, n) in items {
            let r = bodyAABB(n)
            let v = n.physicsBody?.velocity ?? .zero
            out += String(format: "  %@ %@ p(%.1f,%.1f) v(%.1f,%.1f)=%.2f w=%.3f rest=%d z=%.3f rot=%.2f aabb(%.0f,%.0f,%.0f,%.0f)\n",
                          String(id.uuidString.prefix(4)),
                          (n.userData?["glyph"] as? String) ?? "?",
                          n.position.x, n.position.y, v.dx, v.dy, hypot(v.dx, v.dy),
                          n.physicsBody?.angularVelocity ?? 0,
                          (n.physicsBody?.isResting ?? false) ? 1 : 0,
                          n.zPosition, n.zRotation,
                          r.minX, r.minY, r.width, r.height)
        }
        for i in items.indices {
            for j in items.indices where j > i {
                let ri = bodyAABB(items[i].value), rj = bodyAABB(items[j].value)
                let hit = ri.intersection(rj)
                guard !hit.isNull, hit.width > 0, hit.height > 0 else { continue }
                let frac = (hit.width * hit.height) / min(ri.width * ri.height, rj.width * rj.height)
                out += String(format: "  OVERLAP %@~%@ %.1f%% (dx=%.0f dy=%.0f)\n",
                              String(items[i].key.uuidString.prefix(4)),
                              String(items[j].key.uuidString.prefix(4)),
                              frac * 100, hit.width, hit.height)
            }
        }
        physLabLog += out
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? physLabLog.write(to: dir.appendingPathComponent("phys-lab.txt"),
                                  atomically: true, encoding: .utf8)
        }
    }

    private var lastRestlessLog: TimeInterval = 0
    /// calm 창은 통과했는데 변위 검증에서 되돌아온 횟수 — 안착이 반복 실패하는 상태의 관측구.
    private var driftRetries = 0
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

    // MARK: - 그리기 순서 (§13.4)

    /// 칩 z-순서 — **스폰 카운터 기반 고정값**이다.
    ///
    /// 실기기 3차 피드백 ② "겹친 부분이 보였다 안 보였다 깜빡임"의 원인은 알파도 텍스처도 아니라
    /// **그리기 순서가 매 프레임 뒤집힌 것**이었다. 옛 코드는 `didSimulatePhysics`에서 z를 y로
    /// 다시 계산했다(`z = 10 + (H − y) × 0.01`). 바닥 한 줄에 쌓인 칩들은 y가 서로 몇 pt 안이라
    /// z가 **0.01 단위로 붙고**(-physLab 실측: 바닥 6칩이 13.52~13.61, 폭 0.09 안), 솔버 미세
    /// 요동으로 y가 1~2pt만 흔들려도 순서가 뒤집힌다 — 겹친 영역만 프레임마다 다시 칠해진다.
    /// `ignoresSiblingOrder = true`가 그 뒤집힘을 그대로 화면에 통과시킨다.
    ///
    /// 그래서 z를 스폰 순간 한 번만 정하고 다시는 건드리지 않는다. **나중에 떨어진 칩이 위**라는
    /// 규칙은 캐스케이드의 물리와도 일치한다(먼저 떨어진 것 위에 쌓인다). y 기반 깊이 단서는
    /// 어차피 없다시피 했다 — 안착하면 전부 바닥 한 줄이라 z 차이가 0.09였다.
    /// 레이어 상수는 `static`이다 — 겹침 순서 불변식(칩 < 드래그 < 존 < 사라지는 칩)을
    /// ChipZOrderTests가 리터럴을 다시 적지 않고 직접 건다. 값이 서로를 넘으면 존이 칩 뒤로
    /// 숨거나 사라지는 칩이 더미에 파묻힌다.
    static let zBase: CGFloat = 10
    static let zStep: CGFloat = 0.5          // 칩 사이 최소 간격 — 동률이면 그리기 순서가 비결정
    static let zTop: CGFloat = 28            // 여기 닿기 전에 압축(compactZOrder)이 돈다
    static let zDragged: CGFloat = 29        // 잡은 칩은 더미 위, 존 아래
    static let zZone: CGFloat = 30           // 판정 바스켓
    static let zPopOut: CGFloat = 50         // 사라지는 칩 — 항상 최상위
    /// order번째로 스폰된 칩의 고정 z(1부터). 순수 함수 — 테스트가 단조·간격을 고정한다.
    static func chipZ(spawnIndex i: CGFloat, step: CGFloat = zStep) -> CGFloat { zBase + i * step }

    /// `count`개를 z 예산(zBase..zTop) 안에 담는 간격. 기본은 `zStep`이고, 예산을 넘길 만큼
    /// 칩이 많아지면 **균등 분할로 좁힌다**. 압축(compactZOrder)만으로는 부족하기 때문이다 —
    /// 압축은 zCounter를 살아 있는 칩 수로 되돌릴 뿐이라, 칩이 예산 칸 수(36)보다 많으면
    /// 압축이 사실상 무동작이 되어 z가 zTop을 넘어 계속 올라간다(잡은 칩 29·존 30을 침범).
    /// 작업대 상한(6)에선 도달하지 않는 영역이지만, 상한은 불변식이지 희망사항이 아니다.
    static func zStepFor(count: Int) -> CGFloat {
        guard count > 0 else { return zStep }
        return min(zStep, (zTop - zBase) / CGFloat(count))
    }

    /// 압축 배정(순수) — `slots`(각 칩의 보관 z)를 오름차순 순위 그대로 1..n에 다시 매긴다.
    /// 반환은 **입력 순서 그대로**의 (보관 슬롯, 실제 zPosition).
    /// `draggedIndex`의 실제 z만 승격값(`zDragged`)을 유지한다 — 잡고 있는 칩의 z를 압축이 덮으면
    /// 그 칩이 손끝에서 더미 **밑으로** 가라앉고, 놓을 때 되돌릴 값(`userData["z"]`)도 함께 날아간다.
    static func compactedZ(slots: [CGFloat], step: CGFloat = zStep,
                           draggedIndex: Int? = nil) -> [(slot: CGFloat, live: CGFloat)] {
        let rank = slots.indices.sorted { slots[$0] < slots[$1] }
        var out = [(slot: CGFloat, live: CGFloat)](repeating: (0, 0), count: slots.count)
        for (i, idx) in rank.enumerated() {
            let z = chipZ(spawnIndex: CGFloat(i + 1), step: step)
            out[idx] = (slot: z, live: idx == draggedIndex ? zDragged : z)
        }
        return out
    }

    private var zCounter: CGFloat = 0
    /// 지금 쓰는 z 간격 — 평소엔 `zStep`, 칩이 예산을 넘치면 압축이 좁혀 놓는다(`zStepFor`).
    private var zStepLive: CGFloat = zStep

    /// 다음 칩의 고정 z를 뽑는다. 상한에 닿으면 살아 있는 칩만 현재 순서대로 다시 촘촘히 매겨
    /// (세션 내내 칩을 넣고 빼도) z가 상한에 몰려 동률이 되는 일이 없게 한다.
    private func nextChipZ() -> CGFloat {
        // 압축엔 **다음 칩 자리까지** 예산을 잡아 준다 — 압축 직후 태어나는 칩이 곧바로 상한을 넘지 않게.
        if Self.chipZ(spawnIndex: zCounter + 1, step: zStepLive) > Self.zTop { compactZOrder(reserving: 1) }
        zCounter += 1
        return Self.chipZ(spawnIndex: zCounter, step: zStepLive)
    }

    /// 살아 있는 칩의 z를 현재 순서 그대로 1..n으로 다시 매긴다 — 순서는 보존, 값만 회수.
    /// 잡고 있는 칩은 슬롯만 받고 화면 z(승격)는 그대로 둔다(`compactedZ`).
    private func compactZOrder(reserving extra: Int = 0) {
        let nodes = Array(chips.values)
        guard !nodes.isEmpty else { zCounter = 0; zStepLive = Self.zStep; return }
        let slots = nodes.map { ($0.userData?["z"] as? CGFloat) ?? $0.zPosition }
        let step = Self.zStepFor(count: nodes.count + max(0, extra))
        let draggedIndex = dragged.flatMap { d in nodes.firstIndex(where: { $0 === d }) }
        for (i, z) in Self.compactedZ(slots: slots, step: step, draggedIndex: draggedIndex).enumerated() {
            nodes[i].userData?["z"] = z.slot
            nodes[i].zPosition = z.live
        }
        zStepLive = step
        zCounter = CGFloat(nodes.count)
    }

    /// 모든 칩이 조용한가 — 관측 지터 대역(v 4~30)을 통째로 덮는 넉넉한 문턱(40).
    /// 감쇠 플로어(14)와 값이 다른 것은 의도다(jitterFloor 주석). 진짜 안착은 변위 검증이 가른다.
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

    // MARK: - 관통 해소 (§13.4)

    /// AABB 관통률(교집합 면적 / 작은 쪽 AABB 면적) 문턱 — 이 위는 "겹쳐 보인다".
    /// 볼록 바디는 모서리에서 AABB보다 안쪽이라, 15%는 실제 바디 관통으로 치면 한 자릿수다.
    /// 세 상수 모두 `static` — 테스트가 리터럴을 다시 적지 않고 실제 예산에 불변식을 건다.
    ///
    /// **실측(53종 × 회전 12각 × 접근 5방향, 문턱에 걸리는 순간의 폴리곤 교집합/바디 면적):**
    /// | 바디 · AABB | 중앙값 | 평균 | 최대 |
    /// |---|---|---|---|
    /// | 타원 14각 · 타원 닫힌 식 (v1.0 기준선) | 5.4% | 5.2% | 21.5% |
    /// | 수퍼타원 16각 · 타원 닫힌 식 (모양만 바꾼 상태) | 10.4% | 10.0% | 28.7% |
    /// | 수퍼타원 16각 · **폴리곤 실제 AABB**(현재) | 4.8% | **5.3%** | 20.5% |
    ///
    /// 가운데 줄이 이 상수를 건드리지 않고도 예산이 두 배로 벌어지던 상태다. `bodyAABB`를 꼭짓점
    /// 기반으로 되돌리자 예산이 기준선과 같아져(평균 5.2% → 5.3%) **문턱은 그대로 둔다** —
    /// 오너가 실기기에서 맞춘 값이라 재측정 없이 옮길 이유가 없다.
    static let separationOverlap: CGFloat = 0.15
    /// 위치 보정 반복 상한 — 한 바퀴(Gauss-Seidel)가 쌍 하나를 완전히 떼어 놓으므로 몇 바퀴면 수렴한다.
    /// **10**은 최악 배치의 실측에서 왔다: 6칩이 한 줄로 완전히 포개진 상태(칩당 20pt 간격,
    /// 인접 쌍 80% 관통)가 8바퀴에 수렴한다(`ChipDepenetrationTests`). 그래도 못 푸는 배치는
    /// 남은 겹침을 안고 얼린다 — 영영 안 자는 것이 살짝 겹쳐 보이는 것보다 나쁘다.
    static let separationPasses = 10
    /// 떼어 놓은 뒤 남기는 여유(pt) — 부동소수 경계에 딱 붙여 놓지 않는다.
    static let separationSlop: CGFloat = 0.5

    /// 안착 직전 관통 해소 — **속도가 아니라 위치로** 푼다. 밀어낸 쌍 수를 돌려준다.
    ///
    /// 실기기 3차 ②("칩들이 절반 가까이 겹친 채 고착")의 마지막 방어선이다. 스폰 declump가 깊은
    /// **초기** 관통을 없애도 던지기·셰이크·회수가 만든 관통은 남을 수 있고, force-settle은
    /// 속도를 0으로 굳히므로 그 순간의 겹침이 **영구 고착**이 된다.
    ///
    /// v1.0 (6)까지는 얼리기 **전에** 임펄스(240pt/s)로 밀고 calm 창을 다시 돌렸다. 그 방식은
    /// 예산이 마르며 실패했다 — 640g 아래 마찰 0.55가 임펄스를 곧바로 먹어 한 번에 문턱 아래로
    /// 못 벗어나고, 밀 때마다 창이 처음부터 다시 돌아 시도 8회가 ~6.6초에 소진된 뒤 **15% 초과 쌍이
    /// 남은 채** 더미가 얼었다(-physLab 콜드런치 실측, 씨앗 6개·무입력). 위치 보정엔 그 두 실패
    /// 모드가 구조적으로 없다: 속도가 0이라 두께 0의 벽을 뚫을 수 없고(터널링 불가), 얼리는 순간에
    /// 도는 것이라 calm 창을 되돌리지 않는다(예산 소진 자체가 성립하지 않는다).
    /// 미는 축은 AABB 최소 관통 축(MTV) — 대각으로 밀면 더미가 옆으로 무너진다.
    @discardableResult
    private func depenetrateChips() -> Int {
        var separated = 0
        for _ in 0..<Self.separationPasses {
            let items = Array(chips.values)
            var movedThisPass = 0
            for i in items.indices {
                for j in items.indices where j > i {
                    // AABB는 매번 현재 위치에서 다시 잰다 — 같은 바퀴 안의 앞선 보정이 즉시 반영된다.
                    let a = items[i], b = items[j]
                    guard let push = Self.depenetration(bodyAABB(a), bodyAABB(b),
                                                        overlap: Self.separationOverlap,
                                                        slop: Self.separationSlop) else { continue }
                    a.position.x += push.dx
                    a.position.y += push.dy
                    b.position.x -= push.dx
                    b.position.y -= push.dy
                    clampIntoBox(a)
                    clampIntoBox(b)
                    movedThisPass += 1
                }
            }
            separated += movedThisPass
            if movedThisPass == 0 { break }
        }
        #if DEBUG
        if Self.physLab, separated > 0 { physLabSeparations += separated }
        #endif
        return separated
    }

    /// 두 AABB의 관통을 푸는 **반쪽 이동량**(a에 +, b에 − 로 적용) — 관통률이 문턱 이하면 nil.
    /// 미는 축은 **최소 관통 축**(가로 관통이 얕으면 가로로) 하나뿐이고, 이동량은 그 축 관통의
    /// 절반 + 여유라 둘을 반대로 밀면 겹침이 완전히 사라진다. 순수 함수 — 테스트가 "밀고 나면
    /// 정말 문턱 아래인가"를 씬 없이 고정한다(`ChipDepenetrationTests`).
    static func depenetration(_ a: CGRect, _ b: CGRect,
                              overlap threshold: CGFloat, slop: CGFloat) -> CGVector? {
        let hit = a.intersection(b)
        guard !hit.isNull, hit.width > 0, hit.height > 0 else { return nil }
        let area = min(a.width * a.height, b.width * b.height)
        guard area > 0, (hit.width * hit.height) / area > threshold else { return nil }
        // 반씩 나눠 민다 — 한쪽만 밀면 더미 전체가 한 방향으로 흐른다.
        let push = min(hit.width, hit.height) * 0.5 + slop
        if hit.width <= hit.height {
            return CGVector(dx: (a.midX <= b.midX ? -1 : 1) * push, dy: 0)
        }
        return CGVector(dx: 0, dy: (a.midY <= b.midY ? -1 : 1) * push)
    }

    /// 칩 바디의 AABB를 밀폐 상자(벽 안쪽) 안으로 되돌린다 — 위치 보정이 칩을 벽 밖으로 내보내면
    /// 다음 프레임 `recoverEscapedChips`가 천장으로 회수해 더미가 통째로 다시 무너진다.
    private func clampIntoBox(_ node: SKSpriteNode) {
        let r = bodyAABB(node)
        let left = wallInset, right = max(left, size.width - wallInset)
        let bottom = floorY, top = max(bottom, sealedCeiling)
        var dx: CGFloat = 0, dy: CGFloat = 0
        if r.minX < left { dx = left - r.minX } else if r.maxX > right { dx = right - r.maxX }
        if r.minY < bottom { dy = bottom - r.minY } else if r.maxY > top { dy = top - r.maxY }
        // 상자보다 큰 바디는 어느 쪽으로 밀어도 못 담는다 — 그 축은 가운데 정렬로 끝낸다.
        if r.width > right - left { dx = (left + right) * 0.5 - r.midX }
        if r.height > top - bottom { dy = (bottom + top) * 0.5 - r.midY }
        guard dx != 0 || dy != 0 else { return }
        node.position.x += dx
        node.position.y += dy
    }

    /// 변위 검증 통과 → 강제 안착(freeze). 지터로 요동하던 미세 속도를 그 자리에서 0으로 굳혀
    /// 시각적 '꿈틀'까지 없애고 재운다. 물리 파라미터는 건드리지 않는다.
    private func forceSettle() {
        // 천장이 열려 있는 동안(= 가시 영역 위에 표류칩이 있음)은 잠들지 않는다. 여기서 잠들면
        // update()가 멈춰 maintainCeiling의 sealTimeout 강제 회수가 영영 돌지 않는다 —
        // §13.4의 "6초 넘게 열려 있으면 구조적으로 막는다"는 보증은 이 가드가 지킨다.
        guard ceilingSealed else { return }
        // 속도를 굳히기 **직전에** 겹침을 위치로 푼다 — 순서가 뒤바뀌면 겹친 배치가 그대로 영구 고착이다.
        depenetrateChips()
        for node in chips.values {
            node.physicsBody?.velocity = .zero
            node.physicsBody?.angularVelocity = 0
        }
        settleToIdle()
    }

    /// 정착 → idle. 정밀 충돌은 '움직일 가능성이 있는 동안'만이라 여기서 전부 내린다(B6).
    private func settleToIdle() {
        // 안착이 곧 닫을 시점이다 — 모든 칩이 바닥 더미로 돌아온 프레임이라 천장이 내려와도
        // 회수(순간이동)할 것이 없다. idle로 잠들기 전에 닫아야 한다(잠들면 update()가 멈춘다).
        for node in chips.values {
            node.physicsBody?.usesPreciseCollisionDetection = false
            // 스쿼시 액션이 남은 채 pause되면 눌린 모양으로 얼어붙는다 — 여기서 끊고 배율을 1로 굳힌다.
            node.removeAction(forKey: "squash")
            node.setScale(1)
        }
        idle = true
        #if DEBUG
        // 마지막 샘플을 남긴다 — 잠들면 update()가 멈춰 로그가 끊기므로, 안착 시점·최종 배치를
        // 기록해 두지 않으면 "언제 어떤 모양으로 잤는지"가 파일에 영영 안 남는다.
        if Self.physLab { physLabNext = 0; physLabTick(lastUpdateTime) }
        #endif
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
        calmBreaches = 0
        guard idle else { return }
        idle = false
        // 스로틀 리셋은 **실제 휴면→기상 전이에서만**. wake()는 셰이크 킥(0.09초마다)·터치·sync가
        // 깨어 있는 상태에서도 부르는데, 위에 두면 그때마다 쌍 쿨다운(0.26초)이 지워져 같은 두 칩이
        // 전역 상한(11Hz)까지 다시 울린다 — 셰이크 중, 즉 접촉이 가장 많은 구간에서 게이트가 무력해진다.
        // 리셋의 근거(lastUpdateTime은 휴면을 건너뛰며 튄다)도 이 전이에서만 성립한다.
        clatterThrottle.reset()
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
        node.zPosition = Self.zZone
        return node
    }

    private func layoutZones() {
        guard size.width > 1 else { return }
        if tossZone == nil { let z = makeZone(toss: true); tossZone = z; addChild(z) }
        if ateZone == nil { let z = makeZone(toss: false); ateZone = z; addChild(z) }
        // 상단 모서리 — 더미(바닥)와 겹치지 않고, 들어 올려서 넣는 제스처가 자연스럽다.
        // 앵커는 하늘 높이가 아니라 **정지 캡 + 드래그 여유**다 — 하늘이 카드 뒤·최상단까지 열려도
        // 존은 제자리에 남는다(오너 결정). restHeight 미실측(0)이면 종전대로 씬 상단 기준.
        let anchorTop = restHeight > 0
            ? min(size.height, restHeight + Self.dragFieldHeadroom(width: size.width))
            : size.height
        let y = anchorTop - zoneSide * 0.5 - 12
        let toss = CGPoint(x: zoneSide * 0.5 + 14, y: y)
        let ate  = CGPoint(x: size.width - zoneSide * 0.5 - 14, y: y)
        // 보이는 중의 재배치(드래그 여유 개방으로 천장이 오를 때)는 점프 대신 짧게 미끄러진다 —
        // 순간이동은 "지직"으로 읽힌다. 숨어 있으면 즉시 좌표만 갱신.
        for (zone, target) in [(tossZone, toss), (ateZone, ate)] {
            guard let zone else { continue }
            if zone.alpha > 0.01 {
                let move = SKAction.move(to: target, duration: ReffiJudgeZone.fade)
                move.timingMode = .easeOut
                zone.run(move, withKey: "relayout")
            } else {
                zone.removeAction(forKey: "relayout")
                zone.position = target
            }
        }
        #if DEBUG
        // `-zoneLab`은 재생성(다크 전환 리틴트) 뒤에도 계속 보여야 하므로 여기서 알파를 되돌린다.
        if zoneLab { tossZone?.alpha = ReffiJudgeZone.alpha; ateZone?.alpha = ReffiJudgeZone.alpha }
        #endif
    }

    /// 드래그 시작/끝에만 보인다 — 평소엔 물리 필드를 어지럽히지 않는다.
    private func setZones(visible: Bool) {
        let fade = SKAction.fadeAlpha(to: visible ? ReffiJudgeZone.alpha : 0,
                                      duration: ReffiJudgeZone.fade)
        tossZone?.run(fade)
        ateZone?.run(fade)
        if !visible {
            tossZone?.setScale(1)
            ateZone?.setScale(1)
        }
    }

    // MARK: - 드래그 여유 개폐 (§13.4)
    //
    // 처음엔 존 표시/숨김에 신호를 묶었는데 두 가지가 화면에서 "지직"으로 읽혔다(실기 제보):
    // ① 탭에도 존이 떴다 사라지며 상자가 여닫혔고, ② 놓는 순간 닫으면 아직 낙하 중인 칩이
    // 내려오는 천장에 회수(순간이동)됐다. 그래서 **열기는 진짜 드래그가 시작될 때**(dragMoved 전이),
    // **닫기는 더미가 안착한 뒤**(settleToIdle, 백스톱 1.5초)로 갈랐다 — 여닫는 프레임에
    // 움직이는 것이 없어야 리사이즈가 보이지 않는다.


    private func highlight(_ zone: SKSpriteNode?, hovering: Bool) {
        guard let z = zone else { return }
        let target: CGFloat = hovering ? ReffiJudgeZone.hotScale : 1.0
        if abs(z.xScale - target) > 0.01 {
            z.run(.scale(to: target, duration: ReffiJudgeZone.hotDuration))
        }
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

    /// 천장을 스폰 높이 위로 올린다(래칫) — 새 재료가 화면 위에서 떨어져 들어오기 직전에 부른다.
    /// 밀폐된 채로 스폰하면 칩이 천장 **위**에 얹혀 영영 안 보이고, 사다리보다 낮은 천장에
    /// 스폰하면 칩이 상자 밖에서 태어나 벽에 걸려 튕겨 나간다.
    private func raiseSpawnCeiling(to top: CGFloat) {
        let grew = top > spawnCeilingMark
        if grew { spawnCeilingMark = top }
        if ceilingSealed {
            ceilingSealed = false
            buildWalls()
        } else if grew {
            buildWalls()
        }
    }

    /// 상자 **바깥**으로 새어 나간 칩 회수 — 어느 방향이든(아래·옆·위).
    /// 벽은 두께 0의 edge loop라 깊은 관통을 푸는 큰 임펄스를 받으면 CCD로도 못 막고 뚫린다
    /// (-physLab 실측: 스폰 43% 관통 → 한 칩이 v=2050pt/s로 튀어나가 y=−438000까지 낙하).
    /// 새어 나간 칩은 화면에서 사라질 뿐 아니라 **씬 전체의 안착을 영원히 막는다** —
    /// `allChipsCalm()`이 전 칩을 보므로 자유낙하하는 한 칩의 속도가 calm 판정을 계속 깨고,
    /// 그러면 force-settle이 없어 씬이 60fps로 영영 돈다(실기기 ①의 가장 지독한 형태).
    /// 회수 위치는 **그 칩의 x를 유지한 채 천장 바로 아래** — 결정적이고, 더미를 흩지 않는다.
    /// 방향이 고정 하강 벡터인 이유는 `tuckStraysUnderCeiling`과 같다(중력 방향을 쓰면 되쏜다).
    @discardableResult
    private func recoverEscapedChips() -> Bool {
        let s = chipSide, inset = wallInset
        // 판정 여유 = 칩 변 — 벽에 살짝 걸친 정상 상태를 이탈로 오인하지 않는다.
        let lowY = floorY - s, highY = spawnCeiling + s
        let lowX = inset - s, highX = size.width - inset + s
        let minX = inset + s * 0.5, maxX = max(minX, size.width - inset - s * 0.5)
        var recovered = false
        for node in chips.values {
            let p = node.position
            guard !p.x.isFinite || !p.y.isFinite
                    || p.y < lowY || p.y > highY || p.x < lowX || p.x > highX else { continue }
            let x = p.x.isFinite ? min(max(p.x, minX), maxX) : size.width * 0.5
            node.position = CGPoint(x: x, y: sealedCeiling - s * 0.5)
            node.physicsBody?.velocity = CGVector(dx: 0, dy: -220)
            node.physicsBody?.angularVelocity = 0
            recovered = true
        }
        if recovered { wake() }
        return recovered
    }

    /// 천장 관리(매 프레임) — 모든 칩이 가시 영역 안으로 들어오면 밀폐하고, 낙하 중이면 열어 둔다.
    /// 열린 채 `sealTimeout`이 지나면(= 기울기 탓에 위쪽에 갇힌 칩이 있다는 뜻) 강제로 끌어내리고 밀폐해
    /// "화면 밖으로 나가서 안 돌아옴"을 구조적으로 불가능하게 만든다.
    private func maintainCeiling(_ now: TimeInterval) {
        guard size.width > 1, size.height > 1 else { return }
        recoverEscapedChips()   // 상자를 뚫고 나간 칩 — 남겨 두면 안착이 영영 성립하지 않는다
        // 매 프레임 도는 자리다 — 불리언 하나 얻자고 배열을 만들지 않고, 계산 프로퍼티 체인
        // (`sealedCeiling` → `wallInset` → `chipSideFor`)도 칩마다 다시 타지 않게 한 번만 편다
        // (`tuckStraysUnderCeiling`이 이미 쓰는 방식).
        let ceiling = sealedCeiling
        guard chips.values.contains(where: { $0.position.y > ceiling }) else {
            unsealedSince = nil
            // 밀폐 = 이번 캐스케이드 종료 — 래칫을 내려 다음 캐스케이드가 자기 사다리를 새로 세운다.
            if !ceilingSealed { ceilingSealed = true; spawnCeilingMark = 0; buildWalls() }
            return
        }
        let since = unsealedSince ?? now
        unsealedSince = since
        guard now - since > sealTimeout else { return }
        // 갇힌 칩 회수 — 천장 바로 아래로 내려놓고 속도를 죽인 뒤 상자를 닫는다.
        tuckStraysUnderCeiling()
        unsealedSince = nil
        ceilingSealed = true
        spawnCeilingMark = 0
        buildWalls()
        wake()
    }

    /// 천장 **위**에 남은 칩을 상자 안으로 끌어들인다.
    ///
    /// 밀폐된 상자 바깥(위)에 놓인 칩은 스스로 못 들어온다 — 위로 기울인 상태면 그대로 떠올라
    /// 화면 밖에 머물고, 그러면 씬이 안착으로 판정해 잠들어(`forceSettle`) `maintainCeiling`의
    /// 타임아웃이 **영영 돌지 않는다**(재료가 화면 밖에서 사라진 것처럼 보였다).
    /// 그래서 `maintainCeiling`의 지연 회수와 별개로, 천장이 내려오는 순간에도 즉시 회수한다.
    /// 회수된 칩은 **상자 안쪽으로 밀어 넣는다** — 속도를 0으로 두면 천장 아래에 얼어붙은 채
    /// 나타나 실기기 피드백 "아이템이 갑자기 순간이동"처럼 읽혔다. 방향은 **항상 (0, −220)**,
    /// 즉 천장에서 바닥을 향하는 고정 벡터다. 그 시점 중력 방향을 쓰면(v1.0 (4)) 기기를 뒤집어
    /// 중력이 위를 향할 때 회수한 칩을 방금 빠져나온 천장으로 되쏘아, 법선이 중력과 나란한
    /// 착지 접촉이 되어 회수분 전체가 동시에 스쿼시 + 달그락을 냈다.
    private func tuckStraysUnderCeiling() {
        let ceiling = sealedCeiling
        let drop = CGVector(dx: 0, dy: -220)   // 상자 안쪽 고정 — 중력 방향과 무관
        for node in chips.values where node.position.y > ceiling {
            node.position.y = ceiling - chipSide * 0.5
            node.physicsBody?.velocity = drop
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
    /// 신선도는 들어간다 — 같은 글리프라도 시듦(채도·명도·처짐·라운딩)이 달라 픽셀이 다르다.
    /// `internal`(비-private) — `WiltCacheKeyTests`가 `@testable import`로 이 축의 존재를 직접
    /// 고정한다(`MainView.tiltLabLaunchConfig` 선례). 순수 함수라 씬을 띄우지 않고 검증된다.
    static func textureKey(for ing: Ingredient, side: CGFloat, shadowed: Bool) -> String {
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
        node.zPosition = Self.zPopOut
        // 잡고 있던 칩이 사라지면 드래그도 끝난 것이다 — 호버 텍스처를 끊지 않으면 손가락이
        // 존 위에 남아 있는 동안 "붙들려 있다"는 촉감만 주인 없이 계속 울린다.
        if node === dragged { dragged = nil; dragTouch = nil; endDragTexture() }

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
        // glyph는 충돌 시 촉감(sharpness·세기)을 되찾기 위해 — 물리 바디에서 노드로 거슬러 읽는다.
        // z는 드래그 승격에서 되돌릴 **원래 고정값**의 보관처다(nextChipZ 주석).
        let z = nextChipZ()
        node.zPosition = z
        node.userData = ["name": ing.name, "glyph": ing.glyph.rawValue,
                         "wilt": WiltStyle.for(ing.freshness).token, "z": z]
        // 물성은 글리프 클래스별 차등(위 ChipMaterial) — 계란은 굴러가고 두부는 눌러앉는다.
        // **낙하 축은 차등하지 않는다**: linearDamping 0.2와 중력 42는 §13.4의 "쿵" 감각이다.
        let mat = Self.material(for: ing.glyph)
        body.restitution = mat.restitution
        body.friction = mat.friction
        body.linearDamping = 0.2         // 둥둥 뜨진 않게, 빨리 안착 (전 클래스 공통)
        body.angularDamping = mat.angularDamping
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
            // 낙하 없이 바로 놓는다 — 자리는 사다리와 같은 declump 불변식을 지키는 격자(`staticSlot`).
            // 천장 아래로 클램프하는 것은 상자 밖 스폰을 막기 위한 것이다(밖에 놓이면 6초 뒤
            // `tuckStraysUnderCeiling`이 전부 같은 y로 끌어내려 오히려 한 줄로 뭉친다).
            let slot = Self.staticSlot(order: order, count: n, side: s, band: band)
            let top = max(floorY, sealedCeiling - s * 0.5)
            node.position = CGPoint(x: size.width / 2 + slot.dx,
                                    y: min(floorY + slot.dy, top))
        } else {
            // 위에서 스태거 낙하 → 더미. **클램프하지 않는다** — 사다리를 접으면 order가 큰 칩들이
            // 같은 y에 겹쳐 태어나고(실측 43.1% 관통), 그 깊은 관통이 벽 관통·고착·상시 움찔의
            // 공통 뿌리가 된다. 대신 천장을 사다리 위로 **올려서** 상자 안에 담는다.
            let y = size.height + Self.spawnHeight(order: order, side: s)
            node.position = CGPoint(x: x, y: y)
            raiseSpawnCeiling(to: y + s * Self.spawnHeadroom)
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
            node.colorBlendFactor = 0    // 방어적 리셋(폴백 단색 칩도 기본 0) — 텍스처가 틴트에 안 먹히게
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

    /// 칩 물리 바디(볼록 수퍼타원 폴리곤)의 **회전 반영 AABB**(씬 좌표).
    /// 진단 계측(`-physLab`)과 관통 해소가 **같은 식**을 써야 "측정한 겹침"과 "푸는 겹침"이 어긋나지 않는다.
    ///
    /// **닫힌 식을 쓰지 않는다.** 예전엔 회전한 타원의 지지함수 `√((a·cosθ)²+(b·sinθ)²)`로 반폭을 냈는데,
    /// 그건 바디가 실제로 타원(n=2)일 때만 맞는 식이다. 바디가 수퍼타원(n=4)이 된 뒤로는 같은 식이
    /// 53종 전부에서 회전각에 따라 AABB를 **최대 18.9% 과소평가**했다(옛 모양에서는 오차 0%).
    /// 그러면 `separationOverlap`이 재는 겹침이 실제 바디 겹침보다 훨씬 관대해진다 — 실측으로
    /// 예산이 5.2% → 10.0%(평균)로 두 배 벌어졌다. 그래서 **꼭짓점에서 직접** 잰다.
    /// dy 오프셋은 바디 로컬 좌표라 `bodyPolygon`이 이미 먹인 뒤 회전이 걸린다.
    private func bodyAABB(_ node: SKSpriteNode) -> CGRect {
        let s = node.size.width
        let glyph = (node.userData?["glyph"] as? String).flatMap(FoodGlyph.init(rawValue:))
        let m = glyph.flatMap { Self.bodyMetrics[$0] } ?? (w: 0.62, h: 0.60, dy: 0)
        let local = Self.bodyAABB(w: s * m.w, h: s * m.h, dy: s * m.dy, rotation: node.zRotation)
        return local.offsetBy(dx: node.position.x, dy: node.position.y)
    }

    /// 실측 바디 파라미터 (폭비, 높이비, y오프셋[+위]) — `-glyphMetrics` 계측값 그대로 붙여 넣는다:
    /// (w, h) = 알파 bbox × 0.9, dy = **알파 bbox 중심의 상향 오프셋**(`bboxCtrUp`).
    ///
    /// **dy 부호·기준 정정(실기기 3차 ②)**: 여기 있던 값들은 두 가지가 동시에 틀려 있었다 —
    /// v1 34종은 `bboxCtrUp`의 **부호가 뒤집힌** 채였고(그림이 프레임 위쪽에 그려진 글리프의 바디를
    /// 아래로 내려, 오차가 두 배가 됐다), v2 17종은 `dump()`가 세 번째 칸에 찍던 **질량중심**
    /// (`massUp`)을 그대로 옮겨 기준 자체가 달랐다. `-physLab` 콜라이더 오버레이에서 버섯의 바디가
    /// 갓만 덮고 자루를 비우는 식으로 눈에 보인다(어긋남 최대 0.12s ≈ 20pt @ s=169).
    /// 정본은 **bbox 중심**이다 — 볼록 근사 바디는 그려진 영역을 고르게 덮어야 하고, 질량중심은
    /// 짙은 쪽으로 쏠려 옅은 끝을 비운다. `dump()`도 이 칸을 찍도록 함께 고쳤다(재측정 = 재현).
    private static let bodyMetrics: [FoodGlyph: (w: CGFloat, h: CGFloat, dy: CGFloat)] = [
        .leaf: (0.52, 0.68, 0.00),  .root: (0.27, 0.67, 0.01), .squash: (0.35, 0.59, -0.03),
        .onion: (0.52, 0.65, 0.05), .tomato: (0.56, 0.60, 0.00), .pepper: (0.55, 0.64, 0.01),
        .mushroom: (0.59, 0.54, -0.02), .broccoli: (0.56, 0.62, -0.01), .potato: (0.59, 0.46, 0.00),
        .garlic: (0.46, 0.58, 0.03), .cucumber: (0.60, 0.59, -0.01), .pea: (0.59, 0.36, -0.06),
        .cabbage: (0.62, 0.59, 0.02), .chili: (0.30, 0.70, 0.00), .pumpkin: (0.60, 0.54, 0.02),
        .apple: (0.61, 0.67, -0.02),  .citrus: (0.60, 0.45, 0.00), .berry: (0.46, 0.61, 0.01),
        .avocado: (0.44, 0.62, 0.00), .banana: (0.61, 0.35, -0.05), .egg: (0.54, 0.59, -0.01),
        .tofu: (0.68, 0.42, 0.02),  .meat: (0.62, 0.47, -0.01),  .poultry: (0.42, 0.59, -0.01),
        .fish: (0.67, 0.40, 0.00),   .shrimp: (0.48, 0.57, 0.01), .milk: (0.41, 0.62, 0.00),
        .cheese: (0.62, 0.45, 0.04), .bread: (0.56, 0.54, 0.03), .rice: (0.54, 0.49, 0.03),
        .noodles: (0.56, 0.48, 0.06), .corn: (0.46, 0.59, -0.01), .sauceBottle: (0.30, 0.65, 0.01),
        .can: (0.45, 0.47, 0.00),
        // v2 신규 17종 — `-glyphMetrics` 실측(알파 bbox×0.9 + 질량중심 정렬).
        .eggplant: (0.35, 0.63, 0.00), .sweetPotato: (0.55, 0.28, 0.01), .ginger: (0.49, 0.40, 0.02),
        .seaweed: (0.51, 0.58, 0.00), .grape: (0.42, 0.54, -0.02), .watermelon: (0.63, 0.51, 0.02),
        .pineapple: (0.38, 0.65, -0.02), .mango: (0.52, 0.48, -0.02), .sausage: (0.57, 0.52, -0.03),
        .bacon: (0.67, 0.36, -0.02), .crab: (0.61, 0.54, 0.04), .squid: (0.29, 0.61, 0.01),
        .clam: (0.56, 0.43, 0.12), .yogurt: (0.44, 0.61, 0.02), .butter: (0.64, 0.33, 0.07),
        .honey: (0.43, 0.61, 0.02), .dumpling: (0.54, 0.32, 0.04),
        .gimbap: (0.72, 0.71, -0.01),
        .generic: (0.60, 0.56, -0.01),
    ]

    /// 표에서 가장 높은 바디의 높이비 — **스폰 간격(`spawnStep`)이 이 값을 넘어야** 이웃 order가
    /// 겹쳐 태어나지 않는다. `internal`이라 SpawnLadderTests가 리터럴을 다시 적지 않고 불변식을 건다.
    static let maxBodyHeightRatio: CGFloat = bodyMetrics.values.map(\.h).max() ?? 0.7

    /// 표에서 가장 넓은 바디의 폭비 — **정적 배치(`staticSlot`)의 열 간격이 이 값을 넘어야**
    /// 같은 행의 두 칩이 겹쳐 태어나지 않는다. 세로 축의 `maxBodyHeightRatio`와 짝이다.
    static let maxBodyWidthRatio: CGFloat = bodyMetrics.values.map(\.w).max() ?? 0.72

    /// 표 조회구 — 빠진 글리프는 nil. `internal`: 전수 커버(53종)를 테스트가 고정한다.
    /// 실제로 `.gimbap`이 표에서 누락돼 폴백 바디(0.62×0.60)를 쓰고 있었다(실루엣과 어긋남).
    static func bodyMetric(for glyph: FoodGlyph) -> (w: CGFloat, h: CGFloat, dy: CGFloat)? {
        bodyMetrics[glyph]
    }

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

    // MARK: - 재료 물성 (§13.4)

    /// 칩 하나의 물성 — **회전·마찰 축만** 차등한다. 질량 차이만으론 부딪히기 전까지 아무것도 안 보이지만,
    /// 마찰과 각감쇠는 기울이는 순간 바로 읽힌다(계란은 데굴데굴, 두부는 그 자리에 눌러앉는다).
    ///
    /// **낙하 축(중력 42 · linearDamping 0.2)은 일부러 건드리지 않는다.** §13.4가 규정한 감각은
    /// "묵직하게 — 큰 중력 + 낮은 반발로 쿵 떨어져 거의 안 튄다"이고, 클래스별 종단속도를 주는
    /// 튜닝은 그 반대(둥둥 뜨는 수중감)라 SSOT와 충돌한다. 그래서 `linearDamping` 필드 자체를 두지 않는다.
    private struct ChipMaterial {
        /// **햅틱 대표자 선정 전용 랭킹 키**다. `body.mass`에는 절대 대입하지 않는다 —
        /// 실제 질량은 실측 바디 면적비에서 파생한다(`mass(for:)`, 53종 전부 자동 커버).
        /// 칩-칩 충돌에서 "어느 쪽 촉감이 소리를 주도하나"를 가를 때만 쓴다(`clatterMaterial`).
        let mass: CGFloat
        let restitution: CGFloat       // 0 = 안 튐, 클수록 통통 (기준 0.12에서 클래스별 ±0.02)
        let friction: CGFloat          // 클수록 안 미끄러짐
        let angularDamping: CGFloat    // 작을수록 잘 구른다
        /// 달그락 햅틱의 날카로움 — 1에 가까울수록 쨍한 '클링'(캔·병), 0에 가까울수록 둔탁한 '툭'(고기).
        var sharpness: Float = 0.5
        /// 달그락 햅틱의 세기 배율 — 여린 재료(잎·두부)는 같은 임펄스라도 약하게 친다.
        var hapticScale: Float = 0.8
        /// 달그락 햅틱의 **감쇠 속도** 0...1 — 재질 공명 프로필의 셋째 축(§7.6). 1이면 잔향 없이
        /// 즉시 끊기고(단단한 껍질·여린 잎), 0이면 길게 끌린다(물먹은 덩어리). 0.5가 중립이라
        /// 값을 안 주는 `standard`는 예전 꼬리 길이 그대로다.
        var hapticDecay: Float = 0.5

        /// 촉감 계산기(`ClatterFeelRule`·`RollTextureRule`)가 읽는 축만 추린 것. 변환을 여기 한 곳에
        /// 모아 두면 물리 축(마찰·각감쇠·반발)이 촉감 규칙으로 새어 들 통로가 애초에 없다.
        var clatter: ClatterMaterial {
            ClatterMaterial(sharpness: sharpness, scale: hapticScale, decay: hapticDecay)
        }

        /// 기본 — 대부분의 채소·과일. **기존 값 그대로**라 표에 없는 글리프는 완전한 무변화다.
        static let standard = ChipMaterial(mass: 0.70, restitution: 0.12, friction: 0.55,
                                           angularDamping: 0.85)
        /// 가벼움 — 잎채소·해조·버섯·빵. 살짝 더 통통 튀고 잘 미끄러지지 않는다.
        /// 촉감: 여린 '틱' — 잎사귀가 스치는 정도라 세기를 크게 낮추고, 잔향은 거의 없다(감쇠 0.80).
        static let light = ChipMaterial(mass: 0.40, restitution: 0.13, friction: 0.66,
                                        angularDamping: 0.90, sharpness: 0.55,
                                        hapticScale: 0.42, hapticDecay: 0.80)
        /// 잘 구름 — 계란·토마토·사과처럼 둥글고 매끈한 것. 마찰·각감쇠가 낮아 기울이면 데굴데굴 굴러간다.
        /// 촉감: 또각 — 단단한 껍질이 부딪히는 중간 날카로움에 짧은 감쇠(0.70).
        static let rolling = ChipMaterial(mass: 0.80, restitution: 0.14, friction: 0.30,
                                          angularDamping: 0.78, sharpness: 0.68,
                                          hapticScale: 0.85, hapticDecay: 0.70)
        /// 묵직함 — 소고기·연어 등 덩어리 단백질. 안 튀고, 기울여도 굼뜨게 미끄러지며 가벼운 재료를 밀어낸다.
        /// 촉감: 둔탁한 '툭' — 살덩이가 떨어지는 소리. 세기는 크되 날카로움은 최소이고 길게 끌린다(0.22).
        static let heavy = ChipMaterial(mass: 1.40, restitution: 0.11, friction: 0.70,
                                        angularDamping: 0.96, sharpness: 0.18,
                                        hapticScale: 1.0, hapticDecay: 0.22)
        /// 용기 — 우유갑·소스병·캔. 표면이 매끈해 잘 미끄러진다.
        /// 촉감: 쨍한 '클링' — 캔·유리병끼리 부딪히는 금속성. 이 계열이 달그락의 주인공이고,
        /// 딱 끊기는 짧은 감쇠(0.85)가 '클링'을 '웅'과 가른다.
        static let container = ChipMaterial(mass: 1.15, restitution: 0.12, friction: 0.46,
                                            angularDamping: 0.92, sharpness: 0.95,
                                            hapticScale: 1.0, hapticDecay: 0.85)
        /// 물렁함 — 두부·밥·면·만두. 닿은 자리에 착 붙어 거의 안 구른다.
        /// 촉감: 퍽 — 물먹은 덩어리라 거의 촉감이 없다(가장 약하고 가장 뭉툭하며 가장 길게 끌린다).
        static let soft = ChipMaterial(mass: 0.75, restitution: 0.11, friction: 0.82,
                                       angularDamping: 0.98, sharpness: 0.10,
                                       hapticScale: 0.50, hapticDecay: 0.10)
    }

    /// 노드 하나의 촉감 물성 — 구름 텍스처가 대표 칩에서 뽑아 쓴다.
    /// 글리프를 못 읽으면 중립(스폰 직후·userData가 비어 있는 예외 경로에서도 무음이 되지 않게).
    private static func clatterMaterial(of node: SKNode) -> ClatterMaterial {
        guard let raw = node.userData?["glyph"] as? String,
              let glyph = FoodGlyph(rawValue: raw) else { return .neutral }
        return material(for: glyph).clatter
    }

    /// 글리프 → 물성. 53종을 하나씩 손으로 매기면 유지도 안 되고 의도도 흐려져,
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
        .tofu: .soft, .rice: .soft, .noodles: .soft, .dumpling: .soft, .gimbap: .soft,
        .avocado: .soft, .banana: .soft,
    ]

    private static func material(for glyph: FoodGlyph) -> ChipMaterial {
        materials[glyph] ?? .standard
    }

    /// 락스텝 방지용 결정적 지터 0..1 — 흔들기 킥의 각도·세기를 칩마다 흩어
    /// 완전히 같은 벡터로 나란히 이동하는 "판박이 이동"(= 충돌 0, 달그락 0)을 없앤다.
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

    /// 볼록 **수퍼타원** 바디(dy로 중심 오프셋) — `|x/a|^n + |y/b|^n = 1`.
    /// SpriteKit `polygonFrom`은 볼록만 허용해 끼임·진동이 없고, 수퍼타원은 n ≥ 1이면 항상 볼록이다.
    ///
    /// **왜 타원이 아닌가.** 컷페이퍼 글리프는 자기 bbox의 **모서리와 뾰족한 끝까지** 그림이 차 있다
    /// (생선 꼬리·우유갑 모서리·치즈 꼭짓점·베이컨 끝). 내접 타원은 그 모서리를 통째로 비워서
    /// bbox 대비 커버리지가 `0.90² × π/4 ≈ 0.64`에 그쳤다 — 두 칩의 바디가 **정확히 맞닿은 상태에서도**
    /// 그림끼리는 수십 pt 겹쳐 보인다(실측: 생선 꼬리 29pt, 우유갑 모서리 27pt). n을 올리면 모서리가 찬다.
    ///
    /// **크기를 키워 고치면 안 된다.** 타원을 bbox 모서리에 닿게 하려면 두 축 모두 √2배가 필요한데,
    /// 그러면 평평한 변이 bbox 밖으로 41% 삐져나가 칩 사이에 눈에 띄는 빈틈이 생긴다 —
    /// `e5b2bb2`가 고쳤던 바로 그 버그다. **모양만 바꾸고 0.90 인셋과 실측 테이블은 건드리지 않는다.**
    /// 질량(`mass(for:)`)은 바디 면적이 아니라 테이블을 읽으므로 이 변경으로 1비트도 달라지지 않는다.
    ///
    /// **모양을 바꿀 땐 `bodyAABB`도 같이 본다.** 관통 해소·벽 클램프·`-physLab` 계측은 전부
    /// 이 바디의 AABB로 겹침을 재는데, 그 AABB가 실제 꼭짓점이 아니라 옛 모양의 닫힌 식에서 나오면
    /// "재는 겹침"과 "푸는 겹침"이 소리 없이 갈린다(`separationOverlap` 주석의 실측표 참고).
    private static func ovalBody(_ w: CGFloat, _ h: CGFloat, dy: CGFloat = 0) -> SKPhysicsBody {
        let path = CGMutablePath()
        for (i, p) in bodyPolygon(w: w, h: h, dy: dy).enumerated() {
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return SKPhysicsBody(polygonFrom: path)
    }

    /// 실제 바디의 각 수·수퍼타원 지수 — **프로덕션 모양의 유일한 정의처**.
    /// `internal`: 테스트가 리터럴 16·4를 다시 적지 않고 이 값에 불변식을 건다.
    static let bodySides = 16
    static let bodyExponent: CGFloat = 4

    /// 바디 꼭짓점 — `ovalBody`가 **이 점들로** path를 만들고 `bodyAABB`가 **이 점들로** AABB를 잰다.
    /// `internal`(비-private): 커버리지·AABB 테스트가 실제 바디와 **같은 점**을 검사하게 하려고 공유한다.
    /// 테스트가 수식을 복제하면 모양을 바꿔도 테스트만 옛 모양을 검사해 회귀를 놓친다(`textureKey` 선례).
    ///
    /// `sides`·`n`은 **비교 실험 전용 기본인자**다(옛 타원과 커버리지를 견주는 테스트). 프로덕션 경로는
    /// 셋 다 인자를 주지 않아 항상 `bodySides`·`bodyExponent`를 탄다 — 기본값을 되돌리면 커버리지
    /// 테스트가 곧바로 깨진다.
    static func bodyPolygon(w: CGFloat, h: CGFloat, dy: CGFloat = 0,
                            sides: Int = bodySides, n: CGFloat = bodyExponent) -> [CGPoint] {
        // 프로덕션 모양은 **단위 꼭짓점을 한 번만** 계산해 재사용한다 — `bodyAABB`가 관통 해소
        // 한 바퀴에 쌍마다 두 번씩 불리므로(36칩 = 10바퀴 × 630쌍 × 2), 매번 `pow`를 32회 돌면
        // 안착 직전 한 프레임에 40만 회가 몰린다. 모양은 스케일 불변이라 곱셈만 남기면 된다.
        if sides == bodySides, n == bodyExponent {
            return unitBodyPolygon.map { CGPoint(x: $0.x * w / 2, y: $0.y * h / 2 + dy) }
        }
        return unitPolygon(sides: sides, n: n).map { CGPoint(x: $0.x * w / 2, y: $0.y * h / 2 + dy) }
    }

    /// 반지름 1 수퍼타원의 꼭짓점(프로덕션 모양) — `bodyPolygon`이 여기에 반폭·반높이를 곱한다.
    private static let unitBodyPolygon: [CGPoint] = unitPolygon(sides: bodySides, n: bodyExponent)

    private static func unitPolygon(sides: Int, n: CGFloat) -> [CGPoint] {
        (0..<sides).map { i in
            let a = CGFloat(i) / CGFloat(sides) * 2 * .pi
            let c = cos(a), s = sin(a)
            // 수퍼타원 파라메트릭: x = sgn(cos)·|cos|^(2/n), y = sgn(sin)·|sin|^(2/n). n=2면 타원.
            return CGPoint(x: copysign(pow(abs(c), 2 / n), c),
                           y: copysign(pow(abs(s), 2 / n), s))
        }
    }

    /// 바디 로컬 AABB(노드 위치 이전, `rotation` 반영) — 꼭짓점에서 **직접** 잰다.
    /// 순수 함수라 테스트가 씬 없이 "AABB가 실제 폴리곤을 감싸는 최소 사각인가"를 고정한다.
    static func bodyAABB(w: CGFloat, h: CGFloat, dy: CGFloat, rotation: CGFloat) -> CGRect {
        let c = cos(rotation), s = sin(rotation)
        var minX = CGFloat.greatestFiniteMagnitude, minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude, maxY = -CGFloat.greatestFiniteMagnitude
        for p in bodyPolygon(w: w, h: h, dy: dy) {
            let x = p.x * c - p.y * s, y = p.x * s + p.y * c
            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    // MARK: - 착지 임팩트 (스쿼시 + 달그락 햅틱)

    /// 접촉 시작 — **두 가지 일을 한 번에** 한다. 축이 일부러 다르다.
    /// ① 스쿼시: 임펄스를 질량으로 나눠 **근사 속도변화(pt/s)**로 환산한다. 나눈 값은
    ///    calmSpeed와 같은 축이라 "쌓이는 더미의 잔접촉"과 "실제 착지"를 기존 튜닝과
    ///    같은 기준으로 가른다.
    /// ② 달그락: **생 임펄스** 그대로 세 관문(임펄스·전역간격·쌍 쿨다운)에 태운다. 운동량 전달이
    ///    곧 체감 크기라, 질량으로 나누면 소고기와 잎사귀가 같은 세기로 느껴진다.
    func didBegin(_ contact: SKPhysicsContact) {
        guard !idle, !externallyPaused else { return }
        let impulse = contact.collisionImpulse
        guard impulse > 0 else { return }
        #if DEBUG
        if Self.physLab { physLabContacts += 1 }
        #endif
        // 착지 게이트 — 접촉 법선이 현재 중력과 나란한 접촉만 스쿼시한다(굴림 옆접촉 제외).
        // 중력이 0인 극단에선 방향이 정의되지 않으니 게이트를 열어 둔다.
        if isLandingContact(contact) {
            for body in [contact.bodyA, contact.bodyB] where body.categoryBitMask & Category.chip != 0 {
                let dv = impulse / max(0.2, body.mass)
                #if DEBUG
                if Self.physLab { physLabDvMax = max(physLabDvMax, dv); physLabDvSum += dv; physLabDvCount += 1 }
                #endif
                guard dv >= squashImpact, let node = body.node as? SKSpriteNode else { continue }
                squash(node, strength: min(1, (dv - squashImpact) / (squashImpactMax - squashImpact)))
            }
        }
        // 햅틱은 Reduce Motion과 무관하게 살아 있다 — 시각 배려지 촉각 배려가 아니다(§7.4).
        let pair = ClatterPair(ObjectIdentifier(contact.bodyA).hashValue,
                               ObjectIdentifier(contact.bodyB).hashValue)
        guard clatterThrottle.allow(impulse: impulse, pair: pair, now: lastUpdateTime) else { return }
        let mat = clatterMaterial(contact.bodyA, contact.bodyB)
        // 변주 시드는 **발화 순번**이다(allow가 방금 올렸다) — 같은 충돌 시퀀스면 같은 촉감이라
        // 튜닝 비교와 계측 QA가 실행마다 흔들리지 않는다.
        clatter.play(clatterRule.feel(impulse: impulse,
                                      material: mat.clatter,
                                      sequence: clatterThrottle.fireCount))
        // 계측 카운터도 함께 침묵한다 — 아무것도 울리지 않는데 TILT LAB의 "HAPTIC n/s"가 올라가면
        // 유일한 관측 수단이 거짓말을 한다. 스로틀(발화 순번)은 그대로 돌아 튜닝 기준선은 안 흔들린다.
        if hapticsEnabled { onClatter?() }
    }

    /// 이 접촉이 '착지'인가 — 접촉 법선이 **그 시점 중력**과 얼마나 나란한지로 판정한다.
    /// 굴림·더미 옆비빔은 법선이 중력에 수직(dot≈0)이라 걸러지고, 바닥·더미 위 착지는
    /// 기울인 중력에서도 법선이 중력축과 나란해(|dot|≈1) 통과한다. 햅틱 축은 건드리지 않는다 —
    /// 굴러 부딪히는 달그락은 **들려야** 맞고, 다만 눌려 보이면 안 될 뿐이다.
    private func isLandingContact(_ contact: SKPhysicsContact) -> Bool {
        let g = physicsWorld.gravity
        let len = (g.dx * g.dx + g.dy * g.dy).squareRoot()
        guard len > 0 else { return true }
        let n = contact.contactNormal   // SpriteKit이 단위벡터로 준다
        return abs((n.dx * g.dx + n.dy * g.dy) / len) > squashNormalAlign
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

    /// 착지 눌림 — 가로로 퍼지고 세로로 눌렸다가 복귀(최대 6%). 배율은 **정확히 1로** 되돌린다.
    /// 드래그 중인 칩과 Reduce Motion·휴면은 제외(손끝 추종이 흔들리지 않게, §7.4).
    private func squash(_ node: SKSpriteNode, strength: CGFloat) {
        guard !reduceMotion, !idle, node !== dragged else { return }
        guard node.action(forKey: "squash") == nil else { return }   // 연쇄 접촉으로 겹쳐 실행 금지
        // 칩당 쿨다운 — 위 재진입 가드는 애니메이션이 도는 동안(~180ms)만 유효해서, 끝나는 즉시
        // 다음 접촉이 또 눌렀다. 실기기 "움찔거림" 피드백의 나머지 절반이 이 연타였다.
        let now = CACurrentMediaTime()
        if let last = node.userData?["squashAt"] as? TimeInterval, now - last < squashCooldown { return }
        if node.userData == nil { node.userData = [:] }
        node.userData?["squashAt"] = now
        #if DEBUG
        if Self.physLab { physLabSquashes += 1 }
        #endif
        let amt = 0.03 + 0.03 * min(1, max(0, strength))
        let d = ReffiMotion.dur2
        let press = SKAction.scaleX(to: 1 + amt, y: 1 - amt, duration: d * 0.35)
        press.timingMode = .easeOut
        let back = SKAction.scaleX(to: 1, y: 1, duration: d * 0.65)
        back.timingMode = .easeOut
        // 마지막에 한 번 더 확정 대입 — 중간에 액션이 끊겨도 배율 잔차가 남지 않는다.
        node.run(.sequence([press, back, .run { [weak node] in node?.setScale(1) }]), withKey: "squash")
    }

    // MARK: - Drag / throw / tap (단일 터치 추적)

    /// 드래그 승격 해제 — 스폰 때 정한 고정 z로 되돌린다. 보관값이 없으면(옛 노드) 새로 뽑아
    /// 어떤 경우에도 다른 칩과 z가 겹치지 않게 한다(동률 = 그리기 순서 비결정 = 깜빡임).
    private func restoreChipZ(_ node: SKSpriteNode?) {
        guard let node, node.physicsBody != nil else { return }   // popOut 중인 노드는 z=50 유지
        if let z = node.userData?["z"] as? CGFloat {
            node.zPosition = z
        } else {
            let z = nextChipZ()
            node.zPosition = z
            node.userData?["z"] = z
        }
    }

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
        #if DEBUG
        Logger(subsystem: "com.reffi.app", category: "scene")
            .debug("touch: loc=(\(loc.x),\(loc.y)) scene=\(self.size.width)x\(self.size.height) chips=\(self.chips.count) hit=\(self.chip(at: loc) != nil)")
        #endif
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
        node.zPosition = Self.zDragged   // 잡은 칩은 더미 위로 — 복귀값은 userData["z"]에 그대로 있다
        if let body = node.physicsBody {
            body.affectedByGravity = false   // 잡는 동안 중력 off → 손가락 추종(동적 유지)
            body.angularVelocity = 0
            body.usesPreciseCollisionDetection = true   // 던지기 터널링 방지(안착하면 다시 자동 false)
        }
        // 잡히는 순간의 가벼운 '집혔다'. 물리 사건이라 §7.6 의미 매핑이 아니라 물리 질감 계열이고,
        // 터치 시작은 그 자체로 빈도가 묶여 있어 스로틀을 태울 필요가 없다.
        clatter.play(ClatterAccent.pick)
        // 구르던 텍스처는 여기서 끊는다 — 손이 개입한 순간의 채널 주인은 드래그다.
        endDragTexture()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = dragTouch, touches.contains(t), dragged != nil else { return }
        let raw = t.location(in: self)
        // 탭/드래그 판정은 시작점 기준 **누적** 이동 — 아무리 천천히 끌어도 탭으로 오판하지 않는다.
        if !dragMoved, hypot(raw.x - dragStart.x, raw.y - dragStart.y) > 8 {
            dragMoved = true
        }
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
        // 드래그 상태가 **밖에서 지워진** 경우에도 존은 내린다. `popOut`은 sync 도중 잡고 있던 칩이
        // 사라지면 `dragTouch`를 nil로 만드는데, 그 뒤 손을 떼면 옛 가드가 먼저 return하고
        // 아래 `defer`는 설치조차 되지 않아(Swift defer는 실행이 그 줄에 닿아야 등록된다) 판정
        // 블롭이 판정 존 알파로 화면에 남았다 — 다음 드래그가 정상 종료될 때까지 지워지지 않는다.
        // 반대로 "다른 손가락이 떨어진 경우"는 그대로 무시한다(진행 중인 드래그의 예고를 지우면 안 된다).
        guard let t = dragTouch else { setZones(visible: false); return }
        guard touches.contains(t) else { return }
        defer {
            restoreChipZ(dragged)   // 승격 해제 — 스폰 때 정한 고정값으로 되돌린다(결정적)
            endDragTexture()        // 호버 텍스처는 손을 떼는 즉시 끊는다(유예 없이)
            dragTouch = nil; dragged = nil; setZones(visible: false)
        }
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
        guard let t = dragTouch else { setZones(visible: false); endDragTexture(); return }   // touchesEnded와 같은 이유
        guard touches.contains(t) else { return }
        dragged?.physicsBody?.affectedByGravity = true
        restoreChipZ(dragged)
        endDragTexture()
        dragTouch = nil
        dragged = nil
        setZones(visible: false)
    }

    /// 드래그가 끝날 때의 지속 촉감 정리 — 관문을 유예 없이 닫고 채널을 비운다.
    /// 손을 뗀 뒤에도 호버 텍스처가 0.14초 더 울리면 그건 "붙들려 있다"는 거짓말이다.
    private func endDragTexture() {
        textureGate.reset()
        lastRollTexture = nil
        lastCapturedZone = nil
        clatter.stopTexture()
    }
}
