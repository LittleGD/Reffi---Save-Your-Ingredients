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
    /// 냉장고의 To buy 패인으로 데려가 달라 — 덱의 담기 흐름이 "보기"로 끝날 때 루트가 받는다.
    /// 라우터를 새로 만들지 않는다: 이 앱의 화면 전환은 전부 클로저·바인딩으로 위로 올린다
    /// (선례: `onClose`·`onFire`·`onAddMissing`). 실제 탭 전환은 `RootTabView`가 한다.
    var onOpenToBuy: () -> Void = {}

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
    /// 빈 덱에서 호명할 위험 재고 이름 — **비-fresh 전체**(soon + urgent). 덱과 **같은 틱**에 얼린다
    /// (아래 `snapshotCarousel`). 아래 `uncoveredSnapshot`은 **urgent만** 세는 더 좁은 축이라
    /// 이름을 atRisk 계열로 갈라 둔다 — 한쪽 기준으로 다른 쪽을 고치면 두 문구가 조용히 어긋난다.
    @State private var atRiskSnapshot: [String] = []
    /// 덱이 다루지 못한 오늘 만료(urgent) 재료 이름 — 브리지 행의 입력. 역시 같은 틱에 얼린다.
    @State private var uncoveredSnapshot: [String] = []
    @State private var firedTicket = false         // 커버당 발주 1회 — 슬램 창의 더블 파이어 방지
    @State private var coverGeneration = 0         // 지연 닫기 타이머가 새로 연 커버를 닫지 못하게
    /// 담기 흐름(팝업 3단)이 덱 위에 떠 있다 — 켜져 있는 동안 발주 지연 닫기를 **미룬다**.
    @State private var toBuyOverDeck = false
    /// 미뤄 둔 지연 닫기 — **취소가 아니라 보류**다. 흐름이 끝나면 그대로 이어 실행한다.
    @State private var pendingDeckDismiss = false
    /// 커버가 걷힌 뒤 To buy로 간다 — 커버 해체와 탭 전환을 같은 프레임에 겹치지 않게 하는 한 칸.
    @State private var pendingToBuyJump = false
    @State private var fireHaptic = 0
    @State private var decisionHaptic = 0

    private let margin = ReffiGrid.margin

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
                // **세 루트 페이지의 제목이 같은 높이에서 시작한다**(23차). 냉장고·프로필이 둘 다
                // `s5`인데 홈만 `s2`라 탭을 오갈 때 제목이 16pt 튀었다(실측: 홈 78.3pt vs 나머지 94.5pt).
                // 남는 세로 공간은 아래 `physicsField`가 `maxHeight: .infinity` + 바닥 정렬로 흡수하므로
                // 더미가 앉는 자리는 그대로다(필드는 `fieldRestHeight`로 이미 캡이 걸려 있다).
                .padding(.top, ReffiSpace.s5)

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
                .frame(maxWidth: .infinity, maxHeight: fieldRestHeight)
                // 남는 공백은 **전부 위로** 몬다 — 더미가 뱃지 바로 위에 내려앉는다.
                // 가운데 정렬이던 시절엔 필드 상자 자체가 화면 중앙에 떠서, 칩이 상자 바닥에
                // 정확히 붙어 있는데도 "바닥에 안 붙는다"로 읽혔다(-physLab 오버레이로 확인).
                // 중력 방향(아래)과 더미가 앉는 자리가 어긋나면 물리가 거짓말하는 것처럼 보인다.
                .frame(maxHeight: .infinity, alignment: .bottom)

            if !counter.isEmpty {
                badgeScroll
                    .padding(.bottom, ReffiSpace.s2)
                    .id(dayTick)   // 자정 경과 시 D-day·신선도색 재계산
            }

            PaperButton(title: "Start cooking") { cook() }
                .padding(.horizontal, margin)
                .padding(.top, ReffiSpace.s3)
                // 스크롤이 아니라 화면에 못 박힌 CTA라 **자리 예약** 쪽이다(§9.3) — 냉장고 펼침의
                // 바닥 여백과 같은 값을 본다. 홈만 자기 상수(86)를 들고 있어 네비 높이를 건드리면
                // 여기만 조용히 어긋났다.
                .padding(.bottom, ReffiChrome.navReserve)
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
            // 덱이 사라졌으면 그 위에 뜬 것도 없다 — 신호가 true로 굳으면 **다음 발주의 지연 닫기가
            // 영영 미뤄진다**(팝업엔 해체 완료 훅이 없어 극단 타이밍에서 실제로 굳을 수 있다).
            toBuyOverDeck = false
            pendingDeckDismiss = false
            if pendingToBuyJump {
                // 사용자가 방금 고른 목적지가 조리 화면보다 앞선다 — 여기서 조리 커버를 열면
                // 그 위에 덮여 To buy가 보이지 않는다(발주 뒤 담기 흐름에서 실제로 겹치는 경로다).
                pendingToBuyJump = false
                onOpenToBuy()
            } else if firedTicket, store.activeCook != nil {
                // 발주로 닫혔으면 곧장 단계별 레시피로 — "Cook this"의 다음 화면은 조리다.
                showSteps = true
            }
        }) {
            RecipeMemoCarousel(results: carouselSnapshot,
                               hasIngredients: !store.ingredients.isEmpty,
                               atRiskNames: atRiskSnapshot,
                               uncoveredNames: uncoveredSnapshot,
                               onClose: { showCarousel = false },
                               onFire: fire,
                               onAddMissing: { store.addMissingToBuy($0) },
                               onToBuyPresentationChange: { active in
                                   toBuyOverDeck = active
                                   // 흐름이 끝나는 순간 미뤄 둔 닫기를 **그대로 잇는다** — 발주 뒤
                                   // 팝업에서 취소해도 ORDER · FIRED 전환은 사라지지 않는다.
                                   if !active, pendingDeckDismiss {
                                       pendingDeckDismiss = false
                                       showCarousel = false
                                   }
                               },
                               onOpenToBuy: {
                                   pendingToBuyJump = true
                                   showCarousel = false   // 탭 전환은 `onDismiss`에서 — 순서가 곧 안전이다
                               })
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
                snapshotCarousel()
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
                    snapshotCarousel()
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
                shape.fill(ReffiColor.paper).paperEdge(shape)
            }
            .reffiShadow1()
            .padding(.horizontal, margin)
            .padding(.bottom, ReffiChrome.navReserve + 60)
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
            shape.fill(ReffiColor.paper).paperEdge(shape)
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
                    .paperEdge(s)
                    .compositingGroup()
                    .reffiShadow1()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel(Text("Continue cooking \(cook.recipeName)"))
    }

    // MARK: - Physics field (real engine, persistent pile)

    /// 정지 상태 필드 높이의 상한 — "쉬고 있는 더미"에 필요한 만큼만 자리를 잡는다.
    /// 필드가 화면 끝까지 늘어나면 중력에 눕는 더미는 바닥에 붙고 위쪽 여유가 통째로
    /// 빈 띠로 남아, 배너와 더미 사이가 뷰포트의 4분의 1이 됐다(감사 R3-4).
    /// 낙하 스폰은 씬 바깥 절대 좌표(`size.height + 700`)라 드라마는 이 캡과 무관하다.
    /// 칩은 화면 폭에서 3열로 눕으므로 행 수 = ⌈n/3⌉, 행 피치·바닥 여유는 실측값이다.
    /// **스프라이트 몫을 더 얹지 않는다(2026-08 실측으로 기각).** 칩 스프라이트는 `chipSide` 정사각인데
    /// 충돌 바디는 그 높이의 0.28~0.71뿐이라 "그림이 캡 위로 잘리는 것 아닌가"를 의심할 만하지만,
    /// 실제로 그려지는 건 스프라이트가 아니라 **알파 bbox**(바디 = bbox × 0.9)다. `-physLab` 5회 실측에서
    /// 안착 상태의 그림 최상단은 캡을 **11~13pt 밑돌았다**(잘림 0건). 캡 위로 잘려 보이는 칩은 아직
    /// **낙하 중인** 칩이고, 그건 스폰 천장이 씬 바깥(`size.height + chipSide`)이라 설계대로다.
    /// 여유를 얹으면 `sealedCeiling`이 함께 올라가 더미가 40pt 더 쌓인다(실측) — 안 그래야 할 변경이다.
    private var fieldRestHeight: CGFloat {
        guard !counter.isEmpty else { return .infinity }   // 빈 작업대(카피·CTA)는 캡 대상이 아니다
        return 96 * ceil(CGFloat(counter.count) / 3) + 28
    }

    private var physicsField: some View {
        GeometryReader { geo in
            ZStack {
                // 주의: SpriteView(isPaused:)는 초기화 시점에 멈춰 첫 프레임이 안 그려질 수 있다(회색).
                // 일시정지는 씬이 스스로 관리한다(externallyPaused ∥ idle) — 첫 프레임 이후엔
                // SKView 렌더 루프까지 멈춰(마지막 프레임 정지화면) 가려진 탭의 유휴 CPU를 없앤다.
                // `-physLab`(DEBUG) — 콜라이더 오버레이. 칩 실루엣과 실제 충돌체가 어긋나면
                // 겹침·끼임의 원인이 물리 루프가 아니라 **바디 메트릭**이라, 화면만 봐선 못 가른다.
                SpriteView(scene: scene, options: [.allowsTransparency],
                           debugOptions: physLabDebugOptions)
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

    /// 릴리스에선 항상 빈 집합 — 진단 오버레이는 `#if DEBUG` 경로에만 존재한다.
    private var physLabDebugOptions: SpriteView.DebugOptions {
        #if DEBUG
        IngredientDropScene.physLab ? [.showsPhysics, .showsFPS] : []
        #else
        []
        #endif
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
                    // 캔버스 위 링크 잉크는 blueDark — 면 색인 blue는 다크 캔버스에서 대비가 무너진다(§2.2).
                    Text("Or try a sample fridge")
                        .reffiType(.caption)
                        .foregroundStyle(ReffiColor.blueDark)
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

    /// 커버 입력 3종(덱·호명 이름·미커버 임박)을 **한 번에** 얼린다.
    /// 따로 계산하면 발주로 store가 바뀌는 사이에 서로 다른 시점의 재고를 보게 되고,
    /// 브리지 행이 덱에 실제로 있는 재료를 "안 쓴다"고 말하는 자기모순이 생긴다.
    private func snapshotCarousel() {
        let results = carouselResults
        let stock = store.available
        carouselSnapshot = results
        // 호명은 문장 안에 들어가는 **표시 이름**이다 — 저장 `name`은 담던 순간 표기라 로케일이 박제된다
        // (§Ingredient.displayName). 브리지 문구와 그 옆 영상 검색어가 같은 배열을 쓰므로 여기 한 곳만 고르면 된다.
        atRiskSnapshot = stock.filter { $0.freshness != .fresh }.map(\.displayName)   // available은 이미 임박순
        uncoveredSnapshot = RecipeRecommender.uncoveredUrgent(ingredients: stock, results: results).map(\.displayName)
    }

    private func cook() {
        guard !counter.isEmpty else { return }
        snapshotCarousel()   // 발주로 store가 바뀌어도 커버 입력은 고정(재랭크 방지)
        firedTicket = false
        coverGeneration += 1                 // 이전 발주의 지연 닫기 타이머 무효화
        // 커버 표시를 한 틱 지연 — 80레시피 스코어링(carouselResults)과 커버 첫 프레임이
        // 같은 틱에 겹쳐 프레임드롭 나지 않게 랭킹 계산 틱과 표시 틱을 분리한다.
        DispatchQueue.main.async { showCarousel = true }
    }

    /// 티켓 발주(Fire the Ticket) — used 재료를 이 레시피로 전량 소비 처리 → 슬램 본 뒤 커버 닫기.
    /// 되돌리기 토스트는 store의 통합 undo가 띄운다. 커버당 1회만(더블 파이어 방지).
    ///
    /// **이 창 안에 덱 위로 팝업이 뜰 수 있다**(담기 3단 팝업, 2026-08). 그때 커버를 그냥 닫으면
    /// 사용자가 방금 띄운 질문이 부모와 함께 걷힌다 — 그래서 닫기는 취소가 아니라 **보류**가 되고,
    /// 흐름이 끝나는 순간 이어서 실행된다(`onToBuyPresentationChange`). 세대 검사는 그대로다.
    private func fire(_ result: RecipeRecommender.Result) {
        guard !firedTicket, !result.used.isEmpty else { return }
        firedTicket = true
        fireHaptic += 1
        // 스토어 변이는 애니메이션 밖에서 — 슬램 연출은 OrderMemoCard 로컬 fired 상태가 구동하고,
        // 메인 뱃지·씬 변화는 커버 뒤라 애니메이션이 필요 없다(전환 프레임드롭 방지).
        store.cook(result)
        let gen = coverGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.fireDismissDelaySeconds) {
            guard coverGeneration == gen else { return }   // 새로 연 커버는 닫지 않는다
            if toBuyOverDeck { pendingDeckDismiss = true } else { showCarousel = false }
        }
    }

    /// 발주 후 덱 커버가 닫히기까지의 유예(초) — 슬램 도장을 볼 시간이다.
    /// 이름을 아래 순수 함수와 다르게 둔 것은 의도다(같은 이름이면 프로퍼티 호출로 읽혀 모호해진다).
    private static var fireDismissDelaySeconds: Double {
        #if DEBUG
        return fireDismissDelay(from: ProcessInfo.processInfo.arguments)
        #else
        return defaultFireDismissDelay
        #endif
    }

    static let defaultFireDismissDelay: Double = 1.25

    #if DEBUG
    /// `-fireDismissDelay <초>` — 위 창을 넓히는 QA 훅. 1.25초는 UI 테스트가 "그 창 안에서 팝업을
    /// 띄우고 유예가 실제로 걸리는지"를 재현하기엔 너무 좁다(10차 선례에서 6초를 썼다).
    /// 뷰에서 분기를 늘리는 대신 **순수 함수**로 떼어 유닛 테스트로 고정한다
    /// (`FridgeTab.initial(from:)`·`tiltLabLaunchConfig` 선례). 값 파싱은 `arguments` 직접 순회다 —
    /// UserDefaults 인자로 두면 음수·소수 표기에서 바인딩을 잃는다.
    static func fireDismissDelay(from arguments: [String]) -> Double {
        guard let i = arguments.firstIndex(of: "-fireDismissDelay"), i + 1 < arguments.count,
              let value = Double(arguments[i + 1]), value > 0 else { return defaultFireDismissDelay }
        return value
    }
    #endif
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

    /// 판정 블롭 한 변 — 버튼이 셋이면 72, 둘이면 기본 88.
    /// 가장 좁은 지원 기기(375) 기준 가용 폭은 375 − 외곽 s7×2(64) − 카드 s6×2(56) = **255**인데,
    /// 88×3 + s4×2 = 296이라 41pt가 종이 밖으로 새어 나갔다. 72×3 + s4×2 = 248 ≤ 255로 들어온다
    /// (72도 §7.3 최소 터치 타깃 44를 크게 웃돈다). 두 버튼 경로는 88×2 + s6 = 204라 그대로 둔다.
    private var blobSide: CGFloat { showFreeze ? 72 : 88 }

    /// 세로 폴백의 블롭 한 변 — 행이 최대 셋 쌓이므로 가로 폼보다 작게 잡는다(56 × 3 + s3 × 2 = 192).
    /// 큰 글자에서 제목·문구가 이미 세로를 크게 먹는 커버라, 블롭을 그대로 두면 카드가 화면을 넘긴다.
    /// 56도 §7.3 최소 터치 타깃 44를 넘고, 행 전체가 타깃이라 실제로 눌리는 면은 더 넓다.
    private static let stackedBlobSide: CGFloat = 56

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
                // 바깥 s7 마진은 카드에 **제안**으로만 전해진다 — 제안을 무시하는 자식(고정 frame·끊기지
                // 않는 긴 낱말)만이 종이를 마진 밖으로 밀어낼 수 있다. 블롭은 위 `blobSide`가 잡았고,
                // 남은 하나가 이 이름이다(냉장고 카드·간편 행도 같은 이유로 이름을 한 줄로 묶는다).
                Text(verbatim: ingredient.displayName).reffiType(.heading).foregroundStyle(ReffiColor.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                Text("Did you eat it, or toss it?")
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
            }
            outcomeRow
            keepIt
        }
        .padding(.horizontal, ReffiSpace.s6)
        .padding(.top, ReffiSpace.s6)
        .padding(.bottom, ReffiSpace.s3)
        .background {
            let shape = PaperRect(cornerRadius: ReffiRadius.xl)
            shape.fill(ReffiColor.canvas).paperEdge(shape)
        }
        .reffiShadow1()
        .padding(.horizontal, ReffiSpace.s7)
    }

    /// 판정 버튼들 — 가로 한 줄이 **들어가면** 지금 그대로, 안 들어가면 세로 세 행으로 접는다.
    /// 큰 글자에서 'Tossed'가 'To…'로 잘리던 자리다(1라운드 이연분): 라벨을 2줄로 풀면 버튼마다
    /// 줄 수가 갈려 블롭 세로 정렬이 어긋나므로, 줄을 늘리는 대신 **배치를 통째로 바꾼다**.
    /// 세로 폼은 블롭 좌 · 라벨 우의 행이라 라벨이 폭을 다투지 않고, 읽는 순서도 그대로 남는다.
    private var outcomeRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: showFreeze ? ReffiSpace.s4 : ReffiSpace.s6) {
                outcomeButtons(size: blobSide, placement: .below)
            }
            VStack(spacing: ReffiSpace.s3) {
                outcomeButtons(size: Self.stackedBlobSide, placement: .trailing)
            }
        }
    }

    /// 두 배치가 **같은 버튼 셋**을 같은 순서로 세운다 — 손으로 두 번 쓰면 한쪽만 조용히 어긋난다.
    @ViewBuilder
    private func outcomeButtons(size: CGFloat, placement: PaperIconLabel.Placement) -> some View {
        PaperIconButton(icon: ReffiIcon.toss, label: "Tossed", intent: .soft,
                        size: size, seed: 0, placement: placement,
                        capsLabelWidth: false) { onCommit(false) }
        if showFreeze {
            PaperIconButton(icon: ReffiIcon.freeze, label: "Freeze", intent: .neutral,
                            size: size, seed: 2, placement: placement,
                            capsLabelWidth: false) { onFreeze() }
        }
        PaperIconButton(icon: ReffiIcon.ate, label: "Ate", intent: .primary,
                        size: size, seed: 1, placement: placement,
                        capsLabelWidth: false) { onCommit(true) }
    }

    private var keepIt: some View {
        Button { onCancel() } label: {
            Text("Keep it")
                .reffiType(.caption)
                .foregroundStyle(ReffiColor.ink2)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.reffiPress)
    }
}
