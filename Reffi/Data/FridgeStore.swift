import Foundation
import Observation
import os

/// 냉장고 상태 — 앱의 단일 소스. 모든 변경은 메서드를 통해 일어나고 즉시 디스크(JSON)에 저장된다.
/// 메인의 "작업대"(물리 더미에 올라온 재료)와 되돌리기(undo)도 여기 살아서, 탭을 오가도 유지된다.
///
/// 발주(Fire the Ticket)는 **예약 모델**: fire 시점엔 재료를 예약만 하고(작업대·추천에서 제외),
/// 재고 차감·이력 기록은 Finish cooking에서 확정된다 — 조리 포기는 예약 해제로 되돌아간다.
@MainActor
@Observable
final class FridgeStore {
    private(set) var ingredients: [Ingredient]
    /// 시드 레시피(번들 recipes-seed.json) — 하드코딩 금지 규칙에 따라 데이터는 전부 번들/영속화.
    private let seedRecipes: [Recipe]
    /// 사용자 커스텀 레시피 — 스냅샷에 영속화.
    private(set) var userRecipes: [Recipe]
    /// 추천 풀 = 커스텀 + 시드(커스텀 우선 — 내가 만든 레시피가 위로).
    var recipes: [Recipe] { userRecipes + seedRecipes }
    /// 소비/버림 이력 — History·낭비율의 소스(최신이 앞).
    private(set) var history: [RemovalLog]
    /// 이력 트림으로 접힌 과거 누계(전체 Ate/Tossed 카운트 보존용).
    private(set) var archivedAte: Int
    private(set) var archivedTossed: Int
    /// "이번엔 안 살" 항목 — toBuy에서 제외.
    private(set) var dismissedToBuy: Set<String>
    /// 직접 담은 장보기 항목 — 이력 제안(파생 `toBuy`)을 **보완**하는 수동 메모.
    /// 이력에 없는 품목(한 번도 안 써본 재료)은 파생으로는 원천적으로 뜰 수 없어 여기에만 산다.
    private(set) var manualToBuy: [ManualBuyItem]
    /// 메인 작업대(§13.6) — 물리 더미에 올라온 재료. 빈 자리는 다음 임박 재료가 채운다.
    private(set) var counterIDs: [UUID]
    /// 방금 처리한 판정/발주의 되돌리기 창(6초). 탭 전환에도 살아남는다.
    private(set) var pendingUndo: PendingUndo?
    /// 발주 후 "지금 요리 중" 세션(§13.6 C) — 메인 상단 카드의 소스. Finish/Cancel로 닫는다.
    private(set) var activeCook: CookSession?

    /// 조리 세션 스냅샷. 단계(steps·completedSteps)는 더 이상 담지 않는다 — 앱이 조리 단계를 보여주지
    /// 않으므로(조리법은 영상 링크가 맡는다) 저장할 이유가 없다. 옛 파일에 남은 두 키는 디코드 시
    /// 그냥 무시된다(Codable은 모르는 키를 버린다) — 마이그레이션 불필요.
    struct CookSession: Codable, Equatable {
        var recipeName: String
        var recipeID: String?             // 원본 레시피 되찾기(히어로 아이콘 체인) — 구버전 세션엔 없음
        var startedAt: Date
        var count: Int                    // 발주로 예약한 재료 수
        var minutes: Int?                 // 조리 시간(공유 카드 표시용) — 구버전 세션엔 없음
        var usedIDs: [UUID]?              // 예약된 재료 — v1 세션(발주 즉시 소비)엔 없음
    }

    /// 장보기 목록에 손으로 얹은 한 줄. 키가 아니라 **항목**으로 저장한다 — 정규화 키만 남기면
    /// 사용자가 적은 표기(이력 원문 "서울우유1L")로 다시 그려줄 수 없다. 반대로 사전 표제어를
    /// 그대로 담은 줄은 **표시할 때** 현재 로케일 표제어로 다시 푼다(`FridgeStore.displayName(for:)`).
    struct ManualBuyItem: Codable, Equatable, Identifiable {
        var name: String            // 담을 때의 표기 원문(화면 표기는 displayName(for:)이 정한다)
        var canonicalID: String?    // 정본 사전 캐논 ID — 사전 밖 이름이면 nil
        var glyph: FoodGlyph

        var id: String { matchKey }
        /// 재료 동일성 키 — Ingredient/RemovalLog와 같은 규칙(표기 무관 비교).
        var matchKey: String { canonicalID ?? name.lowercased() }
    }

    /// 예약된 재료(조리 중) — 작업대·추천에서 제외된다.
    var reservedIDs: Set<UUID> { Set(activeCook?.usedIDs ?? []) }

    /// 첫 실행(데이터 전무) 여부 — 온보딩 빈 상태에서 샘플 CTA를 보여줄지.
    /// **직접 담은 장보기 메모도 사용자 데이터다**: 이 값이 true면 호출부가 확인 없이
    /// `loadSampleData()`(복구 불가 — pendingUndo까지 지운다)를 실행하므로, 냉장고·이력이 비어도
    /// 손으로 적은 To buy 메모가 있으면 '데이터 전무'가 아니다(빈 냉장고 + 메모만 있는 상태는
    /// 이력 없이도 만들어진다 — 파생 제안이 원천적으로 못 뜨는 그 자리를 메모가 채운다).
    var isPristine: Bool { ingredients.isEmpty && history.isEmpty && manualToBuy.isEmpty }

    private let persists: Bool
    private let counterCapacity = 6
    /// 냉동 재료는 유예 임박(D-3 이내)에만 작업대로 올라온다 — 오늘의 행동 표면은 '지금 상해가는 것'.
    private let frozenCounterWindow = 3
    /// 이력 상한 — 넘치면 오래된 로그를 접어 누계로 보존(카운트는 안 잃는다).
    private let historyCap = 2000
    /// undo 창이 한참 지난 로그의 복원 스냅샷은 비워 파일을 가볍게(60일).
    private let snapshotRetentionDays = 60

    static let currentSchemaVersion = 2
    /// `nonisolated`인 이유: 이 클래스는 `@MainActor`라 static 프로퍼티도 메인 격리를 물려받는데,
    /// 영속화 쓰기는 `ioQueue`(비격리 Sendable 클로저)에서 실패를 남긴다. `Logger`는 Sendable이므로
    /// 격리를 벗기는 것이 맞다 — 안 벗기면 그 자리가 경고로 남고, 다음 사람이 로그를 지워서 지운다.
    nonisolated static let log = Logger(subsystem: "com.reffi.app", category: "store")

    // MARK: - Init / 영속화

    /// 앱 기동용 — 디스크에서 복원. 디코드 실패 파일은 **덮어쓰지 않고 격리**한 뒤 빈 상태로 시작한다.
    init() {
        persists = true
        seedRecipes = RecipeCatalog.loadSeed()
        var snap: Snapshot?
        if let data = try? Data(contentsOf: Self.storeURL) {
            snap = Self.decodeSnapshot(data)
            if snap == nil {
                Self.quarantineStore()
            }
        }
        ingredients = snap?.ingredients ?? []
        history = snap?.history ?? []
        archivedAte = snap?.archivedAte ?? 0
        archivedTossed = snap?.archivedTossed ?? 0
        dismissedToBuy = snap?.dismissedToBuy ?? []
        manualToBuy = snap?.manualToBuy ?? []   // 구버전 파일엔 없음 → 빈 목록
        counterIDs = snap?.counterIDs ?? []
        activeCook = snap?.activeCook
        userRecipes = snap?.userRecipes ?? []
        resolveCanonicalIDs()   // 레거시 데이터 승격(nil→사전) — persist는 다음 변이 때 자연 기록
        let have = Set(ingredients.map(\.id))
        counterIDs.removeAll { !have.contains($0) }   // 스테일 정리
        replenishCounter()
        promoteUrgent()   // 콜드 오픈 정렬 — 저장된 작업대가 더 임박한 재료를 놓치고 있으면 승격(알림 정합)
    }

