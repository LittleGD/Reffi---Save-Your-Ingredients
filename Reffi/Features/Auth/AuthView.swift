import SwiftUI
import AuthenticationServices
import PhosphorSwift

/// 로그인 — 크림 캔버스 위 흰 영수증 한 장(§13 종이 문법).
/// 이메일 로그인/가입 토글 + Apple/Google 소셜 + 게스트 둘러보기.
struct AuthView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    private enum Mode { case signIn, signUp }
    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focus: Field?
    private enum Field { case email, password }

    /// Apple 요청에 넣은 nonce(SHA256) 원본 — 응답 검증 시 Supabase로 보낸다.
    @State private var appleNonce = ""
    @State private var appleCoordinator = AppleSignInCoordinator()

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
        .onOpenURL { auth.handleOpenURL($0) }
        // 프로필에서 시트로 띄운 경우 — 정식(비익명) 세션이 생기면 자동 닫힘.
        // 게이트(루트)에서는 dismiss가 no-op이라 무해하다.
        .onChange(of: auth.session?.user.isAnonymous) { _, isAnon in
            if isAnon == false { dismiss() }
        }
    }

    // MARK: 워드마크

    private var wordmark: some View {
        VStack(spacing: ReffiSpace.s1) {
            Text("Reffi")
                .reffiType(.display)
                .foregroundStyle(ReffiColor.blueDark)
            Text("버리기 전에, 오늘 먹기")
                .reffiType(.caption)
                .foregroundStyle(ReffiColor.ink2)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, ReffiSpace.s2)
        .accessibilityElement(children: .combine)
    }

    // MARK: 영수증 카드 — 폼 + 소셜

    private var receiptCard: some View {
        let shape = ReceiptShape(tooth: 7)
        return VStack(alignment: .leading, spacing: ReffiSpace.s4) {
            HStack(alignment: .firstTextBaseline) {
                Text(isSignIn ? "Log in" : "Sign up")
                    .reffiType(.heading).foregroundStyle(ReffiColor.ink)
                Spacer()
                Text(isSignIn ? "다시 만나 반가워요" : "1분이면 충분해요")
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
            }

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

            PaperButton(title: primaryTitle, seed: 1, action: submit)
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1 : 0.45)   // §7.2 disabled

            modeToggle
            dashRule

            socialButton(icon: .appleLogo, title: "Apple로 계속하기",
                         fill: ReffiColor.ink, fg: .white, seed: 5) { startApple() }
            socialButton(icon: .googleLogo, title: "Google로 계속하기",
                         fill: ReffiColor.paper, fg: ReffiColor.ink, seed: 6) {
                Task { await auth.signInWithGoogle() }
            }

            footer
        }
        .padding(.horizontal, ReffiSpace.s5)
        .padding(.vertical, ReffiSpace.s5 + 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReffiColor.oklch(0.985, 0.004, 90), in: shape)
        .paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
        .reffiShadow1()
    }

    private var primaryTitle: String {
        if auth.busy { return "잠시만요…" }
        return isSignIn ? "로그인" : "가입하기"
    }

    private func submit() {
        let e = email.trimmingCharacters(in: .whitespaces)
        Task {
            if isSignIn { await auth.signIn(email: e, password: password) }
            else { await auth.signUp(email: e, password: password) }
        }
    }

    // MARK: 입력 필드 — 시트 인풋과 같은 PaperRect 문법

    private func field(_ placeholder: String, text: Binding<String>, focused: Field) -> some View {
        TextField(placeholder, text: text)
            .reffiType(.body)
            .foregroundStyle(ReffiColor.ink)
            .focused($focus, equals: focused)
            .padding(.horizontal, ReffiSpace.s4)
            .padding(.vertical, ReffiSpace.s3)
            .frame(minHeight: 44)   // §7.3
            .background {
                let s = PaperRect(cornerRadius: ReffiRadius.md, seed: focused == .email ? 2 : 3)
                s.fill(ReffiColor.canvas).paperEdge(s, tint: ReffiColor.ink.opacity(0.1))
            }
    }

    private var secureField: some View {
        SecureField("Password (6자 이상)", text: $password)
            .reffiType(.body)
            .foregroundStyle(ReffiColor.ink)
            .focused($focus, equals: .password)
            .padding(.horizontal, ReffiSpace.s4)
            .padding(.vertical, ReffiSpace.s3)
            .frame(minHeight: 44)
            .background {
                let s = PaperRect(cornerRadius: ReffiRadius.md, seed: 3)
                s.fill(ReffiColor.canvas).paperEdge(s, tint: ReffiColor.ink.opacity(0.1))
            }
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
            Text(isSignIn ? "처음이신가요?" : "이미 계정이 있나요?")
                .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
            Button(isSignIn ? "가입하기" : "로그인") {
                withAnimation(ReffiMotion.gated(.easeOut(duration: 0.18), reduce: false)) {
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
        .frame(minHeight: 44)
    }

    private var dashRule: some View {
        HStack(spacing: ReffiSpace.s3) {
            line
            Text("OR")
                .font(.custom("Pretendard-Bold", size: 10, relativeTo: .caption2)).tracking(1.2)
                .foregroundStyle(ReffiColor.muted)
            line
        }
    }
    private var line: some View {
        HLine().stroke(ReffiColor.ink.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(height: 1)
    }

    // MARK: 소셜 버튼 — PaperCutRect(와이드 CTA 문법) + 로고 글리프

    private func socialButton(icon: Ph, title: String, fill: Color, fg: Color, seed: Int,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: ReffiSpace.s2) {
                icon.reffi(18, .fill)
                Text(title)
                    .font(ReffiTextRole.subhead.font)
                    .tracking(ReffiTextRole.subhead.tracking)
            }
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, ReffiSpace.s4)
            .background {
                let s = PaperCutRect(seed: seed)
                s.fill(fill)
                    .overlay(PaperGrain(seed: UInt64(seed) &+ 11).clipShape(s))
                    .paperEdge(s, tint: fill == ReffiColor.paper
                               ? ReffiColor.ink.opacity(0.1) : ReffiColor.paperEdgeOnFill, width: 1)
            }
            .compositingGroup()
            .reffiShadow1()
        }
        .buttonStyle(.paperPress)
        .disabled(auth.busy)
        .opacity(auth.busy ? 0.45 : 1)
    }

    private var footer: some View {
        Text("REFFI · KEEP IT FRESH")
            .font(.custom("Pretendard-Bold", size: 10, relativeTo: .caption2)).tracking(1.2)
            .foregroundStyle(ReffiColor.muted)
            .frame(maxWidth: .infinity)
            .padding(.top, ReffiSpace.s1)
    }

    // MARK: 게스트

    private var guestButton: some View {
        QuietButton(title: "계정 없이 둘러보기", icon: ReffiIcon.go, tint: ReffiColor.ink2) {
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
