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
    /// AI 생성 레시피 캐시(오프라인 재사용) — 스냅샷에 영속화. `refreshAIRecipes`가 채운다.
    private(set) var aiRecipes: [Recipe] = []
    /// 추천 풀 = 커스텀 + AI + 시드(커스텀·AI 우선 — 내가 만든/생성한 레시피가 위로).
    var recipes: [Recipe] { userRecipes + aiRecipes + seedRecipes }
    /// 소비/버림 이력 — History·낭비율의 소스(최신이 앞).
    private(set) var history: [RemovalLog]
    /// 이력 트림으로 접힌 과거 누계(전체 Ate/Tossed 카운트 보존용).
    private(set) var archivedAte: Int
    private(set) var archivedTossed: Int
    /// "이번엔 안 살" 항목 — toBuy에서 제외.
    private(set) var dismissedToBuy: Set<String>
    /// 메인 작업대(§13.6) — 물리 더미에 올라온 재료. 빈 자리는 다음 임박 재료가 채운다.
    private(set) var counterIDs: [UUID]
    /// 방금 처리한 판정/발주의 되돌리기 창(6초). 탭 전환에도 살아남는다.
    private(set) var pendingUndo: PendingUndo?
    /// 발주 후 "지금 요리 중" 세션(§13.6 C) — 메인 상단 카드의 소스. Finish/Cancel로 닫는다.
    private(set) var activeCook: CookSession?

    struct CookSession: Codable, Equatable {
        var recipeName: String
        var startedAt: Date
        var count: Int                    // 발주로 예약한 재료 수
        var steps: [String]?              // 단계 레시피(발주 시점 스냅샷) — 구버전 파일 호환용 옵셔널
        var completedSteps: [Int]?        // 체크한 단계 인덱스
        var usedIDs: [UUID]?              // 예약된 재료 — v1 세션(발주 즉시 소비)엔 없음
    }

    /// 예약된 재료(조리 중) — 작업대·추천에서 제외된다.
    var reservedIDs: Set<UUID> { Set(activeCook?.usedIDs ?? []) }

    /// 첫 실행(데이터 전무) 여부 — 온보딩 빈 상태에서 샘플 CTA를 보여줄지.
    var isPristine: Bool { ingredients.isEmpty && history.isEmpty }

    private let persists: Bool
    private let counterCapacity = 6
    /// 냉동 재료는 유예 임박(D-3 이내)에만 작업대로 올라온다 — 오늘의 행동 표면은 '지금 상해가는 것'.
    private let frozenCounterWindow = 3
    /// 이력 상한 — 넘치면 오래된 로그를 접어 누계로 보존(카운트는 안 잃는다).
    private let historyCap = 2000
    /// undo 창이 한참 지난 로그의 복원 스냅샷은 비워 파일을 가볍게(60일).
    private let snapshotRetentionDays = 60
    /// AI 캐시 상한 — 초과 시 오래된(뒤) 것부터 제거.
    private let aiRecipeCap = 30
    /// AI 생성 진행 중(재진입 방지) — 메모리만.
    private var isRefreshingAI = false
    /// 직전 생성의 재시도 시그니처(메모리만) — available 재료 집합 + 가용 소스 상태(클라우드 동의·
    /// 온디바이스 지원). 같은 시그니처면 재생성 스킵. 재료가 그대로여도 동의를 켜면 시그니처가 달라져
    /// 다음 cook()에서 재시도된다(불필요 호출 방지 + 동의 토글 후 재시도 양립).
    private var lastAIRefreshSignature: Int?

    static let currentSchemaVersion = 2
    static let log = Logger(subsystem: "com.reffi.app", category: "store")

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
        counterIDs = snap?.counterIDs ?? []
        activeCook = snap?.activeCook
        userRecipes = snap?.userRecipes ?? []
        aiRecipes = snap?.aiRecipes ?? []   // 레거시 파일엔 없음 → 빈 캐시(안전)
        resolveCanonicalIDs()   // 레거시 데이터 승격(nil→사전) — persist는 다음 변이 때 자연 기록
        let have = Set(ingredients.map(\.id))
        counterIDs.removeAll { !have.contains($0) }   // 스테일 정리
        replenishCounter()
        promoteUrgent()   // 콜드 오픈 정렬 — 저장된 작업대가 더 임박한 재료를 놓치고 있으면 승격(알림 정합)
    }

    /// 프리뷰·테스트용 — 메모리 전용(저장 안 함, 알림 재스케줄도 안 함).
    init(ingredients: [Ingredient],
         recipes: [Recipe]? = nil,
         history: [RemovalLog] = [],
         aiRecipes: [Recipe] = []) {
        persists = false
        seedRecipes = recipes ?? RecipeCatalog.loadSeed()
        userRecipes = []
        self.aiRecipes = aiRecipes
        self.ingredients = ingredients
        self.history = history
        archivedAte = 0
        archivedTossed = 0
        dismissedToBuy = []
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
        var aiRecipes: [Recipe]? = nil     // v2 — 기본 nil이라 기존 memberwise 호출·레거시 파일 안전
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
    /// 재료가 안 바뀌는 변이(단계 체크·쇼핑 skip·커스텀 레시피)는 `reschedulesAlerts: false`로
    /// 알림 재구성을 건너뛴다 — 판정 제스처·체크 토글의 메인 스레드 비용을 줄인다.
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
                            aiRecipes: aiRecipes)
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
    func remove(_ ingredient: Ingredient) {
        ingredients.removeAll { $0.id == ingredient.id }
        counterIDs.removeAll { $0 == ingredient.id }
        detachFromCookSession(ingredient.id)
        replenishCounter()
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
        activeCook = CookSession(recipeName: result.recipe.displayName, startedAt: Date(),
                                 count: used.count, steps: result.recipe.displaySteps,
                                 usedIDs: used.map(\.id))
        let reserved = reservedIDs
        counterIDs.removeAll { reserved.contains($0) }
        replenishCounter()
        beginUndo(.fired(recipe: result.recipe.displayName, count: used.count),
                  logIDs: [], counterSnapshot: counterBefore, previousSession: replaced)
        persist()
    }

    /// 단계 체크 토글 — 조리 진행 상태도 영속화(중간에 앱을 꺼도 이어서).
    func toggleCookStep(_ index: Int) {
        guard var cook = activeCook else { return }
        var done = Set(cook.completedSteps ?? [])
        if !done.insert(index).inserted { done.remove(index) }
        cook.completedSteps = done.sorted()
        activeCook = cook
        persist(reschedulesAlerts: false)   // 재료 불변 — 알림 재구성 불필요
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
        }
        let token: UUID       // 세대 토큰 — 이전 창의 만료 타이머가 새 창을 닫지 못하게
        let logIDs: [UUID]
        let kind: Kind
        let counterSnapshot: [UUID]        // 판정 전 작업대 — undo 시 통째로 원복
        var leftoverSnapshots: [Ingredient] = []   // finish의 '남았어요' 절반 처리 전 원본
        var previousSession: CookSession?          // fired: 교체 전 세션 / finished: 종료된 세션
    }

    private func beginUndo(_ kind: PendingUndo.Kind, logIDs: [UUID], counterSnapshot: [UUID],
                           leftoverSnapshots: [Ingredient] = [],
                           previousSession: CookSession? = nil) {
        let token = UUID()
        pendingUndo = PendingUndo(token: token, logIDs: logIDs, kind: kind,
                                  counterSnapshot: counterSnapshot,
                                  leftoverSnapshots: leftoverSnapshots,
                                  previousSession: previousSession)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard let self, self.pendingUndo?.token == token else { return }
            self.pendingUndo = nil
        }
    }

    /// 되돌리기 — 이력에서 해당 로그를 걷어내고 스냅샷을 복원, 작업대는 판정 전 상태로 원복한다.
    /// 발주 undo = 예약 해제(+교체됐던 이전 세션 복원), 완료 undo = 조리 세션 재개 + 절반 수량 원복.
    func undoPending() {
        guard let undo = pendingUndo else { return }
        pendingUndo = nil
        switch undo.kind {
        case .fired, .finished:
            activeCook = undo.previousSession   // fired: 교체 전(보통 nil) / finished: 종료된 세션 재개
        case .decision:
            break
        }
        var restored: [Ingredient] = []
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

    // MARK: - AI 레시피 캐시(증강)

    /// 보유 재료로 AI 레시피를 생성해 캐시에 얹는다. 스토어는 ProfileStore에 결합하지 않고 호출부(UI)가
    /// `AIRecipePreferences(profile:)`와 로케일("ko"/"en")을 주입한다(`rankedRecipes`와 같은 패턴).
    ///
    /// 방어: ① 이미 진행 중이면 스킵(재진입) ② 일일 캡 초과면 엔진 호출 자체 스킵 ③ 직전과 같은
    /// **시그니처**(재료 집합 + 가용 소스 상태)면 재생성 스킵(불필요 호출) ④ 실패는 조용히(로그만) —
    /// 시드/커스텀이 폴백. 성공분만 중복 제거 후 prepend(캡 30), 사용량 1회 기록, persist(알림 불변).
    ///
    /// `onDeviceAvailable`은 온디바이스 소스의 실사용 가능 여부 — 기본값이 실소스를 조회한다(호출 저렴:
    /// 시뮬레이터/미지원 기기는 즉시 false, 지원 기기는 캐시된 availability 열거값 읽기). 동의를 켜면
    /// 같은 냉장고여도 시그니처가 달라져 재시도되고, 재료가 그대로면 다시 스킵된다.
    func refreshAIRecipes(preferences: AIRecipePreferences, locale: String,
                          onDeviceAvailable: Bool = OnDeviceModelRecipeSource().isAvailable) async {
        guard !isRefreshingAI else { return }
        guard AIConsent.canGenerateToday else { return }
        let candidates = available
        guard !candidates.isEmpty else { return }
        let signature = Self.refreshSignature(ingredients: candidates,
                                              cloudEnabled: AIConsent.cloudEnabled,
                                              onDeviceAvailable: onDeviceAvailable)
        guard signature != lastAIRefreshSignature else { return }

        isRefreshingAI = true
        defer { isRefreshingAI = false }
        lastAIRefreshSignature = signature   // 성공/실패 무관 — 같은 시그니처 재호출을 막는다(재료·소스 상태가 바뀌면 재시도)

        let request = RecipeGenerationRequest(ingredients: candidates, preferences: preferences,
                                              count: 2, locale: locale)
        let generated = await RecipeEngine.standard.recipes(for: request)
        guard !generated.isEmpty else {
            Self.log.info("AI recipe refresh produced nothing (unavailable sources / offline).")
            return
        }
        let merged = Self.mergedAIRecipes(existing: aiRecipes, incoming: generated,
                                          others: userRecipes + seedRecipes, cap: aiRecipeCap)
        guard merged != aiRecipes else { return }   // 전부 중복 — 상태·사용량 변화 없음
        aiRecipes = merged
        AIConsent.recordUsage()
        persist(reschedulesAlerts: false)
    }

    /// AI 캐시 병합 규칙(순수·테스트 가능) — incoming을 정규화 이름 기준 중복 제거(others=시드/커스텀,
    /// existing=기존 AI와 이름 충돌 폐기) 후 existing 앞에 prepend, cap 초과분은 뒤(오래된 것)에서 제거.
    static func mergedAIRecipes(existing: [Recipe], incoming: [Recipe],
                                others: [Recipe], cap: Int) -> [Recipe] {
        var seen = Set((others + existing).map(normRecipeName))
        var fresh: [Recipe] = []
        for recipe in incoming where seen.insert(normRecipeName(recipe)).inserted {
            fresh.append(recipe)
        }
        var merged = fresh + existing
        if merged.count > cap { merged.removeLast(merged.count - cap) }
        return merged
    }

    /// 레시피 이름 정규화 키(중복 판정) — en 이름 소문자 트림.
    static func normRecipeName(_ recipe: Recipe) -> String {
        recipe.name.en.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// available 재료 집합의 순서 무관 해시 — matchKey(표기 무관) 기준. 프로세스 내 안정(메모리 가드용).
    static func ingredientSetHash(_ ingredients: [Ingredient]) -> Int {
        var hasher = Hasher()
        for key in ingredients.map(\.matchKey).sorted() { hasher.combine(key) }
        return hasher.finalize()
    }

    /// 재생성 스킵 시그니처(순수·테스트 가능) — 재료 집합 해시 + 가용 소스 상태(클라우드 동의·온디바이스
    /// 지원). 재료가 그대로여도 소스 상태(동의 켜짐 등)가 바뀌면 값이 달라져 재시도를 허용한다.
    static func refreshSignature(ingredients: [Ingredient], cloudEnabled: Bool,
                                 onDeviceAvailable: Bool) -> Int {
        var hasher = Hasher()
        hasher.combine(ingredientSetHash(ingredients))
        hasher.combine(cloudEnabled)
        hasher.combine(onDeviceAvailable)
        return hasher.finalize()
    }

    // MARK: - 통계 (이력 단일 장부 + 접힌 누계)

    /// 누계 — 헤더의 Ate/Tossed 카운트(트림으로 접힌 과거분 포함).
    var ateCount: Int { archivedAte + history.lazy.filter { !$0.wasted }.count }
    var tossedCount: Int { archivedTossed + history.lazy.filter(\.wasted).count }

    /// 최근 30일 이력 — "Past 30 days"/"Wasted · 30d" 라벨과 계산을 일치시킨다.
    var recentHistory: [RemovalLog] {
        let cutoff = Ingredient.day(offset: -30)
        return history.filter { $0.removedAt >= cutoff }
    }

    /// 낭비율(%) — 최근 30일 기준: 버림 / (먹음 + 버림).
    var wasteRate: Int {
        let recent = recentHistory
        guard !recent.isEmpty else { return 0 }
        let tossed = recent.lazy.filter(\.wasted).count
        return Int((Double(tossed) / Double(recent.count) * 100).rounded())
    }

    // MARK: - 사야 할 식재료(쇼핑 리스트)

    /// 자주 쓰는데(이력에 있는데) 지금 냉장고엔 없는 = 사야 할 식재료. 빈도 많은 순.
    /// 비교는 전부 matchKey(캐논 ID 우선) — 표기(Milk/milk, 양파/onion)가 달라도 한 품목으로 묶인다.
    /// 표시는 최근 로그의 원문.
    var toBuy: [(name: String, glyph: FoodGlyph)] {
        let inStock = Set(ingredients.map(\.matchKey))
        let dismissed = Set(dismissedToBuy.map(dismissKey))
        let grouped = Dictionary(grouping: history) { $0.matchKey }
        return grouped
            .compactMap { key, logs -> (name: String, glyph: FoodGlyph, count: Int)? in
                guard let first = logs.first,   // history는 최신이 앞 → 최근 표기
                      !inStock.contains(key),
                      !dismissed.contains(key) else { return nil }
                return (name: first.name, glyph: first.glyph, count: logs.count)
            }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
            .map { (name: $0.name, glyph: $0.glyph) }
    }

    /// 이번엔 안 사기 — 쇼핑 리스트에서 제외. 캐논 키(없으면 이름 소문자)로 저장해 표기 무관 비교.
    func skipBuy(_ name: String) {
        dismissedToBuy.insert(IngredientLexicon.shared.canonicalID(for: name) ?? name.lowercased())
        persist(reschedulesAlerts: false)   // 재료 불변
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
        counterIDs = []
        pendingUndo = nil
        activeCook = nil
        aiRecipes = []                // 이전 냉장고 기준 생성물 — 샘플로 교체 시 무효
        lastAIRefreshSignature = nil
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
        counterIDs = []
        pendingUndo = nil
        activeCook = nil
        userRecipes = []
        aiRecipes = []
        lastAIRefreshSignature = nil
        persist()
    }
}
