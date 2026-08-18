import SwiftUI
import PhosphorSwift

/// 냉장고 화면의 상단 탭 — 한 화면에 세 목적이 산다: 지금 있는 것(In stock) · 살 것(To buy) · 기록(History).
/// rawValue는 안정 키다(런치 인자·테스트가 문자열로 잡는 축이 아니라, 순서 변경에도 살아남는 식별자).
enum FridgeTab: String, CaseIterable, Identifiable {
    case stock     // 재고 영수증 스택 — 냉장고의 기본 화면
    case toBuy     // 장보기 메모(구 To buy 커버)
    case history   // 먹음·버림 정산과 타임라인(구 History 커버 = 무낭비 리포트)

    var id: String { rawValue }

    /// 표시 라벨 — 짧게. 세 알약이 한 줄에 서므로 두 단어를 넘지 않는다.
    var label: LocalizedStringKey {
        switch self {
        case .stock:   "In stock"
        case .toBuy:   "To buy"
        case .history: "History"
        }
    }

    /// 글리프 — 전부 `ReffiIcon` 정본에서 가져온다(§5 단일 진입점).
    /// `stock`=영수증 스택(이 패인이 실제로 보여 주는 것) · `toBuy`=영수증(장보기 메모의 종이) ·
    /// `history`=리포트 막대(이 패인의 첫 카드가 30일 정산서다 — 걷어낸 헤더 리포트 버튼의 기호를 잇는다).
    var icon: Ph {
        switch self {
        case .stock:   ReffiIcon.stackView
        case .toBuy:   ReffiIcon.receipt
        case .history: ReffiIcon.report
        }
    }

    /// 종이 셰이프 시드 — 알약마다 손으로 오린 윤곽이 달라야 한다(§13.1). 같은 화면의 다른 종이 면
    /// (빈 상태 3 · 정렬 칩 5 · 보기 토글 6 · All 칩 9 · 카테고리 칩 20+)과 겹치지 않는 대역.
    var seed: Int {
        switch self {
        case .stock:   30
        case .toBuy:   31
        case .history: 32
        }
    }
}

#if DEBUG
extension FridgeTab {
    /// 런치 인자 → 진입 탭(QA·스크린샷 자동화). 뷰에서 분기를 늘리는 대신 순수 함수로 떼어
    /// 유닛 테스트로 고정한다(`MainView.tiltLabLaunchConfig` 선례).
    ///
    /// 옛 `-toBuy`/`-toBuy.search`/`-showHistory`는 풀스크린 커버를 열던 인자였고, 탭 구조에서는
    /// **같은 목적지의 탭**으로 착지한다(RUN.md QA 절과 함께 갱신). `-toBuy.search`의 검색 시트
    /// 자동 오픈은 `ShoppingListContent`가 계속 맡는다 — 인자 해석과 시트 표시는 다른 일이다.
    /// 둘 다 주어지면 To buy가 이긴다(검색 시트까지 여는 쪽이 더 구체적인 지시다).
    static func initial(from arguments: [String]) -> FridgeTab {
        if arguments.contains("-toBuy") || arguments.contains("-toBuy.search") { return .toBuy }
        if arguments.contains("-showHistory") { return .history }
        return .stock
    }
}
#endif

/// 상단 탭 행 — 세 개의 종이 알약(아이콘 + 라벨)이 균등 폭으로 선다.
///
/// **선택은 잉크 솔리드다.** 바로 아래 카테고리 필터 칩 행은 "선택 표시가 콘텐츠보다 가벼워야 한다"는
/// 규칙을 지켜 굵은 잉크 단면만 쓰는데(§13.5), 그 규칙은 *필터 상태*가 영수증 스택보다 무거워지는 걸
/// 막으려는 것이다. 탭은 필터가 아니라 **이 화면이 지금 무엇인가**를 정하는 내비게이션이라, 화면에서
/// 가장 확실한 신호여야 한다. 두 행의 무게가 갈리는 것이 오히려 위계를 세운다(내비 > 필터).
///
/// 셰이프는 `PaperRect(cornerRadius: .pill)` — pill 스케일은 `PaperCutRect`(모서리 잘린 8각)으로
/// 라우팅되므로 "완벽한 캡슐 금지"(§13.1)를 지키면서 알약으로 읽힌다. To buy 목록의 Add/Skip 알약과
/// 같은 문법이다.
struct FridgeTabBar: View {
    @Binding var selection: FridgeTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: ReffiSpace.s2) {
            ForEach(FridgeTab.allCases) { pill($0) }
        }
        // 세 알약을 하나의 탭 컨테이너로 묶는다 — 보조기술이 "탭 하나"가 아니라 "탭들"로 읽게.
        .accessibilityElement(children: .contain)
        // 탭 행은 콘텐츠가 아니라 크롬이다 — 접근성 글자에서도 accessibility1까지만 따라 키운다.
        // 3등분 고정 폭에서 그 위 단계는 축소(0.75)로도 못 받아 목적지 이름이 잘리는데, 화면의
        // 유일한 IA 표시가 이름을 잃는 것보다 크기를 멈추는 쪽이 낫다(시스템 탭 바와 같은 태도).
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private func pill(_ tab: FridgeTab) -> some View {
        let on = selection == tab
        return Button {
            guard !on else { return }   // 같은 탭 재탭은 무동작(패인 상태를 흔들지 않는다)
            withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                selection = tab
            }
        } label: {
            HStack(spacing: ReffiSpace.s2) {
                tab.icon.reffi(14, .bold)
                Text(tab.label)
                    .reffiType(.pillLabel)
                    .lineLimit(1)
                    // 라벨은 잘리면 목적지 이름이 사라진다 — 3등분 폭에서 축소를 먼저 쓴다.
                    .minimumScaleFactor(0.75)
            }
            // 선택 면은 잉크(다크에선 크림)라 글자는 캔버스 색으로 뒤집는다(§2.6).
            .foregroundStyle(on ? ReffiColor.canvas : ReffiColor.ink)
            .padding(.horizontal, ReffiSpace.s3)
            .padding(.vertical, ReffiSpace.s2)
            .frame(maxWidth: .infinity, minHeight: 44)   // 균등 3등분 + §7.3 터치 타깃
            .background { surface(on: on, seed: tab.seed) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel(Text(tab.label))
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private func surface(on: Bool, seed: Int) -> some View {
        let s = PaperRect(cornerRadius: ReffiRadius.pill, seed: seed)
        if on {
            s.fill(ReffiColor.ink)
                .overlay(PaperGrain(seed: UInt64(seed) &+ 11, strength: 0.9).clipShape(s))
                .paperEdge(s, tint: ReffiColor.paperEdgeOnFill, width: 1)
                .compositingGroup()
                .reffiShadow1()   // 선택 알약만 떠 있다(§6.2 예외 — 행동 표면)
        } else {
            s.fill(ReffiColor.paper).paperEdge(s)
        }
    }
}
