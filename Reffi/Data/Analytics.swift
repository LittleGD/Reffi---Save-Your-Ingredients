import Foundation
import os
import SwiftUI
import Supabase
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 이벤트 분류(taxonomy)

/// 행동 이벤트 — **닫힌 목록**이다. 이름·속성은 `docs/ANALYTICS.md`의 이벤트 사전과 1:1이고, 서버의
/// `analytics.*` 뷰가 그 이름과 속성 키를 그대로 읽는다. 여기 없는 이벤트는 올릴 수 없고(문자열 API 없음),
/// 속성에는 **재료 이름·구매처·닉네임·이메일 같은 자유 텍스트를 싣지 않는다** — 글리프(닫힌 enum)·
/// 카운트·일수·시드 레시피 슬러그까지만 허용한다. 커스텀 레시피는 id 대신 `"custom"`으로 접는다.
enum AnalyticsEvent: Equatable {
    /// 화면 — `screen_view.screen`. 탭·패인·커버·시트 중 UX 판단에 쓰이는 표면만.
    enum Screen: String {
        case home, profile, onboarding, auth, deck, cook, decision, add, edit
        case fridgeStock = "fridge.stock"
        case fridgeToBuy = "fridge.tobuy"
        case fridgeHistory = "fridge.history"
        case myRecipes = "my_recipes"
    }
    /// 재료가 들어온 입구.
    enum AddSource: String { case manual, receipt, restock }
    /// 판정(먹음/버림)이 일어난 표면 — 배지 탭 커버 / 홈 존 드래그 / 냉장고 영수증.
    enum DecideSurface: String { case badge, zone, fridge, other }
    enum ScanSource: String { case camera, photos }
    enum ToBuySource: String { case memo, missing }
    enum ToBuyRemoval: String { case skip, swipe }
    enum VideoSource: String { case cook, emptyDeck = "empty_deck" }
    enum RecipeAction: String { case create, edit, delete }

    // 수명주기
    case sessionStart(cold: Bool)
    case appBackground(seconds: Int)
    case screenView(Screen)
    case onboardingComplete(skipped: Bool, household: String, cuisines: Int, alerts: Bool)
    case notificationOpen
    case notificationPermission(granted: Bool)
    case alertsToggled(on: Bool, hour: Int)
    case languageChange(to: String)
    // 재료 — 넣기·고치기·판정
    case receiptScan(source: ScanSource, pages: Int, candidates: Int, matched: Int)
    case ingredientAdd(source: AddSource, count: Int, known: Int)
    case ingredientEdit(renamed: Bool)
    case ingredientDelete
    case ingredientFreeze(daysLeft: Int)
    case ingredientPin(on: Bool)
    case ingredientDecide(ate: Bool, surface: DecideSurface, daysLeft: Int, frozen: Bool, glyph: String)
    case sealedCheck(opened: Int, stillSealed: Int)
    // 티켓 — 덱·발주·조리
    case deckOpen(tickets: Int, pinned: Int, atRisk: Int)
    case ticketPass(recipe: String, passes: Int)
    case ticketFire(recipe: String, used: Int, missing: Int, substituted: Int, urgent: Int)
    case cookFinish(recipe: String, used: Int, leftovers: Int, stepsDone: Int, stepsTotal: Int, minutes: Int)
    case cookCancel(recipe: String, minutes: Int)
    case videoOpen(source: VideoSource)
    case undo(kind: String)
    // 장보기·레시피·데이터
    case toBuyAdd(source: ToBuySource, count: Int)
    case toBuyRemove(via: ToBuyRemoval)
    case recipeCustom(action: RecipeAction)
    case sampleLoad
    case dataReset
    // 계정
    case authSignIn(provider: String, anonymous: Bool)
    case authUpgrade(provider: String)
    case authSignOut

