import Testing
import CoreGraphics
@testable import Reffi

/// 스폰 사다리 불변식 — **어떤 두 칩도 겹쳐 태어나지 않는다**(실기기 3차 ②).
///
/// 옛 코드는 스폰 y를 상수 천장(`size.height + 700`)으로 클램프했다. 작업대 6개 · 칩변 169pt이면
/// 사다리 꼭대기가 화면 위 786pt라 마지막 두 칩이 **같은 y로 접혔고**, -physLab 실측에서 두 칩의
/// AABB가 43.1% 관통한 채 태어났다. 솔버가 그 깊은 관통을 푸느라 한 칩을 2050pt/s로 걷어차
/// 두께 0의 벽을 뚫었고(y=−438000까지 영구 낙하), 살아남은 칩들도 상시 분리 압력에 눌려
/// 영영 안 잤다 — 겹침 고착·벽 관통·상시 움찔이 모두 이 한 줄에서 나왔다.
/// 씬 없이 순수 함수로 검증한다(GravityMapper·shakeKick과 같은 규율).
struct SpawnLadderTests {

    /// 실제로 쓰이는 칩 변의 전 구간 — `chipSideFor`는 min(max(124, w×0.42), 188)로 클램프된다.
    private let sides: [CGFloat] = [124, 140, 168.8, 175, 188]

    /// 이웃 order의 스폰 높이 차가 **바디 최대 높이보다 크다** — 겹쳐 태어날 수 없다는 뜻이다.
    @Test func adjacentOrdersCannotOverlapAtSpawn() {
        let maxH = IngredientDropScene.maxBodyHeightRatio
        #expect(IngredientDropScene.spawnStep > maxH,
                "스폰 간격 \(IngredientDropScene.spawnStep)s가 바디 최대 높이 \(maxH)s보다 커야 한다")
        for side in sides {
            for order in 0..<16 {
                let gap = IngredientDropScene.spawnHeight(order: order + 1, side: side)
                    - IngredientDropScene.spawnHeight(order: order, side: side)
                #expect(gap > maxH * side,
                        "side=\(side) order \(order)→\(order + 1) 간격 \(gap) ≤ 바디 최대 높이 \(maxH * side)")
            }
        }
    }

    /// 사다리에 **클램프가 없다** — 개수가 아무리 늘어도 두 order가 같은 y로 접히지 않는다.
    /// (작업대 상한은 6이지만 직접 추가는 상한을 일시 초과할 수 있어, 임의 개수에서 성립해야 한다.)
    @Test func ladderIsStrictlyMonotonicForAnyCount() {
        for side in sides {
            var previous = -CGFloat.infinity
            for order in 0..<32 {
                let y = IngredientDropScene.spawnHeight(order: order, side: side)
                #expect(y > previous, "side=\(side) order=\(order)에서 사다리가 접혔다")
                previous = y
            }
        }
    }

    /// **Reduce Motion 정적 배치도 같은 불변식을 지킨다** — 낙하 사다리만 고치면 Reduce Motion
    /// 사용자만 겹친 더미를 본다. 옛 식(`floorY + s × (0.45 + order%3 × 0.5)`)은 행 간격이 0.5s로
    /// 바디 최대 높이(0.70s)보다 좁아 이웃 order가 겹쳐 태어났다(같은 행끼리도 밴드를 개수로 나눠
    /// 벌리기만 해서, 개수가 늘면 열 간격이 바디 폭 아래로 내려갔다).
    /// 어떤 두 칩도 **가로로 바디 최대 폭 이상 떨어져 있거나 세로로 바디 최대 높이 이상** 떨어져
    /// 있어야 한다(둘 중 하나만 성립해도 AABB가 안 겹친다).
    @Test func reduceMotionSlotsNeverOverlap() {
        let maxW = IngredientDropScene.maxBodyWidthRatio
        let maxH = IngredientDropScene.maxBodyHeightRatio
        for side in sides {
            // 밴드는 addChip과 같은 식 — 칩 변에서 역산한 실제 폭 + 대표 기기 폭을 함께 건다.
            for width in [side / 0.42, 320, 402, 440] as [CGFloat] {
                let band = min(width * 0.66, side * 2.1)
                for count in 1...12 {
                    let slots = (0..<count).map {
                        IngredientDropScene.staticSlot(order: $0, count: count, side: side, band: band)
                    }
                    for i in slots.indices {
                        for j in slots.indices where j > i {
                            let dx = abs(slots[i].dx - slots[j].dx)
                            let dy = abs(slots[i].dy - slots[j].dy)
                            #expect(dx >= maxW * side - 1e-6 || dy >= maxH * side - 1e-6,
                                    "side=\(side) count=\(count) \(i)~\(j) 간격 (dx=\(dx), dy=\(dy))이 바디 (폭 \(maxW * side), 높이 \(maxH * side)) 안에 들어 겹쳐 태어난다")
                        }
                    }
                }
            }
        }
    }

    /// 정적 배치의 행 간격은 낙하 사다리와 **같은 상수**(0.85s)다 — 한쪽만 고쳐지는 일이 없게.
    @Test func reduceMotionRowStepMatchesTheLadderStep() {
        let side: CGFloat = 168.8
        // 한 행에 한 칩만 들어가는 좁은 밴드 → 연속 order가 곧 연속 행이다.
        let narrow: CGFloat = 1
        for order in 0..<8 {
            let a = IngredientDropScene.staticSlot(order: order, count: 8, side: side, band: narrow)
            let b = IngredientDropScene.staticSlot(order: order + 1, count: 9, side: side, band: narrow)
            #expect(abs((b.dy - a.dy) - IngredientDropScene.spawnStep * side) < 1e-6,
                    "행 간격이 사다리 간격과 다르다")
        }
    }

    /// 첫 칩은 화면 바로 위에서 떨어진다 — 캐스케이드가 시작부터 화면 밖 먼 곳에 있지 않게.
    @Test func firstChipStartsJustAboveTheScreen() {
        for side in sides {
            #expect(IngredientDropScene.spawnHeight(order: 0, side: side) == side * IngredientDropScene.spawnBase)
        }
    }

    /// 바디 메트릭 표는 **전 글리프를 덮는다** — 빠진 글리프는 폴백(0.62×0.60) 바디를 써서
    /// 실루엣과 어긋난 채 굴러다닌다. `.gimbap`이 실제로 이렇게 누락돼 있었다.
    @Test func everyGlyphHasAMeasuredBody() {
        for glyph in FoodGlyph.allCases {
            #expect(IngredientDropScene.bodyMetric(for: glyph) != nil, "\(glyph.rawValue) 바디 메트릭 누락")
        }
    }

    /// 정렬 오프셋은 실측 범위 안이다 — 부호가 뒤집히면 그림 반대쪽으로 밀려 어긋남이 두 배가 된다.
    /// (v1 34종이 이 상태였다. 값 자체는 재측정으로 갱신하되, 스케일 이탈은 여기서 잡는다.)
    @Test func alignmentOffsetsStayWithinMeasuredRange() {
        for glyph in FoodGlyph.allCases {
            guard let m = IngredientDropScene.bodyMetric(for: glyph) else { continue }
            #expect(abs(m.dy) <= 0.15, "\(glyph.rawValue) dy=\(m.dy) 정렬 오프셋이 실측 범위를 벗어났다")
            #expect(m.w > 0.2 && m.w <= 0.75, "\(glyph.rawValue) 폭비 \(m.w)")
            #expect(m.h > 0.2 && m.h <= 0.75, "\(glyph.rawValue) 높이비 \(m.h)")
        }
    }
}
