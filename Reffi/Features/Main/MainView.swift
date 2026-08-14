import SwiftUI
import SpriteKit
import PhosphorSwift

/// 메인(§13) — 임박 재료 선택 + 요리하기, 단 두 가지.
/// 작업대(`FridgeStore.counterIngredients`)의 재료가 위에서 **진짜 물리로 떨어져 쌓여 그대로 남고**
/// (SpriteKit, 끌어서 던지기·탭 판정), 버튼 위엔 같은 재료의 **뱃지**가 함께 남는다.
/// 판정으로 빈 자리는 냉장고의 다음 임박 재료가 채운다(§13.6). **요리시작**을 누르면 오더 메모 캐러셀로.
/// 작업대·되돌리기 상태는 store에 살아 탭을 오가도 유지된다(undo 토스트는 RootTabView 공통).
struct MainView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(ProfileStore.self) private var profile
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 앱이 백그라운드로 내려가면 씬을 확실히 멈춘다(아래 scenePaused). `.inactive`는 **일부러 뺐다** —
    /// 앱 전환기·알림 배너 같은 잠깐의 상태에서도 씬이 멈춰 첫 프레임이 회색으로 남는다.
    @Environment(\.scenePhase) private var scenePhase

    // 알림 유도(프리퍼미션) — 첫 임박 재료가 생긴 순간이 가치가 증명되는 순간이다.
    // 알림은 기본 OFF + 스위치가 MyPage에만 있어, 여기서 한 번 제안하지 않으면 발견되지 않는다.
    @AppStorage(ExpiryNotifier.enabledKey) private var alertsEnabled = false
    @AppStorage("expiryAlertPromptSeen") private var alertPromptSeen = false

    /// 현재 탭으로 표시 중인지 — 아닐 때 물리 씬을 일시정지한다(배터리).
    var isActive: Bool = true

    /// SKScene 보관 박스 — @State 초기값 식은 뷰 구조체가 재생성될 때마다 평가되므로(예: undo 토스트
    /// 등장·소멸마다 RootTabView body 재평가 → MainView 재구성) 씬을 게으르게 만들어 1회만 생성한다.
    private final class SceneBox { lazy var scene = IngredientDropScene() }
    @State private var sceneBox = SceneBox()
    private var scene: IngredientDropScene { sceneBox.scene }
    @State private var deciding: Ingredient?       // Ate/Tossed 결정 중인 재료(투명 풀스크린 커버)
    @State private var showCarousel = false
    @State private var showSteps = false           // 단계별 레시피(발주 직후 + Cooking now 카드에서)
    @State private var showAdd = false
    @State private var carouselSnapshot: [RecipeRecommender.Result] = []   // 커버 입력 동결(발주 중 재랭크 방지)
    @State private var firedTicket = false         // 커버당 발주 1회 — 슬램 창의 더블 파이어 방지
    @State private var coverGeneration = 0         // 지연 닫기 타이머가 새로 연 커버를 닫지 못하게
    @State private var fireHaptic = 0
    @State private var decisionHaptic = 0

    private let margin = ReffiGrid.margin
    private let navClearance: CGFloat = 86

    private var counter: [Ingredient] { store.counterIngredients }
    private var carouselResults: [RecipeRecommender.Result] {
        // 소비 후보 = 전체 가용 재고(예약 제외) — 티켓이 쓰는 재료가 작업대 밖에 있어도
        // 함께 소비 처리돼 '실제로 썼는데 재고에 남는' 유령 재고가 생기지 않는다.
        // 프로필 취향(§5.2)을 랭킹에 실배선 — 알레르기 하드 필터·선호/기피/요리스타일 보정.
        Array(store.rankedRecipes(preferences: RecipePreferences(profile: profile)).prefix(3))
    }
    private var topF: Freshness { counter.first?.freshness ?? .fresh }
    private var urgentCount: Int { counter.lazy.filter { $0.freshness == .urgent }.count }
    private var soonCount: Int { counter.lazy.filter { $0.freshness == .soon }.count }
    /// 씬 일시정지 — 다른 탭, 그리고 씬을 완전히 덮는 **풀스크린 커버**(캐러셀·조리 화면·판정)에
    /// 가려진 동안은 물리 렌더와 60Hz 모션 갱신을 멈춘다. 조리 화면(`showSteps`)은 불투명 커버라
    /// 여기서 빠지면 안 보이는 씬이 계속 돌고 손 움직임이 그 씬을 다시 깨운다.
    /// `showAdd`는 뺀다 — 풀스크린 커버가 아니라 시트(`.large` detent)라 위쪽에 표시 뷰가 남고,
    /// 시트를 닫는 순간 정지화면이 잠깐 보이는 쪽이 더 나쁘다.
    /// **백그라운드**도 포함한다 — iOS가 서스펜드하며 모션 콜백을 알아서 끊긴 하지만,
    /// 여기서 명시하면 SKView 렌더 루프까지 결정적으로 멈추고 달그락 엔진도 함께 내려간다.
    private var scenePaused: Bool {
        !isActive || scenePhase == .background || showCarousel || showSteps || deciding != nil
    }
    /// 씬 동기화 트리거 — id·이름·글리프·신선도 어느 것이 바뀌어도 칩이 따라간다.
    private var sceneSyncKey: [String] {
        counter.map { "\($0.id.uuidString)#\($0.name)#\($0.glyph.rawValue)#\($0.freshness)" }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, margin)
                .padding(.top, ReffiSpace.s2)

            // 발주 진행 카드(§13.6 C) — 헤더 아래 죽은 공간이 상태 표면이 된다.
            if let cook = store.activeCook {
                cookingNowCard(cook)
                    .padding(.horizontal, margin)
                    .padding(.top, ReffiSpace.s3)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if showAlertPrompt {
                alertPromptCard
                    .padding(.horizontal, margin)
                    .padding(.top, ReffiSpace.s3)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            physicsField
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !counter.isEmpty {
                badgeScroll
                    .padding(.bottom, ReffiSpace.s2)
                    .id(dayTick)   // 자정 경과 시 D-day·신선도색 재계산
            }

            PaperButton(title: "Start cooking") { cook() }
                .padding(.horizontal, margin)
                .padding(.top, ReffiSpace.s3)
                .padding(.bottom, navClearance)
                .disabled(counter.isEmpty)   // 디밍은 PaperButton이 §7.2로 처리 — 여기서 겹치면 곱해진다.
        }
        .animation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion), value: store.activeCook)
        .background {
            ZStack {
                LiquidGlassBackground(accent: topF.main, accentDeep: topF.dark)
                // 긴급도 연출(F) — 오늘 만료가 있으면 상단에 옅은 웜톤 시노.
                if urgentCount > 0 {
                    LinearGradient(colors: [ReffiColor.urgent.opacity(0.14), .clear],
                                   startPoint: .top, endPoint: .center)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
            .animation(ReffiMotion.gated(.easeInOut(duration: 0.5), reduce: reduceMotion), value: topF)
            .animation(ReffiMotion.gated(.easeInOut(duration: 0.5), reduce: reduceMotion), value: urgentCount > 0)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: fireHaptic)
        .sensoryFeedback(.impact(weight: .light), trigger: decisionHaptic)
        .fullScreenCover(isPresented: $showCarousel, onDismiss: {
            // 발주로 닫혔으면 곧장 단계별 레시피로 — "Cook this"의 다음 화면은 조리다.
            if firedTicket, store.activeCook != nil { showSteps = true }
        }) {
            RecipeMemoCarousel(results: carouselSnapshot,
                               hasIngredients: !store.ingredients.isEmpty,
                               onClose: { showCarousel = false },
                               onFire: fire)
        }
        .fullScreenCover(isPresented: $showSteps) {
            CookingStepsView(onClose: { showSteps = false })
        }
        // 판정은 투명 풀스크린 커버 — 하단 네비까지 덮어 모달리티가 깨지지 않는다.
        .fullScreenCover(item: $deciding) { ing in
            DecisionCover(ingredient: ing,
                          reduceMotion: reduceMotion,
                          onCommit: { ate in commit(ing, ate: ate) },
                          onFreeze: { commitFreeze(ing) },
                          onCancel: { closeDecision() })
                .presentationBackground(.clear)
        }
        .sheet(isPresented: $showAdd) {
            AddIngredientSheet()   // presentationDetents는 시트 내부에서 적용(중복 방지)
        }
        // 자정 경과 — D-day·신선도 파생 UI와 씬 라벨 점을 다시 계산한다.
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            dayTick += 1
            scene.sync(counter)
        }
        #if DEBUG
        // `-tiltLab` — 기울기 QA용 하단 오버레이. overlay라 헤더·배너·뱃지 행·CTA 레이아웃은 그대로다.
        .overlay(alignment: .bottom) { tiltLabOverlay }
        .onAppear {   // 미리보기/검증용: `-loadSample`로 샘플 시드, `-previewCarousel 1`로 캐러셀 바로 열기.
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-loadSample"), store.isPristine {
                store.loadSampleData()
            }
            if args.contains("-previewCarousel") {
                carouselSnapshot = carouselResults
                showCarousel = true
            }
            if args.contains("-previewAdd") { showAdd = true }   // 재료 추가 시트 스크린샷 검증용
            // `-cookCarousel` — 티켓 덱을 런치 시 자동 오픈(스크린샷·UI 테스트용).
            // 시드가 부모(RootTabView)의 `-uiTestSampleFridge`로 들어오는 조합도 있어 한 박자 늦게 연다(`-cookTicket` 선례).
            if args.contains("-cookCarousel") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    // 시드 자가 보장 — 스냅샷을 이 시점에 **한 번만** 읽으므로, 부모 시드가 없거나
                    // 늦으면 덱이 영구히 빈 채로 열린다(테스트는 느려지는 게 아니라 실패한다).
                    // `-cookTicket`이 loadSampleData()를 직접 부르는 선례를 따라 여기서 채운다.
                    if store.available.isEmpty { store.loadSampleData() }
                    carouselSnapshot = carouselResults
                    showCarousel = true
                }
            }
            // `-cookTicket` — 조리 티켓은 fire 없인 열리지 않아 스크린샷 QA가 막힌다.
            // 진행 중 세션이 없으면 샘플로 강제 발주한 뒤 곧장 CookingStepsView를 연다.
            if args.contains("-cookTicket") {
                if store.activeCook == nil {
                    store.loadSampleData()
                    if let top = carouselResults.first { store.cook(top) }
                }
                // fire 직후 같은 프레임의 커버 프레젠테이션은 씹힌다(-fridgeExpand 선례) — 한 박자 늦게 연다.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showSteps = true }
            }
        }
        #endif
    }

    @State private var dayTick = 0   // 자정 리렌더 트리거

    // MARK: - Tilt lab (`-tiltLab`, DEBUG)

    #if DEBUG
    /// 런치 인자 순수 파서 — `-tiltLab.x -0.9`처럼 값이 음수면 NSArgumentDomain(UserDefaults)이 `-0.9`를
    /// 다음 키로 오인해 바인딩을 통째로 잃는다(`-fridge.compact YES` 선례는 값이 항상 양수/문자라 문제가
    /// 없었다). 그래서 ProcessInfo.arguments를 직접 순회해 값을 뽑는다 — 순수 함수라 음수·클램프·누락
    /// 같은 케이스를 실기기/시뮬레이터 없이 유닛 테스트로 고정할 수 있다.
    /// `internal`(비-private) — TiltLabLaunchArgTests가 `@testable import Reffi`로 직접 호출한다.
    /// 반환: x/y는 파싱 성공 시에만 값이 실리고(실패·누락이면 nil, 다음 토큰은 소비하지 않음) -1...1로
    /// 클램프된다. labOn은 `-tiltLab` 존재, x 파싱 성공, y 파싱 성공, `-tiltLab.shake` 존재 중 하나만
    /// 참이어도 true. shake는 `-tiltLab.shake` 존재 여부.
    static func tiltLabLaunchConfig(from args: [String]) -> (x: Double?, y: Double?, labOn: Bool, shake: Bool) {
        func value(after flag: String) -> Double? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count,
                  let raw = Double(args[i + 1]) else { return nil }
            return min(1, max(-1, raw))
        }
        let x = value(after: "-tiltLab.x")
        let y = value(after: "-tiltLab.y")
        let shake = args.contains("-tiltLab.shake")
        let labOn = args.contains("-tiltLab") || x != nil || y != nil || shake
        return (x, y, labOn, shake)
    }

    /// 프로세스당 한 번만 파싱 — 아래 여러 프로퍼티가 ProcessInfo.arguments를 반복해 읽지 않도록 캐싱.
    private static let tiltLabConfig = Self.tiltLabLaunchConfig(from: ProcessInfo.processInfo.arguments)

    @State private var tiltLabX: Double = Self.tiltLabConfig.x ?? 0    // 주입 중력 x(정규화) — 오른쪽이 +
    @State private var tiltLabY: Double = Self.tiltLabConfig.y ?? -1   // 주입 중력 y(정규화) — 위가 +, 세워 든 기본 자세가 -1

    /// `-tiltLab` 또는 `-tiltLab.x/.y`(파싱 성공) 또는 `-tiltLab.shake` 중 하나만 있어도 실험실을 켠다.
    private var tiltLabOn: Bool { Self.tiltLabConfig.labOn }

    /// 기울기 실험실 — X/Y 슬라이더로 씬 중력 벡터를 직접 주입한다. 시뮬레이터엔 자이로가 없어
    /// CoreMotion 경로를 탈 수 없으므로, 굴러가는 모양 QA는 사실상 이 경로로만 가능하다.
    /// CTA 위에 얹어(하단 패딩) 요리시작 버튼은 계속 누를 수 있게 둔다.
    @ViewBuilder private var tiltLabOverlay: some View {
        if tiltLabOn {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(verbatim: "TILT LAB")
                        .reffiType(.monoEyebrow).foregroundStyle(ReffiColor.blueDark)
                    Spacer()
                    Text(verbatim: String(format: "x %.2f   y %.2f", tiltLabX, tiltLabY))
                        .reffiType(.metaText).foregroundStyle(ReffiColor.ink2)
                }
                tiltLabSlider("X", value: $tiltLabX)
                tiltLabSlider("Y", value: $tiltLabY)
                HStack(spacing: ReffiSpace.s3) {
                    Button { scene.shakeBurst() } label: {
                        Text(verbatim: "SHAKE")
                            .reffiType(.monoEyebrow)
                            .foregroundStyle(.white)
                            .padding(.horizontal, ReffiSpace.s3)
                            .padding(.vertical, 4)
                            .background(ReffiColor.blue, in: Capsule())
                    }
                    .buttonStyle(.reffiPress)
                    clatterCounter
                    Spacer()
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, ReffiSpace.s4)
            .padding(.vertical, ReffiSpace.s2)
            .background {
                let shape = PaperRect(cornerRadius: ReffiRadius.md)
                shape.fill(ReffiColor.paper).paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
            }
            .reffiShadow1()
            .padding(.horizontal, margin)
            .padding(.bottom, navClearance + 60)
            .onAppear {
                pushTiltLab()
                scene.onClatter = { [clatterLog] in
                    clatterLog.times.append(ProcessInfo.processInfo.systemUptime)
                    if clatterLog.times.count > 240 { clatterLog.times.removeFirst(120) }
                }
                // `-tiltLab.shake` — 버튼을 코드로 못 눌러서, 런치 1.5초 뒤 버스트를 한 번 자동 발동한다
                // (재료가 자리를 잡은 뒤라야 충돌이 의미 있다). 단독 지정 시에도 tiltLabConfig.labOn이
                // true가 되어 이 오버레이(및 onAppear)가 열리므로 스케줄이 정상 발동한다.
                if Self.tiltLabConfig.shake {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { scene.shakeBurst() }
                }
            }
            .onChange(of: tiltLabX) { _, _ in pushTiltLab() }
            .onChange(of: tiltLabY) { _, _ in pushTiltLab() }
        }
    }

    /// 햅틱 발화 시각 로그 — @State가 아니라 **참조 박스**에 담는다. 초당 수십 회 발화를 @State에
    /// 쓰면 그때마다 SwiftUI가 물리 필드까지 다시 그린다. TimelineView가 자기 주기로 읽어 가면 충분하다.
    private final class ClatterLog { var times: [TimeInterval] = [] }
    @State private var clatterLog = ClatterLog()

    /// 최근 1초 햅틱 발화 수 — 시뮬레이터엔 햅틱 하드웨어가 없어 **이 숫자가 유일한 관측 수단**이다.
    /// 정지한 더미에서 0으로 떨어지는지(웅웅 방지 증명)도 여기서 본다.
    private var clatterCounter: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            let now = ProcessInfo.processInfo.systemUptime
            let recent = clatterLog.times.filter { now - $0 < 1 }.count
            Text(verbatim: "HAPTIC \(recent)/s")
                .reffiType(.metaText)
                .foregroundStyle(recent > 0 ? ReffiColor.blueDark : ReffiColor.ink2)
        }
    }

    private func tiltLabSlider(_ label: String, value: Binding<Double>) -> some View {
        HStack(spacing: ReffiSpace.s2) {
            Text(verbatim: label)
                .reffiType(.metaText).foregroundStyle(ReffiColor.ink2).frame(width: 12)
            Slider(value: value, in: -1...1)
        }
    }

    /// 슬라이더 값을 씬에 주입 — 씬은 이 값을 CoreMotion보다 우선한다.
    private func pushTiltLab() {
        scene.debugTilt = CGVector(dx: tiltLabX, dy: tiltLabY)
    }
    #endif

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s1) {
            HStack(alignment: .center) {
                Text(verbatim: "Reffi").reffiType(.display).foregroundStyle(ReffiColor.ink)
                Spacer()
                // 날짜는 분 단위 타임라인으로 갱신 — 자정이 지나도 어제 날짜가 남지 않는다.
                TimelineView(.everyMinute) { ctx in
                    Text(ctx.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.reffiNum(.meta)).foregroundStyle(ReffiColor.ink2)
                }
            }
            // 미션 헤더(D) — 오늘의 상태를 한 문장으로. 누계(Ate/Tossed)는 MyPage가 맡는다.
            missionText
                .reffiType(.caption)
                .foregroundStyle(urgentCount > 0 ? ReffiColor.urgentDark : ReffiColor.ink2)
        }
    }

    private var missionText: Text {
        if counter.isEmpty { return Text("Fill the counter, then cook") }
        if urgentCount > 0 { return Text("\(urgentCount) at risk today. Cook one?") }
        if soonCount > 0 { return Text("\(soonCount) to eat soon. Plan tonight?") }
        return Text("All fresh. Get ahead of it.")
    }

    // MARK: - 알림 유도 배너 (프리퍼미션)

    /// 임박 재료가 있고 알림이 꺼져 있고 아직 제안 안 했을 때 한 번만.
    private var showAlertPrompt: Bool {
        !alertsEnabled && !alertPromptSeen && (urgentCount + soonCount) > 0
    }

    /// 미니 영수증 스트립(Cooking now와 같은 자리·같은 언어) — 켜기 / 나중에.
    private var alertPromptCard: some View {
        HStack(spacing: ReffiSpace.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "MORNING ALERTS")
                    .reffiType(.monoEyebrow).foregroundStyle(ReffiColor.blueDark)
                Text("Know before food turns")
                    .reffiType(.badgeLabel)
                    .foregroundStyle(ReffiColor.ink).lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: ReffiSpace.s2)
            Button { enableAlerts() } label: {
                Text("Turn on")
                    .reffiType(.pillLabel)
                    .foregroundStyle(ReffiColor.blueDark)
                    .padding(.horizontal, ReffiSpace.s3 + 2)
                    .padding(.vertical, ReffiSpace.s1 + 2)
                    // §13.1 종이컷 8각형(캡슐 금지) — 바로 아래 Start cooking(PaperButton)과 같은 재질 언어.
                    // 다만 면은 채우지 않는다: blue 솔리드 면은 한 화면에 하나(Start cooking)뿐이어야
                    // 부차 액션이 F패턴 #1을 가져가지 않는다(§2.4 5% 강조 배분, 감사 R3-1).
                    .background {
                        let s = PaperCutRect(seed: 3)
                        s.fill(ReffiColor.sub)
                            .paperEdge(s, tint: ReffiColor.blueDark.opacity(0.38), width: 1.2)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.reffiPress)
            Button { withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) { alertPromptSeen = true } } label: {
                Text("Later")
                    .reffiType(.pillLabel)
                    .foregroundStyle(ReffiColor.ink2)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.reffiPress)
        }
        .padding(.horizontal, ReffiSpace.s4)
        .padding(.vertical, ReffiSpace.s1)
        .frame(minHeight: 44)
        .background {
            let shape = ReceiptShape(tooth: ReffiTooth.chip)
            shape.fill(ReffiColor.paper).paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
        }
        .reffiShadow1()
    }

    /// 켜기 — 시스템 권한 요청 후 성공 시 즉시 스케줄. 거부해도 다시 조르지 않는다(seen 처리).
    private func enableAlerts() {
        Task {
            let granted = await ExpiryNotifier.requestAuthorization()
            withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                alertPromptSeen = true
                if granted {
                    alertsEnabled = true
                    ExpiryNotifier.reschedule(for: store.ingredients)
                }
            }
        }
    }

    // MARK: - Cooking now (발주 진행 카드)

    /// 발주 후 "지금 요리 중" — 탭하면 단계별 레시피로 복귀(완료는 그 화면에서).
    /// 셰입은 CTA급(§13.5 `PaperCutRect` + 그레인 + `shadow-1`)이다 — 룰 ⑩이 규정한
    /// "몰입 커버 진입 = 눈에 띄는 CTA"에 맞춘다(감사 R3-3). 색은 종이 면을 유지해
    /// 바로 아래 Start cooking(blue 솔리드)과 경쟁하지 않는다.
    private func cookingNowCard(_ cook: FridgeStore.CookSession) -> some View {
        Button { showSteps = true } label: {
            HStack(spacing: ReffiSpace.s3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "COOKING NOW")
                        .reffiType(.monoEyebrow).foregroundStyle(ReffiColor.blueDark)
                    HStack(spacing: 6) {
                        Text(verbatim: cook.recipeName)
                            .reffiType(.badgeLabel)
                            .foregroundStyle(ReffiColor.ink).lineLimit(1)
                        Text(cook.startedAt, style: .relative)
                            .reffiType(.metaText)
                            .foregroundStyle(ReffiColor.ink2)
                    }
                }
                Spacer(minLength: ReffiSpace.s2)
                ReffiIcon.chevron.reffi(15, .bold).foregroundStyle(ReffiColor.blueDark)
            }
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s3)
            .frame(minHeight: 56)
            .background {
                let s = PaperCutRect(seed: 5)                      // 메인 CTA(PaperButton)와 같은 8각형
                s.fill(ReffiColor.paper)
                    .overlay(PaperGrain(seed: 27, strength: 0.7).clipShape(s))   // 옅은 질감
                    .paperEdge(s, tint: ReffiColor.ink.opacity(0.06), width: 1)
                    .compositingGroup()
                    .reffiShadow1()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel(Text("Continue cooking \(cook.recipeName)"))
    }

    // MARK: - Physics field (real engine, persistent pile)

    private var physicsField: some View {
        GeometryReader { geo in
            ZStack {
                // 주의: SpriteView(isPaused:)는 초기화 시점에 멈춰 첫 프레임이 안 그려질 수 있다(회색).
                // 일시정지는 씬이 스스로 관리한다(externallyPaused ∥ idle) — 첫 프레임 이후엔
                // SKView 렌더 루프까지 멈춰(마지막 프레임 정지화면) 가려진 탭의 유휴 CPU를 없앤다.
                SpriteView(scene: scene, options: [.allowsTransparency])
                    .onAppear { configureScene(size: geo.size) }
                    .onChange(of: geo.size) { _, s in scene.size = s }
                    .onChange(of: sceneSyncKey) { _, _ in scene.sync(counter) }
                    .onChange(of: reduceMotion) { _, v in scene.reduceMotion = v }
                    .onChange(of: scenePaused) { _, p in scene.externallyPaused = p }
                if counter.isEmpty { emptyField }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func configureScene(size: CGSize) {
        scene.scaleMode = .resizeFill
        scene.size = size
        scene.reduceMotion = reduceMotion
        scene.onRemove = { id in decide(id) }
        scene.onDecide = { id, wasted in gestureDecide(id, wasted: wasted) }
        scene.externallyPaused = scenePaused
        scene.sync(counter)
    }

    /// 제스처 판정(§13.6 B) — 존에 끌어다 놓으면 오버레이 없이 바로 확정. undo 토스트가 안전망.
    private func gestureDecide(_ id: UUID, wasted: Bool) {
        guard let ing = counter.first(where: { $0.id == id }) else { return }
        decisionHaptic += 1
        withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) {
            if wasted { store.toss(ing) } else { store.eat(ing) }
        }
    }

    /// 빈 작업대 — 첫 실행(데이터 전무)이면 온보딩 카피 + 샘플 CTA, 아니면 추가 유도.
    private var emptyField: some View {
        VStack(spacing: ReffiSpace.s4) {
            ReffiIcon.fridge.reffi(40).foregroundStyle(ReffiColor.muted)
            if store.isPristine {
                VStack(spacing: ReffiSpace.s1) {
                    Text("What's in your fridge?").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
                    Text("Add a few ingredients. Reffi tells you\nwhat to cook before they turn.")
                        .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                        .multilineTextAlignment(.center)
                }
            } else {
                Text("Nothing to use yet").reffiType(.subhead).foregroundStyle(ReffiColor.ink2)
            }
            AddBadge { showAdd = true }
            if store.isPristine {
                Button {
                    withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                        store.loadSampleData()
                    }
                } label: {
                    Text("Or try a sample fridge")
                        .reffiType(.caption)
                        .foregroundStyle(ReffiColor.blue)
                        .underline()
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.reffiPress)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // 신선도 점 인디케이터(PR #4)는 §13.6 E(뱃지의 인디케이터 바·D-N과 중복 → 제거 결정)와 상충해 미채택.
    // MARK: - Badge scroll (persistent)

    /// 뱃지 행 — 긴급도순 가로 스크롤(가장 임박이 맨 앞). 끝에 ＋추가.
    /// (신선도 점 행은 뱃지의 인디케이터 바·D-N과 중복이라 제거 — §13.6 E)
    private var badgeScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ReffiSpace.s2) {
                ForEach(Array(counter.enumerated()), id: \.element.id) { i, ing in
                    IngredientBadge(ingredient: ing, seed: i) { decide(ing.id) }
                        .transition(.scale(scale: 1.3, anchor: .center).combined(with: .opacity))   // 뿅 사라짐
                }
                AddBadge(seed: counter.count) { showAdd = true }
            }
            .padding(.horizontal, margin)
            .padding(.vertical, ReffiSpace.s1)   // 그림자 여유
        }
        .animation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion), value: counter.map(\.id))
    }

    // MARK: - Ate / Tossed decision

    /// 재료 탭 → "먹었나 버렸나" 묻기. 커버 자체의 슬라이드 애니메이션은 끄고 카드가 pop-in 한다.
    private func decide(_ id: UUID) {
        guard let ing = counter.first(where: { $0.id == id }) else { return }
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { deciding = ing }
    }

    private func closeDecision() {
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { deciding = nil }
    }

    /// 선택 확정 → store에서 제거(실루엣·뱃지 뿅 사라짐) + 이력 기록 + 되돌리기 창(토스트는 탭 공통).
    private func commit(_ ing: Ingredient, ate: Bool) {
        decisionHaptic += 1
        closeDecision()
        withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) {
            if ate { store.eat(ing) } else { store.toss(ing) }
        }
    }

    /// 냉동(버리기 직전 구제) — 유예 14일의 새 시계를 받고 작업대에서 빠진다(유예 임박에 재등장).
    private func commitFreeze(_ ing: Ingredient) {
        decisionHaptic += 1
        closeDecision()
        withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) {
            store.freeze(ing)
        }
    }

    // MARK: - Cook / Fire the Ticket

    private func cook() {
        guard !counter.isEmpty else { return }
        carouselSnapshot = carouselResults   // 발주로 store가 바뀌어도 커버 입력은 고정(재랭크 방지)
        firedTicket = false
        coverGeneration += 1                 // 이전 발주의 지연 닫기 타이머 무효화
        // 커버 표시를 한 틱 지연 — 80레시피 스코어링(carouselResults)과 커버 첫 프레임이
        // 같은 틱에 겹쳐 프레임드롭 나지 않게 랭킹 계산 틱과 표시 틱을 분리한다.
        DispatchQueue.main.async { showCarousel = true }
    }

    /// 티켓 발주(Fire the Ticket) — used 재료를 이 레시피로 전량 소비 처리 → 슬램 본 뒤 커버 닫기.
    /// 되돌리기 토스트는 store의 통합 undo가 띄운다. 커버당 1회만(더블 파이어 방지).
    private func fire(_ result: RecipeRecommender.Result) {
        guard !firedTicket, !result.used.isEmpty else { return }
        firedTicket = true
        fireHaptic += 1
        // 스토어 변이는 애니메이션 밖에서 — 슬램 연출은 OrderMemoCard 로컬 fired 상태가 구동하고,
        // 메인 뱃지·씬 변화는 커버 뒤라 애니메이션이 필요 없다(전환 프레임드롭 방지).
        store.cook(result)
        let gen = coverGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            if coverGeneration == gen { showCarousel = false }   // 새로 연 커버는 닫지 않는다
        }
    }
}