    /// 서버가 읽는 이름 — snake_case, 변경 금지(뷰가 문자열로 참조한다).
    var name: String {
        switch self {
        case .sessionStart: "session_start"
        case .appBackground: "app_background"
        case .screenView: "screen_view"
        case .onboardingComplete: "onboarding_complete"
        case .notificationOpen: "notification_open"
        case .notificationPermission: "notification_permission"
        case .alertsToggled: "alerts_toggled"
        case .languageChange: "language_change"
        case .receiptScan: "receipt_scan"
        case .ingredientAdd: "ingredient_add"
        case .ingredientEdit: "ingredient_edit"
        case .ingredientDelete: "ingredient_delete"
        case .ingredientFreeze: "ingredient_freeze"
        case .ingredientPin: "ingredient_pin"
        case .ingredientDecide: "ingredient_decide"
        case .sealedCheck: "sealed_check"
        case .deckOpen: "deck_open"
        case .ticketPass: "ticket_pass"
        case .ticketFire: "ticket_fire"
        case .cookFinish: "cook_finish"
        case .cookCancel: "cook_cancel"
        case .videoOpen: "video_open"
        case .undo: "undo"
        case .toBuyAdd: "tobuy_add"
        case .toBuyRemove: "tobuy_remove"
        case .recipeCustom: "recipe_custom"
        case .sampleLoad: "sample_load"
        case .dataReset: "data_reset"
        case .authSignIn: "auth_signin"
        case .authUpgrade: "auth_upgrade"
        case .authSignOut: "auth_signout"
        }
    }

    /// 속성 — 평평한 사전(중첩 없음). 뷰에서 `props->>'key'`로 읽는다.
    var props: [String: AnalyticsValue] {
        switch self {
        case .sessionStart(let cold):
            ["cold": .bool(cold)]
        case .appBackground(let seconds):
            ["seconds": .int(seconds)]
        case .screenView(let screen):
            ["screen": .string(screen.rawValue)]
        case .onboardingComplete(let skipped, let household, let cuisines, let alerts):
            ["skipped": .bool(skipped), "household": .string(household),
             "cuisines": .int(cuisines), "alerts": .bool(alerts)]
        case .notificationOpen, .ingredientDelete, .sampleLoad, .dataReset, .authSignOut:
            [:]
        case .notificationPermission(let granted):
            ["granted": .bool(granted)]
        case .alertsToggled(let on, let hour):
            ["on": .bool(on), "hour": .int(hour)]
        case .languageChange(let to):
            ["to": .string(to)]
        case .receiptScan(let source, let pages, let candidates, let matched):
            ["source": .string(source.rawValue), "pages": .int(pages),
             "candidates": .int(candidates), "matched": .int(matched)]
        case .ingredientAdd(let source, let count, let known):
            ["source": .string(source.rawValue), "count": .int(count), "known": .int(known)]
        case .ingredientEdit(let renamed):
            ["renamed": .bool(renamed)]
        case .ingredientFreeze(let daysLeft):
            ["days_left": .int(daysLeft)]
        case .ingredientPin(let on):
            ["on": .bool(on)]
        case .ingredientDecide(let ate, let surface, let daysLeft, let frozen, let glyph):
            ["outcome": .string(ate ? "ate" : "tossed"), "surface": .string(surface.rawValue),
             "days_left": .int(daysLeft), "frozen": .bool(frozen), "glyph": .string(glyph)]
        case .sealedCheck(let opened, let stillSealed):
            ["opened": .int(opened), "still_sealed": .int(stillSealed)]
        case .deckOpen(let tickets, let pinned, let atRisk):
            ["tickets": .int(tickets), "pinned": .int(pinned), "at_risk": .int(atRisk)]
        case .ticketPass(let recipe, let passes):
            ["recipe": .string(recipe), "passes": .int(passes)]
        case .ticketFire(let recipe, let used, let missing, let substituted, let urgent):
            ["recipe": .string(recipe), "used": .int(used), "missing": .int(missing),
             "substituted": .int(substituted), "urgent": .int(urgent)]
        case .cookFinish(let recipe, let used, let leftovers, let stepsDone, let stepsTotal, let minutes):
            ["recipe": .string(recipe), "used": .int(used), "leftovers": .int(leftovers),
             "steps_done": .int(stepsDone), "steps_total": .int(stepsTotal), "minutes": .int(minutes)]
        case .cookCancel(let recipe, let minutes):
            ["recipe": .string(recipe), "minutes": .int(minutes)]
        case .videoOpen(let source):
            ["source": .string(source.rawValue)]
        case .undo(let kind):
            ["kind": .string(kind)]
        case .toBuyAdd(let source, let count):
            ["source": .string(source.rawValue), "count": .int(count)]
        case .toBuyRemove(let via):
            ["via": .string(via.rawValue)]
        case .recipeCustom(let action):
            ["action": .string(action.rawValue)]
        case .authSignIn(let provider, let anonymous):
            ["provider": .string(provider), "anonymous": .bool(anonymous)]
        case .authUpgrade(let provider):
            ["provider": .string(provider)]
        }
    }

