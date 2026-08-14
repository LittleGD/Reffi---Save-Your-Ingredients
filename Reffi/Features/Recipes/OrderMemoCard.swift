import SwiftUI
import PhosphorSwift

/// 오더 메모 카드(§13) — 주방 오더 티켓이자 **단서 카드**: 크림 종이 + 톱니 엣지 + 모노 헤더 + 판정문 +
/// 메뉴/시간 + 재료 이름 블록 + **"이걸로 요리" 발주 CTA**. 발주하면 START 스탬프가 쾅 찍히고 사용 재료가
/// 비워진다(Fire the Ticket). affordance(탭할 스탬프)와 payoff(비우기 증명)가 같은 오브젝트.
///
/// 티켓은 "무엇을 만들지"의 단서까지만 준다 — 조리 방법(단계)은 티켓에 싣지 않고 조리 화면의
/// 영상 링크가 맡는다. 카드에 남는 건 판단에 필요한 것뿐: 왜 이 티켓인가(판정문), 무엇인가(메뉴·시간),
/// 무엇이 빠지나(Short), 그리고 임박 재료의 D-day.
struct OrderMemoCard: View {
    let result: RecipeRecommender.Result
    let number: Int
    /// 덱 가장 깊은 티켓 경량화 — true면 머리(크롬 크라운 줄)까지만 그리고 본문·CTA를 생략한다.
    /// 가장 깊은 티켓은 어차피 상단 슬리버만 보이므로 전환 프레임드롭을 줄이려 본문 렌더를 건너뛴다(§13.6).
    /// 주의: 컨테이너(VStack·배경·compositingGroup·그림자)는 headerOnly와 무관하게 **단일 뷰 정체성**을
    /// 유지하고 내부 콘텐츠만 분기한다 — body 수준 if/else(ConditionalContent)면 덱 회전 시
    /// 카드가 제거+삽입(기본 opacity 트랜지션)되어 번쩍인다.
    var headerOnly: Bool = false
    /// 덱 뒤 티켓(depth ≥ 1) — 크롬 텍스트를 렌더하지 않고 **빈 종이 밴드**만 내민다.
    /// 앞 티켓의 절취 톱니는 골이 파인 지그재그라, 그 골 사이로 뒤 카드의 ORDER 행이
    /// 가로로 잘린 반쪽 글리프로 새어 나왔다(라이트·다크 동일 재현). 노출 띠는 "다음 종이가 있다"만
    /// 말하면 되므로 글자를 지운다. 레이아웃은 그대로 두고 불투명도만 0으로 — 승격(1→0) 시
    /// 헤더가 튀어나오지 않고 덱 회전 애니메이션을 타고 부드럽게 살아난다.
    var peek: Bool = false
    var onFire: () -> Void = {}
    /// "살 것에 담기" 이후의 이동 — 담기는 카드가 store에 직접 하고, **화면 전환만** 부모에게 맡긴다.
    /// 티켓 덱은 커버 안이라 자기 위에 To buy를 띄울 수 있는 건 덱(호스트)뿐이다.
    var onOpenToBuy: () -> Void = {}
    /// 오른쪽 플릭(Cook) 발주 트리거 — 덱이 값을 올리면 "Cook this" 버튼과 **같은** `fire()`를 태운다.
    /// 발주 상태(슬램·줄긋기·이중 발주 가드)를 카드가 소유하므로 부모가 `fired`를 직접 켜지 않는다.
    var fireTrigger: Int = 0
    /// Short 행의 To buy 원탭 — 부족 재료 **전부**를 장보기 메모로 담고 **새로 담긴 수**를 돌려준다.
    /// nil이면 알약 자체를 그리지 않는다(스토어에 닿지 못하는 프리뷰·공유 렌더에서 위약 버튼 금지).

