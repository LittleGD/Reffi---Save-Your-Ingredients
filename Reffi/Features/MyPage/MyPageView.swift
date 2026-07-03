import SwiftUI
import PhosphorSwift
import UserNotifications

/// 마이페이지 — 낭비 요약 + 임박 알림 설정 + 데이터 관리. 흰 영수증 카드 언어(§13)로 통일.
struct MyPageView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(ExpiryNotifier.enabledKey) private var alertsEnabled = false
    @AppStorage(ExpiryNotifier.hourKey) private var alertHour = ExpiryNotifier.defaultHour
    // 등록 폼 기본값 — 수량·단위(프로필에서 설정, AddIngredientSheet가 소비).
    @AppStorage("defaultQuantityValue") private var defaultQuantityValue = 1.0
    @AppStorage("defaultQuantityUnit") private var defaultQuantityUnit = IngredientUnit.piece.rawValue

    @State private var showResetConfirm = false
    @State private var showSampleConfirm = false
    @State private var showDenied = false
    @State private var showMyRecipes = false

    private var rate: Int { store.wasteRate }
    private var rateColor: Color {
        switch rate {
        case ...10: ReffiColor.freshDark
        case ...30: ReffiColor.soonDark
        default:    ReffiColor.urgentDark
        }
    }

    var body: some View {
        ZStack {
            LiquidGlassBackground(accent: ReffiColor.blue.opacity(0.4))
            ScrollView {
                VStack(alignment: .leading, spacing: ReffiSpace.s4) {
                    header
                    summaryCard
                    alertsCard
                    defaultsCard
                    recipesCard
                    dataCard
                }
                .padding(.horizontal, ReffiGrid.margin)
                .padding(.top, ReffiSpace.s5)
                .padding(.bottom, 120)
            }
        }
        .confirmationDialog(Text("Reset all data?"), isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset everything", role: .destructive) {
                withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                    store.resetAllData()
                }
            }
        } message: {
            Text("Ingredients and history will be deleted. This can't be undone.")
        }
        .confirmationDialog(Text("Load the sample fridge?"), isPresented: $showSampleConfirm, titleVisibility: .visible) {
            Button("Replace with sample data", role: .destructive) {
                withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                    store.loadSampleData()
                }
            }
        } message: {
            Text("Your current ingredients and history will be replaced.")
        }
        .alert(Text("Notifications are off"), isPresented: $showDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Allow notifications for Reffi in Settings to get expiry alerts.")
        }
        // 시스템 설정에서 권한을 나중에 회수한 경우 — 토글이 켜진 채 조용히 실패하지 않게 동기화.
        .task { await syncAuthorization() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await syncAuthorization() } }
        }
    }

    private func syncAuthorization() async {
        guard alertsEnabled else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus == .denied {
            alertsEnabled = false
            ExpiryNotifier.reschedule(for: store.ingredients)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s1) {
            Text("Profile").reffiType(.display).foregroundStyle(ReffiColor.ink)
            Text("Your no-waste record and settings")
                .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
        }
    }

    // MARK: 낭비 요약

    private var summaryCard: some View {
        card {
            VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Past 30 days").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
                    Spacer()
                    Text("\(store.recentHistory.count) handled")
                        .font(.custom("Pretendard-Medium", size: 12, relativeTo: .caption2))
                        .foregroundStyle(ReffiColor.ink2)
                }
                HStack(spacing: ReffiSpace.s5) {
                    stat(value: "\(rate)%", label: Text("Wasted"), color: rateColor)
                    stat(value: "\(store.ateCount)", label: Text("Ate · all time"), color: ReffiColor.freshDark)
                    stat(value: "\(store.tossedCount)", label: Text("Tossed · all time"), color: ReffiColor.urgentDark)
                }
            }
        }
    }

    private func stat(value: String, label: Text, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: value).font(.reffiNum(26, relativeTo: .title2)).foregroundStyle(color)
            label.reffiType(.caption).foregroundStyle(ReffiColor.ink2)
        }
    }

    // MARK: 임박 알림

    private var alertsCard: some View {
        card {
            VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                Text("Expiry alerts").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
                Toggle(isOn: $alertsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Morning reminder").reffiType(.body).foregroundStyle(ReffiColor.ink)
                        Text("What expires today and tomorrow")
                            .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                    }
                }
                .tint(ReffiColor.blue)
                .onChange(of: alertsEnabled) { _, on in
                    if on {
                        Task {
                            if await ExpiryNotifier.requestAuthorization() {
                                ExpiryNotifier.reschedule(for: store.ingredients)
                            } else {
                                alertsEnabled = false
                                showDenied = true
                            }
                        }
                    } else {
                        ExpiryNotifier.reschedule(for: store.ingredients)
                    }
                }

                if alertsEnabled {
                    Picker(selection: $alertHour) {
                        ForEach(6..<22, id: \.self) { h in
                            Text(verbatim: Self.hourLabel(h)).tag(h)
                        }
                    } label: {
                        Text("Alert time").reffiType(.body).foregroundStyle(ReffiColor.ink)
                    }
                    .pickerStyle(.menu)
                    .tint(ReffiColor.blue)
                    .onChange(of: alertHour) { _, _ in
                        ExpiryNotifier.reschedule(for: store.ingredients)
                    }
                }
            }
        }
    }

    private static func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    // MARK: 등록 기본값 (수량·단위)

    private var defaultsCard: some View {
        card {
            VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                Text("Defaults").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Default quantity").reffiType(.body).foregroundStyle(ReffiColor.ink)
                        Text("Pre-filled when you add an ingredient")
                            .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                    }
                    Spacer()
                    TextField("1", value: $defaultQuantityValue, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 56)
                    Picker(selection: $defaultQuantityUnit) {
                        ForEach(IngredientUnit.allCases) { u in
                            Text(verbatim: u.label).tag(u.rawValue)
                        }
                    } label: { EmptyView() }
                    .pickerStyle(.menu)
                    .tint(ReffiColor.blue)
                }
            }
        }
    }

    // MARK: 내 레시피 (커스텀 — 추천 풀에 합류)

    private var recipesCard: some View {
        card {
            VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                Text("My recipes").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
                dataRow(icon: ReffiIcon.recipe,
                        title: store.userRecipes.isEmpty
                            ? Text("Add your own recipe")
                            : Text("\(store.userRecipes.count) recipes"),
                        tint: ReffiColor.blueDark) {
                    showMyRecipes = true
                }
            }
        }
        .sheet(isPresented: $showMyRecipes) { MyRecipesView() }
    }

    // MARK: 데이터 관리

    private var dataCard: some View {
        card {
            VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                Text("Data").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
                dataRow(icon: ReffiIcon.fridge, title: Text("Load the sample fridge"), tint: ReffiColor.blueDark) {
                    if store.isPristine {
                        withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                            store.loadSampleData()
                        }
                    } else {
                        showSampleConfirm = true
                    }
                }
                dataRow(icon: ReffiIcon.toss, title: Text("Reset all data"), tint: ReffiColor.urgentDark) {
                    showResetConfirm = true
                }
            }
        }
    }

    private func dataRow(icon: Ph, title: Text, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: ReffiSpace.s3) {
                icon.reffi(18).foregroundStyle(tint)
                title.reffiType(.body).foregroundStyle(tint)
                Spacer()
                ReffiIcon.chevron.reffi(14).foregroundStyle(ReffiColor.muted)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.reffiPress)
    }

    // MARK: 영수증 카드 래퍼 — Fridge/History와 같은 흰 영수증(톱니)

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let shape = ReceiptShape(tooth: 7)
        return content()
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s5 + 7)   // 톱니 인셋
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ReffiColor.oklch(0.985, 0.004, 90), in: shape)
            .paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
            .shadow(color: ReffiColor.ink.opacity(0.06), radius: 5, x: 0, y: 2)
    }
}
