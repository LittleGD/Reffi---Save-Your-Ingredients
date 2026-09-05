import Testing
import Foundation
@testable import Reffi

/// 행동 계측 파이프라인(64차) — 세션 30분 규칙·큐 배치 업로드·실패 보존·옵트아웃·재실행 영속·행 인코딩,
/// 그리고 스토어가 변이 지점에서 내는 이벤트를 고정한다. 정본은 `docs/ANALYTICS.md`.
///
/// 파이프라인은 시계·업로더·업로드 가능 여부·백그라운드 러너를 전부 주입받으므로 네트워크·UIKit·
/// 실시간 없이 결정론적으로 돈다. `Analytics.shared`는 테스트 호스트에서 킬스위치로 꺼져 있어
/// 여기서 만든 인스턴스와 섞이지 않는다.
@MainActor
struct AnalyticsTests {

    /// 주입 시계 — 세션 판정이 벽시계 함수라 테스트가 시간을 쥔다.
    final class Clock {
        var now: Date
        init(_ now: Date = Date(timeIntervalSince1970: 1_800_000_000)) { self.now = now }
        func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
    }

    /// 업로더 캡처 — 배치 단위로 받은 행을 쌓고, `fail`이면 던진다.
    final class Capture {
        var batches: [[Analytics.Row]] = []
        var fail = false
    }
    struct UploadError: Error {}

    private static let context = Analytics.Context(
        appVersion: "1.0", build: "22", osVersion: "26.5.0", deviceModel: "iPhone17,3",
        locale: "ko_KR", language: "ko", channel: "release")

    private func freshDefaults() -> UserDefaults {
        let name = "reffi.tests.analytics.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func tempQueueURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("analytics-test-\(UUID().uuidString).json")
    }

    private func make(defaults: UserDefaults? = nil, queueURL: URL? = nil,
                      clock: Clock = Clock(), capture: Capture = Capture(),
                      canUpload: Bool = false, killSwitch: Bool = false) -> Analytics {
        Analytics(defaults: defaults ?? freshDefaults(), queueURL: queueURL,
                  uploader: { rows in
                      if capture.fail { throw UploadError() }
                      capture.batches.append(rows)
                  },
                  canUpload: { canUpload },
                  now: { clock.now },
                  killSwitch: killSwitch,
                  context: Self.context,
                  backgroundRunner: { work in Task { await work() } })
    }

    // MARK: 세션

    @Test func sessionResumesWithinThirtyMinutesAndRestartsAfter() {
        let clock = Clock()
        let a = make(clock: clock)
        a.sceneDidBecomeActive()
        let first = a.sessionID
        #expect(first != nil)
        #expect(a.queue.map(\.name) == ["session_start"])
        #expect(a.queue.first?.props["cold"] == .bool(true))

        clock.advance(5 * 60)
        a.sceneDidEnterBackground()
        #expect(a.queue.last?.name == "app_background")
        #expect(a.queue.last?.props["seconds"] == .int(300))

        clock.advance(10 * 60)   // 15분 뒤 복귀 — 같은 세션
        a.sceneDidBecomeActive()
        #expect(a.sessionID == first)
        #expect(a.queue.filter { $0.name == "session_start" }.count == 1)

        clock.advance(31 * 60)   // 30분 넘김 — 새 세션(같은 프로세스라 cold=false)
        a.sceneDidBecomeActive()
        #expect(a.sessionID != first)
        let starts = a.queue.filter { $0.name == "session_start" }
        #expect(starts.count == 2)
        #expect(starts.last?.props["cold"] == .bool(false))
        #expect(a.queue.last?.sessionID == a.sessionID)
    }

    @Test func trackStartsSessionImplicitlyAndScreenDedupes() {
        let clock = Clock()
        let a = make(clock: clock)
        a.screen(.home)
        #expect(a.queue.map(\.name) == ["session_start", "screen_view"])
        a.screen(.home)   // 연속 중복은 접힌다
        #expect(a.queue.count == 2)
        a.screen(.profile)
        #expect(a.queue.compactMap { $0.props["screen"] } == [.string("home"), .string("profile")])

        clock.advance(31 * 60)
        a.track(.ingredientPin(on: true))   // 새 세션 — 보고 있던 화면(profile)이 다시 기록된다
        #expect(a.queue.suffix(3).map(\.name) == ["session_start", "screen_view", "ingredient_pin"])
        #expect(a.queue[a.queue.count - 2].props["screen"] == .string("profile"))
    }

    // MARK: 업로드

    @Test func flushUploadsInOrderedBatchesOfHundred() async {
        let capture = Capture()
        let a = make(capture: capture, canUpload: true)
        for _ in 0..<250 { a.track(.ingredientPin(on: true)) }   // + session_start = 251
        await a.flush()
        #expect(a.queue.isEmpty)
        #expect(capture.batches.map(\.count) == [100, 100, 51])
        let seqs = capture.batches.flatMap { $0.map(\.seq) }
        #expect(seqs == seqs.sorted())
        #expect(Set(seqs).count == 251)
        #expect(capture.batches.first?.first?.name == "session_start")
    }

