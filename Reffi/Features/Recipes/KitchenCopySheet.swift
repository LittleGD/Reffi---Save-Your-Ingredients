import SwiftUI

/// 주방 전표 시트(39차) — 티켓의 조용한 "See the cooking details?" 링크가 여는 **옵트인** 조리
/// 단계 목록. 33c8861("조리법은 영상이 맡는다")의 오너 테제를 **부분적으로** 되돌린다 — 하지만
/// 뒤집는 방식이 다르다: 티켓 본문엔 여전히 단계 텍스트가 한 글자도 없고(§CookingStepsView가
/// 옛 기대치 캡션을 없앤 그대로), 영상 CTA는 이 시트를 열지 않아도 항상
/// 1차 자리를 지킨다. 이 시트는 **점진적 공개**(progressive disclosure)다 — 원하는 사람만
/// 한 겹 더 들어가 본다. 단계가 없는 레시피(대부분의 커스텀 레시피)는 링크 자체가 안 서므로
/// 이 시트에 도달할 길이 없다.
///
/// 시트 컨테이너는 시스템 `.sheet`(이 파일과 같은 화면의 `finishSheet`와 같은 문법 — 하단에서
/// 올라오는 시트는 이미 이 앱의 정본 패턴이다)를 그대로 쓰고, **내용**만 영수증 어휘로 채운다 —
/// `ReceiptShape`(톱니) + 모노 크라운 헤더 + 절취선 + 종이 체크박스. `PaperChecklistDialog`처럼
/// 완전히 커스텀 오버레이를 새로 짜지 않은 것은 이 화면이 이미 시스템 시트 하나(`finishSheet`)를
/// 정상적으로 쓰고 있어서다 — 같은 화면에 "시트 두 문법"을 두지 않는다.
struct KitchenCopySheet: View {
    let recipeName: String
    let steps: [String]
    let completedSteps: Set<Int>
    let onToggle: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ReffiRule(.ticket)
            list
        }
        .padding(ReffiSpace.s5)
        .background {
            let shape = ReceiptShape(tooth: ReffiTooth.card)
            shape.fill(ReffiColor.paper).paperEdge(shape)
        }
        .reffiShadowCard()
        .padding(.horizontal, ReffiSpace.s4)
        .padding(.top, ReffiSpace.s4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ReffiColor.canvas.ignoresSafeArea())
    }

    /// 크라운 — 오더/조리 티켓의 "ORDER · FIRED"와 같은 모노 문법. **크롬과 데이터를 가른다**(42차):
    /// `monoTicketLabel`(올캡·자간 2.5)은 §3.5가 비번역 라틴 크롬 전용으로 못 박은 role이라,
    /// 번역되는 레시피명을 같은 문자열에 이어 붙이면 한국어에서 `.uppercased()`가 no-op이 되고
    /// 13pt 한글에 em의 19% 자간이 걸려 낱글자로 흩어진다("김 치 찌 개"). 크라운 조각만 그 role에
    /// 남기고 레시피명은 같은 13pt 밴드의 `metaText`(자간 0)로 — 티켓 표면의 "한 크기·다른 무게"
    /// 문법 그대로다. 레시피명 자체는 데이터라 verbatim(§i18n, `cook.recipeName`과 같은 규칙).
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(alignment: .firstTextBaseline, spacing: ReffiSpace.s1) {
                Text(verbatim: "KITCHEN COPY ·")
                    .reffiType(.monoTicketLabel).foregroundStyle(ReffiColor.ink2)
                Text(verbatim: recipeName)
                    .reffiType(.metaText).foregroundStyle(ReffiColor.ink2)
            }
            .lineLimit(1)
            .minimumScaleFactor(ReffiShrink.chrome)
            Spacer(minLength: ReffiSpace.s3)
            Text("\(steps.count) steps")
                .reffiType(.metaText).foregroundStyle(ReffiColor.muted)
                .fixedSize()
        }
        .padding(.bottom, ReffiSpace.s3)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// 단계 목록 — 길면 시트 안에서 스크롤한다(`PaperChecklistDialog.list`·`PaperDropdown`과 같은
    /// "실측 높이 + 상한" 문법 대신, 시스템 시트가 이미 detent로 전체 높이를 쥐고 있어 여기선
    /// 그냥 `ScrollView`에 맡긴다 — 이중으로 높이를 캡하면 오히려 튄다).
    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    stepRow(index: index, text: step)
                    if index < steps.count - 1 { ReffiRule(.ticket) }
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        // UI 테스트 전용 식별자(39차 실측) — 시트가 뜬 채로도 딤 처리된 배경(`CookingStepsView`)의
        // 자기 ScrollView·버튼("Open recipe videos" 등)이 트리에 그대로 남아 있어, `app.scrollViews`로
        // 앱 전체를 훑으면 문서 순서상 배경 쪽이 먼저 걸린다 — 배경은 모달 밑이라 안 눌리는 게 맞는
        // 동작인데, 식별자 없이 짠 첫 테스트는 그 버튼을 집어 "not hittable"로 깨졌다. `cook.intro`와
        // 같은 문법으로 이 리스트만 좁혀 잡는다.
        .accessibilityIdentifier("kitchenCopy.steps")
    }

    private func stepRow(index: Int, text: String) -> some View {
        let done = completedSteps.contains(index)
        return Button { onToggle(index) } label: {
            HStack(alignment: .top, spacing: ReffiSpace.s3) {
                checkbox(on: done, seed: index)
                Text(verbatim: text)
                    .reffiType(.body)
                    .foregroundStyle(done ? ReffiColor.muted : ReffiColor.ink)
                    .strikethrough(done, color: ReffiColor.muted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.vertical, ReffiSpace.s3)
            .frame(minHeight: ReffiChrome.tapMin)   // §7.3 — 행 전체가 타깃
            .contentShape(Rectangle())
            // 상자·취소선·잉크색이 **한 클럭**에 움직인다(42차) — 체크박스 안에만 애니메이션을 걸면
            // 같은 행의 절반(텍스트)은 0프레임에 튀고 절반(상자)만 흘러 손가락 하나에 두 반응 속도가 붙는다.
            .animation(ReffiMotion.gated(ReffiMotion.standard, reduce: reduceMotion), value: done)
        }
        .buttonStyle(.reffiPress)
        .accessibilityLabel(Text(verbatim: text))   // 단계 문장은 데이터 — 번역 키가 아니다(§i18n)
        // 단계 완료는 "선택"이 아니라 "끝냄"이다(42차) — `.isSelected` 트레잇을 얹으면 VoiceOver가
        // "선택됨"을 붙여 뜻이 틀리고, 값과 겹치면 이중 발화가 된다. 도메인 값 하나만 말한다.
        .accessibilityValue(done ? Text("Done") : Text("Not done"))
        .accessibilityHint(Text("Toggles whether this step is done"))
    }

    /// 체크 상자 — `PaperChecklistDialog.checkbox`(§14.7)와 **같은 시각 문법**을 재사용한다: 켜짐 =
    /// blue 솔리드 + `PaperGrain` + `paperEdgeOnFill` + onAccent 체크, 꺼짐 = paper 면 + 헤어라인.
    /// 그 파일의 사설 함수를 직접 부르지 않는 이유는 그쪽이 `Row`·`Set<Int>` 모델에 이미 묶여
    /// 있어서다 — 여기는 인덱스 하나만 받는 훨씬 얕은 계약이라, 파일을 가로지르는 의존을 만드는
    /// 것보다 같은 그림을 다시 그리는 쪽이 실제로 더 작은 결합이다.
    @ViewBuilder
    private func checkbox(on: Bool, seed: Int) -> some View {
        let shape = PaperRect(cornerRadius: ReffiRadius.xs, seed: seed)
        ZStack {
            if on {
                shape.fill(ReffiColor.blue)
                    .overlay(PaperGrain(seed: UInt64(max(0, seed)) &+ 11, strength: 0.9).clipShape(shape))
                    .paperEdge(shape, tint: ReffiColor.paperEdgeOnFill)
                    .compositingGroup()
                ReffiIcon.check.reffi(13, .bold).foregroundStyle(ReffiColor.onAccent)
            } else {
                // 상태 경계 정본 토큰(§2.7·42차) — ink α .18은 카드 위 1.4:1대라 3:1 미달이었다.
                shape.fill(ReffiColor.paper).paperEdge(shape, tint: ReffiColor.paperEdgeState)
            }
        }
        .frame(width: 22, height: 22)
        .padding(.top, 1)   // 체크박스 상단을 첫 줄 텍스트 베이스라인에 살짝 맞춘다
        // 전환은 행(stepRow)이 한 클럭으로 몬다(42차) — 여기 걸면 상자만 다른 시계로 돈다.
    }
}
