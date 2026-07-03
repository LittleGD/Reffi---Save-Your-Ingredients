import Foundation
import Observation
import Supabase
import AuthenticationServices
import CryptoKit

/// 인증 상태 — Supabase Auth 세션의 단일 소스.
/// 이메일 가입/로그인 + Apple(네이티브 ID 토큰) + Google(OAuth 브라우저) + 게스트(둘러보기).
/// 세션은 supabase-swift가 Keychain에 영속화하고, `authStateChanges`로 복원·구독한다.
@Observable
@MainActor
final class AuthStore {

    /// Supabase 클라이언트 — publishable key는 클라이언트 임베드용 공개 키(RLS로 보호).
    static let client = SupabaseClient(
        supabaseURL: URL(string: "https://itianwvwbeixfarblqzy.supabase.co")!,
        supabaseKey: "sb_publishable_G0kaRfSEKwS-qW4hAOscKA_x5DXA_bV"
    )

    /// OAuth 콜백 — Info.plist의 `reffi` URL 스킴과 일치해야 한다.
    static let redirectURL = URL(string: "reffi://auth-callback")!

    // MARK: - 상태

    private(set) var session: Session?
    /// 익명 로그인 실패(대시보드 비활성·오프라인) 시 폴백 — 로컬 전용 게스트 플래그.
    private(set) var localGuest: Bool
    /// 저장된 세션 복원 중(첫 프레임 스플래시 판단용).
    private(set) var restoring = true
    /// 네트워크 요청 진행 중(버튼 비활성).
    private(set) var busy = false

    var errorMessage: String?
    /// 성공 안내(예: 가입 후 이메일 확인).
    var notice: String?

    /// 게스트 = 익명 세션(서버 user id 보유, 가입 시 승계) 또는 로컬 폴백.
    var isGuest: Bool { session?.user.isAnonymous == true || localGuest }
    /// 앱 진입 가능 여부 — 세션(익명 포함)이 있거나 로컬 게스트.
    var isSignedIn: Bool { session != nil || localGuest }
    var userEmail: String? { session?.user.email }

    init() {
        var guest = UserDefaults.standard.bool(forKey: Key.guest)
        #if DEBUG
        // 스크린샷·QA용 — 인증 게이트 건너뛰기(-fridgeTab 선례).
        if ProcessInfo.processInfo.arguments.contains("-skipAuth") { guest = true }
        if ProcessInfo.processInfo.arguments.contains("-authGate") { guest = false }
        #endif
        localGuest = guest
        Task { await listen() }
    }

    /// Keychain의 세션을 복원하고 이후 변경(로그인·로그아웃·갱신)을 구독.
    private func listen() async {
        for await (event, session) in Self.client.auth.authStateChanges {
            self.session = session
            if session != nil { setLocalGuest(false) }
            if event == .initialSession { restoring = false }
        }
    }

    // MARK: - 이메일

    /// 가입 — 익명 세션이면 같은 user id를 유지한 채 정식 계정으로 전환(데이터 승계).
    /// 이메일 확인이 켜져 있으면 인증 완료 시점에 전환이 확정된다.
    func signUp(email: String, password: String) async {
        await run {
            if let user = session?.user, user.isAnonymous {
                try await Self.client.auth.update(
                    user: UserAttributes(email: email, password: password)
                )
                self.notice = "Check your inbox — once verified, your guest data carries over."
            } else {
                let res = try await Self.client.auth.signUp(email: email, password: password)
                if res.session == nil {
                    self.notice = "Confirmation email sent. Verify it, then log in."
                }
            }
        }
    }

    func signIn(email: String, password: String) async {
        await run { try await Self.client.auth.signIn(email: email, password: password) }
    }

    // MARK: - 소셜

    /// Apple — 네이티브 시트의 ID 토큰을 Supabase로 교환. `nonce`는 요청에 넣은 원본(raw) 값.
    func signInWithApple(_ result: Result<ASAuthorization, Error>, nonce: String) async {
        await run {
            switch result {
            case .failure(let e):
                if (e as? ASAuthorizationError)?.code == .canceled { return }
                throw e
            case .success(let auth):
                guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                      let data = cred.identityToken,
                      let idToken = String(data: data, encoding: .utf8) else {
                    throw AuthLocalError.appleToken
                }
                try await Self.client.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
                )
            }
        }
    }

    /// Google — 시스템 브라우저(ASWebAuthenticationSession) OAuth. 완료 시 reffi:// 콜백으로 세션 수립.
    func signInWithGoogle() async {
        await run {
            try await Self.client.auth.signInWithOAuth(provider: .google, redirectTo: Self.redirectURL)
        }
    }

    /// OAuth 콜백 URL 처리(onOpenURL) — 외부 브라우저로 돌아온 경우의 안전망.
    func handleOpenURL(_ url: URL) {
        guard url.scheme == "reffi" else { return }
        Task { try? await Self.client.auth.session(from: url) }
    }

    // MARK: - 게스트 · 로그아웃

    /// 둘러보기 — 익명 세션 발급(서버 user id 확보 → 가입 시 기록 승계).
    /// 익명 로그인이 꺼져 있거나 오프라인이면 로컬 게스트로 조용히 폴백.
    func continueAsGuest() async {
        errorMessage = nil
        busy = true
        defer { busy = false }
        do { try await Self.client.auth.signInAnonymously() }
        catch { setLocalGuest(true) }
    }

    func signOut() async {
        setLocalGuest(false)
        await run { try await Self.client.auth.signOut() }
        session = nil
    }

    private func setLocalGuest(_ v: Bool) {
        guard localGuest != v else { return }
        localGuest = v
        UserDefaults.standard.set(v, forKey: Key.guest)
    }

    // MARK: - 공통 실행 래퍼

    private func run(_ work: () async throws -> Void) async {
        errorMessage = nil
        notice = nil
        busy = true
        defer { busy = false }
        do { try await work() }
        catch { errorMessage = Self.friendly(error) }
    }

    /// 서버 에러 → 사용자 문구(과도한 기술 노출 방지).
    private static func friendly(_ error: Error) -> String {
        let raw = error.localizedDescription
        let lower = raw.lowercased()
        if lower.contains("invalid login credentials") { return "Email or password doesn't match." }
        if lower.contains("email not confirmed") { return "Please verify your email first — check your inbox." }
        if lower.contains("already registered") { return "This email is already registered. Try logging in." }
        if lower.contains("at least 6 characters") || lower.contains("password should")
            { return "Password must be at least 6 characters." }
        if lower.contains("invalid format") || lower.contains("validate email")
            { return "Please check the email address." }
        if lower.contains("network") || lower.contains("offline") || lower.contains("internet")
            { return "Check your network connection." }
        if lower.contains("provider is not enabled") { return "This sign-in method isn't available yet." }
        if (error as? ASAuthorizationError) != nil { return "Couldn't complete Apple sign-in." }
        return raw
    }

    enum AuthLocalError: LocalizedError {
        case appleToken
        var errorDescription: String? { "Couldn't complete Apple sign-in." }
    }

    private enum Key {
        static let guest = "auth.guest"
    }

    // MARK: - Apple nonce 헬퍼 (replay 방지)

    /// 요청용 랜덤 nonce — 원본은 Supabase에, SHA256은 Apple 요청에 넣는다.
    static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            guard status == errSecSuccess else { continue }
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