    @Test func failedUploadKeepsEventsAndBacksOff() async {
        let clock = Clock()
        let capture = Capture()
        let a = make(clock: clock, capture: capture, canUpload: true)
        a.track(.ingredientPin(on: true))
        capture.fail = true
        await a.flush()
        #expect(a.queue.count == 2)             // session_start + pin 그대로
        capture.fail = false
        await a.flush()                         // 60초 백오프 안 — 아직 안 올린다
        #expect(a.queue.count == 2)
        #expect(capture.batches.isEmpty)
        clock.advance(61)
        await a.flush()
        #expect(a.queue.isEmpty)
        #expect(capture.batches.count == 1)
    }

    @Test func flushWaitsForSession() async {
        let capture = Capture()
        let a = make(capture: capture, canUpload: false)   // 세션 없음(로컬 게스트) — 큐에 남는다
        a.track(.dataReset)
        await a.flush()
        #expect(a.queue.count == 2)
        #expect(capture.batches.isEmpty)
    }

    // MARK: 옵트아웃 · 정체성

    @Test func optOutDropsQueueAndSilencesTracking() {
        let a = make()
        a.track(.ingredientPin(on: true))
        #expect(a.queue.count == 2)
        a.setEnabled(false)
        #expect(!a.isEnabled)
        #expect(a.queue.isEmpty)
        a.track(.ingredientPin(on: true))
        a.screen(.home)
        #expect(a.queue.isEmpty)
        a.setEnabled(true)   // 다시 켜면 새 세션으로 시작
        #expect(a.isEnabled)
        #expect(a.queue.map(\.name) == ["session_start"])
    }

    @Test func killSwitchDisablesEverything() {
        let a = make(killSwitch: true)
        a.sceneDidBecomeActive()
        a.track(.dataReset)
        a.screen(.home)
        #expect(!a.isEnabled)
        #expect(a.queue.isEmpty)
        #expect(a.sessionID == nil)
    }

    @Test func queueAndSequenceSurviveRelaunch() {
        let defaults = freshDefaults()
        let url = tempQueueURL()
        let clock = Clock()
        let a1 = make(defaults: defaults, queueURL: url, clock: clock)
        a1.track(.ingredientPin(on: true))
        a1.track(.ingredientPin(on: false))
        a1.waitForPersistence()

        let a2 = make(defaults: defaults, queueURL: url, clock: clock)
        #expect(a2.queue == a1.queue)              // 3건 복원
        #expect(a2.installID == a1.installID)
        a2.track(.dataReset)                       // 30분 안 — 같은 세션, seq는 이어진다
        #expect(a2.sessionID == a1.sessionID)
        #expect(a2.queue.last?.seq == 4)
        #expect(a2.queue.filter { $0.name == "session_start" }.count == 1)
        try? FileManager.default.removeItem(at: url)
    }

    @Test func resetIdentityIssuesNewInstallAndRestartsSequence() {
        let a = make()
        a.track(.dataReset)
        let before = a.installID
        a.resetIdentity()
        #expect(a.queue.isEmpty)
        #expect(a.installID != before)
        #expect(a.sessionID == nil)
        a.track(.dataReset)
        #expect(a.queue.map(\.seq) == [1, 2])
    }

    // MARK: 행 인코딩 — 서버 컬럼과 1:1