    /// 프리뷰·테스트용 — 메모리 전용(저장 안 함, 알림 재스케줄도 안 함).
    init(ingredients: [Ingredient],
         recipes: [Recipe]? = nil,
         history: [RemovalLog] = []) {
        persists = false
        seedRecipes = recipes ?? RecipeCatalog.loadSeed()
        userRecipes = []
        self.ingredients = ingredients
        self.history = history
        archivedAte = 0
        archivedTossed = 0
        dismissedToBuy = []
        manualToBuy = []
        counterIDs = []
        resolveCanonicalIDs()   // 메모리 스토어도 로드 규칙과 일관되게 해석(프리뷰·테스트)
        replenishCounter()
    }

    /// nil canonicalID를 사전으로 1회 해석 — 재료·이력 모두 승격(표기 무관 매칭의 전제).
    /// 레거시 파일·샘플 데이터는 캐논 키가 없어, 로드 시 한 번 채워야 교차 표기(양파↔onion) 매칭이 산다.
    private func resolveCanonicalIDs() {
        let lex = IngredientLexicon.shared
        for i in ingredients.indices where ingredients[i].canonicalID == nil {
            ingredients[i].canonicalID = lex.canonicalID(for: ingredients[i].name)
        }
        for i in history.indices where history[i].canonicalID == nil {
            history[i].canonicalID = lex.canonicalID(for: history[i].name)
        }
    }

    /// dismissedToBuy 저장값 → matchKey 정규화. 캐논 ID로 저장된 값은 그대로, 그 외는 이름으로 해석
    /// (레거시 저장값=원문 이름 호환). 캐논 ID를 name 조회에 넣으면 포함 매칭 오탐이 나므로 먼저 ID 판별.
    private func dismissKey(_ stored: String) -> String {
        let lex = IngredientLexicon.shared
        if lex.entry(id: stored) != nil { return stored }
        return lex.canonicalID(for: stored) ?? stored.lowercased()
    }

    /// 영속 스냅샷. 이전 버전이 기록한 `aiRecipes` 키는 더 이상 선언하지 않는다 —
    /// JSONDecoder는 모르는 키를 무시하므로 AI 기능 제거 전에 저장된 파일도 그대로 열린다
    /// (다음 persist에서 자연스럽게 사라진다). 필드 추가는 반드시 옵셔널+기본값으로.
    struct Snapshot: Codable {
        var schemaVersion: Int?            // v1 파일엔 없음(nil = 1)
        var ingredients: [Ingredient]
        var history: [RemovalLog]
        var dismissedToBuy: Set<String>
        var counterIDs: [UUID]
        var activeCook: CookSession?
        var userRecipes: [Recipe]?         // v2
        var archivedAte: Int?              // v2
        var archivedTossed: Int?           // v2
        var manualToBuy: [ManualBuyItem]? = nil   // v2 — 직접 담은 장보기 항목(옵셔널+기본값)
    }

