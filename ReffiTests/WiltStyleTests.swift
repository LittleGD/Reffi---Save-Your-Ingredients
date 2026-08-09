import Testing
import CoreGraphics
import Foundation
@testable import Reffi

/// 시듦(WiltStyle) — 신선도가 나빠질수록 **한 방향으로만** 시든다는 단조성과,
/// 색조를 바꾸지 않는(재료 정체성 유지) 색행렬의 성질을 고정한다. 렌더 없이 순수 값만 검증.
struct WiltStyleTests {

    private let ordered: [WiltStyle] = [.freshStyle, .soonStyle, .urgentStyle]

    @Test func mapsEachFreshnessState() {
        #expect(WiltStyle.for(.fresh) == .freshStyle)
        #expect(WiltStyle.for(.soon) == .soonStyle)
        #expect(WiltStyle.for(.urgent) == .urgentStyle)
    }

    @Test func freshIsUntouched() {
        // 신선한 재료는 원본 그대로 — 필터·트랜스폼을 건너뛸 수 있어야 렌더 비용이 0이다.
        let f = WiltStyle.freshStyle
        #expect(f.isIdentity)
        #expect(f.saturation == 1 && f.brightness == 1 && f.squash == 1 && f.lean == 0)
        #expect(f.transform(baselineY: 100) == .identity)
        #expect(!WiltStyle.soonStyle.isIdentity)
        #expect(!WiltStyle.urgentStyle.isIdentity)
    }

    @Test func wiltIsStrictlyMonotonic() {
        // fresh → soon → urgent 로 갈수록 채도·명도·높이는 줄고 기울임은 커진다(역전 금지).
        for (a, b) in zip(ordered, ordered.dropFirst()) {
            #expect(b.saturation < a.saturation)
            #expect(b.brightness < a.brightness)
            #expect(b.squash < a.squash)
            #expect(b.lean > a.lean)
        }
    }

    @Test func wiltStaysWithinLegibleRange() {
        // 시들어도 재료를 알아볼 수 있어야 한다 — 회색으로 무너지거나 형체가 찌그러지면 실패.
        for s in ordered {
            #expect(s.saturation >= 0.6 && s.saturation <= 1)
            #expect(s.brightness >= 0.9 && s.brightness <= 1)
            #expect(s.squash >= 0.9 && s.squash <= 1)
            #expect(s.lean >= 0 && s.lean <= 6)   // 인셋 10% 안에 들어오는 상한
        }
    }

    @Test func tokensAreDistinct() {
        // 텍스처 캐시 키 조각 — 겹치면 시든 칩이 신선한 칩의 텍스처를 재사용한다.
        #expect(Set(ordered.map(\.token)).count == ordered.count)
    }

    @Test func colorMatrixKeepsGrayAxisAndDarkensByBrightness() {
        // 회색(무채색)은 채도와 무관 — 밝기 배수만 남아야 한다(색조 이동 없음의 필요조건).
        for s in ordered {
            let m = s.colorMatrix
            let rowR = Double(m.r1 + m.r2 + m.r3)
            let rowG = Double(m.g1 + m.g2 + m.g3)
            let rowB = Double(m.b1 + m.b2 + m.b3)
            #expect(abs(rowR - s.brightness) < 0.0001)
            #expect(abs(rowG - s.brightness) < 0.0001)
            #expect(abs(rowB - s.brightness) < 0.0001)
            // 상수항(5열)과 알파 행은 건드리지 않는다 — 프리멀티플라이 알파에서 테두리가 뜨지 않게.
            #expect(m.r5 == 0 && m.g5 == 0 && m.b5 == 0 && m.a5 == 0)
            #expect(m.a1 == 0 && m.a2 == 0 && m.a3 == 0 && m.a4 == 1)
        }
    }

    @Test func transformSquashesFromTheBottomAndLeans() {
        let baseline: CGFloat = 200
        for s in ordered.dropFirst() {
            let t = s.transform(baselineY: baseline)
            // 밑변은 고정 — 시들어도 재료가 바닥에서 떠오르거나 파고들지 않는다.
            let bottom = CGPoint(x: 50, y: baseline).applying(t)
            #expect(abs(bottom.y - baseline) < 0.0001)
            #expect(abs(bottom.x - 50) < 0.0001)
            // 위쪽은 내려앉고(스쿼시) 옆으로 밀린다(전단).
            let top = CGPoint(x: 50, y: baseline - 100).applying(t)
            #expect(top.y > baseline - 100)
            #expect(top.x > 50)
        }
        // 더 시들수록 더 많이 주저앉고 더 많이 기운다.
        let soonTop = CGPoint(x: 0, y: 0).applying(WiltStyle.soonStyle.transform(baselineY: baseline))
        let urgentTop = CGPoint(x: 0, y: 0).applying(WiltStyle.urgentStyle.transform(baselineY: baseline))
        #expect(urgentTop.y > soonTop.y)
        #expect(urgentTop.x > soonTop.x)
    }
}
