import SwiftUI
import PhosphorSwift

/// 오더 메모 카드(§13) — 주방 오더 티켓: 크림 종이 + 톱니 엣지 + 모노 헤더 + 판정문 + 메뉴/시간 +
/// 재료 체크리스트 + **"이걸로 요리" 발주 CTA**. 발주하면 START 스탬프가 쾅 찍히고 사용 재료가 비워진다
/// (Fire the Ticket). affordance(탭할 스탬프)와 payoff(비우기 증명)가 같은 오브젝트.
struct OrderMemoCard: View {
    let result: RecipeRecommender.Result
    let number: Int
    /// 덱 가장 깊은 티켓 경량화 — true면 머리(ORDER/#·TABLE 줄)까지만 그리고 본문·CTA를 생략한다.
    /// 가장 깊은 티켓은 어차피 상단 슬리버만 보이므로 전환 프레임드롭을 줄이려 본문 렌더를 건너뛴다(§13.6).
    /// 주의: 컨테이너(VStack·배경·compositingGroup·그림자)는 headerOnly와 무관하게 **단일 뷰 정체성**을
    /// 유지하고 내부 콘텐츠만 분기한다 — body 수준 if/else(ConditionalContent)면 덱 회전 시
    /// 카드가 제거+삽입(기본 opacity 트랜지션)되어 번쩍인다.
    var headerOnly: Bool = false
    var onFire: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fired = false
    @State private var middleScrolls = false   // 중간 섹션이 실제로 스크롤되는가(안전망 발동 여부)

    /// 임박(urgent+soon) 재료 수 — 안티-웨이스트 증명.
    private var rescuedCount: Int { result.used.filter { $0.freshness != .fresh }.count }

    /// 카드 1순위 판정문 — 왜 이 티켓이 추천됐나(랭킹 근거를 사람 말로).
    private var verdictKicker: Text {
        if result.urgentUsedCount > 0 { return Text("Saves \(result.urgentUsedCount) expiring today") }
        if rescuedCount > 0 { return Text("Clears \(rescuedCount) before they spoil") }
        return Text("Use these while fresh")
    }
    private var verdictColor: Color {
        result.urgentUsedCount > 0 ? ReffiColor.urgentDark
            : rescuedCount > 0 ? ReffiColor.soonDark : ReffiColor.freshDark
    }