    @Test func rowsCarrySnakeCaseColumnsAndFlatProps() async throws {
        let capture = Capture()
        let a = make(capture: capture, canUpload: true)
        a.track(.ingredientDecide(ate: false, surface: .zone, daysLeft: 2, frozen: false, glyph: "tofu"))
        await a.flush()
        let row = try #require(capture.batches.first?.last)
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(row))
        let dict = try #require(object as? [String: Any])
        #expect(Set(dict.keys) == ["install_id", "session_id", "seq", "name", "props", "occurred_at",
                                   "app_version", "build", "os_version", "device_model",
                                   "locale", "language", "channel"])
        #expect(dict["user_id"] == nil)   // 서버가 auth.uid()로 채운다 — 클라이언트는 보내지 않는다
        #expect(dict["name"] as? String == "ingredient_decide")
        #expect(dict["channel"] as? String == "release")
        #expect((dict["occurred_at"] as? String)?.hasSuffix("Z") == true)
        let props = try #require(dict["props"] as? [String: Any])
        #expect(props["outcome"] as? String == "tossed")
        #expect(props["surface"] as? String == "zone")
        #expect(props["days_left"] as? Int == 2)
        #expect(props["frozen"] as? Bool == false)
        #expect(props["glyph"] as? String == "tofu")
    }

    @Test func recipeKeyFoldsCustomRecipes() {
        #expect(AnalyticsEvent.recipeKey("beef-bulgogi") == "beef-bulgogi")
        #expect(AnalyticsEvent.recipeKey(UUID().uuidString) == "custom")
    }

    // MARK: 스토어 훅 — 변이가 사실을 낸다

    private func makeStore(daysLeft: [Int] = [0, 1, 3]) -> FridgeStore {
        let ings = daysLeft.enumerated().map { i, d in
            Ingredient(name: "Item\(i)", category: "Veg", daysLeft: d,
                       quantity: Quantity(value: 2, unit: .piece), glyph: .generic)
        }
        return FridgeStore(ingredients: ings, recipes: [], history: [])
    }

    @Test func storeEmitsFireFinishAndUndo() {
        let store = makeStore()
        var events: [AnalyticsEvent] = []
        store.track = { events.append($0) }

        let recipe = Recipe.userRecipe(name: "Test", ingredientNames: ["Item0", "Item1"],
                                       minutes: 10, steps: ["Mix"])
        let result = RecipeRecommender.result(for: recipe, ingredients: store.sorted)
        #expect(result.used.count == 2)
        store.cook(result)
        guard case .ticketFire(let key, let used, let missing, let substituted, _)? = events.last else {
            Issue.record("ticket_fire 미기록: \(String(describing: events.last))"); return
        }
        #expect(key == "custom")
        #expect(used == 2)
        #expect(missing == 0)
        #expect(substituted == 0)

        store.finishCooking(leftovers: [result.used[1].id])
        guard case .cookFinish(let fkey, let consumed, let leftovers, let done, let total, _)? = events.last else {
            Issue.record("cook_finish 미기록: \(String(describing: events.last))"); return
        }
        #expect(fkey == "custom")
        #expect(consumed == 1)
        #expect(leftovers == 1)
        #expect(done == 0)
        #expect(total == 1)

        store.undoPending()
        #expect(events.last == .undo(kind: "finished"))
    }

    @Test func storeEmitsCancelWithRecipe() {
        let store = makeStore()
        var events: [AnalyticsEvent] = []
        store.track = { events.append($0) }
        let recipe = Recipe.userRecipe(name: "Test", ingredientNames: ["Item0"], minutes: 10, steps: [])
        store.cook(RecipeRecommender.result(for: recipe, ingredients: store.sorted))
        store.cancelCooking()
        #expect(events.last == .cookCancel(recipe: "custom", minutes: 0))
    }

    @Test func storeEmitsDecisionPinPassToBuyAndAddEvents() {
        let store = makeStore()
        var events: [AnalyticsEvent] = []
        store.track = { events.append($0) }
        let item1 = store.ingredients[1]   // D-1

        #expect(store.togglePin(item1.id))
        #expect(events.last == .ingredientPin(on: true))
        #expect(!store.togglePin(item1.id))
        #expect(events.last == .ingredientPin(on: false))

        store.recordPass(recipeID: "beef-bulgogi")
        store.recordPass(recipeID: "beef-bulgogi")
        #expect(events.last == .ticketPass(recipe: "beef-bulgogi", passes: 2))
        store.recordPass(recipeID: UUID().uuidString)
        #expect(events.last == .ticketPass(recipe: "custom", passes: 1))

        store.addToBuy(name: "Fish sauce brand X", canonicalID: nil, canonicalIsFinal: true)
        #expect(events.last == .toBuyAdd(source: .memo, count: 1))
        store.skipBuy(key: "fish sauce brand x")
        #expect(events.last == .toBuyRemove(via: .skip))

        store.toss(item1, surface: .fridge)
        #expect(events.last == .ingredientDecide(ate: false, surface: .fridge, daysLeft: 1,
                                                 frozen: false, glyph: "generic"))
        store.undoPending()
        #expect(events.last == .undo(kind: "tossed"))

        store.eat(item1, surface: .zone)
        #expect(events.last == .ingredientDecide(ate: true, surface: .zone, daysLeft: 1,
                                                 frozen: false, glyph: "generic"))

        store.add(Ingredient(name: "Item9", category: "Veg", daysLeft: 2,
                             quantity: Quantity(value: 1, unit: .piece), glyph: .generic),
                  source: .restock)
        #expect(events.last == .ingredientAdd(source: .restock, count: 1, known: 0))
    }

    @Test func memoryStoreHookIsNoOpByDefault() {
        // 메모리 스토어(프리뷰·테스트)는 공유 파이프라인에 붙지 않는다 — 여기서 변이해도 `shared` 큐가 안 는다.
        // (`shared`는 호스트 앱 컨테이너에 남은 큐 파일을 로드할 수 있으므로 "비어 있다"가 아니라 "안 변한다"를 본다.)
        let before = Analytics.shared.queue
        let store = makeStore()
        store.toss(store.ingredients[0])
        #expect(Analytics.shared.queue == before)
        #expect(!Analytics.shared.isEnabled)   // XCTest 호스트 — 킬스위치
    }
}
