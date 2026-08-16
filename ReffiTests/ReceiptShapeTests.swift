import Testing
import SwiftUI
@testable import Reffi

/// 영수증 셰이프 — 톱니 토큰과 위상 시드.
///
/// 시드는 오래도록 "받기만 하고 안 쓰는 인자"였다(History 카드가 0/1/2를 넘기며 있지도 않은 결 변주를
/// 믿고 있었다). 그 실패 양상이 조용해서 여기서 세 가지를 고정한다: ① 기본값은 종전 그림과 완전히 같다
/// ② 시드가 다르면 그림이 실제로 달라진다 ③ 어떤 시드에서도 종이가 프레임을 벗어나지 않는다.
struct ReceiptShapeTests {
    private let rect = CGRect(x: 0, y: 0, width: 320, height: 180)

    /// 시드 미지정 = 위상 0 — 토큰화 이전 그림을 그대로 보존한다는 계약.
    @Test func defaultSeedKeepsLegacyPath() {
        #expect(ReceiptShape(tooth: ReffiTooth.card).path(in: rect)
                == ReceiptShape(tooth: ReffiTooth.card, seed: 0).path(in: rect))
    }

    /// 시드가 다르면 톱니 위상이 실제로 어긋난다 — 인자만 받고 쓰지 않는 상태로 되돌아가지 않게.
    @Test func seedActuallyVariesTheTeeth() {
        let base = ReceiptShape(tooth: ReffiTooth.card, seed: 0).path(in: rect)
        #expect(ReceiptShape(tooth: ReffiTooth.card, seed: 1).path(in: rect) != base)
        #expect(ReceiptShape(tooth: ReffiTooth.card, seed: 2).path(in: rect) != base)
        #expect(ReceiptShape(tooth: ReffiTooth.card, seed: 1).path(in: rect)
                != ReceiptShape(tooth: ReffiTooth.card, seed: 2).path(in: rect))
    }

    /// 같은 시드는 항상 같은 그림 — `PaperRect`·`PaperBlob`과 같은 규약(레이아웃이 흔들리지 않는다).
    @Test func sameSeedIsStable() {
        #expect(ReceiptShape(tooth: ReffiTooth.ticket, seed: 3).path(in: rect)
                == ReceiptShape(tooth: ReffiTooth.ticket, seed: 3).path(in: rect))
    }

    /// 어떤 톱니·시드에서도 종이는 프레임 안에 남는다 — 위상이 밀려 톱니가 밖으로 새면 카드가 잘린다.
    @Test func staysInsideFrameForEveryToothAndSeed() {
        for tooth in [ReffiTooth.chip, ReffiTooth.card, ReffiTooth.ticket] {
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
}
