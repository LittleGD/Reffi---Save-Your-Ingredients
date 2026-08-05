#if DEBUG
import Testing
import Foundation
import SwiftUI
import SpriteKit
@testable import Reffi

/// 판정 존(§13.6 3-1) 배치 회귀 — 존은 헤더·배너가 덮지 않는 **가려지지 않는 영역** 안에 있어야 한다.
///
/// 회귀 이력: 물리 필드가 화면 전체로 확장되면서(0bb9c76) 씬은 `overlayTopInset`(헤더·배너가 덮는
/// 높이)을 받아 존을 그 아래로 내리게 됐는데, 그 값을 나르는 `ClearFieldTopKey`의 `reduce`가
/// "마지막이 이김"이라 실측값이 형제(뱃지 행·CTA)의 기본값 0에 덮여 **항상 0이 배달됐다**.
/// 결과: `clearHeight`가 화면 전체 높이가 되어 존이 Reffi 로고·날짜 위(화면 최상단)에 붙었다.
///
/// 그래서 두 층을 각각 고정한다 — (1) 값이 접기에서 살아남는가, (2) 씬이 어떤 도착 순서에서도
/// 존을 가려지지 않는 영역에 두는가.
@MainActor
struct ZonePlacementTests {

    /// 존 반높이 — `IngredientDropScene.zoneSide`(86)의 절반. private라 테스트에서 상수로 든다.
    private let zoneHalf: CGFloat = 43

    /// SKNode.position은 내부적으로 float32라 Double 산술과 정확히 같지 않다(507.33 → 507.32998…).
    /// 좌표 비교는 항상 이 허용오차로 한다.
    private func isNear(_ a: CGFloat?, _ b: CGFloat) -> Bool {
        guard let a else { return false }
        return abs(a - b) < 0.01
    }

    private func makeScene(size: CGSize, inset: CGFloat) -> IngredientDropScene {
        let scene = IngredientDropScene()
        scene.size = size
        scene.overlayTopInset = inset
        return scene
    }

