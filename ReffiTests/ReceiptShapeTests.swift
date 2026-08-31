import Testing
import SwiftUI
@testable import Reffi

/// 영수증 셰이프 — 절취 기하의 계약.
///
/// 여기서 잠그는 것은 **그림 자체가 아니라 그림이 지켜야 할 관계**다. 톱니를 "너무 크고 아마추어
/// 클립아트 같다"에서 데려오면서 다섯 가지가 계약이 됐다: ① 시드가 같으면 항상 같은 그림 ② 시드가
/// 다르면 실제로 다른 그림 ③ 어떤 톱니·시드에서도 종이가 프레임을 안 벗어난다 ④ 진폭이 주기·인셋
/// 예산에 비해 얕다(= 45° 삼각파로 안 돌아간다) ⑤ 마지막 칸이 코너에 정확히 앉는다(= 수직 가시 없음).
///
/// 넷째·다섯째가 없으면 다음 튜닝이 조용히 옛 그림으로 되돌아간다 — 그게 이 파일이 커진 이유다.
struct ReceiptShapeTests {
    private let rect = CGRect(x: 0, y: 0, width: 320, height: 180)

    /// 실제 앱에서 영수증이 그려지는 폭들 — 어느 것도 절취 주기의 정수 배가 아니다.
    /// (옛 코드가 코너에 1~4pt짜리 잔여 조각을 남기던 바로 그 폭들이다.)
    private let realWidths: [CGFloat] = [272, 322, 342, 346, 358]

    private let teeth: [CGFloat] = [ReffiTooth.chip, ReffiTooth.card, ReffiTooth.ticket]

    // MARK: - 경로 읽기 도구
    //
    // 셰이프는 직선만 쓴다. 경로 구조는 `move`(좌상 골) + 상단 3n점 + 우변 1점 + 하단 3n점 + `close`이고,
    // 칸 하나가 정확히 세 점(봉우리 왼쪽·봉우리 오른쪽·다음 골)을 낸다 → 정점 수 = 6n + 2.
    // 이 구조를 바꾸면 아래 인덱스가 먼저 깨지므로, 구조 자체를 `pathIsWellFormed`가 따로 잠근다.

    private func points(_ path: Path) -> [CGPoint] {
        var out: [CGPoint] = []
        path.forEach { element in
            switch element {
            case let .move(to: pt):                   out.append(pt)
            case let .line(to: pt):                   out.append(pt)
            case let .quadCurve(to: pt, control: _):  out.append(pt)
            case let .curve(to: pt, control1: _, control2: _): out.append(pt)
            case .closeSubpath:                       break
            }
        }
        return out
    }

    private func cellCount(_ pts: [CGPoint]) -> Int { (pts.count - 2) / 6 }

    /// 한 변의 절취 진폭 — **골의 극값**으로 잰다.
    ///
    /// `boundingRect`로 재면 안 된다: 봉우리가 바깥 변에 거의 붙어 있어 바운딩 박스는 진폭이 아니라
    /// "봉우리 들뜸"(진폭의 0.2배)만 반영한다. 그걸로 상한을 걸면 `depthRatio`를 3배로 올려도 통과하는
    /// 거짓 안전장치가 된다.
    private func tearDepth(_ pts: [CGPoint], in r: CGRect, top: Bool) -> CGFloat {
        pts.filter { top ? $0.y < r.midY : $0.y >= r.midY }
            .map { top ? $0.y - r.minY : r.maxY - $0.y }
            .max() ?? 0
    }

    /// 점들을 원점 기준 오프셋으로 양자화한 비교 키. `rotated`면 180° 돌려서(우하 코너 기준) 읽는다.
    private func fingerprint(_ pts: [CGPoint], in r: CGRect, rotated: Bool) -> [String] {
        pts.map { pt in
            let x = rotated ? r.maxX - pt.x : pt.x - r.minX
            let y = rotated ? r.maxY - pt.y : pt.y - r.minY
            return "\(Int((x * 100).rounded())),\(Int((y * 100).rounded()))"
        }.sorted()
    }