    static var storeURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Reffi", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("fridge-v1.json")
    }

    /// 스냅샷 디코드 — 필드 추가는 반드시 옵셔널+기본값으로(규약). 비호환 변경은 schemaVersion 분기.
    static func decodeSnapshot(_ data: Data) -> Snapshot? {
        do {
            return try JSONDecoder().decode(Snapshot.self, from: data)
        } catch {
            log.error("snapshot decode failed: \(String(describing: error))")
            return nil
        }
    }

    /// 손상/비호환 파일 격리 — `fridge-v1.corrupt-<ts>.json`으로 보존(조용한 데이터 소실 방지).
    private static func quarantineStore() {
        let ts = Int(Date().timeIntervalSince1970)
        let dest = storeURL.deletingLastPathComponent()
            .appendingPathComponent("fridge-v1.corrupt-\(ts).json")
        do {
            try FileManager.default.moveItem(at: storeURL, to: dest)
            log.error("store quarantined to \(dest.lastPathComponent)")
        } catch {
            log.error("store quarantine failed: \(String(describing: error))")
        }
    }

    /// 디스크 쓰기 직렬 큐 — 순서 보장(FIFO), 메인 스레드에서 IO를 떼어낸다.
    private static let ioQueue = DispatchQueue(label: "com.reffi.app.store-io", qos: .utility)

    /// 스냅샷 저장(+기본으로 임박 알림 재스케줄). 인코드는 메인에서 값을 캡처하고 쓰기는 직렬 큐로.
    /// 재료가 안 바뀌는 변이(작업대 교체·쇼핑 skip·커스텀 레시피)는 `reschedulesAlerts: false`로
    /// 알림 재구성을 건너뛴다 — 판정 제스처의 메인 스레드 비용을 줄인다.
    /// 메모리 전용 스토어(프리뷰·테스트)는 아무것도 하지 않는다.
    private func persist(reschedulesAlerts: Bool = true) {
        guard persists else { return }
        trimHistoryIfNeeded()
        if reschedulesAlerts { ExpiryNotifier.reschedule(for: ingredients) }
        let snap = Snapshot(schemaVersion: Self.currentSchemaVersion,
                            ingredients: ingredients, history: history,
                            dismissedToBuy: dismissedToBuy, counterIDs: counterIDs,
                            activeCook: activeCook, userRecipes: userRecipes,
                            archivedAte: archivedAte, archivedTossed: archivedTossed,
                            manualToBuy: manualToBuy)
        do {
            let data = try JSONEncoder().encode(snap)
            let url = Self.storeURL
            Self.ioQueue.async {
                do { try data.write(to: url, options: .atomic) }
                catch { Self.log.error("persist write failed: \(String(describing: error))") }
            }
        } catch {
            Self.log.error("persist encode failed: \(String(describing: error))")
        }
    }

    /// 이력 관리 — ① 60일 지난 로그의 undo 스냅샷 제거(파일 다이어트)
    /// ② 상한 초과분은 삭제하되 Ate/Tossed 누계로 접어 보존.
    private func trimHistoryIfNeeded() {
        let cutoff = Ingredient.day(offset: -snapshotRetentionDays)
        for i in history.indices where history[i].snapshot != nil && history[i].removedAt < cutoff {
            history[i].snapshot = nil
        }
        guard history.count > historyCap else { return }
        let overflow = history.suffix(history.count - historyCap)   // 최신이 앞 → 뒤가 가장 오래됨
        archivedAte += overflow.lazy.filter { !$0.wasted }.count
        archivedTossed += overflow.lazy.filter(\.wasted).count
        history.removeLast(history.count - historyCap)
    }

    // MARK: - 조회

    /// 마감 임박 오름차순(§8.1, 냉동은 유예 시계 기준) — 위에서부터 "먹어야 할 순서".
    var sorted: [Ingredient] {
        ingredients.sorted { $0.effectiveDaysLeft < $1.effectiveDaysLeft }
    }

    /// 예약(조리 중) 제외 재고 — 추천·작업대 보충의 후보.
    var available: [Ingredient] {
        let reserved = reservedIDs
        return sorted.filter { !reserved.contains($0.id) }
    }

    /// 메인 작업대 재료 — 임박순.
    var counterIngredients: [Ingredient] {
        let byID = Dictionary(ingredients.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return counterIDs.compactMap { byID[$0] }
            .sorted { $0.effectiveDaysLeft < $1.effectiveDaysLeft }
    }

    /// 스와이프 덱 — 점수순 추천. 후보는 **전체 가용 재고**(작업대 6개 한정 아님) — 티켓이 쓰는
    /// 재료가 냉장고에 있으면 함께 소비 처리돼 유령 재고가 남지 않는다.
    /// `preferences`(프로필 취향)를 넘기면 알레르기 하드 필터·선호/기피/요리스타일 보정이 적용된다
    /// (기본 `.none`은 순수 freshness — FridgeStore는 ProfileStore에 결합하지 않고 호출부가 주입).
    func rankedRecipes(preferences: RecipePreferences = .none) -> [RecipeRecommender.Result] {
        RecipeRecommender.rank(for: available, from: recipes, preferences: preferences)
    }

    // MARK: - 추가/편집/삭제

    /// 재료 추가 — 어느 입구(메인 ＋, 네비 ＋, 재입고)로 들어와도 작업대에 함께 올라온다
    /// (직접 추가는 보충 목표 6을 일시 초과할 수 있다 — 방금 넣은 한 개를 바로 작업대에서 보이게).
    /// 재입고는 '이번엔 안 사기'를 해제한다.
    func add(_ ingredient: Ingredient) {
        insert([ingredient], capsCounter: false)
    }

    /// 일괄 추가(영수증 스캔) — N개를 넣어도 스냅샷 기록·알림 재스케줄은 1회만. 직접 추가와 달리
    /// 작업대는 상한(6)까지만 채운다 — 스캔 한 번에 15개가 쏟아져도 작업대가 넘치지 않게, 최임박 재료부터
    /// 올리고 나머지는 냉장고에만 둔다(빈 자리가 나면 replenishCounter가 다음 임박 재료로 자연 보충).
    func add(contentsOf newItems: [Ingredient]) {
        insert(newItems, capsCounter: true)
    }

    /// 추가 공통 — 캐논 승격·재입고 스킵 해제는 두 경로 동일. 작업대 등재만 다르다:
    /// 직접 추가(`capsCounter=false`)는 일시 초과 허용(무조건 등재), 일괄 스캔(`capsCounter=true`)은
    /// 상한까지만 — replenishCounter가 available(임박순, counterEligible 적용)로 빈 자리를 채운다.
    private func insert(_ newItems: [Ingredient], capsCounter: Bool) {
        guard !newItems.isEmpty else { return }
        let lex = IngredientLexicon.shared
        for item in newItems {
            var ingredient = item
            if ingredient.canonicalID == nil {   // 해석 시점 — 미해석 재료를 캐논 키로 승격
                ingredient.canonicalID = lex.canonicalID(for: ingredient.name)
            }
            ingredients.append(ingredient)
            if !capsCounter, !counterIDs.contains(ingredient.id) {
                counterIDs.append(ingredient.id)   // 직접 추가 — 일시 초과 허용
            }
            // 재입고면 '이번엔 안 사기'를 해제 — matchKey(캐논/이름) 기준으로 비교.
            let key = ingredient.matchKey
            dismissedToBuy = dismissedToBuy.filter { dismissKey($0) != key }
            // 직접 담아둔 장보기 메모도 함께 내린다 — 어느 입구로 들어왔든 '샀다'는 사실은 같다.
            manualToBuy.removeAll { $0.matchKey == key }
        }
        if capsCounter { replenishCounter() }   // 스캔 — 상한(6)까지 최임박 우선 등재, 나머지는 냉장고에
        persist()
    }

    /// 편집 저장 — 같은 id를 찾아 교체. 이름이 바뀌면 글리프·카테고리도 다시 매칭(파생값 동기화).
    func update(_ ingredient: Ingredient) {
        guard let i = ingredients.firstIndex(where: { $0.id == ingredient.id }) else { return }
        var updated = ingredient
        if ingredients[i].name != ingredient.name {
            updated.glyph = FoodGlyph.match(ingredient.name)
            updated.category = updated.glyph.categoryLabel
            updated.canonicalID = IngredientLexicon.shared.canonicalID(for: ingredient.name)   // 이름 바뀌면 캐논 키 재해석
        }
        ingredients[i] = updated
        persist()
    }

    /// 이력 없는 삭제 — 오입력·중복 정정용. 통계(낭비율·쇼핑리스트)를 오염시키지 않는다.
    ///
    /// **되돌리기 창을 연다(룰⑧)** — 커먼 룰이 재료삭제를 약한 `.confirmationDialog`로 분류한 근거가
    /// "`pendingUndo` 기반 undo 토스트가 떠서 dialog로 충분"인데, 정작 이 경로는 `beginUndo`를 부르지
    /// 않아 전제가 비어 있었다(감사 R4-3). 확인 강도는 그대로 두고 안전망만 더한다.
    ///
    /// 이력 로그를 만들지 않는 삭제라 `logIDs`가 아니라 `restoreSnapshots`로 원본을 들고 있는다 —
    /// 로그를 만들면 6초 동안(그리고 되돌리지 않으면 영구히) 낭비율·쇼핑리스트가 오염돼
    /// "이력 없는 삭제"라는 이 함수의 정의가 깨진다.
    func remove(_ ingredient: Ingredient) {
        guard let removed = ingredients.first(where: { $0.id == ingredient.id }) else { return }
        let counterBefore = counterIDs
        ingredients.removeAll { $0.id == ingredient.id }
        counterIDs.removeAll { $0 == ingredient.id }
        detachFromCookSession(ingredient.id)
        replenishCounter()
        beginUndo(.removed(name: removed.name), logIDs: [], counterSnapshot: counterBefore,
                  restoreSnapshots: [removed])
        persist()
    }

    /// 냉동(버리기 직전 구제, §13.6) — 원본 소비기한은 두고 `frozenAt`을 기록해
    /// 유예 14일의 새 시계를 부여한다. 재냉동은 불가(1회 제한 — 미루기 버튼 방지).
    func freeze(_ ingredient: Ingredient) {
        guard let i = ingredients.firstIndex(where: { $0.id == ingredient.id }),
              ingredients[i].canFreeze else { return }
        ingredients[i].storage = .freezer
        ingredients[i].frozenAt = Date()
        counterIDs.removeAll { $0 == ingredient.id }   // 유예 임박(D-3)에 다시 올라온다
        replenishCounter()
        persist()
    }

    // MARK: - 판정(Ate / Tossed)

    /// 다 먹음 — 보유에서 빼고 이력 기록. 되돌리기 창이 열린다.
    func eat(_ ingredient: Ingredient) { decide(ingredient, wasted: false) }
    /// 버림 — 보유에서 빼고 이력 기록. 되돌리기 창이 열린다.
    func toss(_ ingredient: Ingredient) { decide(ingredient, wasted: true) }

    private func decide(_ ingredient: Ingredient, wasted: Bool) {
        guard ingredients.contains(where: { $0.id == ingredient.id }) else { return }
        let counterBefore = counterIDs   // undo가 작업대를 판정 전 상태로 원복(§13.6)
        let log = removeLogging(ingredient, wasted: wasted, via: nil)
        replenishCounter()
        beginUndo(.decision(name: ingredient.name, wasted: wasted),
                  logIDs: [log.id], counterSnapshot: counterBefore)
        persist()
    }

    // MARK: - 발주(Fire the Ticket) — 예약 모델

    /// 티켓 발주 — 재료를 **예약**한다(§13.6 START 슬램은 연출, 데이터 확정은 Finish에서).
    /// 예약 재료는 작업대·추천에서 빠지고, undo(6초)나 조리 취소로 그대로 돌아온다.
    func cook(_ result: RecipeRecommender.Result) {
        let have = Set(ingredients.map(\.id))
        let used = result.used.filter { have.contains($0.id) }
        guard !used.isEmpty else { return }
        let counterBefore = counterIDs
        // 진행 중 세션이 있으면 교체 — 이전 예약은 자동 해제되고, undo가 이전 세션을 복원한다.
        let replaced = activeCook
        activeCook = CookSession(recipeName: result.recipe.displayName, recipeID: result.recipe.id,
                                 startedAt: Date(),
                                 count: used.count, minutes: result.recipe.minutes,
                                 usedIDs: used.map(\.id))
        let reserved = reservedIDs
        counterIDs.removeAll { reserved.contains($0) }
        replenishCounter()
        beginUndo(.fired(recipe: result.recipe.displayName, count: used.count),
                  logIDs: [], counterSnapshot: counterBefore, previousSession: replaced)
        persist()
    }

    /// 요리 완료 — 예약 재료의 소비를 **확정**한다(이력 기록·재고 차감은 여기서).
    /// `leftovers`에 담긴 재료는 남은 것 — 수량을 절반으로 줄이고 냉장고에 남긴다.
    /// v1 세션(usedIDs 없음 — 발주 시점에 이미 소비됨)은 세션만 닫는다.
    func finishCooking(leftovers: Set<UUID> = []) {
        guard let cook = activeCook else { return }
        dismissStaleFireUndo()   // 발주 토스트가 완료 뒤까지 살아남아 가짜 원복을 하지 않게
        let counterBefore = counterIDs
        var logIDs: [UUID] = []
        var leftoverOriginals: [Ingredient] = []
        for id in cook.usedIDs ?? [] {
            guard let i = ingredients.firstIndex(where: { $0.id == id }) else { continue }
            if leftovers.contains(id) {
                leftoverOriginals.append(ingredients[i])   // undo용 원본(절반 전) 보존
                ingredients[i].quantity = ingredients[i].quantity.halved
            } else {
                logIDs.append(removeLogging(ingredients[i], wasted: false, via: cook.recipeName).id)
            }
        }
        activeCook = nil
        replenishCounter()
        if !logIDs.isEmpty || !leftoverOriginals.isEmpty {
            beginUndo(.finished(recipe: cook.recipeName, count: logIDs.count),
                      logIDs: logIDs, counterSnapshot: counterBefore,
                      leftoverSnapshots: leftoverOriginals, previousSession: cook)
        }
        persist()
    }

    /// 조리 포기 — 예약 해제. 재료는 그대로 냉장고·작업대로 돌아온다(기록 없음).
    func cancelCooking() {
        guard activeCook != nil else { return }
        dismissStaleFireUndo()   // 취소된 발주의 'Started' 토스트 잔존 방지
        activeCook = nil
        replenishCounter()
        persist()
    }

    /// 발주(.fired) 되돌리기 창 무효화 — 세션이 완료/취소로 이미 닫힌 뒤의 스테일 undo 방지.
    private func dismissStaleFireUndo() {
        if case .fired = pendingUndo?.kind { pendingUndo = nil }
    }

    /// 제거 공통 — 이력에 복원 스냅샷과 함께 남긴다. 조리 세션에 예약돼 있었다면 함께 정리한다
    /// (Fridge 탭에서 예약 재료를 판정해도 'N used' 카운트·완료 시트가 어긋나지 않게).
    @discardableResult
    private func removeLogging(_ ing: Ingredient, wasted: Bool, via: String?) -> RemovalLog {
        let log = RemovalLog(name: ing.name, glyph: ing.glyph, canonicalID: ing.canonicalID,
                             wasted: wasted, via: via, snapshot: ing)
        history.insert(log, at: 0)
        ingredients.removeAll { $0.id == ing.id }
        counterIDs.removeAll { $0 == ing.id }
        detachFromCookSession(ing.id)
        return log
    }

    /// 조리 세션의 예약 목록에서 재료를 제거하고 카운트를 동기화.
    private func detachFromCookSession(_ id: UUID) {
        guard var cook = activeCook, var ids = cook.usedIDs, ids.contains(id) else { return }
        ids.removeAll { $0 == id }
        cook.usedIDs = ids
        cook.count = ids.count
        activeCook = cook
    }

    /// 작업대 자격 — 유예가 넉넉한 냉동 재료(D-3 초과)는 오늘의 행동 표면에 올리지 않는다.
    private func counterEligible(_ ing: Ingredient) -> Bool {
        !(ing.isFrozen && ing.effectiveDaysLeft > frozenCounterWindow)
    }

    /// 작업대 빈 자리는 아직 안 올라온 다음 임박 재료가 채운다(§13.6).
    /// 예약(조리 중) 재료와, 유예가 넉넉한 냉동 재료는 제외.
    private func replenishCounter() {
        let reserved = reservedIDs
        counterIDs.removeAll { reserved.contains($0) }
        var onCounter = Set(counterIDs)
        for ing in available where counterIDs.count < counterCapacity {
            guard counterEligible(ing) else { continue }
            if onCounter.insert(ing.id).inserted { counterIDs.append(ing.id) }
        }
    }

    /// 임박 승격 — 작업대가 가득 찼을 때, 아직 올라오지 않은 더 임박한 재료를 작업대 내 '가장 여유로운'
    /// 항목과 교체해 알림(오늘·내일 만료)이 가리키는 재료와 메인 작업대를 정합시킨다. 스캔 상한(§Fix3)으로
    /// 냉장고에만 남은 임박 재료가 작업대에 못 오르는 구멍을 콜드 오픈/포그라운드에서 메운다.
    ///
    /// 규칙: 후보(비예약·counterEligible·작업대 밖)의 effectiveDaysLeft가 작업대 내 최대(가장 여유로운)보다
    /// **엄격히 작을 때만** 교체. 회당 최대 2개 스왑(대량 교체로 물리 씬이 출렁이지 않게). 빈 자리는
    /// replenishCounter 담당이라 여기선 '가득 찬' 경우만 손댄다. **라이브 변이 중엔 호출하지 않는다**
    /// (작업대 sticky 유지 — 콜드 오픈/포그라운드에서만 정렬).
    func promoteUrgent() {
        guard counterIDs.count >= counterCapacity else { return }   // 빈 자리는 replenishCounter가 채운다
        let maxSwaps = 2
        var swaps = 0
        while swaps < maxSwaps {
            let byID = Dictionary(ingredients.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            let onCounter = Set(counterIDs)
            // 승격 후보 — 작업대 밖의 가장 임박한 available(available는 임박순·예약 제외).
            guard let candidate = available.first(where: { !onCounter.contains($0.id) && counterEligible($0) })
            else { break }
            // 작업대 안에서 가장 여유로운(effectiveDaysLeft 최대) 항목.
            guard let slack = counterIDs.compactMap({ byID[$0] })
                .max(by: { $0.effectiveDaysLeft < $1.effectiveDaysLeft }),
                  candidate.effectiveDaysLeft < slack.effectiveDaysLeft,   // 엄격히 더 임박할 때만
                  let idx = counterIDs.firstIndex(of: slack.id)
            else { break }
            counterIDs[idx] = candidate.id
            swaps += 1
        }
        if swaps > 0 { persist(reschedulesAlerts: false) }   // 재료 불변 — 알림 재구성 불필요
    }

    // MARK: - 되돌리기 (통합 undo — 판정·발주 공통)

    struct PendingUndo: Equatable {
        enum Kind: Equatable {
            case fired(recipe: String, count: Int)      // 발주(예약) — undo = 예약 해제
            case finished(recipe: String, count: Int)   // 완료(확정) — undo = 세션·수량·이력 원복
            case decision(name: String, wasted: Bool)
            case removed(name: String)                 // 이력 없는 삭제(정정) — undo = 스냅샷 복원
            case memoRemoved(name: String)             // 장보기 메모 한 줄 — undo = 그 줄을 제자리로
        }

        /// 메모 한 줄을 되돌리는 데 필요한 전부 — 재료가 아니라 `ManualBuyItem`이라
        /// `restoreSnapshots`(냉장고 재료) 경로를 탈 수 없다. 다른 undo가 이력에서 되살리는 것과 달리
        /// 메모는 지우면 흔적이 남지 않으므로 항목 자체를 들고 있는다.
        struct MemoRestore: Equatable {
            let item: ManualBuyItem
            /// 지우기 전의 자리 — 되돌린 줄이 목록 맨 끝으로 튀면 "되돌렸다"가 아니라 "다시 담았다"로 읽힌다.
            let index: Int
            /// `skipBuy`가 이번 호출에서 영구 제외에 새로 넣은 키(안 넣었으면 nil) — undo가 그것도 되돌린다.
            let dismissedKey: String?
        }
        let token: UUID       // 세대 토큰 — 이전 창의 만료 타이머가 새 창을 닫지 못하게
        let logIDs: [UUID]
        let kind: Kind
        let counterSnapshot: [UUID]        // 판정 전 작업대 — undo 시 통째로 원복
        var leftoverSnapshots: [Ingredient] = []   // finish의 '남았어요' 절반 처리 전 원본
        /// 이력 로그 없이 지운 재료의 원본 — `logIDs` 경로와 달리 이력에서 되살릴 게 없어 직접 들고 있는다.
        var restoreSnapshots: [Ingredient] = []
        var previousSession: CookSession?          // fired: 교체 전 세션 / finished: 종료된 세션
        var memoRestore: MemoRestore?              // memoRemoved 전용
    }

    /// 되돌리기 창의 길이(초). 기본 6, **VoiceOver가 켜지면 UI 레이어가 늘려 준다**(`RootTabView`) —
    /// 고지를 듣고 토스트로 포커스를 옮겨 Undo까지 가는 데 6초로는 닿지 못한다. 값만 받는 이유는
    /// 이 클래스가 순수 데이터이기 때문이다: 여기서 `UIAccessibility`를 보면 스토어가 UI를 알게 된다.
    var undoWindowSeconds: Double = FridgeStore.defaultUndoWindow
    static let defaultUndoWindow: Double = 6
    static let voiceOverUndoWindow: Double = 14

    private func beginUndo(_ kind: PendingUndo.Kind, logIDs: [UUID], counterSnapshot: [UUID],
                           leftoverSnapshots: [Ingredient] = [],
                           restoreSnapshots: [Ingredient] = [],
                           previousSession: CookSession? = nil,
                           memoRestore: PendingUndo.MemoRestore? = nil) {
        let token = UUID()
        pendingUndo = PendingUndo(token: token, logIDs: logIDs, kind: kind,
                                  counterSnapshot: counterSnapshot,
                                  leftoverSnapshots: leftoverSnapshots,
                                  restoreSnapshots: restoreSnapshots,
                                  previousSession: previousSession,
                                  memoRestore: memoRestore)
        // 창 길이는 **열 때 정해진다** — 도중에 값이 바뀌어도 이미 뜬 토스트의 수명은 흔들리지 않는다.
        let window = undoWindowSeconds
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(window))
            guard let self, self.pendingUndo?.token == token else { return }
            self.pendingUndo = nil
        }
    }

    /// 되돌리기 — 이력에서 해당 로그를 걷어내고 스냅샷을 복원, 작업대는 판정 전 상태로 원복한다.
    /// 발주 undo = 예약 해제(+교체됐던 이전 세션 복원), 완료 undo = 조리 세션 재개 + 절반 수량 원복.
    func undoPending() {
        guard let undo = pendingUndo else { return }
        pendingUndo = nil
        // 메모 되돌리기는 **여기서 끝난다** — 이력도 재고도 작업대도 건드리지 않았으므로 아래의
        // 복원·작업대 재구성 경로를 태울 이유가 없다(태우면 무관한 replenish가 한 번 더 돈다).
        if case .memoRemoved = undo.kind, let memo = undo.memoRestore {
            if let key = memo.dismissedKey { dismissedToBuy.remove(key) }
            // 자리 복원 — 그 사이 목록이 짧아졌으면 끝에 붙인다(인덱스는 힌트지 계약이 아니다).
            let at = min(memo.index, manualToBuy.count)
            if !manualToBuy.contains(where: { $0.matchKey == memo.item.matchKey }) {
                manualToBuy.insert(memo.item, at: at)
            }
            persist(reschedulesAlerts: false)   // 재료 불변
            return
        }
        switch undo.kind {
        case .fired, .finished:
            activeCook = undo.previousSession   // fired: 교체 전(보통 nil) / finished: 종료된 세션 재개
        case .decision, .removed, .memoRemoved:
            break
        }
        // 이력 로그 없이 지운 재료(정정 삭제)는 스냅샷에서 바로 되살린다.
        var restored: [Ingredient] = undo.restoreSnapshots
        for logID in undo.logIDs {
            guard let i = history.firstIndex(where: { $0.id == logID }) else { continue }
            if let snap = history[i].snapshot { restored.append(snap) }
            history.remove(at: i)
        }
        let have = Set(ingredients.map(\.id))
        for ing in restored where !have.contains(ing.id) {
            ingredients.append(ing)
        }
        // '남았어요' 절반 처리 원복 — 반복 undo/finish에도 수량이 드리프트하지 않게 원본으로.
        for original in undo.leftoverSnapshots {
            if let i = ingredients.firstIndex(where: { $0.id == original.id }) {
                ingredients[i] = original
            }
        }
        // 스냅샷 원복도 작업대 자격 규칙(예약 제외·유예 넉넉한 냉동 제외)을 지킨다 —
        // 판정 후 냉동한 재료가 undo로 작업대에 되돌아오는 구멍을 막는다.
        let byID = Dictionary(ingredients.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let reserved = reservedIDs
        counterIDs = undo.counterSnapshot.filter { id in
            guard let ing = byID[id], !reserved.contains(id) else { return false }
            return counterEligible(ing)
        }
        replenishCounter()
        persist()
    }

    func dismissUndo() { pendingUndo = nil }

    // MARK: - 커스텀 레시피

    func addUserRecipe(_ recipe: Recipe) {
        userRecipes.insert(recipe, at: 0)
        persist(reschedulesAlerts: false)
    }

    func updateUserRecipe(_ recipe: Recipe) {
        guard let i = userRecipes.firstIndex(where: { $0.id == recipe.id }) else { return }
        userRecipes[i] = recipe
        persist(reschedulesAlerts: false)
    }

    func deleteUserRecipe(id: String) {
        userRecipes.removeAll { $0.id == id }
        persist(reschedulesAlerts: false)
    }

    // MARK: - 통계 (이력 단일 장부 + 접힌 누계)

    /// 누계 — 헤더의 Ate/Tossed 카운트(트림으로 접힌 과거분 포함).
    var ateCount: Int { archivedAte + history.lazy.filter { !$0.wasted }.count }
    var tossedCount: Int { archivedTossed + history.lazy.filter(\.wasted).count }

    /// 최근 30일 이력 — 정산서 헤더("Tally · past 30 days") 라벨과 계산을 일치시킨다.
    var recentHistory: [RemovalLog] {
        let cutoff = Ingredient.day(offset: -30)
        return history.filter { $0.removedAt >= cutoff }
    }

    /// 최근 30일 중 **발주(레시피 티켓)로 소비된** 건수 — 정산서의 "Cooked into recipes" 행.
    ///
    /// `via`를 붙이는 곳은 `finishCooking` **한 곳**뿐이고(직접 판정은 `via: nil`), 그 경로는 항상
    /// `wasted: false`로 기록한다. 그래도 `!wasted`를 함께 보는 것은 방어다 — 언젠가 버림에도 출처를
    /// 달게 되면 이 행이 조용히 "버린 것도 요리한 것"으로 세기 시작한다.
    ///
    /// 이 수치는 `ateCount`(= `!wasted`)의 **부분집합**이지 별도의 판정이 아니다.
    var cookedCount: Int { recentHistory.lazy.filter { $0.via != nil && !$0.wasted }.count }

    /// 낭비율(%) — 최근 30일 기준: 버림 / (먹음 + 버림).
    var wasteRate: Int {
        let recent = recentHistory
        guard !recent.isEmpty else { return 0 }
        let tossed = recent.lazy.filter(\.wasted).count
        return Int((Double(tossed) / Double(recent.count) * 100).rounded())
    }

    // MARK: - 사야 할 식재료(쇼핑 리스트)

    /// 자주 쓰는데(이력에 있는데) 지금 냉장고엔 없는 = 사야 할 식재료 **제안**. 빈도 많은 순.
    /// 비교는 전부 matchKey(캐논 ID 우선) — 표기(Milk/milk, 양파/onion)가 달라도 한 품목으로 묶인다.
    /// 표시는 최근 로그의 `displayName`(로케일 박제 방지 + 사용자 표기 보존, 전역 단일 정책).
    private var derivedToBuy: [(name: String, glyph: FoodGlyph, key: String)] {
        let inStock = Set(ingredients.map(\.matchKey))
        let dismissed = Set(dismissedToBuy.map(dismissKey))
        let grouped = Dictionary(grouping: history) { $0.matchKey }
        return grouped
            .compactMap { key, logs -> (name: String, glyph: FoodGlyph, key: String, count: Int)? in
                guard let first = logs.first,   // history는 최신이 앞 → 최근 표기
                      !inStock.contains(key),
                      !dismissed.contains(key) else { return nil }
                return (name: first.displayName, glyph: first.glyph, key: key, count: logs.count)
            }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
            .map { (name: $0.name, glyph: $0.glyph, key: $0.key) }
    }

    /// 화면에 뜨는 장보기 목록 — **직접 담은 항목이 맨 위**(내가 적은 게 먼저 읽혀야 한다), 그 아래 이력 제안.
    /// 수동 항목은 재고 보유·'이번엔 안 사기' 필터를 **우회한다**: 지금 있어도 더 사려고 손으로 적은 것이라
    /// 재고 유무로 지울 수 없다(있으면 안 산다는 파생 제안의 전제와 정반대). 같은 품목이 제안으로도 잡히면
    /// 수동이 흡수해 한 줄로만 뜬다.
    /// `key`는 두 갈래(수동 `matchKey` / 파생 `derivedToBuy.key`) 모두 이미 정확한 캐논 키를 들고 있어
    /// 그대로 실어 나른다 — 호출부(Skip 버튼)가 이름을 다시 역조회할 필요 없이 `skipBuy(key:)`로 바로
    /// 넘길 수 있게 한다(이름 역조회로 인한 오귀속 위험을 원천 차단, `addToBuy`/`skipBuy(key:)`와 같은 규약).
    var toBuy: [(name: String, glyph: FoodGlyph, manual: Bool, key: String)] {
        let manualKeys = Set(manualToBuy.map(\.matchKey))
        return manualToBuy.map { (name: Self.displayName(for: $0), glyph: $0.glyph, manual: true, key: $0.matchKey) }
            + derivedToBuy.filter { !manualKeys.contains($0.key) }
                          .map { (name: $0.name, glyph: $0.glyph, manual: false, key: $0.key) }
    }

    /// 수동 항목 한 줄의 **표시 이름** — `Ingredient`·`RemovalLog`와 **같은 함수**를 탄다
    /// (`IngredientLexicon.displayName(stored:canonicalID:)`, 앱 전역 단일 정책).
    ///
    /// 이 줄이 특히 예민한 이유: 저장된 `name`은 담을 때의 표기 스냅샷이라 한국어 기기에서 사전
    /// 타일로 담은 "양파"는 언어를 바꿔도 "양파"로 남는데, 같은 시트의 타일은 "Onion"으로 떠
    /// 한 화면 건너 표기가 갈린다. 반대로 FREQUENT 칩은 이력 원문("서울우유1L")을 이름으로 싣고
    /// 캐논만 `milk`라, 무조건 덮으면 사용자가 적은 그 표기를 잃는다(`ManualBuyItem` 주석의 전제).
    /// 가드형은 두 요구를 동시에 만족시키는 유일한 답이다.
    static func displayName(for item: ManualBuyItem) -> String {
        IngredientLexicon.shared.displayName(stored: item.name, canonicalID: item.canonicalID)
    }

    /// 지금 **메모에 떠 있는** 품목 키 — 검색 시트의 '이미 담김' 도장이 읽는다(행마다 재계산 방지).
    ///
    /// **수동만 센다.** 파생 제안을 목록에서 걷어낸 뒤(2026-08)로는 파생 키까지 합치면 도장이
    /// 거짓말을 한다 — 메모에 없는 품목이 시트에서 '담김'으로 보이고, 실제로 누르면 그때 담긴다
    /// (`appendToBuy`는 `manualToBuy`만 보고 막으므로 그 탭은 no-op이 아니다).
    /// 이 집합은 **표시 전용**이라 담기를 막지 않는다 — 흡수 경로(파생으로만 있던 품목이 수동이 되는 길)는
    /// `appendToBuy`가 그대로 쥐고 있다.
    var toBuyKeys: Set<String> {
        Set(manualToBuy.map(\.matchKey))
    }

    /// 첫 사용자 시드 칩 — **재료 지식이 아니라 노출 순서(UX)**라 코드 상수로 둔다.
    /// 재료 자체의 사실(표기·글리프·기한)은 여전히 `IngredientLexicon`(JSON)에서만 나온다.
    static let frequentSeedIDs = ["egg", "milk", "onion", "green-onion", "tofu", "garlic",
                                  "potato", "carrot", "kimchi", "cucumber", "rice", "chicken"]

    /// 자주 쓰는 재료 — 검색 시트의 원탭 칩 소스. 축은 `derivedToBuy`와 같은 **이력 빈도**지만
    /// **필터가 없다**: 지금 재고에 있어도, '이번엔 안 사기'로 접었어도 뜬다 — 자주 쓰는 건 또 사고,
    /// 이건 제안 목록이 아니라 '빨리 담기' 단축키이기 때문이다(무엇을 담을지는 사용자가 정한다).
    /// 이력 상위가 `limit`에 못 미치면 **부족분을 항상** 큐레이션 시드로 채운다(중복 제거) — 이력이
    /// 3종에서 4종으로 느는 순간 칩이 12개에서 4개로 급감하는 계단식 UX 역행을 막는다. '빈 그리드는
    /// 고장으로 읽힌다'는 원래 설계 의도가 이력 규모와 무관하게 항상 성립해야 한다.
    func frequentIngredients(limit: Int = 12) -> [(name: String, glyph: FoodGlyph, key: String)] {
        let ranked = Dictionary(grouping: history) { $0.matchKey }
            .compactMap { key, logs -> (name: String, glyph: FoodGlyph, key: String, count: Int)? in
                guard let first = logs.first else { return nil }   // history는 최신이 앞 → 최근 표기
                return (name: first.displayName, glyph: first.glyph, key: key, count: logs.count)
            }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
            .prefix(limit)
            .map { (name: $0.name, glyph: $0.glyph, key: $0.key) }

        var out = Array(ranked)
        guard out.count < limit else { return out }
        let lex = IngredientLexicon.shared
        var seen = Set(out.map(\.key))
        for id in Self.frequentSeedIDs where out.count < limit {
            guard !seen.contains(id), let e = lex.entry(id: id) else { continue }
            out.append((name: e.displayName, glyph: FoodGlyph(rawValue: e.glyph) ?? .generic, key: e.id))
            seen.insert(id)
        }
        return out
    }

    /// 장보기 목록에 직접 담기 — 이력 제안이 닿지 못하는 품목을 사용자가 손으로 얹는다.
    /// **재고 추가가 아니라 '살 것' 메모**다(§13.5 To buy 예외 — 실제 반입은 여전히 영수증 스캔·재입고).
    /// 이미 목록에 있으면 아무 것도 하지 않는다(중복 추가 no-op — 시트가 체크 상태로 이미 알린다).
    /// `canonicalID`·`glyph`는 사전에서 고른 호출부가 그대로 넘긴다(이름 역조회로 다른 항목에 붙는 것 방지).
    ///
    /// `canonicalIsFinal`은 "**나는 이미 해석을 끝냈다**"는 신호다. nil을 그렇게 넘기면 = 사전에 없는
    /// 품목이라는 뜻이므로 아래 포함 매칭 폴백을 타지 않는다. 레시피 표기처럼 다른 재료명을 품은
    /// 자유 문장("paprika powder", "chicken or vegetable stock")이 폴백에 걸려 엉뚱한 캐논에 붙는 것을
    /// 막는다 — 그러면 그 품목은 **이미 담긴 다른 재료로 취급돼 목록에 들어가지도 않는다**.
    @discardableResult
    func addToBuy(name: String, canonicalID: String? = nil, glyph: FoodGlyph? = nil,
                  canonicalIsFinal: Bool = false) -> Bool {
        guard appendToBuy(name: name, canonicalID: canonicalID, glyph: glyph,
                          canonicalIsFinal: canonicalIsFinal) else { return false }
        persist(reschedulesAlerts: false)   // 재료 불변
        return true
    }

    /// 메모 한 줄을 **그 줄의 키로** 내린다 — 재입고(`insert`)의 자동 내리기는 냉장고에 들어간
    /// 재료의 `matchKey`(캐논)로 비교하는데, 자유 입력 줄("서울우유", "계란 한 판")의 키는 친 문자열
    /// 그대로라 캐논과 영영 어긋난다: 줄이 안 내려가고, 같은 캐논의 **다른** 줄이 대신 내려간다.
    /// Bought를 누른 행이 무엇인지는 뷰가 이미 알고 있으므로 재해석 없이 그 키로 지운다(멱등 —
    /// insert가 이미 지웠으면 no-op이고, 그 경우 persist는 insert 쪽이 이미 했다).
    func clearToBuy(key: String) {
        let before = manualToBuy.count
        manualToBuy.removeAll { $0.matchKey == key }
        guard manualToBuy.count != before else { return }
        persist(reschedulesAlerts: false)
    }

    /// `addToBuy`의 **저장 없는** 내부 경로 — 판정·흡수 의미론은 전부 여기 있고 `persist`만 호출부가 쥔다.
    /// 루프로 담는 `addMissingToBuy`가 항목마다 전량 스냅샷을 인코딩(메인 스레드)하지 않게 하려는 분리다.
    /// 단건 호출부는 `addToBuy`를 그대로 쓰므로 동작이 바뀌지 않는다.
    /// - Returns: 실제로 목록에 새 줄이 생겼으면 true(= 저장할 변화가 있다).
    private func appendToBuy(name: String, canonicalID: String?, glyph: FoodGlyph?,
                             canonicalIsFinal: Bool = false) -> Bool {
        let lex = IngredientLexicon.shared
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let canonical = canonicalID ?? (canonicalIsFinal ? nil : lex.canonicalID(for: trimmed))
        let key = canonical ?? trimmed.lowercased()
        // 이미 '수동으로' 담긴 것만 중복으로 막는다 — 파생 제안으로만 잡혀 있는 품목은 여기서
        // 걸러지면 안 된다(그래야 아래 append가 그 파생 제안을 흡수해 한 줄로 만든다, toBuy 참고).
        // toBuyKeys(수동∪파생)로 막으면 흡수가 영영 못 일어난다 — skipBuy의 wasManual과 같은 축.
        guard !manualToBuy.contains(where: { $0.matchKey == key }) else { return false }
        manualToBuy.append(ManualBuyItem(name: trimmed, canonicalID: canonical,
                                         glyph: glyph ?? lex.glyph(for: trimmed) ?? FoodGlyph.match(trimmed)))
        return true
    }

    /// 티켓의 부족 재료(Short: …)를 한 번에 장보기 메모로 — 오더 카드의 원탭 담기(§13.5).
    ///
    /// **표시명이 아니라 레시피 항목을 그대로 받는다.** 해석은 `RecipeRecommender.toBuyEntry(for:)`가
    /// ref 우선으로 끝내 사전 표제어·캐논 ID·글리프를 확정해 준다 — 표시명을 넘기면 "pork (or beef)"의
    /// 괄호 **안** 단어가 포함 매칭에 먼저 걸려 엉뚱한 품목 키가 붙는다(시드 실측: pork→beef).
    /// 사전에 없는 서술형 라인은 `canonicalIsFinal`로 넘겨 store 쪽 폴백 역조회까지 끊는다.
    ///
    /// 흡수 의미론은 `addToBuy` 그대로다 — 이미 수동으로 담긴 품목은 세지 않고, 파생 제안으로만
    /// 있던 품목은 수동이 흡수해 한 줄이 된다.
    ///
    /// 저장은 **루프가 끝난 뒤 한 번**이다(`appendToBuy` + 끝에 `persist`) — 항목마다 `addToBuy`를
    /// 부르면 부족 재료 5종짜리 티켓의 원탭 한 번에 전량 스냅샷 인코딩 + 히스토리 트림이 5회 돌아
    /// 알약의 `pop` 첫 프레임과 겹친다. 새로 담긴 게 0이면 저장 자체를 건너뛴다(변화가 없다).
    /// - Returns: **새로 담긴** 개수. 호출부는 0이면 햅틱을 울리지 않는다(아무 일도 안 일어났으므로).
    @discardableResult
    func addMissingToBuy(_ items: [Recipe.Item]) -> Int {
        var added = 0
        for item in items {
            let entry = RecipeRecommender.toBuyEntry(for: item)
            if appendToBuy(name: entry.name, canonicalID: entry.canonicalID,
                           glyph: entry.glyph, canonicalIsFinal: true) {
                added += 1
            }
        }
        if added > 0 { persist(reschedulesAlerts: false) }   // 재료 불변
        return added
    }

    /// 이번엔 안 사기(레거시) — 이름을 사전으로 **역조회**해 키를 만든다. `addToBuy`는 호출부가 캐논 키를
    /// 직접 넘기도록 설계됐는데(이름 역조회로 다른 항목에 붙는 것 방지) 이 함수만 반대 방향이라 규약이
    /// 비대칭이다 — 표기가 갈라지는 이름이 들어오면 잘못된 품목의 키에 붙을 잠재 위험이 있다.
    /// **Deprecated**: 프로덕션 호출부는 전환 완료됐다 — `toBuy` 튜플이 이제 `key`를 실어 나르므로
    /// `ShoppingListView`의 빼기(✕) 버튼은 `skipBuy(key:)`를 쓴다. 이 오버로드는 `ReffiTests`가 이름 기반
    /// 크로스 로케일 시나리오(예: 영문 "Onion"으로 스킵해 한글 "양파" 이력과 같은 캐논에 맞는지)를
    /// 직접 검증하는 데 계속 쓰고 있어 남겨둔다 — 테스트가 이 경로를 그만 쓰게 되면 제거해도 된다.
    func skipBuy(_ name: String) {
        skipBuy(key: IngredientLexicon.shared.canonicalID(for: name) ?? name.lowercased())
    }

    /// 이번엔 안 사기 — 쇼핑 리스트에서 제외. **저장된 키(캐논 ID 또는 matchKey)를 그대로 받는다** —
    /// 호출부가 이미 알고 있는 키를 넘기게 해(`addToBuy`와 같은 규약) 이름 역조회로 인한 오귀속을
    /// 원천적으로 막는다. 직접 담은 항목은 메모 자체를 지운다 — 손으로 얹은 걸 손으로 내리는 것이라,
    /// 영구 제외 목록까지 오염시킬 이유가 없다. 다만 같은 품목이 이력 제안으로도 잡히는 상태면 그
    /// 제안까지 함께 접는다(수동이 흡수하던 제안이 되살아나 같은 줄이 그 자리에 남으면 Skip이 안
    /// 먹은 것처럼 보인다).
    func skipBuy(key: String) {
        let wasManual = manualToBuy.contains { $0.matchKey == key }
        manualToBuy.removeAll { $0.matchKey == key }
        if !wasManual || derivedToBuy.contains(where: { $0.key == key }) {
            dismissedToBuy.insert(key)
        }
        persist(reschedulesAlerts: false)   // 재료 불변
    }

    /// 메모 한 줄 빼기 + **되돌리기 창**(21차) — 밀어서 삭제 전용 경로다.
    ///
    /// `skipBuy(key:)`와 결과는 같고 undo 토스트가 뜨는 것만 다르다. 창이 필요해진 이유는
    /// 어포던스가 바뀌었기 때문이다: 버튼(✕)은 누를 의도 없이 눌리지 않지만 **밀기는 오발이 잦다**
    /// (스크롤하려다, 다른 행을 만지려다). 19차가 확인 다이얼로그를 두지 않기로 한 근거가
    /// "되돌리기 비용이 한 번의 탭"이었는데, 그 근거는 사용자가 **무엇을 지웠는지 알 때만** 성립한다.
    /// 실수로 민 줄은 이름조차 못 보고 사라지므로, 다이얼로그(사전 확인) 대신 토스트(사후 취소)를 세운다.
    ///
    /// 판정을 바꾸지 않고 `skipBuy`를 그대로 태운다 — 흡수·영구 제외의 두 갈래 규칙이 한 곳에만 있어야
    /// 두 경로가 조용히 갈리지 않는다. 이 함수는 그 앞뒤로 스냅샷과 undo 창만 두른다.
    func skipBuyUndoable(key: String) {
        guard let index = manualToBuy.firstIndex(where: { $0.matchKey == key }) else {
            skipBuy(key: key)   // 수동 항목이 아니면 되돌릴 줄이 없다 — 기존 경로 그대로
            return
        }
        let item = manualToBuy[index]
        let wasDismissed = dismissedToBuy.contains(key)
        skipBuy(key: key)
        // 이번 호출이 **새로** 영구 제외에 넣었을 때만 그것도 되돌린다(원래 제외였다면 건드리지 않는다).
        let newlyDismissed = !wasDismissed && dismissedToBuy.contains(key)
        beginUndo(.memoRemoved(name: Self.displayName(for: item)),
                  logIDs: [], counterSnapshot: counterIDs,
                  memoRestore: PendingUndo.MemoRestore(item: item, index: index,
                                                       dismissedKey: newlyDismissed ? key : nil))
    }

    /// 이름으로 최근 이력 스냅샷 조회 — 재입고 프리필(보관·구매처·수량 복원)용. matchKey로 교차 표기 조회.
    func lastSnapshot(named name: String) -> Ingredient? {
        let key = IngredientLexicon.shared.canonicalID(for: name) ?? name.lowercased()
        return history.first { $0.matchKey == key && $0.snapshot != nil }?.snapshot
    }

    // MARK: - 데이터 관리 (MyPage)

    /// 샘플 냉장고 불러오기 — 온보딩 둘러보기/데모용. 기존 데이터를 대체한다(파생 상태 전부 리셋).
    func loadSampleData() {
        ingredients = SampleData.ingredients
        history = SampleData.history
        archivedAte = 0
        archivedTossed = 0
        dismissedToBuy = []
        manualToBuy = []
        counterIDs = []
        pendingUndo = nil
        activeCook = nil
        resolveCanonicalIDs()   // 샘플 데이터도 캐논 키 승격(매칭 일관성)
        replenishCounter()
        persist()
    }

    /// 모든 데이터 초기화 — 빈 냉장고로.
    func resetAllData() {
        ingredients = []
        history = []
        archivedAte = 0
        archivedTossed = 0
        dismissedToBuy = []
        manualToBuy = []
        counterIDs = []
        pendingUndo = nil
        activeCook = nil
        userRecipes = []
        persist()
    }
}
