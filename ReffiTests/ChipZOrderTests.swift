import Testing
import CoreGraphics
@testable import Reffi

/// 칩 그리기 순서 불변식 — **겹친 영역이 깜빡이지 않으려면 z가 결정적이어야 한다**(실기기 3차 ②).
///
/// 옛 코드는 매 프레임 `didSimulatePhysics`에서 z를 y로 다시 계산했다(`10 + (H − y) × 0.01`).
/// 안착하면 칩이 전부 바닥 한 줄이라 z가 0.01 단위로 붙었고(-physLab 실측: 바닥 6칩이
/// 13.52~13.61, 폭 0.09), 솔버 미세 요동으로 y가 1~2pt만 흔들려도 순서가 뒤집혔다.
/// `SKView.ignoresSiblingOrder = true`가 그 뒤집힘을 그대로 화면에 통과시켜, 겹친 영역만
/// 프레임마다 다른 칩으로 다시 칠해졌다 — 그게 "보였다 안 보였다"의 정체다.
struct ChipZOrderTests {

    /// 스폰 순서가 다르면 z도 다르다 — 동률이 하나라도 있으면 그 쌍의 그리기 순서가 비결정이 된다.
    @Test func spawnIndicesGetDistinctZ() {
        var seen = Set<CGFloat>()
        for i in 1...36 {
            let z = IngredientDropScene.chipZ(spawnIndex: CGFloat(i))
            #expect(!seen.contains(z), "spawnIndex \(i)의 z=\(z)가 이미 쓰였다")
            seen.insert(z)
        }
    }

    /// 이웃 인덱스 간 간격이 zStep 이상이다 — 부동소수 반올림으로도 붙지 않는다.
    @Test func neighbouringZAreSeparatedByAtLeastOneStep() {
        for i in 1...36 {
            let gap = IngredientDropScene.chipZ(spawnIndex: CGFloat(i + 1))
                - IngredientDropScene.chipZ(spawnIndex: CGFloat(i))
            #expect(gap >= IngredientDropScene.zStep - 1e-9, "간격 \(gap) < zStep")
        }
    }

    /// 나중에 스폰된 칩이 위 — 캐스케이드의 물리(먼저 떨어진 것 위에 쌓인다)와 같은 방향.
    @Test func laterChipsDrawOnTop() {
        var previous = -CGFloat.infinity
        for i in 1...36 {
            let z = IngredientDropScene.chipZ(spawnIndex: CGFloat(i))
            #expect(z > previous)
            previous = z
        }
    }

    /// 레이어 순서: 쌓인 칩 < 잡은 칩 < 판정 존 < 사라지는 칩.
    /// 하나라도 넘으면 존이 더미 뒤로 숨거나(끌어다 놓을 곳이 안 보인다) 사라지는 칩이 파묻힌다.
    @Test func layerOrderIsStrict() {
        #expect(IngredientDropScene.zBase < IngredientDropScene.zTop)
        #expect(IngredientDropScene.zTop < IngredientDropScene.zDragged)
        #expect(IngredientDropScene.zDragged < IngredientDropScene.zZone)
        #expect(IngredientDropScene.zZone < IngredientDropScene.zPopOut)
    }

    /// 압축(compactZOrder)이 돌기 전까지 쌓이는 칩은 상한을 넘지 않는다 —
    /// 상한을 넘겨 클램프되면 여러 칩이 같은 값에 몰려 동률(= 깜빡임)이 돌아온다.
    @Test func chipsStayBelowTheDraggedLayerUntilCompaction() {
        let capacity = Int((IngredientDropScene.zTop - IngredientDropScene.zBase) / IngredientDropScene.zStep)
        #expect(capacity >= 12, "압축 없이 담을 수 있는 칩이 \(capacity)개뿐이다(작업대 상한 6의 두 배는 돼야 한다)")
        for i in 1...capacity {
            #expect(IngredientDropScene.chipZ(spawnIndex: CGFloat(i)) <= IngredientDropScene.zTop)
        }
    }

    /// **압축은 잡고 있는 칩의 승격 z를 덮지 않는다.** 압축이 잡은 칩까지 다시 매기면 그 칩이
    /// 손끝에서 더미 밑으로 가라앉고(zDragged 29 → 10대), 놓을 때 되돌릴 보관값도 같이 날아간다.
    @Test func compactionKeepsTheDraggedChipPromoted() {
        let slots: [CGFloat] = [14, 11, 28, 12.5, 19]
        let dragged = 2
        let out = IngredientDropScene.compactedZ(slots: slots, draggedIndex: dragged)
        #expect(out[dragged].live == IngredientDropScene.zDragged, "잡은 칩의 화면 z가 압축에 덮였다")
        #expect(out[dragged].slot < IngredientDropScene.zDragged, "잡은 칩도 보관 슬롯은 받아야 한다")
        for i in slots.indices where i != dragged {
            #expect(out[i].live == out[i].slot, "안 잡은 칩은 슬롯과 화면 z가 같아야 한다")
        }
        // 순서는 보존되고(슬롯 순위 = 원래 z 순위), 값은 전부 다르다.
        let byRank = slots.indices.sorted { slots[$0] < slots[$1] }
        var previous = -CGFloat.infinity
        for idx in byRank {
            #expect(out[idx].slot > previous, "압축이 순서를 뒤집었다")
            previous = out[idx].slot
        }
    }

    /// **칩이 예산 칸 수를 넘어도 z는 상한 안에 있다.** 압축은 zCounter를 살아 있는 칩 수로
    /// 되돌릴 뿐이라, 칩이 36개를 넘으면 압축이 무동작이 되어 z가 zTop을 넘어 계속 올라갔다
    /// (잡은 칩 29·판정 존 30을 칩이 덮는다). 간격을 좁혀 예산 안에 담는 것이 정본이다.
    @Test func zStaysUnderTheCapForAnyChipCount() {
        for count in 1...80 {
            let step = IngredientDropScene.zStepFor(count: count)
            #expect(step > 0, "count=\(count) 간격이 0 이하다")
            #expect(step <= IngredientDropScene.zStep, "count=\(count) 간격이 기본값보다 넓다")
            for i in 1...count {
                let z = IngredientDropScene.chipZ(spawnIndex: CGFloat(i), step: step)
                #expect(z > IngredientDropScene.zBase, "count=\(count) i=\(i) z=\(z)")
                #expect(z <= IngredientDropScene.zTop, "count=\(count) i=\(i) z=\(z)가 상한을 넘었다")
            }
        }
    }

    /// 40칩 압축 — 값이 전부 다르고, 순서가 보존되고, 상한을 안 넘는다.
    @Test func fortyChipsCompactWithinBudget() {
        let count = 40
        let slots = (0..<count).map { CGFloat($0) * 0.5 + 10 }.shuffled()
        let out = IngredientDropScene.compactedZ(slots: slots,
                                                 step: IngredientDropScene.zStepFor(count: count))
        var seen = Set<CGFloat>()
        for z in out {
            #expect(z.live == z.slot)
            #expect(z.slot <= IngredientDropScene.zTop, "z=\(z.slot)가 상한을 넘었다")
            #expect(z.slot > IngredientDropScene.zBase)
            #expect(!seen.contains(z.slot), "z=\(z.slot) 동률 — 그리기 순서가 비결정이 된다")
            seen.insert(z.slot)
        }
        let byRank = slots.indices.sorted { slots[$0] < slots[$1] }
        var previous = -CGFloat.infinity
        for idx in byRank {
            #expect(out[idx].slot > previous)
            previous = out[idx].slot
        }
    }
}