    @Environment(FridgeStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fired = false
    @State private var middleScrolls = false   // 중간 섹션이 실제로 스크롤되는가(안전망 발동 여부)
    @State private var addToBuyHaptic = 0      // 룰⑦ — 목록에 담김 = 성공 완료(.success)

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
        .background(ReceiptShape(tooth: ReffiTooth.ticket).fill(ReffiColor.paper))
        .overlay { if !headerOnly { ReceiptShape(tooth: ReffiTooth.ticket).stroke(ReffiColor.ink.opacity(0.07), lineWidth: 1) } }
        .overlay { if fired { slamStamp } }
        .compositingGroup()   // 그림자 재합성을 1패스로 — PaperGrain(.overlay)도 이 경계에 갇힌다.
        // 그림자는 값만 분기, 체인(2패스)은 고정 — 뷰 정체성 유지.
        // 풀 렌더면 reffiShadow1(§6.2)과 동일 값, headerOnly면 가벼운 단일 패스(2패스째 투명).
        .shadow(color: ReffiColor.shadowTint.opacity(headerOnly ? 0.06 : 0.10),
                radius: headerOnly ? 4 : 1.5, x: 0, y: headerOnly ? 2 : 1)
        .shadow(color: ReffiColor.shadowTint.opacity(headerOnly ? 0 : 0.05),
                radius: 10, x: 0, y: 8)
        .sensoryFeedback(.success, trigger: addToBuyHaptic)   // 룰⑦ 성공 완료 — To buy 시트의 담기와 같은 햅틱
        .onChange(of: fireTrigger) { _, _ in fire() }
        .sensoryFeedback(.success, trigger: addToBuyHaptic)   // 룰⑦ 성공 완료 — To buy 시트의 담기와 같은 햅틱
    }

    /// 중간 섹션 — 헤더·fireBand는 고정, 판정문~'ON THE TICKET'(+ Short 문구)만 내부 스크롤(§13.6).
    /// 단계 미리보기를 걷어낸 뒤로는 기본 텍스트 크기에서 항상 다 들어간다 — 스크롤·페이드는
    /// 극단 Dynamic Type(접근성 크기)에서만 발동하는 **오버플로 안전망**으로만 남긴다.
    /// 지우면 큰 글자에서 마지막 재료 줄과 Short 문구가 잘려 판단 근거가 사라진다.
    private var middleScroll: some View {
        let r = result.recipe
        // 콘텐츠가 프레임보다 작으면 스크롤이 비활성이라 시각 무변화, 극단 Dynamic Type에서만 발동.
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                ReffiRule(.ticket)

                // 판정문 키커 — 이 티켓이 비우는 임박 재료(미션 페이로드).
                // role은 metaText 축으로 흡수한다: 신선도 색(verdictColor)이 이미 강조를 맡고 있어
                // 13pt에서 SemiBold/Medium 한 단을 더 두면 계층이 아니라 잡음으로 읽혔다.
                verdictKicker
                    .reffiType(.metaText).foregroundStyle(verdictColor)

                // 메뉴명 + 시간 + 요리 아이콘. 아이콘은 **오른쪽 여백에 얹힌 그림**이고 글이 주인공이다 —
                // 이름 위에 한 줄로 올리면 티켓 상단이 그림에 밀려 "주문서"가 아니라 메뉴판이 된다.
                // 배경 타일 없이 종이 위에 그대로 둔다(§13.3 — 일러스트는 색면 박스에 담지 않는다).
                HStack(alignment: .top, spacing: ReffiSpace.s3) {
                    VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                        Text(verbatim: r.displayName)
                            .reffiType(.menuName).foregroundStyle(ReffiColor.ink)
                            .lineLimit(2).minimumScaleFactor(0.8).fixedSize(horizontal: false, vertical: true)
                            // UI 테스트 훅 — 앞 티켓의 메뉴명을 이름 하드코딩 없이 집어 조리 화면과 대조한다
                            // (오른쪽 플릭이 덱을 넘기지 않고 **1번** 티켓을 발주했다는 증거). 라벨은 그대로다.
                            .accessibilityIdentifier("ticket.menuName")
                        HStack(spacing: 4) {
                            ReffiIcon.time.reffi(13).foregroundStyle(ReffiColor.ink2)
                            Text("\(r.minutes) min · \(result.used.count) to use")
                                .reffiType(.metaText)
                                .foregroundStyle(ReffiColor.ink2)
                        }
                    }
                    Spacer(minLength: ReffiSpace.s2)
                    // 조리 화면·공유 카드·내 레시피와 **같은** `heroIcon`을 쓴다 — 표면마다 다른 그림이면
                    // 발주 전후로 다른 요리로 바뀐 것처럼 읽힌다(정체는 같고, 비중만 표면마다 다르다).
                    // 크기는 68pt(`ReffiDishIcon.ticket`) 고정 — 덱은 여러 장을 훑어 **고르는** 자리라
                    // 그림은 메뉴명 옆의 식별자여야 한다. 카드 아래쪽이 비어 보인다고 여기만 키워
                    // 메뉴명과 시간 줄을 합친 높이를 넘기면, 글이 주인공인 티켓이 메뉴판으로 넘어간다.
                    // (요리를 이미 고른 뒤인 조리 티켓은 반대로 아이콘이 종이 한복판의 주인공이다.)
                    RecipeHeroIconView(icon: r.heroIcon)
                        .frame(width: ReffiDishIcon.ticket, height: ReffiDishIcon.ticket)
                }

