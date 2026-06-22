import SwiftUI

/// 영수증 도형 — 좌·우 변은 직선, 위·아래 변은 톱니(지그재그)로 찢긴 종이 가장자리.
/// 카드 모서리를 라운드 대신 영수증처럼 처리한다. `ScallopedCircle`과 같은 커스텀 Path 방식.
/// 톱니가 콘텐츠를 가리지 않도록, 쓰는 쪽에서 위/아래에 `toothHeight`만큼 인셋을 둔다.
struct ReceiptShape: Shape {
    /// 톱니 높이(가장자리에서 안쪽으로). 기본 6pt.
    var toothHeight: CGFloat = 6
    /// 톱니 하나의 가로 폭(목표값) — 실제는 폭에 맞춰 정수개로 보정.
    var toothWidth: CGFloat = 12
    var hasTop: Bool = true
    var hasBottom: Bool = true

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let th = min(toothHeight, rect.height / 2)
        let topY = rect.minY + (hasTop ? th : 0)
        let botY = rect.maxY - (hasBottom ? th : 0)

        // 위 가장자리: 왼→오, 골(th)과 봉우리(0)를 번갈아.
        p.move(to: CGPoint(x: rect.minX, y: topY))
        if hasTop {
            let n = max(1, Int((rect.width / toothWidth).rounded()))
            let step = rect.width / CGFloat(n)
            for i in 0..<n {
                let x0 = rect.minX + CGFloat(i) * step
                p.addLine(to: CGPoint(x: x0 + step / 2, y: rect.minY))  // 봉우리(위로)
                p.addLine(to: CGPoint(x: x0 + step, y: topY))           // 골
            }
        } else {
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }

        // 오른쪽 변 아래로.
        p.addLine(to: CGPoint(x: rect.maxX, y: botY))

        // 아래 가장자리: 오→왼.
        if hasBottom {
            let n = max(1, Int((rect.width / toothWidth).rounded()))
            let step = rect.width / CGFloat(n)
            for i in 0..<n {
                let x0 = rect.maxX - CGFloat(i) * step
                p.addLine(to: CGPoint(x: x0 - step / 2, y: rect.maxY))  // 봉우리(아래로)
                p.addLine(to: CGPoint(x: x0 - step, y: botY))           // 골
            }
        } else {
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }

        // 왼쪽 변 위로.
        p.addLine(to: CGPoint(x: rect.minX, y: topY))
        p.closeSubpath()
        return p
    }
}