    /// 레시피 식별 — 시드는 슬러그 그대로(어느 레시피가 발주·패스되는지가 곧 시드 품질 지표),
    /// 커스텀은 사용자가 지은 이름·UUID를 싣지 않고 `"custom"`으로 접는다.
    static func recipeKey(_ id: String) -> String {
        UUID(uuidString: id) != nil ? "custom" : id
    }
}

/// 속성 값 — JSON 스칼라 셋뿐이다(중첩·배열 없음). 큐 파일(Codable)과 업로드 행(Encodable)이 같이 쓴다.
enum AnalyticsValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case bool(Bool)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let i = try? c.decode(Int.self) { self = .int(i); return }
        self = .string(try c.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .int(let i): try c.encode(i)
        case .bool(let b): try c.encode(b)
        }
    }
}

// MARK: - 파이프라인

/// 행동 계측 파이프라인 — 앱 안의 **유일한** 이벤트 출구.
///
/// 설계(정본은 `docs/ANALYTICS.md`):
/// - **1st-party.** 서드파티 SDK 없이 이미 쓰는 Supabase에 `analytics_events` 한 테이블로 쌓는다.
///   사용자 id는 Supabase Auth의 uid(익명 세션 포함)라 별도 식별자를 만들지 않고, 게스트가 가입해도
///   같은 uid가 이어져 리텐션 코호트가 끊기지 않는다. `user_id`는 서버가 `auth.uid()`로 채운다 —
///   클라이언트는 보내지 않고 보낼 수도 없다(컬럼 권한 없음).
/// - **세션 = 30분 규칙.** 마지막 활동으로부터 30분 안의 복귀는 같은 세션(GA4와 같은 정의). 새 세션마다
///   `session_start`, 백그라운드 진입마다 `app_background{seconds}` — 세션 길이는 그 최댓값이다.
/// - **오프라인 우선.** 이벤트는 먼저 로컬 큐(JSON, 상한 1000)에 쓰이고 포그라운드·백그라운드·20건 누적·
///   로그인 시점에 100건씩 업로드된다. 실패하면 큐에 남고 60초 뒤 재시도한다. `(install_id, seq)`가
///   유니크라 재전송은 서버에서 중복 제거된다(`ignoreDuplicates`).
/// - **옵트아웃.** 프로필 › App › "Share usage data"를 끄면 큐를 비우고 그 즉시 아무것도 올리지 않는다.
///   "Erase this device"는 install id까지 새로 발급한다.
/// - **채널 분리.** DEBUG 빌드는 `channel = 'debug'`로 올라가고 서버 뷰는 `release`만 집계한다 —
///   개발·시뮬레이터 세션이 지표를 오염시키지 않는다. 유닛 테스트 호스트에서는 아예 꺼진다.
@MainActor
final class Analytics {

    static let shared: Analytics = {
        let args = ProcessInfo.processInfo.arguments
        let underXCTest = NSClassFromString("XCTestCase") != nil
        return Analytics(defaults: .standard,
                         queueURL: Analytics.defaultQueueURL,
                         uploader: Analytics.supabaseUploader,
                         canUpload: { AuthStore.client.auth.currentSession != nil },
                         killSwitch: underXCTest || args.contains("-analyticsOff"))
    }()

    /// 옵트아웃 토글의 `@AppStorage` 키 — 미설정 = 켬(`ReffiFeedback.hapticsKey`와 같은 규약).
    static let enabledKey = "analytics.enabled"
    nonisolated static let log = Logger(subsystem: "com.reffi.app", category: "analytics")

    static let sessionTimeout: TimeInterval = 30 * 60
    static let queueCap = 1000
    static let batchSize = 100
    static let flushThreshold = 20
    static let retryDelay: TimeInterval = 60

    /// 업로드 행 — `public.analytics_events` 컬럼과 1:1(snake_case). `user_id`는 없다(서버 기본값).
    struct Row: Encodable, Equatable {
        let install_id: String
        let session_id: String
        let seq: Int
        let name: String
        let props: [String: AnalyticsValue]
        let occurred_at: String
        let app_version: String
        let build: String
        let os_version: String
        let device_model: String
        let locale: String
        let language: String
        let channel: String
    }