                ReffiRule(.ticket)

                // 티켓 위 인쇄 크롬은 크라운 행과 **같은 모노 role**이다 — 색(ink vs ink2)으로만 갈린다.
                // 형제 라벨(ORDER · REFFI KITCHEN · ORDER · FIRED)과 같이 verbatim: 주방 티켓의
                // 인쇄 문자열이라 번역하지 않는다.
                Text(verbatim: "ON THE TICKET")
                    .reffiType(.monoTicketLabel).foregroundStyle(ReffiColor.ink2)   // §2.6 — 소형 텍스트는 불투명 토큰으로

                // 이름 블록은 최대 5줄 미리보기(+N more) — 소비는 result.used 전체를 쓰므로 표시만 축약.
                VStack(alignment: .leading, spacing: ReffiSpace.s1 + 2) {
                    ForEach(result.used.prefix(5)) { ing in ticketLine(ing, done: fired) }
                    if result.used.count > 5 {
                        Text("+\(result.used.count - 5) more on the ticket")
                            .reffiType(.metaText)
                            .foregroundStyle(ReffiColor.ink2)
                    }
                }

                if !result.missing.isEmpty {
                    // 부족 재료 — 읽는 줄(무엇이 없나)과 **행동 한 개**(살 것에 담기)를 붙여 둔다.
                    // 표기는 레시피 원문 그대로다("소고기 (얇게 썬 것)") — 여기선 레시피를 읽는 자리라
                    // 괄호 주석이 정보다. 담을 때만 `toBuyEntry`가 이름을 장보기용으로 정리한다.
                    VStack(alignment: .leading, spacing: ReffiSpace.s2) {
                        Text("Short: \(result.missing.map(\.displayName).joined(separator: ", "))")
                            .reffiType(.metaText)
                            .foregroundStyle(ReffiColor.ink2).lineLimit(2)
                        addToBuyChip
                    }
                    .padding(.top, 1)
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


    /// 티켓 크롬 한 줄(§13.5) — 옛 2행("ORDER"/"#NN" + "TABLE · REFFI KITCHEN" 에보로우)을 한 줄로 합쳤다.
    /// 메뉴명까지 닿기 전에 크롬만 3계층(모노13 + 숫자14 + 에보로우10)을 지나야 했고, 그게 티켓 한 장의
    /// 텍스트 계층을 10종까지 밀어 올린 주범이었다. 지금은 **한 모노 role·한 크기**로 좌 발주처·우 번호다.
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: ReffiSpace.s2) {
            // 모노 티켓 크롬은 번역하지 않는다(§13.5) — "ON THE TICKET"·"ORDER · FIRED"와 같은 규칙.
            // verbatim으로 카탈로그 조회 자체를 끊어, 누가 키를 등록해도 흔들리지 않게 한다.
            Text(verbatim: "ORDER · REFFI KITCHEN")
                .reffiType(.monoTicketLabel).foregroundStyle(ReffiColor.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: ReffiSpace.s2)
            // 번호도 같은 모노 role·크기 — 옛 GSF 14는 크롬 안에서 홀로 다른 서체였다.
            Text(verbatim: String(format: "#%02d", number))
                .reffiType(.monoTicketLabel).foregroundStyle(ReffiColor.ink2)   // §2.6 — 소형 텍스트 대비
                .lineLimit(1)
        }
        .opacity(peek ? 0 : 1)   // 뒤 티켓 노출 띠는 빈 종이 — 톱니 골에 반쪽 글리프가 새지 않게
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

