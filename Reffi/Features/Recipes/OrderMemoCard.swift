import SwiftUI
import PhosphorSwift

/// 오더 메모 카드(§13) — 주방 오더 티켓: 크림 종이 + 톱니 엣지 + 모노 헤더 + 판정문 + 메뉴/시간 +
/// 재료 체크리스트 + **"이걸로 요리" 발주 CTA**. 발주하면 START 스탬프가 쾅 찍히고 사용 재료가 비워진다
/// (Fire the Ticket). affordance(탭할 스탬프)와 payoff(비우기 증명)가 같은 오브젝트.
struct OrderMemoCard: View {
    let result: RecipeRecommender.Result
    let number: Int
    var onFire: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fired = false

    /// 임박(urgent+soon) 재료 수 — 안티-웨이스트 증명.
    private var rescuedCount: Int { result.used.filter { $0.freshness != .fresh }.count }

    /// 카드 1순위 판정문 — 왜 이 티켓이 추천됐나(랭킹 근거를 사람 말로).
    private var verdictKicker: String {
        if result.urgentUsedCount > 0 { return "Saves \(result.urgentUsedCount) expiring today" }
        if rescuedCount > 0 { return "Clears \(rescuedCount) before they spoil" }
        return "Use these while fresh"
    }
    private var verdictColor: Color {
        result.urgentUsedCount > 0 ? ReffiColor.urgentDark
            : rescuedCount > 0 ? ReffiColor.soonDark : ReffiColor.freshDark
    }

    var body: some View {
        let r = result.recipe
        VStack(alignment: .leading, spacing: ReffiSpace.s3) {
            header

            DashedRule()

            // 판정문 키커 — 이 티켓이 비우는 임박 재료(미션 페이로드).
            Text(verdictKicker)
                .font(.custom("Pretendard-Bold", size: 12, relativeTo: .caption2))
                .tracking(0.2).foregroundStyle(verdictColor)

            // 메뉴명 + 시간
            Text(r.name)
                .font(.custom("Pretendard-Bold", size: 24, relativeTo: .title2))
                .tracking(-0.3).foregroundStyle(ReffiColor.ink)
                .lineLimit(2).minimumScaleFactor(0.8).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 4) {
                ReffiIcon.time.reffi(13).foregroundStyle(ReffiColor.ink2)
                Text("\(r.minutes) min · \(result.used.count) to use")
                    .font(.reffiNum(13, relativeTo: .caption)).foregroundStyle(ReffiColor.ink2)
            }

            DashedRule()

            Text("ON THE TICKET")
                .font(.custom("Pretendard-SemiBold", size: 11, relativeTo: .caption2))
                .tracking(1.4).foregroundStyle(ReffiColor.ink.opacity(0.5))

            VStack(alignment: .leading, spacing: ReffiSpace.s2) {
                ForEach(result.used) { ing in ticketLine(ing, done: fired) }
            }

            if !result.missing.isEmpty {
                Text("Short: " + result.missing.joined(separator: ", "))
                    .font(.custom("Pretendard-Medium", size: 12, relativeTo: .caption))
                    .foregroundStyle(ReffiColor.muted).lineLimit(2).padding(.top, 1)
            }

            Spacer(minLength: ReffiSpace.s3)
            fireBand
        }
        .padding(.horizontal, ReffiSpace.s5)
        .padding(.top, ReffiSpace.s5 + 2)
        .padding(.bottom, ReffiSpace.s5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ReceiptShape(tooth: 9).fill(ReffiColor.paper))
        .overlay(ReceiptShape(tooth: 9).stroke(ReffiColor.ink.opacity(0.07), lineWidth: 1))
        .overlay { if fired { slamStamp } }
        .reffiShadow1()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            HStack(alignment: .firstTextBaseline) {
                Text("ORDER").font(.custom("Pretendard-Bold", size: 13, relativeTo: .caption))
                    .tracking(2.5).foregroundStyle(ReffiColor.ink)
                Spacer()
                Text(String(format: "#%02d", number))
                    .font(.reffiNum(14, relativeTo: .caption)).foregroundStyle(ReffiColor.ink2)
            }
            Text("TABLE · REFFI KITCHEN")
                .font(.custom("Pretendard-Medium", size: 10, relativeTo: .caption2))
                .tracking(1.6).foregroundStyle(ReffiColor.muted)
        }
    }

    /// 발주 밴드 — 미발주: "이걸로 요리" CTA / 발주 후: 비우기 판정문.
    @ViewBuilder private var fireBand: some View {
        if fired {
            HStack(spacing: 6) {
                ReffiIcon.ate.reffi(15, .fill).foregroundStyle(ReffiColor.freshDark)
                Text("Saved \(result.used.count)" + (result.urgentUsedCount > 0 ? " · \(result.urgentUsedCount) today" : ""))
                    .font(.custom("Pretendard-SemiBold", size: 14, relativeTo: .caption))
                    .foregroundStyle(ReffiColor.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ReffiSpace.s2)
        } else {
            Button { fire() } label: {
                Text("Cook this")
                    .font(ReffiTextRole.subhead.font).tracking(ReffiTextRole.subhead.tracking)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ReffiSpace.s3 + 1)
                    .background {
                        let shape = PaperCutRect(seed: number)
                        shape.fill(ReffiColor.blue)
                            .overlay(PaperGrain(seed: UInt64(number) &+ 4).clipShape(shape))
                            .paperEdge(shape, tint: ReffiColor.paperEdgeOnFill)
                    }
            }
            .buttonStyle(.paperPress)
            .accessibilityLabel("Cook with this")
        }
    }

    private func fire() {
        guard !fired else { return }
        withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) { fired = true }
        onFire()
    }

    /// 발주 도장 — "START"가 쾅(scale 1.5→1, pop) 찍힌다. 빨강 잉크(키친 fired).
    private var slamStamp: some View {
        Text("START")
            .font(.custom("Pretendard-Bold", size: 34, relativeTo: .largeTitle))
            .tracking(3).foregroundStyle(ReffiColor.urgentDark.opacity(0.88))
            .padding(.horizontal, ReffiSpace.s4).padding(.vertical, ReffiSpace.s2)
            .overlay(PaperRect(cornerRadius: ReffiRadius.sm, seed: 2)
                .stroke(ReffiColor.urgentDark.opacity(0.7), lineWidth: 3.5))
            .rotationEffect(.degrees(-11))
            .transition(.scale(scale: 1.5).combined(with: .opacity))
            .accessibilityHidden(true)
    }

    /// 티켓 한 줄 — 체크 박스 + 이름 + D-N. 발주하면 체크가 채워지고 줄이 그어진다.
    private func ticketLine(_ ing: Ingredient, done: Bool) -> some View {
        HStack(spacing: ReffiSpace.s2) {
            ZStack {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(ing.freshness.dark.opacity(0.7), lineWidth: 1.5)
                    .frame(width: 14, height: 14)
                if done {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(ing.freshness.dark).frame(width: 14, height: 14)
                    Image(systemName: "checkmark").font(.system(size: 8, weight: .heavy)).foregroundStyle(.white)
                }
            }
            Text(ing.name)
                .font(.custom("Pretendard-SemiBold", size: 16, relativeTo: .body))
                .foregroundStyle(done ? ReffiColor.muted : ReffiColor.ink)
                .strikethrough(done, color: ReffiColor.muted)
            Spacer(minLength: ReffiSpace.s2)
            Text(ing.dDayText)
                .font(.reffiNum(13, relativeTo: .caption))
                .foregroundStyle(ing.freshness.dark)
        }
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
