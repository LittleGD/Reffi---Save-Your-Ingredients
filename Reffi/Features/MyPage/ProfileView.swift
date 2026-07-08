import SwiftUI

/// 프로필/마이(§5) — 무낭비 리포트 + 요리 취향(스타일·비선호·알레르기) + 알림 + 계정.
/// 구성은 Main의 리퀴드글래스 배경 + Fridge의 "흰 영수증 더미" 문법(톱니+점선+틸트·슬립)을 그대로 따른다.
/// 흰 종이 면은 그레인 없이 깨끗하게 — 그레인은 채도 버튼 면 전용(PaperButton 문법).
struct ProfileView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(ProfileStore.self) private var profile
    @Environment(AuthStore.self) private var auth

    @State private var sheet: Sheet?
    @State private var showLogout = false
    @State private var showDelete = false
    @State private var showAuth = false

    private enum Sheet: String, Identifiable {
        case nickname, cuisines, favorites, disliked, allergies, time
        var id: String { rawValue }
    }

    /// 영수증 인셋 — Fridge cardInset처럼 페이지 마진 위에 추가로 좁혀 영수증 폭을 만든다.
    private let receiptInset: CGFloat = 6

    var body: some View {
        @Bindable var profile = profile
        ScrollView {
            VStack(alignment: .leading, spacing: ReffiSpace.s5) {
                header
                // 영수증 스택 — 설정 화면이라 기울임 없이 정돈된 정렬(질서 있는 영수증 문법).
                // 무낭비 리포트는 냉장고 페이지 History(No-waste report)로 이동.
                tasteReceipt
                householdReceipt
                notifyReceipt($profile)
                accountReceipt
            }
            .padding(.horizontal, ReffiGrid.margin + receiptInset)
            .padding(.top, ReffiSpace.s5)
            .padding(.bottom, 120)   // 떠 있는 캡슐 네비 위로 스크롤 여유
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LiquidGlassBackground(accent: accent))
        .sheet(item: $sheet) { which in
            switch which {
            case .nickname:  NicknameEditSheet().presentationDetents([.height(260)])
            case .cuisines:  CuisinePickerSheet().presentationDetents([.medium, .large])
            case .favorites: TagEditorSheet(title: "Favorites", placeholder: "e.g. Tofu",
                                            tags: $profile.favorites).presentationDetents([.medium, .large])
            case .disliked:  TagEditorSheet(title: "Disliked", placeholder: "e.g. Cucumber",
                                            tags: $profile.disliked).presentationDetents([.medium, .large])
            case .allergies: TagEditorSheet(title: "Allergies", placeholder: "e.g. Peanuts",
                                            tags: $profile.allergies).presentationDetents([.medium, .large])
            case .time:      NotifyTimeSheet().presentationDetents([.height(300)])
            }
        }
        .sheet(isPresented: $showAuth) { AuthView() }
        .alert("Log out", isPresented: $showLogout) {
            Button("Log out", role: .destructive) { Task { await auth.signOut() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Log out of Reffi?") }
        .alert("Delete account", isPresented: $showDelete) {
            Button("Delete", role: .destructive) { profile.resetAll() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Your profile and preferences will be reset.") }
    }

    /// 배경 액센트 — 가장 임박한 재료의 신선도색(Fridge와 동일, 세 탭이 한 몸).
    private var accent: Color { store.sorted.first?.freshness.main ?? ReffiColor.fresh }

    // MARK: - 헤더 (아바타 + 닉네임 — Main·Fridge 디스플레이 헤더 문법)
    private var header: some View {
        Button { sheet = .nickname } label: {
            HStack(spacing: ReffiSpace.s4) {
                // 아바타 — 닉네임 이니셜(워드마크 서체, 한글은 Pretendard). 빈 닉네임은 아이콘 폴백.
                Group {
                    if avatarInitial.isEmpty {
                        ReffiIcon.profile.reffi(30).foregroundStyle(ReffiColor.blue)
                    } else {
                        Text(avatarInitial)
                            .font(avatarInitial.hasHangul
                                  ? .custom("Pretendard-Bold", size: 28, relativeTo: .title)
                                  : .custom("StoryScript-Regular", size: 30, relativeTo: .title))
                            .foregroundStyle(ReffiColor.blue)
                    }
                }
                .frame(width: 64, height: 64)
                .background {
                    let s = PaperBlob(sides: 9, seed: 2)
                    s.fill(ReffiColor.blueLight).paperEdge(s, tint: ReffiColor.ink.opacity(0.06))
                }
                VStack(alignment: .leading, spacing: 2) {
                    // 한글 닉네임은 Story Script(한글 미지원) 대신 Pretendard Bold 폴백(§3.1).
                    Text(profile.nickname)
                        .font(profile.nickname.hasHangul
                              ? ReffiTextRole.display.koreanDisplayFont
                              : ReffiTextRole.display.font)
                        .foregroundStyle(ReffiColor.ink)
                        .lineLimit(1)
                    Text(subtitle).reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                }
                Spacer(minLength: 0)
                ReffiIcon.manual.reffi(16, .bold).foregroundStyle(ReffiColor.muted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.reffiPress)
        .accessibilityLabel("Edit nickname")
        .accessibilityValue(profile.nickname)
    }

    /// 아바타 이니셜 — 닉네임 첫 글자(대문자).
    private var avatarInitial: String {
        String(profile.nickname.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
    }

    /// 부제 — 요리 취향 요약(스트릭은 리포트 도장으로 이동해 중복 제거). 취향 없으면 담백한 문구.
    private var subtitle: String {
        profile.cuisines.isEmpty ? "Saving with Reffi" : profile.cuisines.summaryText
    }

    // MARK: - 요리 취향 영수증
    private var tasteReceipt: some View {
        ReceiptCard(title: "Taste") {
            SettingsRow(label: "Cuisines", value: profile.cuisines.summaryText,
                        valueColor: profile.cuisines.isEmpty ? ReffiColor.muted : ReffiColor.blueDark) {
                sheet = .cuisines
            }
            ReceiptRule()
            SettingsRow(label: "Favorites", value: tagSummary(profile.favorites)) { sheet = .favorites }
            ReceiptRule()
            SettingsRow(label: "Disliked", value: tagSummary(profile.disliked)) { sheet = .disliked }
            ReceiptRule()
            SettingsRow(label: "Allergies", value: tagSummary(profile.allergies)) { sheet = .allergies }
        }
    }

    // MARK: - 가구 인원 영수증 — 레시피 양·쇼핑 수량의 근거. 인라인 칩 단일 선택(Remind me 문법).
    private var householdReceipt: some View {
        ReceiptCard(title: "Household") {
            VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                Text("How many servings should we plan for?")
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                HStack(spacing: ReffiSpace.s2) {
                    ForEach(HouseholdSize.allCases) { h in
                        SelectableChip(text: h.label, selected: profile.household == h,
                                       fullWidth: false) {
                            profile.household = h
                        }
                    }
                }
            }
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s4)
        }
    }

    private func tagSummary(_ tags: [String]) -> String {
        guard !tags.isEmpty else { return "None yet" }   // 빈 상태 카피 통일(Cuisines·시트와 동일)
        let head = tags.prefix(2).joined(separator: ", ")
        let extra = tags.count - Swift.min(2, tags.count)
        return extra > 0 ? "\(head) +\(extra)" : head
    }

    // MARK: - 알림 영수증
    private func notifyReceipt(_ profile: Bindable<ProfileStore>) -> some View {
        ReceiptCard(title: "Notifications") {
            HStack {
                Text("Expiry alerts").reffiType(.body).foregroundStyle(ReffiColor.ink)
                Spacer()
                Toggle("", isOn: profile.notifyEnabled).labelsHidden().tint(ReffiColor.blue)
                    .accessibilityLabel("Expiry alerts")
            }
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s4)

            if profile.wrappedValue.notifyEnabled {
                ReceiptRule()
                VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                    Text("Remind me").reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                    HStack(spacing: ReffiSpace.s2) {
                        ForEach(ProfileStore.leadDayOptions, id: \.self) { d in
                            SelectableChip(text: "D-\(d)", selected: profile.wrappedValue.leadDays == d) {
                                profile.wrappedValue.leadDays = d
                            }
                        }
                    }
                }
                .padding(.horizontal, ReffiSpace.s5)
                .padding(.vertical, ReffiSpace.s4)

                ReceiptRule()
                SettingsRow(label: "Time", value: profile.wrappedValue.notifyTimeText,
                            numeric: true) { sheet = .time }
            }
        }
    }

    // MARK: - 계정 영수증
    private var accountReceipt: some View {
        ReceiptCard(title: "Account") {
            // 로그인 상태 행 — 이메일(로그인) 또는 게스트 안내.
            HStack {
                Text(auth.isGuest ? "Guest mode" : "Signed in")
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                Spacer()
                Text(auth.userEmail ?? "Sign up to keep your data")
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink)
                    .lineLimit(1).truncationMode(.middle)
            }
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s3)
            ReceiptRule()
            QuietButton(title: auth.isGuest ? "Log in / Sign up" : "Log out",
                        icon: ReffiIcon.go, tint: ReffiColor.blueDark) {
                // 게스트는 익명 세션을 유지한 채 시트에서 전환/로그인(승계 보장).
                if auth.isGuest { showAuth = true }
                else { showLogout = true }
            }
            .padding(.horizontal, ReffiSpace.s3)
            .padding(.vertical, ReffiSpace.s1)
            ReceiptRule()
            // toss(재료 버림)와 의미 충돌 방지 — 탈퇴는 별도 아이콘(x).
            QuietButton(title: "Delete account", icon: ReffiIcon.close, tint: ReffiColor.urgentDark) {
                showDelete = true
            }
            .padding(.horizontal, ReffiSpace.s3)
            .padding(.vertical, ReffiSpace.s1)
        }
    }
}

// MARK: - 재사용 컴포넌트

/// 흰 영수증 카드 — Fridge 영수증(FridgeCard·ExpandedFridgeCard)과 같은 문법.
/// 톱니(절취) 엣지 + 대문자 트래킹 헤더 + 점선 룰, 면은 그레인 없는 깨끗한 흰 종이.
struct ReceiptCard<Content: View>: View {
    let title: String
    var stamp: String? = nil        // 제목 옆 고무 도장(DDayStamp) — 스트릭 등
    var trailing: String? = nil     // 헤더 우측 보조(날짜 등)
    @ViewBuilder var content: Content

    private let toothH: CGFloat = 7

    var body: some View {
        let shape = ReceiptShape(tooth: toothH)
        let paper = ReffiColor.oklch(0.985, 0.004, 90)   // 흰 영수증(Fridge와 동일)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text(title.uppercased())
                    .font(.custom("Pretendard-Bold", size: 11, relativeTo: .caption2)).tracking(1.2)
                    .foregroundStyle(ReffiColor.ink2)
                if let stamp {
                    DDayStamp(text: stamp, color: ReffiColor.freshDark, size: 10)
                        .padding(.leading, ReffiSpace.s2)
                }
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.reffiNum(11, relativeTo: .caption2)).foregroundStyle(ReffiColor.muted)
                }
            }
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.top, ReffiSpace.s4 + toothH)
            .padding(.bottom, ReffiSpace.s3)

            ReceiptRule()
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, ReffiSpace.s2 + toothH)
        .background(paper, in: shape)
        .paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
        .shadow(color: ReffiColor.ink.opacity(0.06), radius: 4, x: 0, y: 2)   // 약한 드롭섀도(Fridge와 동일)
    }
}