    // MARK: - 기존 계약

    /// 시드 미지정 = 시드 0 — 두 표기가 갈리지 않는다는 계약이다.
    ///
    /// **"토큰화 이전 그림을 보존한다"는 계약이 아니다.** 절취 기하를 다시 쓰면서 그림 자체는 바뀌었고,
    /// 그건 의도다. 여기가 잠그는 것은 기본 인자값 하나뿐이라 그림이 또 바뀌어도 유효하다.
    @Test func defaultSeedEqualsExplicitZero() {
        #expect(ReceiptShape(tooth: ReffiTooth.card).path(in: rect)
                == ReceiptShape(tooth: ReffiTooth.card, seed: 0).path(in: rect))
    }

    /// 시드가 다르면 절취 변주가 실제로 어긋난다 — 인자만 받고 쓰지 않는 상태로 되돌아가지 않게.
    @Test func seedActuallyVariesTheTeeth() {
        let base = ReceiptShape(tooth: ReffiTooth.card, seed: 0).path(in: rect)
        #expect(ReceiptShape(tooth: ReffiTooth.card, seed: 1).path(in: rect) != base)
        #expect(ReceiptShape(tooth: ReffiTooth.card, seed: 2).path(in: rect) != base)
        #expect(ReceiptShape(tooth: ReffiTooth.card, seed: 1).path(in: rect)
                != ReceiptShape(tooth: ReffiTooth.card, seed: 2).path(in: rect))
    }

    /// 같은 시드는 항상 같은 그림 — `PaperRect`·`PaperBlob`과 같은 규약(레이아웃이 흔들리지 않는다).
    /// 난수는 반드시 시드 기반이어야 한다: 비결정 난수를 쓰면 레이아웃 패스마다 종이가 다시 찢긴다.
    @Test func sameSeedIsStable() {
        #expect(ReceiptShape(tooth: ReffiTooth.ticket, seed: 3).path(in: rect)
                == ReceiptShape(tooth: ReffiTooth.ticket, seed: 3).path(in: rect))
    }

    /// 어떤 톱니·시드에서도 종이는 프레임 안에 남는다 — 변주가 밖으로 새면 카드가 잘린다.
    @Test func staysInsideFrameForEveryToothAndSeed() {
        for tooth in teeth {
            for seed in 0..<8 {
                let box = ReceiptShape(tooth: tooth, seed: seed).path(in: rect).boundingRect
                #expect(box.minX >= rect.minX - 0.01)
                #expect(box.minY >= rect.minY - 0.01)
                #expect(box.maxX <= rect.maxX + 0.01)
                #expect(box.maxY <= rect.maxY + 0.01)
            }
        }
    }

    /// 톱니 토큰은 좁은 조각일수록 작다 — 세 자리의 순서가 뒤집히면 종이 폭과 절취 리듬이 어긋난다.
    @Test func toothTokensAreOrdered() {
        #expect(ReffiTooth.chip < ReffiTooth.card)
        #expect(ReffiTooth.card < ReffiTooth.ticket)
    }

    // MARK: - 절취 기하 계약

    /// 경로 구조 — 칸 하나가 정확히 세 점, 정점 수 = 6n + 2.
    /// 아래 인덱스 기반 검사들이 전부 이 구조를 전제하므로 여기서 먼저 잠근다.
    @Test func pathIsWellFormed() {
        for w in realWidths {
            for tooth in teeth {
                let pts = points(ReceiptShape(tooth: tooth).path(in: CGRect(x: 0, y: 0, width: w, height: 200)))
                #expect(pts.count % 6 == 2)
                #expect(cellCount(pts) >= 3)
            }
        }
    }

    /// 절취는 **얕다** — 진폭이 주기에도, 인셋 예산(`tooth`)에도 한참 못 미친다.
    ///
    /// 옛 그림은 진폭 = 주기/2 = tooth로 셋이 한 숫자에 묶여 있었다(빗변이 늘 정확히 45°). 이 테스트가
    /// 잠그는 것은 상수 값이 아니라 **그 재결합**이다: 누가 진폭과 주기를 다시 묶으면 비율이 0.5로
    /// 튀면서 여기서 걸린다. 진폭 조절 자체는 막지 않는다(`depthRatio`는 상한 안에서 자유롭다).
    @Test func tearIsShallowRelativeToPitchAndBudget() {
        for w in realWidths {
            let r = CGRect(x: 0, y: 0, width: w, height: 200)
            for tooth in teeth {
                let pts = points(ReceiptShape(tooth: tooth).path(in: r))
                let step = w / CGFloat(cellCount(pts))
                for depth in [tearDepth(pts, in: r, top: true), tearDepth(pts, in: r, top: false)] {
                    #expect(depth / step <= 0.35)             // 옛 값 0.50 = 45° 톱니
                    #expect(depth <= tooth * 0.5)             // 찢김은 인셋 예산 안에 산다
                    #expect(depth <= ReceiptShape.depthCap + 0.001)
                    #expect(depth >= 0.75)                    // 헤어라인에 먹힐 만큼 얕지도 않다
                }
            }
        }
    }

    /// 코너에 수직 가시가 없다 — 폭을 정수 칸으로 나누므로 마지막 골이 코너에 **정확히** 앉는다.
    ///
    /// 옛 코드는 마지막 칸을 `min(x + t, maxX)`로 클램프해, 폭이 주기의 배수가 아니면 폭 1~4pt에
    /// 높이는 그대로 tooth인 거의 수직인 조각이 끝에 남았다(3x에서 3px × 21px의 뾰족한 가시).
    @Test func lastCellLandsExactlyOnTheCorner() {
        for w in realWidths {
            let r = CGRect(x: 0, y: 0, width: w, height: 200)
            for tooth in teeth {
                let pts = points(ReceiptShape(tooth: tooth).path(in: r))
                let n = cellCount(pts)
                let step = w / CGFloat(n)
                // 칸 경계(골)에는 지터가 없다 — 정확히 step 간격으로 앉고, 마지막이 maxX다.
                for k in 0..<n {
                    #expect(abs(pts[3 * (k + 1)].x - (r.minX + step * CGFloat(k + 1))) < 0.001)
                }
                #expect(abs(pts[3 * n].x - r.maxX) < 0.001)
                // 코너에 닿는 마지막 선분이 가파르지 않다 — 옛 잔여 조각은 폭이 칸의 7분의 1이라
                // 높이 tooth를 그 폭에 욱여넣은 82° 사면(=가시)이었다. 지금은 최소 칸의 3분의 1이다.
                #expect(pts[3 * n].x - pts[3 * n - 1].x > step * 0.25)
            }
        }
    }

    /// 상·하 절취선은 **시드 0에서도** 서로 다른 그림이다.
    ///
    /// 두 변이 180° 회전대칭으로 맞물리면 손으로 오린 종이가 아니라 스탬프로 찍은 테두리로 읽힌다.
    /// 옛 코드는 폭이 주기의 짝수 배일 때 정확히 그랬고(322 = 46×7, 342 = 38×9), 시드가 0이면
    /// 위상 보정마저 꺼져 있어 앱의 거의 모든 영수증이 그 상태였다. 그래서 이 분리는 시드가 아니라
    /// **구조**(상·하 독립 난수 스트림)로 보장한다 — 호출부 대부분이 시드를 안 넘기기 때문이다.
    @Test func topAndBottomTearsAreNotMirrorImages() {
        for w in realWidths {
            let r = CGRect(x: 0, y: 0, width: w, height: 128)
            for tooth in teeth {
                let pts = points(ReceiptShape(tooth: tooth, seed: 0).path(in: r))
                let top = pts.filter { $0.y < r.midY }
                let bottom = pts.filter { $0.y >= r.midY }
                #expect(top.count == bottom.count)
                #expect(fingerprint(top, in: r, rotated: false) != fingerprint(bottom, in: r, rotated: true))
            }
        }
    }

    /// 같은 폭에서 칸 수는 톱니 프리셋을 따라 단조롭게 변한다 — 좁은 종이(chip)일수록 촘촘하다.
    ///
    /// `tooth`가 인셋 예산으로 재정의된 뒤에도 절취 **리듬**은 여전히 그 값에서 파생된다는 계약이다.
    /// 세 프리셋이 같은 칸 수를 내면 토큰이 그림에 아무 영향도 못 주고 있다는 뜻이다.
    @Test func cellCountFollowsToothPreset() {
        for w in realWidths {
            let r = CGRect(x: 0, y: 0, width: w, height: 200)
            let counts = teeth.map { cellCount(points(ReceiptShape(tooth: $0).path(in: r))) }
            #expect(counts[0] > counts[1])   // chip > card
            #expect(counts[1] > counts[2])   // card > ticket
            // 옛 그림(주기 = 2 × tooth)보다 확실히 촘촘하다 — "톱니가 너무 크다"의 절반은 개수였다.
            #expect(counts[1] > Int(w / (2 * ReffiTooth.card)))
        }
    }

    /// 시드는 값 전체가 쓰인다.
    ///
    /// 옛 위상표는 원소가 넷이라 `seed % 4`가 같으면 그림이 완전히 같았다 — 카드마다 `seed: i`를
    /// 성실히 넘겨도 네 장마다 픽셀 단위로 반복됐고, 기존 테스트는 하필 1·2만 골라 그 구멍을 지나쳤다.
    @Test func seedSpaceIsWiderThanFour() {
        let four = ReceiptShape(tooth: ReffiTooth.card, seed: 4).path(in: rect)
        #expect(ReceiptShape(tooth: ReffiTooth.card, seed: 8).path(in: rect) != four)
        #expect(ReceiptShape(tooth: ReffiTooth.card, seed: 0).path(in: rect) != four)
    }

    /// 병적인 프레임에서 크래시하지 않는다.
    ///
    /// 레이아웃 프로빙 패스는 NaN·무한 크기를 던진다. 정수 칸 분할이 들어오면서 `Int(_:)` 변환이
    /// 생겼고, 그 변환은 범위 밖 값에서 **트랩**한다(옛 코드에는 정수 변환이 없어 이 문이 없었다).
    @Test func degenerateRectsDoNotTrap() {
        let shape = ReceiptShape(tooth: ReffiTooth.card)
        // 트랩은 잡을 수 없고 프로세스를 죽인다 — 그래서 **호출이 돌아온다는 것 자체가 단언**이다.
        // (`CGRect`가 병적인 값을 어떻게 정규화하는지는 플랫폼 사정이라 결과 모양을 못 박지 않는다.)
        // `.nan`/`.infinity`를 CGRect 리터럴에 바로 쓰면 CGFloat 추론이 모호해진다 — 타입을 못 박는다.
        let nan = CGFloat.nan, inf = CGFloat.infinity
        for r in [CGRect(x: 0, y: 0, width: nan, height: 100),
                  CGRect(x: 0, y: 0, width: inf, height: 100),
                  CGRect(x: 0, y: 0, width: 300, height: nan),
                  CGRect(x: nan, y: 0, width: 300, height: 100)] {
            _ = shape.path(in: r)
        }
        #expect(shape.path(in: CGRect(x: 0, y: 0, width: 0, height: 0)).isEmpty)
        // 유한하지만 터무니없이 넓은 프레임 — 칸 수 상한이 루프 폭주와 정수 트랩을 동시에 막는다.
        let huge = points(shape.path(in: CGRect(x: 0, y: 0, width: 1e30, height: 100)))
        #expect(cellCount(huge) == ReceiptShape.maxCells)
        // 아주 납작한 면에서도 절취선이 프레임 밖으로 나가지 않는다(진폭이 높이에도 매여 있다).
        let flat = shape.path(in: CGRect(x: 0, y: 0, width: 120, height: 4)).boundingRect
        #expect(flat.minY >= -0.01)
        #expect(flat.maxY <= 4.01)
    }
}