    /// 큐 항목 — 디스크에 그대로 남는다. 컨텍스트(버전·기기)는 업로드 시점에 붙인다.
    struct Queued: Codable, Equatable {
        let seq: Int
        let sessionID: UUID
        let name: String
        let props: [String: AnalyticsValue]
        let occurredAt: Date
    }

    /// 기기·앱 컨텍스트 — 모든 행에 붙는다. 기기 식별자(IDFV 등)는 싣지 않는다.
    struct Context: Equatable {
        var appVersion: String
        var build: String
        var osVersion: String
        var deviceModel: String
        var locale: String
        var language: String
        var channel: String

        static func current() -> Context {
            let info = Bundle.main.infoDictionary ?? [:]
            let os = ProcessInfo.processInfo.operatingSystemVersion
            var uts = utsname(); uname(&uts)
            let model = withUnsafePointer(to: &uts.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) { String(cString: $0) }
            }
            let language: String = switch AppLanguage.current {
            case .system: Locale.current.language.languageCode?.identifier ?? "und"
            case .en, .ko: AppLanguage.current.rawValue
            }
            #if DEBUG
            let channel = "debug"
            #else
            let channel = "release"
            #endif
            return Context(appVersion: info["CFBundleShortVersionString"] as? String ?? "",
                           build: info["CFBundleVersion"] as? String ?? "",
                           osVersion: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
                           deviceModel: model,
                           locale: Locale.current.identifier,
                           language: language,
                           channel: channel)
        }
    }

    typealias Uploader = @MainActor ([Row]) async throws -> Void
    typealias BackgroundRunner = @MainActor (@escaping @MainActor () async -> Void) -> Void

    private let defaults: UserDefaults
    private let queueURL: URL?
    private let uploader: Uploader
    private let canUpload: @MainActor () -> Bool
    private let now: () -> Date
    private let killSwitch: Bool
    private let backgroundRunner: BackgroundRunner
    let context: Context

    private(set) var queue: [Queued] = []
    private(set) var sessionID: UUID?
    private var sessionStartedAt: Date?
    private var lastActiveAt: Date?
    private var currentScreen: AnalyticsEvent.Screen?
    private var startedSessionThisProcess = false
    private var flushing = false
    private var retryAfter: Date = .distantPast

    init(defaults: UserDefaults,
         queueURL: URL?,
         uploader: @escaping Uploader,
         canUpload: @escaping @MainActor () -> Bool,
         now: @escaping () -> Date = Date.init,
         killSwitch: Bool = false,
         context: Context = .current(),
         backgroundRunner: @escaping BackgroundRunner = Analytics.uiKitBackgroundRunner) {
        self.defaults = defaults
        self.queueURL = queueURL
        self.uploader = uploader
        self.canUpload = canUpload
        self.now = now
        self.killSwitch = killSwitch
        self.context = context
        self.backgroundRunner = backgroundRunner
        queue = Self.loadQueue(from: queueURL)
        // 프로세스가 죽었다 살아나도 30분 규칙은 이어진다 — 마지막 세션을 복원해 두고 판정은 ensureSession이.
        if let raw = defaults.string(forKey: Key.sessionID), let id = UUID(uuidString: raw) {
            sessionID = id
            sessionStartedAt = Date(timeIntervalSince1970: defaults.double(forKey: Key.sessionStart))
            lastActiveAt = Date(timeIntervalSince1970: defaults.double(forKey: Key.sessionLastActive))
        }
    }

    // MARK: 상태

    /// 켜짐 = 옵트아웃 안 함 && 킬스위치 없음. 꺼져 있으면 `track`은 즉시 버린다.
    var isEnabled: Bool {
        !killSwitch && (defaults.object(forKey: Self.enabledKey) as? Bool ?? true)
    }

    /// 설치 식별자 — 기기가 아니라 **이 설치**의 id. 재설치·"Erase this device"로 바뀐다.
    /// 서버 중복 제거 키(`install_id, seq`)의 절반이라 user id와 무관하게 안정적이어야 한다.
    var installID: UUID {
        if let raw = defaults.string(forKey: Key.installID), let id = UUID(uuidString: raw) { return id }
        let id = UUID()
        defaults.set(id.uuidString, forKey: Key.installID)
        return id
    }

    // MARK: 기록

    /// 이벤트 한 건 — 세션을 보장한 뒤 큐에 넣는다. 꺼져 있으면 아무 흔적도 남기지 않는다.
    func track(_ event: AnalyticsEvent) {
        guard isEnabled else { return }
        if case .sessionStart = event {} else { ensureSession() }
        append(event)
        if queue.count >= Self.flushThreshold { flushSoon() }
    }

    /// 화면 노출 — 같은 화면의 연속 기록은 접는다(탭 토글 왕복·커버 재등장을 두 번 세지 않게).
    func screen(_ screen: AnalyticsEvent.Screen) {
        guard isEnabled else { return }
        ensureSession()
        guard currentScreen != screen else { return }
        currentScreen = screen
        append(.screenView(screen))
    }

    // MARK: 수명주기(ReffiApp의 scenePhase가 부른다)

    func sceneDidBecomeActive() {
        guard isEnabled else { return }
        ensureSession()
        lastActiveAt = now()
        persistSession()
        flushSoon()
    }

    func sceneDidEnterBackground() {
        guard isEnabled, let started = sessionStartedAt else { return }
        let at = now()
        lastActiveAt = at
        persistSession()
        append(.appBackground(seconds: Int(at.timeIntervalSince(started))))
        // 백그라운드 유예 안에 올린다 — 안 그러면 마지막 세션의 길이는 다음 실행에서야 도착한다.
        backgroundRunner { [weak self] in await self?.flush() }
    }

    // MARK: 옵트아웃 · 정체성

    /// 토글 — 끄면 **큐까지** 비운다(아직 안 올라간 것도 사용자 뜻대로 버린다). 켜면 새 세션으로 시작.
    func setEnabled(_ on: Bool) {
        defaults.set(on, forKey: Self.enabledKey)
        if on {
            sessionID = nil
            ensureSession()
        } else {
            queue = []
            saveQueue()
            sessionID = nil
            sessionStartedAt = nil
            lastActiveAt = nil
            clearSession()
        }
    }

    /// "Erase this device" — 큐·시퀀스·install id·세션 전부 새로. 서버의 과거 행은 그대로다(uid 기준 삭제는
    /// 계정 삭제 경로의 일, `docs/ANALYTICS.md` §8).
    func resetIdentity() {
        queue = []
        saveQueue()
        defaults.removeObject(forKey: Key.installID)
        defaults.removeObject(forKey: Key.seq)
        sessionID = nil
        sessionStartedAt = nil
        lastActiveAt = nil
        currentScreen = nil
        clearSession()
    }

    // MARK: 업로드

    func flushSoon() {
        Task { await flush() }
    }

    /// 큐를 100건씩 순서대로 올린다. 실패하면 그 배치부터 남기고 60초 뒤로 물러난다(다음 트리거가 재시도).
    func flush() async {
        guard isEnabled, !flushing, !queue.isEmpty, canUpload(), now() >= retryAfter else { return }
        flushing = true
        defer { flushing = false }
        let install = installID.uuidString
        while !queue.isEmpty {
            let batch = Array(queue.prefix(Self.batchSize))
            do {
                try await uploader(batch.map { row($0, install: install) })
            } catch {
                retryAfter = now().addingTimeInterval(Self.retryDelay)
                Self.log.error("flush failed (\(batch.count) events kept): \(String(describing: error))")
                return
            }
            let sent = Set(batch.map(\.seq))
            queue.removeAll { sent.contains($0.seq) }   // 올리는 사이 뒤에 붙은 건 남긴다
            saveQueue()
        }
    }

    // MARK: - 내부

    private func ensureSession() {
        let at = now()
        if let last = lastActiveAt, sessionID != nil,
           at.timeIntervalSince(last) < Self.sessionTimeout {
            lastActiveAt = at
            return
        }
        sessionID = UUID()
        sessionStartedAt = at
        lastActiveAt = at
        persistSession()
        append(.sessionStart(cold: !startedSessionThisProcess))
        startedSessionThisProcess = true
        // 새 세션의 첫 화면 — 화면 전환 없이 30분 뒤 돌아오면 onAppear가 다시 안 오므로 여기서 잇는다.
        if let screen = currentScreen { append(.screenView(screen)) }
    }

    private func append(_ event: AnalyticsEvent) {
        guard let sessionID else { return }
        let seq = defaults.integer(forKey: Key.seq) + 1
        defaults.set(seq, forKey: Key.seq)
        queue.append(Queued(seq: seq, sessionID: sessionID, name: event.name,
                            props: event.props, occurredAt: now()))
        if queue.count > Self.queueCap { queue.removeFirst(queue.count - Self.queueCap) }
        saveQueue()
        #if DEBUG
        Self.log.debug("\(event.name, privacy: .public) \(String(describing: event.props), privacy: .public)")
        #endif
    }

    private func row(_ q: Queued, install: String) -> Row {
        Row(install_id: install, session_id: q.sessionID.uuidString, seq: q.seq, name: q.name,
            props: q.props, occurred_at: Self.iso8601.string(from: q.occurredAt),
            app_version: context.appVersion, build: context.build, os_version: context.osVersion,
            device_model: context.deviceModel, locale: context.locale, language: context.language,
            channel: context.channel)
    }

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func persistSession() {
        guard let sessionID, let sessionStartedAt, let lastActiveAt else { return }
        defaults.set(sessionID.uuidString, forKey: Key.sessionID)
        defaults.set(sessionStartedAt.timeIntervalSince1970, forKey: Key.sessionStart)
        defaults.set(lastActiveAt.timeIntervalSince1970, forKey: Key.sessionLastActive)
    }

    private func clearSession() {
        defaults.removeObject(forKey: Key.sessionID)
        defaults.removeObject(forKey: Key.sessionStart)
        defaults.removeObject(forKey: Key.sessionLastActive)
    }

    // MARK: 큐 영속화 — 인코드는 메인, 쓰기는 직렬 큐(FridgeStore.persist와 같은 규약)

    private static let ioQueue = DispatchQueue(label: "com.reffi.app.analytics-io", qos: .utility)

    private func saveQueue() {
        guard let queueURL else { return }
        do {
            let data = try JSONEncoder().encode(queue)
            Self.ioQueue.async {
                do { try data.write(to: queueURL, options: .atomic) }
                catch { Self.log.error("queue write failed: \(String(describing: error))") }
            }
        } catch {
            Self.log.error("queue encode failed: \(String(describing: error))")
        }
    }

    /// 테스트용 — 직렬 큐의 쓰기가 끝날 때까지 기다린다.
    func waitForPersistence() { Self.ioQueue.sync {} }

    private static func loadQueue(from url: URL?) -> [Queued] {
        guard let url, let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Queued].self, from: data)) ?? []
    }

    private static var defaultQueueURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("analytics-queue.json")
    }

    private enum Key {
        static let installID = "analytics.installID"
        static let seq = "analytics.seq"
        static let sessionID = "analytics.session.id"
        static let sessionStart = "analytics.session.start"
        static let sessionLastActive = "analytics.session.lastActive"
    }

    // MARK: 기본 배선

    /// Supabase 업로더 — `(install_id, seq)` 충돌은 무시(재전송 멱등), 응답 본문은 받지 않는다
    /// (`returning: .minimal` — 이 테이블엔 SELECT 권한이 없어 representation을 요청하면 실패한다).
    static func supabaseUploader(_ rows: [Row]) async throws {
        try await AuthStore.client
            .from("analytics_events")
            .upsert(rows, onConflict: "install_id,seq", returning: .minimal, ignoreDuplicates: true)
            .execute()
    }

    /// 백그라운드 유예 안에서 작업을 끝낸다(약 30초). UIKit 없는 환경(테스트)은 즉시 실행 러너를 주입.
    static func uiKitBackgroundRunner(_ work: @escaping @MainActor () async -> Void) {
        #if canImport(UIKit)
        var id = UIBackgroundTaskIdentifier.invalid
        id = UIApplication.shared.beginBackgroundTask(withName: "analytics-flush") {
            UIApplication.shared.endBackgroundTask(id)
        }
        Task {
            await work()
            if id != .invalid { UIApplication.shared.endBackgroundTask(id) }
        }
        #else
        Task { await work() }
        #endif
    }
}

// MARK: - 뷰 편의

extension View {
    /// 표면 노출 기록 — 커버·시트의 `onAppear`에 건다(탭 패인은 `isActive` 전환에서 직접 부른다).
    func analyticsScreen(_ screen: AnalyticsEvent.Screen) -> some View {
        onAppear { Analytics.shared.screen(screen) }
    }
}

extension FridgeTab {
    var analyticsScreen: AnalyticsEvent.Screen {
        switch self {
        case .stock: .fridgeStock
        case .toBuy: .fridgeToBuy
        case .history: .fridgeHistory
        }
    }
}