/// 영수증 점선 룰 — Fridge 상세의 dashRule과 동일.
struct ReceiptRule: View {
    var body: some View {
        HLine().stroke(ReffiColor.ink.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(height: 1)
            .padding(.horizontal, ReffiSpace.s5)
    }
}

/// 설정 행 — 라벨 + 값 + 셰브런. 탭하면 편집 시트로.
struct SettingsRow: View {
    let label: String
    var value: String? = nil
    var valueColor: Color = ReffiColor.ink2
    var showChevron: Bool = true
    var numeric: Bool = false   // 시간·수량 등 데이터성 숫자 값 → reffiNum 의무(§3.4)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ReffiSpace.s3) {
                Text(label).reffiType(.body).foregroundStyle(ReffiColor.ink)
                Spacer(minLength: ReffiSpace.s4)
                if let value {
                    Text(value)
                        .font(numeric ? .reffiNum(14, relativeTo: .caption) : ReffiTextRole.caption.font)
                        .tracking(numeric ? 0 : ReffiTextRole.caption.tracking)
                        .foregroundStyle(valueColor)
                        .lineLimit(1)
                }
                if showChevron {
                    ReffiIcon.chevron.reffi(13, .bold).foregroundStyle(ReffiColor.muted)
                }
            }
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.reffiPress)
    }
}

private extension String {
    /// 한글 포함 여부 — Story Script는 한글 미지원(§3.1) → Display 폴백(Pretendard Bold) 판별.
    var hasHangul: Bool {
        unicodeScalars.contains {
            (0xAC00...0xD7A3).contains($0.value)      // 완성형
            || (0x1100...0x11FF).contains($0.value)   // 자모
            || (0x3130...0x318F).contains($0.value)   // 호환 자모
        }
    }
}
