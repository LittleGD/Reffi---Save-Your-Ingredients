import SwiftUI
import PhosphorSwift

/// 오더 메모 카드(§13) — 주방 오더 티켓이자 **단서 카드**: 크림 종이 + 톱니 엣지 + 모노 헤더 + 판정문 +
/// 메뉴/시간 + 재료 이름 블록. 발주하면 START 스탬프가 쾅 찍히고 사용 재료가 비워진다(Fire the Ticket).
///
/// **발주 CTA는 이 종이 안에 없다 — 화면 하단에 도킹된다**(§14.4, `RecipeMemoCarousel.deckCTA`).
/// 티켓 안에 두었을 땐 확정 액션 하나가 세 가지를 한꺼번에 어겼다: ① 카드 높이가 밖에서 고정돼 있어
/// 마지막 잉크와 CTA 사이 빈 종이가 레시피마다 다르게 벌어졌고 ② 정본 `PaperButton`을 우회해 손으로
/// 조립한 유일한 1차 CTA라 재질이 앱 안에서 홀로 달랐으며 ③ 확정 액션이 화면 바닥에 있다는 앱의
/// 규칙(조리 커버의 "Finish cooking")에서 이 화면만 빠져 있었다. **되돌리지 말 것.**
/// 티켓에 남는 것은 판단 근거와 **발주 후 payoff**(비우기 판정문)뿐이다.
///
/// 티켓은 "무엇을 만들지"의 단서까지만 준다 — 조리 방법(단계)은 티켓에 싣지 않고 조리 화면의
/// 영상 링크가 맡는다. 카드에 남는 건 판단에 필요한 것뿐: 왜 이 티켓인가(판정문), 무엇인가(메뉴·시간),
/// 무엇이 빠지나(Short), 그리고 임박 재료의 D-day.
///
/// **세로 간격은 세 축이다**(§3.5·§4.1) — 쌍 `s0`(메뉴명↔조리시간처럼 행간의 연장) · 묶음 `s2`
/// (이름표↔목록, 목록 안 행) · 섹션 `s4`(절취선으로 갈리는 덩어리 사이). 옛 코드는 셋 다 `s3`(12)
/// 하나였고, 그래서 "메뉴명과 조리시간 사이"가 "판정문과 메뉴 블록 사이"와 똑같이 벌어져 카드 안
/// 위계가 통째로 사라져 있었다. 새 줄을 넣을 때 이 셋 중 어느 축인지 먼저 정할 것.
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
    /// 발주 트리거 — 덱이 값을 올리면 `fire()`가 돈다. **이 카드로 들어오는 발주 경로는 이것 하나뿐**이다:
    /// 오른쪽 플릭도, 화면 하단 도킹 "Cook this" 버튼도 덱이 여기로 모아서 올린다(`RecipeMemoCarousel`).
    /// 발주 상태(슬램·줄긋기·이중 발주 가드)를 카드가 소유하므로 부모가 `fired`를 직접 켜지 않는다 —
    /// 두 입력이 각자 상태를 켜면 이중 발주 가드가 두 곳으로 갈린다.
    var fireTrigger: Int = 0
    /// Short 행의 담기 진입 — 부족 재료를 **덱에 넘기기만** 한다. 무엇을 담을지 고르는 팝업부터
    /// 담김 알림·이동 질문까지가 덱 위에 뜨는 흐름이라, 카드가 직접 담으면 그 흐름을 카드 안
    /// `middleScroll`(내부 세로 ScrollView + 톱니 클리핑)에 가둬야 한다.
    /// 레시피 항목을 그대로 넘긴다(표시명이 아니라) — `ref`가 있어야 장보기 표기를 정확히 풀 수 있다.
    /// nil이면 알약 자체를 그리지 않는다(스토어에 닿지 못하는 프리뷰·공유 렌더에서 위약 버튼 금지).
    var onPickMissing: (([Recipe.Item]) -> Void)?
    /// 오늘 요리 핀(48차 E6) — used 줄 중 핀 재료에 압정 마크를 찍는 판정 집합. 정본은
    /// `FridgeStore.pinnedIDs`지만 이 카드는 store에 닿지 않으므로(프리뷰·공유 렌더 규약) 덱이
    /// 스냅샷으로 내려준다 — `Result`에는 rank 시점 핀 정보가 실리지 않아 파라미터가 맞다.
    /// 기본 빈 집합 = 마크 없음(기존 호출부 무수정).
    var pinnedIDs: Set<UUID> = []

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fired = false
    @State private var middleScrolls = false   // 중간 섹션이 실제로 스크롤되는가(안전망 발동 여부)
    /// 중간 섹션의 콘텐츠 높이 — 종이가 내용만큼만 길어지게 하는 캡(46차, `middleScroll` 주석).
    @State private var contentHeight: CGFloat = 0

    /// 임박(urgent+soon) 재료 수 — 안티-웨이스트 증명.
    private var rescuedCount: Int { result.used.filter { $0.freshness != .fresh }.count }

    /// 카드 1순위 판정문 — 왜 이 티켓이 추천됐나(랭킹 근거를 사람 말로).
    private var verdictKicker: Text {
        if result.urgentUsedCount > 0 { return Text("Saves \(result.urgentUsedCount) expiring today") }
        // 동사는 Saves 하나·상함은 turn 하나다(42차) — 조건 구분은 색(urgentDark/soonDark)이 이미
        // 말하고 있어 낱말까지 갈리면 없는 의미 차이를 찾게 된다. ko는 처음부터 '구출' 하나였다.
        if rescuedCount > 0 { return Text("Saves \(rescuedCount) before they turn") }
        return Text("Use these while fresh")
    }
    private var verdictColor: Color {
        result.urgentUsedCount > 0 ? ReffiColor.urgentDark
            : rescuedCount > 0 ? ReffiColor.soonDark : ReffiColor.freshDark
    }

    /// 컨테이너는 항상 같은 뷰 트리(단일 정체성) — headerOnly는 내부 콘텐츠·모디파이어 값만 바꾼다.
    /// 덱 회전으로 headerOnly가 토글돼도(승격·강등) 카드가 통째로 교체되지 않아 번쩍임이 없다.
    var body: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s4) {   // 섹션 축(위 독스트링의 세 축 중 가장 넓은 것)
            header
            if headerOnly {
                Spacer(minLength: 0)
            } else {
                // 유연한 자식은 **`middleScroll` 하나뿐이다.** 옛 코드는 여기에 `Spacer`를 하나 더
                // 두어 남는 높이를 둘이 나눠 가졌는데, 유연 자식이 둘이면 어느 쪽이 얼마를 받는지가
                // 콘텐츠 길이에 따라 갈려 같은 자리의 간격이 티켓마다 달라진다. 하나로 줄이면
                // 남는 높이는 전부 스크롤 영역이 먹고, 발주 밴드는 언제나 종이 바닥에 붙는다.
                middleScroll
                // 미발주 상태에서 아래에 남는 것은 **인쇄되지 않은 영수증 꼬리**다 — 그 자리에
                // 다시 버튼을 세우지 말 것(위 독스트링). 발주 후에만 payoff 한 줄이 바닥에 찍힌다.
                if fired { firedBand }
            }
        }
        .padding(.horizontal, ReffiSpace.s5)
        // 상·하 **같은** 광학 보정 — `ReceiptShape`는 위아래가 다 톱니라 보정 근거가 양쪽에 똑같이
        // 성립한다(형제 표면인 조리 티켓·공유 카드는 처음부터 `.vertical`로 양쪽 26이었다).
        // 위만 `ticketTop`, 아래는 `s5`로 두면 2pt 어긋난 채 아래 톱니만 조금 더 가까워 보인다.
        .padding(.vertical, ReffiSpace.ticketTop)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(ReceiptShape(tooth: ReffiTooth.ticket).fill(ReffiColor.paper))
        .overlay { if !headerOnly { ReceiptShape(tooth: ReffiTooth.ticket).stroke(ReffiColor.paperEdge, lineWidth: 1) } }
        .overlay { if fired { slamStamp } }
        .compositingGroup()   // 그림자 재합성을 1패스로 — PaperGrain(.overlay)도 이 경계에 갇힌다.
        // 그림자는 값만 분기, 체인(2패스)은 고정 — 뷰 정체성 유지.
        // 풀 렌더면 reffiShadow1(§6.2)과 동일 값, headerOnly면 가벼운 단일 패스(2패스째 투명).
        .shadow(color: ReffiColor.shadowTint.opacity(headerOnly ? 0.06 : 0.10),
                radius: headerOnly ? 4 : 1.5, x: 0, y: headerOnly ? 2 : 1)
        .shadow(color: ReffiColor.shadowTint.opacity(headerOnly ? 0 : 0.05),
                radius: 10, x: 0, y: 8)
        .onChange(of: fireTrigger) { _, _ in fire() }
    }

    /// 중간 섹션 — 크라운 헤더와 (발주 후) 판정문 밴드는 고정, 판정문~'ON THE TICKET'(+ Short 문구)만
    /// 내부 스크롤(§13.6). 카드 안에서 **유일하게 유연한 자식**이라 남는 종이는 전부 여기로 간다.
    /// 단계 미리보기를 걷어낸 뒤로는 기본 텍스트 크기에서 항상 다 들어간다 — 스크롤·페이드는
    /// 극단 Dynamic Type(접근성 크기)에서만 발동하는 **오버플로 안전망**으로만 남긴다.
    /// 지우면 큰 글자에서 마지막 재료 줄과 Short 문구가 잘려 판단 근거가 사라진다.
    private var middleScroll: some View {
        // **스크롤 뷰를 자기 콘텐츠 높이로 묶는다**(46차). ScrollView는 제안된 높이를 통째로 먹는
        // 유연 자식이라, 카드 안 유일한 유연 자식인 이것 하나만으로 종이가 늘 영역을 가득 채워
        // 짧은 티켓 아래에 인쇄되지 않은 빈 종이가 100pt 넘게 남았다(오너 지적). 캡을 걸면 종이가
        // 내용만큼만 길어지고, 내용이 영역보다 길 때만 `min`이 영역 쪽을 골라 스크롤이 산다 —
        // 영수증은 원래 길이가 제각각이다.
        //
        // **`ViewThatFits`로 풀지 마라.** 후보 서브트리를 둘 다 세워 측정하므로 접근성 트리에
        // 같은 요소가 두 벌 남는다(VoiceOver가 메뉴명·재료를 두 번 읽고, 단일 매칭을 기대하는
        // UI 테스트 7건이 "Multiple matching elements"로 무너졌다 — 실측).
        //
        // 세로 스크롤에서 `contentSize.height`는 뷰포트와 무관하므로 캡이 자기 입력을 바꾸지
        // 않는다(피드백 루프 없음).
        return ScrollView(.vertical, showsIndicators: false) { middleContent }
        .scrollBounceBehavior(.basedOnSize)
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentSize.height } action: { _, h in
            contentHeight = h
        }
        .frame(maxHeight: contentHeight > 0 ? contentHeight : .infinity)
        .onScrollGeometryChange(for: Bool.self) { g in
            g.contentSize.height > g.containerSize.height + 1
        } action: { _, scrolls in
            middleScrolls = scrolls
        }
        // 스크롤이 실제로 발동할 때만 하단 페이드 — 경계에서 줄이 '뚝' 잘린 게 아니라
        // 더 있음을 읽히게 한다.
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

    @ViewBuilder private var middleContent: some View {
        let r = result.recipe
            VStack(alignment: .leading, spacing: ReffiSpace.s4) {   // 섹션 축 — 절취선이 가르는 덩어리 사이
                ReffiRule(.ticket)

                // 판정문 키커와 메뉴 블록은 **한 덩어리**다(키커가 그 아래 메뉴를 설명한다) —
                // 섹션 축(s4)이 아니라 묶음 축(s2)으로 묶는다. 여기서 s4를 쓰면 키커가 어느 쪽
                // 덩어리에 속하는지 알 수 없는 고아 줄이 된다.
                VStack(alignment: .leading, spacing: ReffiSpace.s2) {
                    // 판정문 키커 — 이 티켓이 비우는 임박 재료(미션 페이로드).
                    // role은 metaText 축으로 흡수한다: 신선도 색(verdictColor)이 이미 강조를 맡고 있어
                    // 13pt에서 SemiBold/Medium 한 단을 더 두면 계층이 아니라 잡음으로 읽혔다.
                    verdictKicker
                        .reffiType(.metaText).foregroundStyle(verdictColor)

                    // 메뉴명 + 시간 + 요리 아이콘. 아이콘은 **오른쪽 여백에 얹힌 그림**이고 글이 주인공이다 —
                    // 이름 위에 한 줄로 올리면 티켓 상단이 그림에 밀려 "주문서"가 아니라 메뉴판이 된다.
                    // 배경 타일 없이 종이 위에 그대로 둔다(§13.3 — 일러스트는 색면 박스에 담지 않는다).
                    HStack(alignment: .top, spacing: ReffiSpace.s3) {
                        // 메뉴명↔조리시간은 §3.5가 말하는 **두 줄 텍스트 쌍**이다 — 행간의 연장(s0)이지
                        // 요소 간격이 아니다. 옛 s3(12)은 이 카드의 섹션 간격과 같은 값이라, 한 이름과 그
                        // 이름의 메타가 서로 다른 덩어리처럼 떨어져 보였다(같은 파일의 `shortPanel`은
                        // 처음부터 같은 성격의 쌍을 s0으로 붙여 두어 한 파일 안에서 규칙이 갈려 있었다).
                        VStack(alignment: .leading, spacing: ReffiSpace.s0) {
                            Text(verbatim: r.displayName)
                                .reffiType(.menuName).foregroundStyle(ReffiColor.ink)
                                .lineLimit(2).minimumScaleFactor(ReffiShrink.chrome).fixedSize(horizontal: false, vertical: true)
                                // UI 테스트 훅 — 앞 티켓의 메뉴명을 이름 하드코딩 없이 집어 조리 화면과 대조한다
                                // (오른쪽 플릭이 덱을 넘기지 않고 **1번** 티켓을 발주했다는 증거). 라벨은 그대로다.
                                .accessibilityIdentifier("ticket.menuName")
                            HStack(spacing: ReffiSpace.s0) {
                                ReffiIcon.time.reffi(13).foregroundStyle(ReffiColor.ink2)
                                // 분모 병기(48차 E6) — `Result.total`(비상비 재료 수)은 계산만 되고
                                // 뷰 소비자가 없던 값이다. used 수만 말하면 "3 to use"가 3/4 티켓과
                                // 3/9 티켓에서 같은 말이 된다 — 분모가 있어야 "얼마나 갖춰졌나"가
                                // 판단 근거로 선다. 신규 행이 아니라 기존 메타 줄의 확장이다(46차
                                // 절제 방향과의 타협점 — xcstrings 키도 함께 교체됐다).
                                Text("\(r.minutes) min · \(result.used.count)/\(result.total) to use")
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
                }

                ReffiRule(.ticket)

                // 이름표와 그 목록도 **한 덩어리**다 — 묶음 축(s2). 이름표는 자기가 읽히려고 있는 게
                // 아니라 아래 목록을 여는 표지라, 목록에서 떨어지면 가리키는 대상을 잃는다.
                VStack(alignment: .leading, spacing: ReffiSpace.s2) {
                    // 티켓 위 인쇄 크롬은 크라운 행과 **같은 모노 role**이다 — 색(ink vs ink2)으로만 갈린다.
                    // 형제 라벨(ORDER · REFFI KITCHEN · ORDER · FIRED)과 같이 verbatim: 주방 티켓의
                    // 인쇄 문자열이라 번역하지 않는다.
                    Text(verbatim: "ON THE TICKET")
                        .reffiType(.monoTicketLabel).foregroundStyle(ReffiColor.ink2)   // §2.6 — 소형 텍스트는 불투명 토큰으로

                    // 이름 블록은 최대 5줄 미리보기(+N more) — 소비는 result.used 전체를 쓰므로 표시만 축약.
                    VStack(alignment: .leading, spacing: ReffiSpace.s2) {
                        ForEach(result.used.prefix(5)) { ing in ticketLine(ing, done: fired) }
                        if result.used.count > 5 {
                            Text("+\(result.used.count - 5) more")
                                .reffiType(.metaText)
                                .foregroundStyle(ReffiColor.ink2)
                        }
                    }
                }

                if !result.missing.isEmpty {
                    // 구제 고지 ↔ Short 패널은 **한 덩어리**(묶음 축 s2) — 고지가 바로 아래
                    // 부족 목록의 이유를 설명한다. rescued는 엔진 계약상 missing≥3의 구제
                    // 통과에서만 참이라 고지가 Short 없이 홀로 서는 상태는 없다.
                    VStack(alignment: .leading, spacing: ReffiSpace.s2) {
                        if result.rescued {
                            // 구제 고지(48차 E6) — missing≥3 문턱을 구제 조건으로 넘어온 티켓임을
                            // 정직하게 말한다(RecipeRadar match_any → "partial results" 배너 패턴의
                            // 이식). 표시 전용 — 랭킹·문턱은 이 값을 다시 읽지 않는다.
                            // 카피는 구제 조건 ①(비우는 재료 ≥ 사는 재료)을 그대로 말한다 —
                            // 첫 카피("맞는 티켓이 적어 범위를 넓혔어요")는 엔진이 평가한 적 없는
                            // 희소성을 주장해 잘 채워진 냉장고의 1번 티켓에서도 떴다(적대 검증
                            // 실측: 후보 27장 수용 중 2장이 구제 — 희소가 아니라 풍요였다).
                            Text("Clears more than it asks you to buy.")
                                .reffiType(.metaText)
                                .foregroundStyle(ReffiColor.ink2)
                        }
                        shortLine
                    }
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
                .lineLimit(1).minimumScaleFactor(ReffiShrink.fit)
            Spacer(minLength: ReffiSpace.s2)
            // 번호도 같은 모노 role·크기 — 옛 GSF 14는 크롬 안에서 홀로 다른 서체였다.
            Text(verbatim: String(format: "#%02d", number))
                .reffiType(.monoTicketLabel).foregroundStyle(ReffiColor.ink2)   // §2.6 — 소형 텍스트 대비
                .lineLimit(1)
        }
        .opacity(peek ? 0 : 1)   // 뒤 티켓 노출 띠는 빈 종이 — 톱니 골에 반쪽 글리프가 새지 않게
    }

    /// 발주 **후** 비우기 판정문(payoff). 미발주 CTA는 이 카드에 없다 — 덱의 하단 도킹 바
    /// (`RecipeMemoCarousel.deckCTA`)가 맡는다. 여기 파랑 면을 손으로 다시 세우면 정본
    /// `PaperButton`(세로 패딩 s4 + `compositingGroup` + `reffiShadow1` + 그레인 시드 +11)과
    /// 재질이 갈려, 앱에서 이 한 곳만 다른 1차 CTA가 된다(감사 R4-2와 같은 실수).
    ///
    /// 이 밴드는 발주 후에만 뷰 트리에 들어오므로, 유연 자식(`middleScroll`)이 남는 높이를 전부
    /// 먹고 밴드는 언제나 종이 바닥에 붙는다.
    private var firedBand: some View {
        HStack(spacing: ReffiSpace.s1) {   // 아이콘-텍스트 축(옛 리터럴 6 = 이 토큰)
            ReffiIcon.ate.reffi(15, .fill).foregroundStyle(ReffiColor.freshDark)
            (result.urgentUsedCount > 0
                ? Text("Saved \(result.used.count) · \(result.urgentUsedCount) today")
                : Text("Saved \(result.used.count)"))
                .reffiType(.pillLabel)
                .foregroundStyle(ReffiColor.ink)
        }
        .frame(maxWidth: .infinity)
    }

    private func fire() {
        guard !fired else { return }
        withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) { fired = true }
        onFire()
    }

    /// 부족 재료 표시 — `onPickMissing`이 있으면 **전폭 패널 버튼**(아래 `shortPanel`, 2026-08 32차
    /// option C), 없으면(미리보기·공유 카드처럼 store에 닿지 못하는 렌더) 사실만 말하는 텍스트 한
    /// 줄로 그친다 — 뷰가 게이팅 없이 store로 보내는 다른 탭 규약과 달리, 여기는 **누를 곳이 아예
    /// 없는 렌더**라 위약 버튼을 세우지 않는다(`add(name:...)` 주석의 위약 버튼 금지와 같은 원칙).
    ///
    /// 여기까지가 '이 티켓을 못 하는 이유'인데, 그 다음 행동(장보기 메모에 적기)은 화면 두 개 건너에
    /// 있었다. 패널은 그 왕복을 없앤다 — 다만 **무엇을 담을지는 고르게 한다**(2026-08 owner request):
    /// 부족 재료 중 이미 집에 있는 것이 섞이면 전량 담기는 목록에 없는 줄을 얹는다. 고르는 UI는
    /// 티켓 위가 아니라 **덱 위 팝업**에 산다 — 티켓은 단서 카드라는 규율(§13.5)은 그대로다.
    ///
    /// 표기는 레시피 원문 그대로다("소고기 (얇게 썬 것)") — 여기선 레시피를 읽는 자리라 괄호 주석이
    /// 정보다. 담을 때만 `toBuyEntry`가 이름을 장보기용으로 정리한다.
    ///
    /// **제스처 우선순위** — 카드 본문엔 탭 제스처가 없고 플릭은 덱의 `frontDrag`(`.gesture`,
    /// minimumDistance 14)라, 패널의 탭은 버튼이 가져간다. 발주 CTA가 종이 밖으로 나간 뒤로는
    /// **이 패널이 티켓 종이 위에 남은 유일한 탭 표면**이다 — 카드 안에 새 버튼을 세우기 전에
    /// 이 우선순위가 여전히 성립하는지 먼저 볼 것.
    /// 패널 위에서 시작한 **드래그**는 그대로 덱으로 흘러 플릭이 산다.
    @ViewBuilder private var shortLine: some View {
        if let onPickMissing {
            shortPanel(onPickMissing)
        } else {
            Text("Short: \(result.missing.map(\.displayName).joined(separator: ", "))")
                .reffiType(.metaText)
                .foregroundStyle(ReffiColor.ink2).lineLimit(2)
                .padding(.top, ReffiSpace.s0)
        }
    }

    /// 부족 재료 패널 — 하나의 **전폭 버튼**(owner 디자인 리뷰 "option C", 2026-08 32차). 예전엔 회색
    /// "Short: …" 텍스트 옆에 작은 파란 알약이 따로 붙어 있었는데, 알약이 본문 속에서 시각적으로
    /// 작아 discoverability 리스크로 지적됐다(부족 재료를 읽고도 담기로 잘 이어지지 않았다) — 패널
    /// 전체를 탭 표면으로 만들면 "부족하다"는 사실 자체가 곧 행동 진입점이 된다.
    ///
    /// **면은 톱니가 아니라 `PaperRect`다** — 이 카드(`OrderMemoCard`) 자체가 이미 바깥 톱니
    /// (`ReceiptShape(tooth: .ticket)`)이고, 안쪽 행 구분은 톱니가 아니라 절취선(`ReffiRule(.ticket)`,
    /// §13.1)이 맡는다. 카드 속에 중첩된 다른 행동 표면(검색 시트의 직접 입력 담기 행 등)도 전부
    /// `PaperRect`를 쓴다 — 톱니를 한 번 더 중첩하면 "오려 낸 종이 안에 또 오려 낸 종이"로 겹쳐
    /// 읽혀 이 카드의 기존 문법과 어긋난다(레퍼런스 목업의 톱니 스트립 대신 이 판단을 택했다).
    ///
    /// **discoverability 완화**(option C가 안고 가는 리스크에 대한 대응) — 패널 전체가 버튼
    /// 트레잇 + `.paperPress` 눌림을 갖고, 우측 ＋ 블롭(`PaperBlob(sides: 9)` — `PaperIconLabel`의
    /// 블롭과 같은 셰이프, §13.5)이 늘 보이는 행동 아이콘 역할을 한다. 접근성 라벨도 "N개 부족"
    /// 사실에서 끝나지 않고 "Add to list"까지 붙여 행동을 스스로 말한다.
    ///
    /// 탭하면 **25차 3단 팝업**(고르기 → 알림 → 이동)이 그대로 열린다 — 그 흐름과 발주 후 동작은
    /// 이 라운드에서 손대지 않는다. 라벨·면 색은 To buy 계열(§13.5, `blueLight`/`blueDark`)이라
    /// "이 카드에서 유일하게 다른 화면으로 이어지는 문"임을 색으로 먼저 말한다.
    private func shortPanel(_ pick: @escaping ([Recipe.Item]) -> Void) -> some View {
        let count = result.missing.count
        let names = result.missing.map(\.displayName).joined(separator: ", ")
        return Button {
            pick(result.missing)
        } label: {
            HStack(spacing: ReffiSpace.s3) {
                VStack(alignment: .leading, spacing: ReffiSpace.s0) {
                    Text("^[\(count) ingredient](inflect: true) short")
                        .reffiType(.metaText)
                        .foregroundStyle(ReffiColor.blueDark)
                        .lineLimit(1)
                    // 표기는 `displayName`(=`toBuyEntry`와 같은 해석)이라 카드 위 재료 이름 블록과
                    // 다른 규칙을 쓰지 않는다 — 여기서 새로 사전을 조회하지 않는다.
                    Text(verbatim: names)
                        .reffiType(.metaText)
                        .foregroundStyle(ReffiColor.ink2)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ZStack {
                    let blob = PaperBlob(sides: 9, seed: number &+ 3)
                    blob.fill(ReffiColor.blueDark)
                    // `*Dark` 면 위 콘텐츠는 `onInk`다(42차) — blueDark는 다크에서 L .76으로 밝게
                    // 뒤집혀 고정 흰색(`onAccent`)이 2.13:1로 무너진다(라이트는 흰색 그대로 9.18).
                    ReffiIcon.add.reffi(13, .bold).foregroundStyle(ReffiColor.onInk)
                }
                .frame(width: 30, height: 30)
            }
            .padding(.horizontal, ReffiSpace.s3)
            .padding(.vertical, ReffiSpace.s2)
            .frame(minHeight: ReffiChrome.tapMin, alignment: .leading)   // §7.3 터치 타깃
            .background {
                let shape = PaperRect(cornerRadius: ReffiRadius.md, seed: number &+ 7)
                shape.fill(ReffiColor.blueLight)
                    .paperEdge(shape, tint: ReffiColor.paperEdgeAccent(ReffiColor.blueDark))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel(Text("^[\(count) ingredient](inflect: true) short. Add to list."))
        .accessibilityValue(Text(verbatim: names))
        .accessibilityHint(Text("Opens a list of the missing ingredients to pick from"))
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
            // 도장은 슬램이다(§7.5·42차) — 자기 커브를 트랜지션에 달아 fire()의 pop 트랜잭션과
            // 분리한다(온보딩 Start·히어로 stamp와 같은 물리). 카드 본문 리플로우는 pop 그대로.
            .transition(.scale(scale: 1.5).combined(with: .opacity)
                .animation(ReffiMotion.gated(ReffiMotion.slam, reduce: reduceMotion)))
            .accessibilityHidden(true)
    }

    /// 티켓 한 줄 — 이름 + (임박할 때만) D-day 칩. 체크박스는 없다: 티켓은 체크하며 따라가는 목록이 아니라
    /// "무엇이 들어가나"를 한눈에 읽는 단서 블록이다. 발주하면 줄이 그어져 비웠음이 남는다(payoff).
    ///
    /// D-day 칩의 면은 §13.1 종이컷 8각형(`PaperCutRect`)이다 — 행동 표면에 완벽한 캡슐을 두지 않는다.
    /// D-day는 `.soon`·`.urgent`에만 붙인다 — 신선도는 앱의 본체지만, 아직 여유 있는 재료의 카운트다운은
    /// 노이즈일 뿐이라 "지금 급한 것"만 눈에 띄게 남긴다(색+텍스트 동반, §1).
    private func ticketLine(_ ing: Ingredient, done: Bool) -> some View {
        // 대체 투입은 이름 뒤 괄호로 그 자리에서 말한다(45차) — 대체 줄은 missing이 아니라 Short에도
        // 안 뜨므로, 여기서 침묵하면 발주가 지울 재고를 화면 어디도 예고하지 않게 된다.
        let name = result.substituted.first { $0.with.id == ing.id }
            .map { Ingredient.substitutionLabel(stockName: ing.displayName, lineName: $0.item.displayName) }
            ?? ing.displayName
        return HStack(spacing: ReffiSpace.s2) {
            // 핀 마크(48차 E6) — "이 티켓이 왜 위에 있나"의 최소 설명. 핀 배지(홈 좌상단 압정,
            // `IngredientBadge`)와 같은 글리프·크기(12pt)·잉크색이고, 낭독도 같은 규칙(상태 접두 —
            // 이름보다 먼저 들려야 구분이 선다)이다. 색 없는 잉크인 이유: 이 줄의 색 축은 이미
            // D-day 칩(신선도)이 쓰고 있어, 핀까지 색을 들면 두 신호가 한 줄에서 다툰다.
            if pinnedIDs.contains(ing.id) {
                ReffiIcon.pin.reffi(12, .fill)
                    .foregroundStyle(done ? ReffiColor.muted : ReffiColor.ink)
                    .accessibilityLabel(Text("Pinned"))
            }
            Text(verbatim: name)
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
                    .padding(.vertical, ReffiSpace.s0)
                    .background(ing.freshness.light, in: PaperCutRect(seed: 2))   // §13.1 종이컷 8각형(캡슐 금지)
                    // 보이는 값은 축약(3d)이라 소리로는 뜻이 서지 않는다 — 냉장고 도장·간편 행·재료 뱃지와
                    // 같은 표기/문구 한 쌍(`Ingredient.dDayAccessibilityText`)을 이 칩도 본다.
                    .accessibilityLabel(ing.dDayAccessibilityText)
            }
        }
    }
}

