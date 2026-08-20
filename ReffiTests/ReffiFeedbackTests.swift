import Testing
import Foundation
@testable import Reffi

/// 감각 토글(프로필 "Feel")의 저장소 판독 규약.
///
/// 여기서 잡으려는 회귀는 하나다: **미설정 = 켬**. `UserDefaults.bool(forKey:)`는 값이 없으면
/// false를 돌려주므로, 그대로 쓰면 토글을 한 번도 만지지 않은 첫 실행에서 햅틱·기울임이 통째로
/// 꺼진 채 시작한다(화면의 스위치는 `@AppStorage` 기본값 true라 켜져 보인다 = 위약 UI).
/// 씬은 이 정적 접근자로 초기값을 읽으므로(뷰 주입은 `didMove` 뒤일 수 있다) 판독이 갈리면
/// 홈 진입 한 프레임의 거동이 화면 표시와 어긋난다.
///
/// UserDefaults.standard를 실제로 만지므로 직렬 실행 + 각 케이스가 끝에 키를 원복한다.
@Suite(.serialized)
struct ReffiFeedbackTests {

    private func withKey(_ key: String, _ body: () -> Void) {
        let saved = UserDefaults.standard.object(forKey: key)
        defer {
            if let saved { UserDefaults.standard.set(saved, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        body()
    }

    @Test func hapticsDefaultsToOnWhenUnset() {
        withKey(ReffiFeedback.hapticsKey) {
            UserDefaults.standard.removeObject(forKey: ReffiFeedback.hapticsKey)
            #expect(ReffiFeedback.hapticsEnabled == true)
        }
    }

    @Test func tiltDefaultsToOnWhenUnset() {
        withKey(ReffiFeedback.tiltKey) {
            UserDefaults.standard.removeObject(forKey: ReffiFeedback.tiltKey)
            #expect(ReffiFeedback.tiltEnabled == true)
        }
    }

    @Test func storedFalseTurnsOff() {
        withKey(ReffiFeedback.hapticsKey) {
            UserDefaults.standard.set(false, forKey: ReffiFeedback.hapticsKey)
            #expect(ReffiFeedback.hapticsEnabled == false)
        }
        withKey(ReffiFeedback.tiltKey) {
            UserDefaults.standard.set(false, forKey: ReffiFeedback.tiltKey)
            #expect(ReffiFeedback.tiltEnabled == false)
        }
    }

    @Test func storedTrueTurnsOn() {
        withKey(ReffiFeedback.tiltKey) {
            UserDefaults.standard.set(true, forKey: ReffiFeedback.tiltKey)
            #expect(ReffiFeedback.tiltEnabled == true)
        }
    }

    /// 두 키는 서로 독립이다 — 한쪽을 꺼도 다른 쪽 판독이 흔들리면 안 된다(키 오타 가드).
    @Test func keysAreIndependent() {
        withKey(ReffiFeedback.hapticsKey) {
            withKey(ReffiFeedback.tiltKey) {
                UserDefaults.standard.set(false, forKey: ReffiFeedback.hapticsKey)
                UserDefaults.standard.set(true, forKey: ReffiFeedback.tiltKey)
                #expect(ReffiFeedback.hapticsEnabled == false)
                #expect(ReffiFeedback.tiltEnabled == true)
            }
        }
    }
}