    /// 부족 재료 → 살 것. 티켓의 유일한 **보조** 행동이라 파랑 와이드 CTA("Cook this")를 덮지 않는
    /// 작은 종이 필(`ShoppingListView`의 Add 칩과 같은 문법·같은 To buy 블루)로 둔다.
    /// 발주 후에도 살아 있다 — 재료가 부족하다는 사실은 발주로 바뀌지 않고, 오히려 그때 더 사야 한다.
    private var addToBuyChip: some View {
        Button { addMissingToBuy() } label: {
            HStack(spacing: ReffiSpace.s1) {
                ReffiIcon.receipt.reffi(12, .bold)
                Text("Add to To buy").reffiType(.pillLabel)
            }
            .foregroundStyle(ReffiColor.blueDark)
            .padding(.horizontal, ReffiSpace.s3 + 2)
            .padding(.vertical, ReffiSpace.s1 + 1)
            .background {
                let s = PaperRect(cornerRadius: ReffiRadius.pill, seed: number &+ 7)
                s.fill(ReffiColor.blueLight).paperEdge(s, tint: ReffiColor.ink.opacity(0.06))
            }
            .frame(minHeight: 44)   // §7.3 터치 타깃(시각 높이는 그대로)
            .contentShape(Rectangle())
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel(Text("Add to To buy"))
        .accessibilityHint(Text("Adds the missing ingredients and opens your To buy list"))
    }

    /// 부족 재료를 **한꺼번에** 담고 곧장 목록으로 보낸다. 중복·파생 제안 흡수는 `addToBuy`가 처리하므로
    /// 여기서 미리 거르지 않는다(이미 담긴 건 no-op, 이력 제안으로만 떠 있던 건 수동 항목으로 승격).
    /// 이름·캐논 ID·글리프는 `toBuyEntry`가 확정해 넘긴다 — 표시명을 store에 그대로 주면 괄호 주석이
    /// 포함 매칭에 걸려 엉뚱한 품목 키가 붙는다.
    private func addMissingToBuy() {
        // 햅틱은 **실제로 담긴 게 있을 때만** — 전부 이미 담겨 있던 재탭은 아무것도 바꾸지 않았으므로
        // 성공 신호를 주면 거짓말이 된다(`ToBuySearchSheet.add`의 `if added`와 같은 규약).
        // `reduce`에 단축 평가(`||`)를 쓰면 첫 성공 이후가 호출되지 않으니 각 항목을 반드시 먼저 부른다.
        var addedAny = false
        for item in result.missing {
            let entry = RecipeRecommender.toBuyEntry(for: item)
            let added = store.addToBuy(name: entry.name, canonicalID: entry.canonicalID, glyph: entry.glyph)
            addedAny = addedAny || added
        }
        if addedAny { addToBuyHaptic += 1 }
        onOpenToBuy()
    }

    /// 발주 도장 — "START"가 쾅(scale 1.5→1, pop) 찍힌다. 빨강 잉크(키친 fired).
    /// 도장 텍스트도 모노 티켓 크롬이라 번역하지 않는다(§13.5, `stampLabel`).
    private var slamStamp: some View {
        Text(verbatim: "START")
            .reffiType(.stampLabel).foregroundStyle(ReffiColor.urgentDark.opacity(0.88))
            .padding(.horizontal, ReffiSpace.s4).padding(.vertical, ReffiSpace.s2)
            .overlay(PaperRect(cornerRadius: ReffiRadius.sm, seed: 2)
                .stroke(ReffiColor.urgentDark.opacity(0.7), lineWidth: 3.5))
            .rotationEffect(.degrees(-11))
            .transition(.scale(scale: 1.5).combined(with: .opacity))
            .accessibilityHidden(true)
    }

    /// 티켓 한 줄 — 이름 + (임박할 때만) D-day 칩. 체크박스는 없다: 티켓은 체크하며 따라가는 목록이 아니라
    /// "무엇이 들어가나"를 한눈에 읽는 단서 블록이다. 발주하면 줄이 그어져 비웠음이 남는다(payoff).
    ///
    /// D-day 칩의 면은 §13.1 종이컷 8각형(`PaperCutRect`)이다 — 행동 표면에 완벽한 캡슐을 두지 않는다.
    /// D-day는 `.soon`·`.urgent`에만 붙인다 — 신선도는 앱의 본체지만, 아직 여유 있는 재료의 카운트다운은
    /// 노이즈일 뿐이라 "지금 급한 것"만 눈에 띄게 남긴다(색+텍스트 동반, §1).
    private func ticketLine(_ ing: Ingredient, done: Bool) -> some View {
        HStack(spacing: ReffiSpace.s2) {
            Text(verbatim: ing.displayName)
                .reffiType(.checklistItem)
                .foregroundStyle(done ? ReffiColor.muted : ReffiColor.ink)
                .strikethrough(done, color: ReffiColor.muted)
                .lineLimit(1).truncationMode(.tail)
            Spacer(minLength: ReffiSpace.s2)
            if ing.freshness != .fresh {
                Text(verbatim: ing.dDayText)
                    .font(.reffiNum(.meta))
                    .foregroundStyle(ing.freshness.dark)
                    .padding(.horizontal, ReffiSpace.s2)
                    .padding(.vertical, 1)
                    .background(ing.freshness.light, in: PaperCutRect(seed: 2))   // §13.1 종이컷 8각형(캡슐 금지)
            }
        }
    }
}