/// Ate/Tossed 결정 — 투명 풀스크린 커버 위 딤 + 종이 카드 + 종이컷 아이콘 버튼 쌍 + 명시적 취소.
/// **오늘 만료(urgent)이고 아직 얼린 적 없는 재료**엔 3번째 선택지 Freeze가 나타난다(§13.6) —
/// 미리 얼려두기가 아니라 버리기 직전의 구제로만. 커버라서 하단 네비까지 덮인다(모달리티).
private struct DecisionCover: View {
    let ingredient: Ingredient
    let reduceMotion: Bool
    var onCommit: (Bool) -> Void
    var onFreeze: () -> Void = {}
    var onCancel: () -> Void

    @State private var shown = false

    /// Freeze 노출 조건 — 오늘 만료(urgent) + 재냉동 아님(1회 제한). '미루기 버튼' 방지.
    private var showFreeze: Bool { ingredient.freshness == .urgent && ingredient.canFreeze }

    var body: some View {
        ZStack {
            ReffiColor.scrim.ignoresSafeArea()
                .opacity(shown ? 1 : 0)
                .onTapGesture { onCancel() }
                .accessibilityHidden(true)
            card
                .scaleEffect(shown ? 1 : 0.85)
                .opacity(shown ? 1 : 0)
        }
        .onAppear {
            if reduceMotion {
                shown = true
            } else {
                withAnimation(ReffiMotion.pop) { shown = true }
            }
        }
        .accessibilityAction(.escape) { onCancel() }
    }

