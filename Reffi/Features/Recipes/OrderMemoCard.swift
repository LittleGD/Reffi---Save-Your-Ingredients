import SwiftUI
import PhosphorSwift

/// 오더 메모 카드(§13) — 업장 주방 오더 티켓 미감: 크림 종이 + 상/하 톱니 찢김 엣지, 모노 헤더,
/// 점선 룰, 레시피명 + 시간, 재료 체크리스트(신선도), 옅은 START 스탬프. 캐러셀에서 둘러보기만(액션 없음).
struct OrderMemoCard: View {
    let result: RecipeRecommender.Result
    let number: Int

    private var f: Freshness { result.used.first?.freshness ?? .fresh }

    var body: some View {
        let r = result.recipe
        VStack(alignment: .leading, spacing: ReffiSpace.s3) {
            // 티켓 헤더
            HStack(alignment: .firstTextBaseline) {
                Text("ORDER")
                    .font(.custom("Pretendard-Bold", size: 13, relativeTo: .caption))
                    .tracking(2.5).foregroundStyle(ReffiColor.ink)
                Spacer()
                Text(String(format: "#%02d", number))
                    .font(.reffiNum(14, relativeTo: .caption)).foregroundStyle(ReffiColor.ink2)
            }
            Text("TABLE · REFFI KITCHEN")
                .font(.custom("Pretendard-Medium", size: 10, relativeTo: .caption2))
                .tracking(1.6).foregroundStyle(ReffiColor.muted)

            DashedRule()

            // 메뉴명 + 시간
            Text(r.name)
                .font(.custom("Pretendard-Bold", size: 26, relativeTo: .title2))
                .tracking(-0.3).foregroundStyle(ReffiColor.ink)
                .lineLimit(2).minimumScaleFactor(0.8).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: ReffiSpace.s2) {
                HStack(spacing: 4) {
                    ReffiIcon.time.reffi(14).foregroundStyle(ReffiColor.ink2)
                    Text("\(r.minutes) min").font(.reffiNum(14, relativeTo: .caption)).foregroundStyle(ReffiColor.ink2)
                }
                Text("·").foregroundStyle(ReffiColor.muted)
                Text(result.urgentUsedCount > 0 ? "\(result.urgentUsedCount) expiring today" : "\(result.used.count) to use")
                    .font(.custom("Pretendard-Medium", size: 14, relativeTo: .caption))
                    .foregroundStyle(result.urgentUsedCount > 0 ? ReffiColor.urgentDark : ReffiColor.ink2)
            }

            DashedRule()

            Text("ON THE TICKET")
                .font(.custom("Pretendard-SemiBold", size: 11, relativeTo: .caption2))
                .tracking(1.4).foregroundStyle(ReffiColor.ink.opacity(0.5))

            VStack(alignment: .leading, spacing: ReffiSpace.s2) {
                ForEach(result.used) { ing in ticketLine(ing) }
            }

            if !result.missing.isEmpty {
                Text("Short: " + result.missing.joined(separator: ", "))
                    .font(.custom("Pretendard-Medium", size: 12, relativeTo: .caption))
                    .foregroundStyle(ReffiColor.muted)
                    .lineLimit(2)
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, ReffiSpace.s5)
        .padding(.top, ReffiSpace.s6)
        .padding(.bottom, ReffiSpace.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ReceiptShape(tooth: 9).fill(ReffiColor.oklch(0.99, 0.008, 92)))
        .overlay(ReceiptShape(tooth: 9).stroke(ReffiColor.ink.opacity(0.07), lineWidth: 1))
        .overlay(alignment: .bottomTrailing) { startStamp.padding(ReffiSpace.s5) }
        .reffiShadow1()
    }

    /// 티켓 한 줄 — 체크 박스 + 이름 + D-N(신선도색).
    private func ticketLine(_ ing: Ingredient) -> some View {
        HStack(spacing: ReffiSpace.s2) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(ing.freshness.dark.opacity(0.7), lineWidth: 1.5)
                .frame(width: 14, height: 14)
            Text(ing.name)
                .font(.custom("Pretendard-SemiBold", size: 16, relativeTo: .body))
                .foregroundStyle(ReffiColor.ink)
            Spacer(minLength: ReffiSpace.s2)
            Text(ing.dDayText)
                .font(.reffiNum(13, relativeTo: .caption))
                .foregroundStyle(ing.freshness.dark)
        }
    }

    /// 고무 스탬프 — 둘러보기 전용 장식(액션 아님).
    private var startStamp: some View {
        Text("START")
            .font(.custom("Pretendard-Bold", size: 15, relativeTo: .subheadline))
            .tracking(2).foregroundStyle(ReffiColor.blue.opacity(0.8))
            .padding(.horizontal, ReffiSpace.s3)
            .padding(.vertical, ReffiSpace.s1)
            .overlay(PaperRect(cornerRadius: ReffiRadius.sm, seed: 2)
                .stroke(ReffiColor.blue.opacity(0.55), lineWidth: 2))
            .rotationEffect(.degrees(-8))
            .opacity(0.9)
            .accessibilityHidden(true)
    }
}

/// 점선 룰 — 오더 티켓의 절취선 느낌.
struct DashedRule: View {
    var body: some View {
        GeometryReader { g in
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0.5))
                p.addLine(to: CGPoint(x: g.size.width, y: 0.5))
            }
            .stroke(ReffiColor.ink.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .frame(height: 1)
    }
}

/// 영수증/티켓 셰이프 — 상·하 톱니(절취) 엣지. 좌우는 곧다.
struct ReceiptShape: Shape {
    var tooth: CGFloat = 9

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let t = max(4, tooth)
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + t))
        // 상단 톱니 (좌→우)
        var x = rect.minX
        var up = true
        while x < rect.maxX {
            let nx = min(x + t, rect.maxX)
            p.addLine(to: CGPoint(x: nx, y: rect.minY + (up ? 0 : t)))
            x = nx; up.toggle()
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - t))
        // 하단 톱니 (우→좌)
        up = true
        x = rect.maxX
        while x > rect.minX {
            let nx = max(x - t, rect.minX)
            p.addLine(to: CGPoint(x: nx, y: rect.maxY - (up ? 0 : t)))
            x = nx; up.toggle()
        }
        p.closeSubpath()
        return p
    }
}
