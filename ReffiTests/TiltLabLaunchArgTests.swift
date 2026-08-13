#if DEBUG
import Testing
import Foundation
@testable import Reffi

/// tiltLab 런치 인자 파서(`MainView.tiltLabLaunchConfig`) — NSArgumentDomain(UserDefaults)은
/// `-tiltLab.x -0.9`처럼 값이 음수면 `-0.9`를 다음 키로 오인해 바인딩을 통째로 잃는 결함이 있었고
/// (시뮬레이터 QA로 실증), `-tiltLab.shake` 단독 지정도 실험실 게이트 밖이라 스케줄이 안 걸렸다.
/// ProcessInfo.arguments를 직접 파싱하는 순수 함수로 교체한 뒤 이 회귀들을 여기서 고정한다.
@MainActor
struct TiltLabLaunchArgTests {
    private func parse(_ args: [String]) -> (x: Double?, y: Double?, labOn: Bool, shake: Bool) {
        MainView.tiltLabLaunchConfig(from: args)
    }

    /// 핵심 회귀 — 음수 x는 NSArgumentDomain에서 소실됐지만, 직접 파싱에선 그대로 살아남아야 한다.
    @Test func negativeX() {
        let c = parse(["-tiltLab.x", "-0.9"])
        #expect(c.x == -0.9)
        #expect(c.labOn == true)
    }

    /// 핵심 회귀 — 음수 y도 동일하게 살아남아야 한다.
    @Test func negativeY() {
        let c = parse(["-tiltLab.y", "-0.2"])
        #expect(c.y == -0.2)
        #expect(c.labOn == true)
    }

    /// 양수 x/y 조합 — 기존에도 동작하던 경로가 계속 동작해야 한다.
    @Test func positiveCombo() {
        let c = parse(["-tiltLab.x", "0.9", "-tiltLab.y", "0.4"])
        #expect(c.x == 0.9)
        #expect(c.y == 0.4)
        #expect(c.labOn == true)
        #expect(c.shake == false)
    }

    /// `-tiltLab` 단독 — x/y 없이도 실험실은 켜지고, 슬라이더는 기본값(nil)을 쓴다.
    @Test func standaloneTiltLabFlag() {
        let c = parse(["-tiltLab"])
        #expect(c.labOn == true)
        #expect(c.x == nil)
        #expect(c.y == nil)
        #expect(c.shake == false)
    }

    /// 핵심 회귀 — `-tiltLab.shake` 단독 지정. 예전엔 tiltLabOn 게이트 안쪽에서만 셰이크 스케줄을
    /// 걸어서 실험실 자체가 안 켜지면 아무 효과가 없었다. 이제는 shake 존재만으로 labOn도 true.
    @Test func standaloneShakeTurnsLabOn() {
        let c = parse(["-tiltLab.shake"])
        #expect(c.shake == true)
        #expect(c.labOn == true)
        #expect(c.x == nil)
        #expect(c.y == nil)
    }

    /// 값 누락 — `-tiltLab.x`가 마지막 토큰이면 다음 토큰이 없어 nil. 다른 트리거가 없으면 labOn도 false.
    @Test func missingValueAtEndOfArgs() {
        let c = parse(["-tiltLab.x"])
        #expect(c.x == nil)
        #expect(c.labOn == false)
    }

    /// 비수치 값 — 파싱 실패는 nil이며, 그 자체만으로는 labOn을 켜지 않는다(파싱 "성공" 기준).
    @Test func nonNumericValue() {
        let c = parse(["-tiltLab.x", "abc"])
        #expect(c.x == nil)
        #expect(c.labOn == false)
    }

    /// 범위 밖 양수 값은 슬라이더 범위(-1...1) 상한으로 클램프된다.
    @Test func clampsOutOfRangePositiveValue() {
        let c = parse(["-tiltLab.x", "2.0"])
        #expect(c.x == 1.0)
    }

    /// 범위 밖 음수 값은 하한으로 클램프된다.
    @Test func clampsOutOfRangeNegativeValue() {
        let c = parse(["-tiltLab.y", "-2.0"])
        #expect(c.y == -1.0)
    }

    /// 무관 인자가 앞뒤로 섞여도 관련 없는 토큰은 파싱에 영향을 주지 않는다.
    @Test func ignoresUnrelatedArguments() {
        let c = parse(["/path/to/Reffi", "-skipOnboarding", "-tiltLab.x", "-0.5", "-fridge.compact", "YES"])
        #expect(c.x == -0.5)
        #expect(c.labOn == true)
        #expect(c.y == nil)
        #expect(c.shake == false)
    }
}
#endif