    private var card: some View {
        VStack(spacing: ReffiSpace.s5) {
            VStack(spacing: 2) {
                Text(verbatim: ingredient.displayName).reffiType(.heading).foregroundStyle(ReffiColor.ink)
                Text("Did you eat it, or toss it?")
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
            }
            HStack(spacing: showFreeze ? ReffiSpace.s4 : ReffiSpace.s6) {
                PaperIconButton(icon: ReffiIcon.toss, label: "Tossed", intent: .soft, seed: 0) { onCommit(false) }
                if showFreeze {
                    PaperIconButton(icon: ReffiIcon.freeze, label: "Freeze", intent: .neutral, seed: 2) { onFreeze() }
                }
                PaperIconButton(icon: ReffiIcon.ate, label: "Ate", intent: .primary, seed: 1) { onCommit(true) }
            }
            Button { onCancel() } label: {
                Text("Keep it")
                    .reffiType(.caption)
                    .foregroundStyle(ReffiColor.ink2)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.reffiPress)
        }
        .padding(.horizontal, ReffiSpace.s6)
        .padding(.top, ReffiSpace.s6)
        .padding(.bottom, ReffiSpace.s3)
        .background {
            let shape = PaperRect(cornerRadius: ReffiRadius.xl)
            shape.fill(ReffiColor.canvas).paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
        }
        .reffiShadow1()
        .padding(.horizontal, ReffiSpace.s7)
    }
}
