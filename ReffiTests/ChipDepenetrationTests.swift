import Testing
import CoreGraphics
@testable import Reffi

/// 얼리는 순간의 관통 해소 불변식 — **어떤 두 칩도 겹친 채 얼지 않는다**(실기기 3차 ②).
///
/// force-settle은 속도를 0으로 굳히므로 그 순간의 겹침이 **영구 고착**이 된다. v1.0 (6)까지는
/// 얼리기 **전에** 임펄스(240pt/s)로 밀고 calm 창을 다시 돌렸는데, 640g 아래 마찰 0.55가 임펄스를
/// 즉시 먹어 한 번에 문턱 밖으로 못 나가고 밀 때마다 창이 처음부터 다시 돌아 **시도 8회가
/// ~6.6초에 소진**됐다 — 그러고도 15% 초과 쌍이 남은 채 더미가 얼었다(-physLab 콜드런치).
/// 정본은 **얼리는 순간의 위치 보정**이다: 속도가 0이라 벽을 뚫을 수 없고, 창을 되돌리지 않으니
/// 예산이라는 개념 자체가 없다. 여기선 그 한 쌍의 산식을 씬 없이 고정한다.
struct ChipDepenetrationTests {

    private let threshold = IngredientDropScene.separationOverlap
    private let slop = IngredientDropScene.separationSlop

    private func push(_ a: CGRect, _ b: CGRect) -> CGVector? {
        IngredientDropScene.depenetration(a, b, overlap: threshold, slop: slop)
    }

    /// 한 번 밀면 **문턱 아래로 떨어진다** — 두 번째 호출이 nil이어야 "예산 소진"이 성립하지 않는다.
    @Test func onePushClearsTheThreshold() {
        // 100×100 두 칩이 60% 겹친 상태(가로 60pt · 세로 100pt 교집합).
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        let b = CGRect(x: 40, y: 0, width: 100, height: 100)
        guard let v = push(a, b) else { Issue.record("60% 관통인데 밀지 않았다"); return }
        let moved = a.offsetBy(dx: v.dx, dy: v.dy), movedB = b.offsetBy(dx: -v.dx, dy: -v.dy)
        #expect(moved.intersection(movedB).isEmpty, "한 번 밀고도 겹침이 남았다")
        #expect(push(moved, movedB) == nil, "밀어낸 배치가 여전히 문턱 위다")
    }

    /// 문턱 이하의 얕은 접촉은 **건드리지 않는다** — 쌓인 더미의 정상 접촉까지 밀면 더미가 흩어진다.
    @Test func shallowContactIsLeftAlone() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        let b = CGRect(x: 0, y: 90, width: 100, height: 100)   // 10% 겹침
        #expect(push(a, b) == nil)
        #expect(push(a, CGRect(x: 0, y: 100, width: 100, height: 100)) == nil, "맞닿기만 한 쌍")
        #expect(push(a, CGRect(x: 300, y: 300, width: 100, height: 100)) == nil, "떨어진 쌍")
    }

    /// 미는 축은 **최소 관통 축 하나뿐**이다 — 대각으로 밀면 더미가 옆으로 무너진다.
    @Test func pushIsAlongTheShallowAxisOnly() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        // 가로 30pt · 세로 80pt 겹침 → 가로가 얕다 → x축으로만 민다.
        let sideways = push(a, CGRect(x: 70, y: 20, width: 100, height: 100))
        #expect(sideways?.dy == 0)
        #expect((sideways?.dx ?? 0) < 0, "왼쪽 칩은 왼쪽으로 밀려야 한다")
        // 가로 80pt · 세로 30pt 겹침 → 세로가 얕다 → y축으로만 민다.
        let vertical = push(a, CGRect(x: 20, y: 70, width: 100, height: 100))
        #expect(vertical?.dx == 0)
        #expect((vertical?.dy ?? 0) < 0, "아래 칩은 아래로 밀려야 한다")
    }

    /// 이동량은 **반씩** 나눈다 — 한쪽만 밀면 더미 전체가 한 방향으로 흐른다.
    @Test func bothChipsMoveTheSameDistance() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        let b = CGRect(x: 40, y: 0, width: 100, height: 100)
        guard let v = push(a, b) else { Issue.record("밀지 않았다"); return }
        #expect(abs(v.dx) == 60 * 0.5 + slop, "관통 60pt의 절반 + 여유가 아니다: \(v.dx)")
    }

    /// 크기가 다른 칩도 **작은 쪽 면적 기준**으로 판정한다 — 큰 칩에 얹힌 작은 칩이 묻히지 않게.
    @Test func thresholdUsesTheSmallerBody() {
        let big = CGRect(x: 0, y: 0, width: 200, height: 200)
        let small = CGRect(x: 150, y: 150, width: 60, height: 60)   // 작은 쪽의 69% 관통
        #expect(push(big, small) != nil)
        let grazing = CGRect(x: 194, y: 150, width: 60, height: 60)  // 작은 쪽의 10%
        #expect(push(big, grazing) == nil)
    }

    /// 여러 쌍이 얽혀도 **반복 예산 안에서 전부 문턱 아래로 내려간다** — 씬의 반복 상한이
    /// 넉넉한지 확인한다(실측 8바퀴 수렴 vs 예산 10). 한 줄로 완전히 포갠 6칩(실기기 3차의
    /// 최악 배치: 칩당 20pt 간격 = 인접 쌍 80% 관통)을 씬과 같은 순서로 푼다.
    @Test func stackedPileResolvesWithinThePassBudget() {
        var boxes = (0..<6).map { CGRect(x: CGFloat($0) * 20, y: 0, width: 100, height: 100) }
        var passes = 0
        while passes < IngredientDropScene.separationPasses {
            var moved = 0
            for i in boxes.indices {
                for j in boxes.indices where j > i {
                    guard let v = push(boxes[i], boxes[j]) else { continue }
                    boxes[i] = boxes[i].offsetBy(dx: v.dx, dy: v.dy)
                    boxes[j] = boxes[j].offsetBy(dx: -v.dx, dy: -v.dy)
                    moved += 1
                }
            }
            passes += 1
            if moved == 0 { break }
        }
        for i in boxes.indices {
            for j in boxes.indices where j > i {
                #expect(push(boxes[i], boxes[j]) == nil,
                        "\(passes)바퀴 뒤에도 \(i)~\(j)가 문턱 위다")
            }
        }
    }
}
