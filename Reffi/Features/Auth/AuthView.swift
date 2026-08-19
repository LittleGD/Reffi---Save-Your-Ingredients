import SwiftUI
import AuthenticationServices
import PhosphorSwift

/// 로그인 — 크림 캔버스 위 흰 영수증 한 장(§13 종이 문법).
/// 이메일 로그인/가입 토글 + Apple/Google 소셜 + 게스트 둘러보기.
struct AuthView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Mode { case signIn, signUp }
    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focus: Field?
    private enum Field { case email, password }

    /// Apple 요청에 넣은 nonce(SHA256) 원본 — 응답 검증 시 Supabase로 보낸다.
    @State private var appleNonce = ""
    @State private var appleCoordinator = AppleSignInCoordinator()

    /// 지금 응답을 기다리는 **입구** — `auth.busy`는 화면 전체가 함께 보는 한 칸이라 그대로 쓰면
    /// 누르지도 않은 버튼까지 같이 돌아, 스피너가 "무엇을 눌렀는가"를 말해 주지 못한다.
    /// nil = 이메일 폼(1차 CTA)이 일하는 중.
    private enum Entry { case apple, google, guest }
    @State private var pending: Entry?

    private var isSignIn: Bool { mode == .signIn }
    private var canSubmit: Bool {
        email.contains("@") && password.count >= 6 && !auth.busy
    }

    var body: some View {
        ZStack {
            LiquidGlassBackground(accent: ReffiColor.blue)
            ScrollView {
                VStack(spacing: ReffiSpace.s5) {
                    wordmark
                    receiptCard
                    guestButton
                }
                .padding(.horizontal, ReffiGrid.margin)
                .padding(.top, ReffiSpace.s7 + ReffiSpace.s5)
                .padding(.bottom, ReffiSpace.s6)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        // 프로필에서 시트로 띄운 경우의 닫기 신호(룰④) — 핸들 노출. 루트 게이트로 쓰일 땐
        // 시트가 아니라 이 modifier가 무시되므로 무해하다.
        .presentationDragIndicator(.visible)
        // 시트 높이도 같은 이유로 여기서 선언한다(룰⑪ / §14.5 "미설정=무조건 풀높이" 금지).
        // 로그인 화면은 워드마크·소셜 버튼·게스트 진입이 한 화면에 다 서야 해서 `.large` 한 단이다 —
        // `.medium`을 함께 주면 절반 높이에서 CTA가 잘린다. 호출부(ProfileView)엔 중복 선언하지 않는다.
        .presentationDetents([.large])
        .onOpenURL { auth.handleOpenURL($0) }
        // 프로필에서 시트로 띄운 경우 — 정식(비익명) 세션이 생기면 자동 닫힘.
        // 게이트(루트)에서는 dismiss가 no-op이라 무해하다.
        .onChange(of: auth.session?.user.isAnonymous) { _, isAnon in
            if isAnon == false { dismiss() }
        }
        // 일이 끝나면 스피너의 주인도 함께 내려놓는다(다음 탭이 자기 자리에서 다시 돌게).
        .onChange(of: auth.busy) { _, busy in
            if !busy { pending = nil }
        }
    }

    // MARK: 워드마크

    private var wordmark: some View {
        VStack(spacing: ReffiSpace.s1) {
            Text(verbatim: "Reffi")
                .reffiType(.display)
                .foregroundStyle(ReffiColor.blueDark)
            Text("Eat it today, waste nothing")
                .reffiType(.caption)
                .foregroundStyle(ReffiColor.ink2)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, ReffiSpace.s2)
        .accessibilityElement(children: .combine)
    }

    // MARK: 영수증 카드 — 폼 + 소셜

    private var receiptCard: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s4) {
            HStack(alignment: .firstTextBaseline) {
                Text(isSignIn ? "Log in" : "Sign up")
                    .reffiType(.heading).foregroundStyle(ReffiColor.ink)
                Spacer()
                Text(isSignIn ? "Good to see you again" : "Takes under a minute")
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
            }

            // 소셜 우선 — Apple/Google을 기본 이메일 로그인보다 위에 배치.
            // fg는 onInk — ink 면이 다크에서 크림으로 뒤집히므로 흰 리터럴이 아닌 ink 대응 콘텐츠 토큰을 쓴다.
            socialButton(icon: .appleLogo, title: "Continue with Apple", provider: .apple,
                         fill: ReffiColor.ink, fg: ReffiColor.onInk, seed: 5) { startApple() }
            socialButton(icon: .googleLogo, title: "Continue with Google", provider: .google,
                         fill: ReffiColor.paper, fg: ReffiColor.ink, seed: 6) {
                Task { await auth.signInWithGoogle() }
            }

            dashRule

            field("Email", text: $email, focused: .email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .onSubmit { focus = .password }

            secureField
                .textContentType(isSignIn ? .password : .newPassword)
                .submitLabel(.go)
                .onSubmit { if canSubmit { submit() } }

            feedback

            PaperButton(title: LocalizedStringKey(primaryTitle), seed: 1,
                        isBusy: auth.busy && pending == nil, action: submit)
                .disabled(!canSubmit)   // 디밍은 PaperButton이 §7.2로 처리 — 여기서 겹치면 곱해진다.

            modeToggle

            footer
        }
        .receiptSurface(elevated: .floating)
    }

    /// 1차 CTA 문구 — 진행 중에도 **방금 누른 동작을 그대로 지목한다**(로그인 중…/가입 중…).
    /// 옛 "One sec…"은 어느 버튼이 무슨 일을 하는지 지워 버려, 화면에 진행 신호가 이것뿐인 상황에서
    /// 사용자가 자기가 무엇을 눌렀는지 확인할 길이 없었다. 진행 자체는 옆의 스피너가 말한다.
    /// 소셜 응답을 기다리는 동안은 그쪽 버튼이 이미 스피너를 들고 있으므로 여기는 평소 문구로 둔다.
    private var primaryTitle: String {
        if auth.busy, pending == nil { return isSignIn ? "Logging in…" : "Signing up…" }
        return isSignIn ? "Log in" : "Sign up"
    }

    private func submit() {
        let e = email.trimmingCharacters(in: .whitespaces)
        Task {
            if isSignIn { await auth.signIn(email: e, password: password) }
            else { await auth.signUp(email: e, password: password) }
        }
    }

    // MARK: 입력 필드 — 시트 인풋과 같은 `fieldSurface` 한 칸(§13.8)

    private func field(_ placeholder: LocalizedStringKey, text: Binding<String>, focused: Field) -> some View {
        TextField(placeholder, text: text)
            .reffiType(.body)
            .foregroundStyle(ReffiColor.ink)
            .focused($focus, equals: focused)
            .fieldSurface(seed: focused == .email ? 2 : 3)   // 면·패딩·히트를 모디파이어가 쥔다
    }

    private var secureField: some View {
        SecureField("Password (6+ characters)", text: $password)
            .reffiType(.body)
            .foregroundStyle(ReffiColor.ink)
            .focused($focus, equals: .password)
            .fieldSurface(seed: 3)
    }

    // MARK: 피드백 — 에러(urgent-dark) / 안내(fresh-dark), §2.6 캔버스 위 dark

    @ViewBuilder private var feedback: some View {
        if let msg = auth.errorMessage {
            Text(msg).reffiType(.caption).foregroundStyle(ReffiColor.urgentDark)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let msg = auth.notice {
            Text(msg).reffiType(.caption).foregroundStyle(ReffiColor.freshDark)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 모드 전환 — 질문 + 텍스트 버튼(§2.6 캔버스 위 blue-dark).
    private var modeToggle: some View {
        HStack(spacing: ReffiSpace.s1) {
            Text(isSignIn ? "New here?" : "Already have an account?")
                .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
            Button(isSignIn ? "Sign up" : "Log in") {
                withAnimation(ReffiMotion.gated(.easeOut(duration: 0.18), reduce: reduceMotion)) {
                    mode = isSignIn ? .signUp : .signIn
                    auth.errorMessage = nil
                    auth.notice = nil
                }
            }
            .font(ReffiTextRole.caption.font)
            .foregroundStyle(ReffiColor.blueDark)
            .buttonStyle(.reffiPress)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: ReffiChrome.tapMin)
    }

    private var dashRule: some View {
        HStack(spacing: ReffiSpace.s3) {
            line
            // 번역되는 라벨(ko "또는")이라 올캡 모노 크롬이 아니라 caption(§3.5).
            Text("OR")
                .reffiType(.caption)
                .foregroundStyle(ReffiColor.muted)
            line
        }
    }
    private var line: some View { ReffiRule(.receipt) }

    // MARK: 소셜 버튼 — PaperCutRect(와이드 CTA 문법) + 로고 글리프

    private func socialButton(icon: Ph, title: LocalizedStringKey, provider: Entry,
                              fill: Color, fg: Color, seed: Int,
                              action: @escaping () -> Void) -> some View {
        // 스피너는 **누른 그 버튼에만** 선다 — 디밍은 둘 다 먹으므로(전역 busy), 디밍만으로는
        // "내가 누른 쪽"과 "그동안 못 누르는 쪽"이 같은 모습이 된다.
        let isBusy = auth.busy && pending == provider
        return Button {
            pending = provider
            action()
        } label: {
            HStack(spacing: ReffiSpace.s2) {
                icon.reffi(18, .fill)
                Text(title)
                    .font(ReffiTextRole.subhead.font)
                    .tracking(ReffiTextRole.subhead.tracking)
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .tint(fg)
                }
            }
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, ReffiSpace.s4)
            .background {
                let s = PaperCutRect(seed: seed)
                s.fill(fill)
                    .overlay(PaperGrain(seed: UInt64(seed) &+ 11).clipShape(s))
                    .paperEdge(s, tint: fill == ReffiColor.paper
                               ? ReffiColor.paperEdgeField : ReffiColor.paperEdgeOnFill)
            }
            .compositingGroup()
            .reffiShadow1()
        }
        .buttonStyle(.paperPress)
        .disabled(auth.busy)
        // PaperButton이 아닌 자체 표면이라 디밍이 겹치지 않는다 — 여기가 §7.2 디밍의 유일한 지점.
        // **일하는 버튼은 디밍하지 않는다**: 디밍은 "지금 못 누름"의 표기고, 이 버튼이 지금 하는 말은
        // "내가 처리 중"이다. 잉크를 살려 스피너와 함께 두고, 대기하는 반대쪽만 내린다.
        .opacity(auth.busy && !isBusy ? ReffiOpacity.disabled : 1)
    }

    private var footer: some View {
        Text(verbatim: "REFFI · KEEP IT FRESH")
            .reffiType(.monoEyebrow)
            .foregroundStyle(ReffiColor.muted)
            .frame(maxWidth: .infinity)
            .padding(.top, ReffiSpace.s1)
    }

    // MARK: 게스트

    private var guestButton: some View {
        QuietButton(title: "Browse without an account", icon: ReffiIcon.go, tint: ReffiColor.ink2) {
            pending = .guest   // 둘러보기도 busy를 켠다 — 그 사이 1차 CTA가 "로그인 중…"이 되면 거짓말이다
            Task { await auth.continueAsGuest() }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Apple 네이티브 플로우

    private func startApple() {
        let nonce = AuthStore.randomNonce()
        appleNonce = nonce
        appleCoordinator.start(hashedNonce: AuthStore.sha256(nonce)) { result in
            Task { await auth.signInWithApple(result, nonce: nonce) }
        }
    }
}

/// ASAuthorizationController 코디네이터 — 커스텀 버튼에서 네이티브 Apple 시트를 띄운다.
@MainActor
final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate,
                                    ASAuthorizationControllerPresentationContextProviding {
    private var completion: ((Result<ASAuthorization, Error>) -> Void)?

    func start(hashedNonce: String, completion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.completion = completion
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]
        request.nonce = hashedNonce
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        completion?(.success(authorization))
        completion = nil
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        completion?(.failure(error))
        completion = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }
}