    /// 컨테이너는 항상 같은 뷰 트리(단일 정체성) — headerOnly는 내부 콘텐츠·모디파이어 값만 바꾼다.
    /// 덱 회전으로 headerOnly가 토글돼도(승격·강등) 카드가 통째로 교체되지 않아 번쩍임이 없다.
    var body: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s3) {
            header
            if headerOnly {
                Spacer(minLength: 0)
            } else {
                middleScroll
                Spacer(minLength: ReffiSpace.s3)
                fireBand
            }
        }
        .padding(.horizontal, ReffiSpace.s5)
        .padding(.top, ReffiSpace.s5 + 2)
        .padding(.bottom, ReffiSpace.s5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ReceiptShape(tooth: 9).fill(ReffiColor.paper))
        .overlay { if !headerOnly { ReceiptShape(tooth: 9).stroke(ReffiColor.ink.opacity(0.07), lineWidth: 1) } }
        .overlay { if fired { slamStamp } }
        .compositingGroup()   // 그림자 재합성을 1패스로 — PaperGrain(.overlay)도 이 경계에 갇힌다.
        // 그림자는 값만 분기, 체인(2패스)은 고정 — 뷰 정체성 유지.
        // 풀 렌더면 reffiShadow1(§6.2)과 동일 값, headerOnly면 가벼운 단일 패스(2패스째 투명).
        .shadow(color: ReffiColor.shadowTint.opacity(headerOnly ? 0.06 : 0.10),
                radius: headerOnly ? 4 : 1.5, x: 0, y: headerOnly ? 2 : 1)
        .shadow(color: ReffiColor.shadowTint.opacity(headerOnly ? 0 : 0.05),
                radius: 10, x: 0, y: 8)
    }

    /// 중간 섹션 — 헤더·fireBand는 고정, 'ON THE TICKET'~PREP(+ Short 문구)만 내부 스크롤(§13.6).
    private var middleScroll: some View {
        let r = result.recipe
        // 콘텐츠가 프레임보다 작으면 스크롤이 비활성이라 시각 무변화, 극단 Dynamic Type에서만 발동.
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                DashedRule()

                // 판정문 키커 — 이 티켓이 비우는 임박 재료(미션 페이로드).
                verdictKicker
                    .reffiType(.pillLabel).foregroundStyle(verdictColor)

                // 메뉴명 + 시간
                Text(verbatim: r.displayName)
                    .reffiType(.menuName).foregroundStyle(ReffiColor.ink)
                    .lineLimit(2).minimumScaleFactor(0.8).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    ReffiIcon.time.reffi(13).foregroundStyle(ReffiColor.ink2)
                    Text("\(r.minutes) min · \(result.used.count) to use")
                        .reffiType(.metaText)
                        .foregroundStyle(ReffiColor.ink2)
                }

                DashedRule()

                Text("ON THE TICKET")
                    .reffiType(.sectionLabel).foregroundStyle(ReffiColor.ink2)   // §2.6 — 소형 텍스트는 불투명 토큰으로

                // 체크리스트는 최대 5줄 미리보기(+N more) — 소비는 result.used 전체를 쓰므로 표시만 축약.
                VStack(alignment: .leading, spacing: ReffiSpace.s2) {
                    ForEach(result.used.prefix(5)) { ing in ticketLine(ing, done: fired) }
                    if result.used.count > 5 {
                        Text("+\(result.used.count - 5) more on the ticket")
                            .reffiType(.metaText)
                            .foregroundStyle(ReffiColor.ink2)
                    }
                }

                if !result.missing.isEmpty {
                    Text("Short: \(result.missing.joined(separator: ", "))")
                        .reffiType(.metaText)
                        .foregroundStyle(ReffiColor.ink2).lineLimit(2).padding(.top, 1)
                }

                if !r.displaySteps.isEmpty {
                    DashedRule()
                    prepSection(r.displaySteps)
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .onScrollGeometryChange(for: Bool.self) { g in
            g.contentSize.height > g.containerSize.height + 1
        } action: { _, scrolls in
            middleScrolls = scrolls
        }
        // 스크롤이 실제로 발동할 때만 하단 페이드 — 경계에서 줄이 '뚝' 잘린 게 아니라
        // 더 있음을 읽히게 한다. 콘텐츠가 다 들어가면 마스크 없음(마지막 줄 흐림 방지).
        .mask {
            if middleScrolls {
                LinearGradient(stops: [.init(color: .black, location: 0),
                                       .init(color: .black, location: 0.92),
                                       .init(color: .black.opacity(0.15), location: 1)],
                               startPoint: .top, endPoint: .bottom)
            } else {
                Rectangle()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            HStack(alignment: .firstTextBaseline) {
                Text("ORDER").reffiType(.monoTicketLabel).foregroundStyle(ReffiColor.ink)
                Spacer()
                // AI 생성 배지(§13.5) — 헤더 콘텐츠 분기라 카드 컨테이너 정체성엔 영향 없음(body 최상위 불변식 참고).
                if result.recipe.isAI { aiBadge }
                Text(String(format: "#%02d", number))
                    .font(.reffiNum(14, relativeTo: .caption)).foregroundStyle(ReffiColor.ink2)
            }
            Text(verbatim: "TABLE · REFFI KITCHEN")
                .reffiType(.monoEyebrow).foregroundStyle(ReffiColor.ink2)   // §2.6 — 소형 텍스트 대비
        }
    }

    /// AI 생성 미니 배지 — sparkle + "AI"(고유 표기, 비로컬라이즈). `blue-light` 종이 칩.
    private var aiBadge: some View {
        HStack(spacing: 3) {
            ReffiIcon.ai.reffi(13).foregroundStyle(ReffiColor.blueDark)
            Text(verbatim: "AI")
                .reffiType(.monoEyebrow).foregroundStyle(ReffiColor.blueDark)
        }
        .padding(.horizontal, ReffiSpace.s2)
        .padding(.vertical, 3)
        .background {
            let shape = PaperRect(cornerRadius: ReffiRadius.xs, seed: number)
            shape.fill(ReffiColor.blueLight)
        }
        .accessibilityLabel(Text("AI generated recipe"))
    }

    /// 조리 메모(§13.6 payoff) — 발주 전부터 티켓에 짧은 순서를 보여줘 "누르면 뭘 하게 되는지"가 보인다.
    /// 미리보기는 최대 3단계(+N more) — 전체 단계는 발주 후 CookingStepsView가 정본이다.
    private func prepSection(_ steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s1 + 2) {
            Text("PREP")
                .reffiType(.sectionLabel).foregroundStyle(ReffiColor.ink2)
            ForEach(Array(steps.prefix(3).enumerated()), id: \.offset) { i, step in
                HStack(alignment: .firstTextBaseline, spacing: ReffiSpace.s2) {
                    Text(verbatim: "\(i + 1).")
                        .font(.reffiNum(12, relativeTo: .caption)).foregroundStyle(ReffiColor.ink2)
                    Text(verbatim: step)
                        .reffiType(.metaText)
                        .foregroundStyle(ReffiColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if steps.count > 3 {
                Text("+\(steps.count - 3) more steps")
                    .reffiType(.metaText)
                    .foregroundStyle(ReffiColor.ink2)
            }
        }
    }

    /// 발주 밴드 — 미발주: "이걸로 요리" CTA / 발주 후: 비우기 판정문.
    @ViewBuilder private var fireBand: some View {
        if fired {
            HStack(spacing: 6) {
                ReffiIcon.ate.reffi(15, .fill).foregroundStyle(ReffiColor.freshDark)
                (result.urgentUsedCount > 0
                    ? Text("Saved \(result.used.count) · \(result.urgentUsedCount) today")
                    : Text("Saved \(result.used.count)"))
                    .reffiType(.pillLabel)
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
            .accessibilityLabel(Text("Cook this"))
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
            .reffiType(.stampLabel).foregroundStyle(ReffiColor.urgentDark.opacity(0.88))
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
                    // 다크에서 freshness.dark 도트가 밝아지므로 체크는 onInk(어두운 콘텐츠)여야 산다.
                    Image(systemName: "checkmark").font(.system(size: 8, weight: .heavy)).foregroundStyle(ReffiColor.onInk)
                }
            }
            Text(verbatim: ing.name)
                .reffiType(.checklistItem)
                .foregroundStyle(done ? ReffiColor.muted : ReffiColor.ink)
                .strikethrough(done, color: ReffiColor.muted)
            Spacer(minLength: ReffiSpace.s2)
            Text(verbatim: ing.dDayText)
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
