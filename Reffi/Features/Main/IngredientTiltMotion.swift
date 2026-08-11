import CoreMotion
import Foundation

/// deviceMotion 한 프레임 — 저역(중력 방향)과 고역(손이 흔든 성분)을 함께 넘긴다.
/// 중력만으론 **빠른 흔들기가 씬에 전혀 전달되지 않는다** — gravity는 저역 통과된 자세 신호라
/// 흔드는 동안에도 거의 변하지 않기 때문이다. 달그락을 만들려면 `userAcceleration`(중력 제외분)이
/// 필요하고, 그 값을 씬이 임펄스 킥으로 바꿔 재료를 실제로 부딪히게 한다.
struct TiltSample {
    /// 정규화된 중력 방향(세워 들면 (0, -1)) — 씬 중력의 방향이 된다.
    let gravityX: CGFloat
    let gravityY: CGFloat
    /// 사용자 가속도(G 단위, 중력 제외) — 흔들기 에너지.
    let shakeX: CGFloat
    let shakeY: CGFloat
}

/// 기울기 중력원(§13.4) — CoreMotion `deviceMotion.gravity`의 **화면 평면 성분(x, y)** 만 뽑아
/// 물리 씬에 흘린다. 폰을 기울이면 재료 더미가 중력 방향으로 굴러가는 연출의 입력단이다.
///
/// **CMMotionManager는 앱에 하나만 둔다** — 인스턴스를 여러 개 만들면 서로의 갱신 주기를 덮어써
/// 샘플링이 불안정해진다(Apple 권고). 씬(`IngredientDropScene`)이 이 객체 하나를 소유하고,
/// 시작·정지도 씬 수명주기에 묶는다.
///
/// **세로 고정 전제** — `project.yml`의 `UISupportedInterfaceOrientations`가 Portrait 단독이라
/// 기기 좌표(+x 오른쪽 / +y 위)가 곧 씬 좌표(SpriteKit도 +y 위)와 일치한다. 즉 세워 든 자세의
/// gravity는 (0, -1, 0)이고, 이는 씬의 기본 중력 방향(아래)과 그대로 맞아떨어진다.
/// 나중에 가로 회전을 열게 되면 여기서 인터페이스 방향만큼 축을 돌려야 한다.
///
/// 메인 스레드 전용 — SpriteKit 씬을 다른 스레드에서 만지지 않도록 갱신도 메인 큐로 받는다.
final class IngredientTiltMotion {
    /// 60fps 물리와 같은 주기. 더 자주 받아봐야 시뮬레이션 스텝이 소화하지 못한다.
    private static let updateInterval = 1.0 / 60.0

    private let manager = CMMotionManager()
    private var onSample: ((TiltSample) -> Void)?

    /// 자이로·가속도계가 없는 환경(시뮬레이터 등)에선 false — 호출부는 기본 중력을 유지한다.
    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    /// 갱신 시작. 이미 돌고 있으면 콜백만 갈아끼운다(중복 start로 큐가 겹치지 않게).
    func start(_ handler: @escaping (TiltSample) -> Void) {
        onSample = handler
        guard isAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = Self.updateInterval
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let m = motion else { return }
            self.onSample?(TiltSample(gravityX: CGFloat(m.gravity.x),
                                      gravityY: CGFloat(m.gravity.y),
                                      shakeX: CGFloat(m.userAcceleration.x),
                                      shakeY: CGFloat(m.userAcceleration.y)))
        }
    }

    /// 정지 — 탭을 벗어나거나 백그라운드로 가면 반드시 부른다(센서 갱신은 배터리를 먹는다).
    func stop() {
        // 핸들러를 먼저 비운다 — 업데이트가 활성이 아니어도 클로저를 붙들고 있지 않도록
        // (in-flight 콜백 자가 취소 계약은 이 nil 처리에 의존한다).
        onSample = nil
        guard manager.isDeviceMotionActive else { return }
        manager.stopDeviceMotionUpdates()
    }

    /// 안전망 — 소유자(씬)가 stop 없이 사라져도 센서가 계속 돌지 않게.
    deinit { manager.stopDeviceMotionUpdates() }
}