    /// 존 전체가 가려지지 않는 영역 안에 있는가 — 이게 이 버그의 본질적 계약이다.
    /// 씬 좌표는 y가 위로 자라므로 가려지지 않는 영역의 위끝은 `height - inset`이다.
    private func expectInsideClearRegion(_ scene: IngredientDropScene,
                                         inset: CGFloat,
                                         sourceLocation: SourceLocation = #_sourceLocation) {
        guard let centers = scene.debugZoneCenters else {
            Issue.record("판정 존이 생성되지 않았다", sourceLocation: sourceLocation)
            return
        }
        let clearTop = scene.size.height - inset
        for (name, center) in [("toss", centers.toss), ("ate", centers.ate)] {
            #expect(center.y + zoneHalf <= clearTop,
                    "\(name) 존 윗변이 배너 뒤로 올라갔다 (center.y=\(center.y), clearTop=\(clearTop))",
                    sourceLocation: sourceLocation)
            // 위끝에 붙어 있어야 한다 — 더미(바닥)까지 내려가면 그것도 회귀다.
            #expect(center.y > clearTop - 120,
                    "\(name) 존이 가려지지 않는 영역 위끝에서 너무 멀다 (center.y=\(center.y), clearTop=\(clearTop))",
                    sourceLocation: sourceLocation)
        }
        #expect(centers.toss.x < centers.ate.x, "휴지통은 좌상, 냄비는 우상(§13.6 3-1)",
                sourceLocation: sourceLocation)
    }

    // MARK: - 인셋을 나르는 PreferenceKey (근본 원인 지점)

    /// **이 버그의 근본 원인** — SwiftUI는 컨테이너의 모든 자식을 접으면서 값을 안 쓰는 형제도
    /// `defaultValue`로 참여시킨다. 실측값을 쓰는 `fieldStack`이 맨 앞이고 뒤에 뱃지 행·CTA가
    /// 오므로, 뒤따르는 기본값이 실측값을 덮으면 안 된다.
    @Test func clearFieldTopSurvivesNonWritingSiblings() {
        var value = ClearFieldTopKey.defaultValue
        ClearFieldTopKey.reduce(value: &value) { 143.33 }                        // fieldStack(유일한 실측 주체)
        ClearFieldTopKey.reduce(value: &value) { ClearFieldTopKey.defaultValue } // badgeScroll
        ClearFieldTopKey.reduce(value: &value) { ClearFieldTopKey.defaultValue } // Start cooking CTA
        #expect(value == 143.33)
    }

    /// 형제 순서가 반대여도 같은 값이어야 한다 — 레이아웃 순서 변경에 취약하지 않게.
    @Test func clearFieldTopIsOrderIndependent() {
        var value = ClearFieldTopKey.defaultValue
        ClearFieldTopKey.reduce(value: &value) { ClearFieldTopKey.defaultValue }
        ClearFieldTopKey.reduce(value: &value) { 143.33 }
        ClearFieldTopKey.reduce(value: &value) { ClearFieldTopKey.defaultValue }
        #expect(value == 143.33)
    }

    /// 쓰는 자식이 하나도 없으면 기본값 그대로(= 인셋 없음).
    @Test func clearFieldTopDefaultsToZero() {
        var value = ClearFieldTopKey.defaultValue
        ClearFieldTopKey.reduce(value: &value) { ClearFieldTopKey.defaultValue }
        #expect(value == 0)
    }

    // MARK: - 물리 천장을 나르는 키 (같은 접기 함정)

    /// `HeaderBottomKey`(물리 천장)는 `ClearFieldTopKey`와 **같은 VStack의 같은 형제들** 사이를
    /// 지나므로 접기 함정도 같다 — 값을 싣는 건 헤더 하나뿐이고 뱃지 행·CTA가 기본값 0을 들고
    /// 뒤따른다. 두 키가 함께 살아야 재료가 헤더 텍스트를 덮지 않으므로 규칙을 따로 고정한다.
    @Test func headerBottomSurvivesNonWritingSiblings() {
        var value = HeaderBottomKey.defaultValue
        HeaderBottomKey.reduce(value: &value) { 96.67 }                    // header(유일한 실측 주체)
        HeaderBottomKey.reduce(value: &value) { HeaderBottomKey.defaultValue }  // 발주 진행 카드
        HeaderBottomKey.reduce(value: &value) { HeaderBottomKey.defaultValue }  // 배너·스페이서
        #expect(value == 96.67)
    }

    /// 형제 순서가 반대여도 같은 값이어야 한다 — 헤더 아래 요소가 늘고 줄어도 천장이 안 흔들리게.
    @Test func headerBottomIsOrderIndependent() {
        var value = HeaderBottomKey.defaultValue
        HeaderBottomKey.reduce(value: &value) { HeaderBottomKey.defaultValue }
        HeaderBottomKey.reduce(value: &value) { 96.67 }
        HeaderBottomKey.reduce(value: &value) { HeaderBottomKey.defaultValue }
        #expect(value == 96.67)
    }

    // MARK: - 씬 배치 (도착 순서 불문)

    /// 실측 재현값(iPhone 17 Pro, MORNING ALERTS 배너 표시 상태): 씬 562.33, 인셋 143.33.
    /// 존 중심 y = (562.33 - 143.33) - 43 - 12 = 364.0.
    @Test func zoneSitsBelowBanner() {
        let scene = makeScene(size: CGSize(width: 402, height: 562.33), inset: 143.33)
        #expect(isNear(scene.debugZoneCenters?.toss.y, 364.0))
        expectInsideClearRegion(scene, inset: 143.33)
    }

    /// 크기 → 인셋 순서(실제 런치 경로: didChangeSize가 먼저, 배너 실측이 나중).
    @Test func zoneCorrectWhenInsetArrivesAfterSize() {
        let scene = IngredientDropScene()
        scene.size = CGSize(width: 402, height: 562.33)
        scene.overlayTopInset = 143.33
        expectInsideClearRegion(scene, inset: 143.33)
    }

    /// 인셋 → 크기 순서(프레젠트 전에 인셋이 먼저 주입되는 경로).
    @Test func zoneCorrectWhenSizeArrivesAfterInset() {
        let scene = IngredientDropScene()
        scene.overlayTopInset = 143.33
        scene.size = CGSize(width: 402, height: 562.33)
        expectInsideClearRegion(scene, inset: 143.33)
    }

    /// 배너 등장/소멸로 인셋이 바뀌면 존이 따라 움직인다 — 인셋이 커지면 존은 아래로 내려간다.
    @Test func zoneFollowsBannerAppearing() {
        let scene = makeScene(size: CGSize(width: 402, height: 626.33), inset: 75.33)
        let before = scene.debugZoneCenters?.toss.y
        scene.size = CGSize(width: 402, height: 562.33)   // 배너가 들어오며 필드가 줄고
        scene.overlayTopInset = 143.33                    // 덮이는 높이가 커진다
        let after = scene.debugZoneCenters?.toss.y
        #expect(before != nil && after != nil)
        #expect(after! < before!, "배너가 덮는 높이가 커지면 존은 더 아래로 내려와야 한다")
        expectInsideClearRegion(scene, inset: 143.33)
    }

    /// 인셋이 그대로인 채 씬만 리사이즈돼도 계약은 유지된다(didChangeSize 경로).
    @Test func zoneSurvivesResize() {
        let scene = makeScene(size: CGSize(width: 402, height: 562.33), inset: 143.33)
        scene.size = CGSize(width: 440, height: 700)
        expectInsideClearRegion(scene, inset: 143.33)
    }

    /// 인셋 0(헤더가 없는 가상 상황)이면 예전처럼 씬 위끝 기준 — 회귀 수정이 이 경로를 안 깼는지.
    @Test func zoneUsesFullHeightWhenNoOverlay() {
        let scene = makeScene(size: CGSize(width: 402, height: 562.33), inset: 0)
        #expect(isNear(scene.debugZoneCenters?.toss.y, 562.33 - 43 - 12))
    }
}
#endif
