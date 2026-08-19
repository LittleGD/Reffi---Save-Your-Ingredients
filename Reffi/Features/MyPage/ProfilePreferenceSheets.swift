import SwiftUI

/// 시트 공통 셸 — 크림 캔버스 + `SheetHeader`(좌측 타이틀 + 종이 X) + 콘텐츠. 편집 시트를 통일한다.
/// 헤더는 인터랙션 커먼 룰 ②③의 단일 공급원 `SheetHeader`에 위임 — 인라인 종이 X 조립을 제거했다.
///
/// **핸들도 셸이 보증한다(§14.3 / 룰④)** — `SheetHeader`는 "프레젠테이션 측에서 dragIndicator를 켠다"를
/// 전제하는데, 호출부(ProfileView)마다 붙이면 같은 누락이 재발한다. 여기서 한 번 선언해 이 셸을 쓰는
/// 프로필 시트 6종이 함께 정렬되게 한다. 단일 고정 detent(.height) 시트는 automatic으로 그래버가
/// 뜨지 않으므로 이 선언이 곧 핸들 유무를 가른다.
private struct SheetShell<Content: View>: View {
    let title: LocalizedStringKey
    let onClose: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: title, showsClose: true, onClose: onClose)
            content
                .padding(.horizontal, ReffiGrid.margin)
            Spacer(minLength: 0)
        }
        .padding(.bottom, ReffiSpace.s5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ReffiColor.canvas.ignoresSafeArea())
        .presentationDragIndicator(.visible)   // §14.3 — 핸들 없는 시트를 두지 않는다(룰④)
    }
}

/// 닉네임 편집(§5.1.1).
///
/// **미저장 보호(§14.6 / 룰⑨)** — 명시적 Save를 가진 편집 시트라 §14.4의 "편집·생성 = 도킹 커밋"
/// 버킷에 속한다. 타이핑한 뒤 스와이프로 닫으면 경고 없이 사라지던 구멍을 `IngredientEditView`의
/// `requestClose()` 패턴 그대로 막는다(자동저장 버킷인 Cuisines·태그·알림시간 시트는 해당 없음).
struct NicknameEditSheet: View {
    @Environment(ProfileStore.self) private var profile
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""
    @State private var showDiscardConfirm = false

    /// 초안이 저장값과 다르면 미저장 변경이다. 앞뒤 공백만 다른 경우는 커밋 결과가 같아 dirty로 보지 않는다.
    private var isDirty: Bool {
        draft.trimmingCharacters(in: .whitespacesAndNewlines) != profile.nickname
    }

    var body: some View {
        SheetShell(title: "Nickname", onClose: { requestClose() }) {
            VStack(alignment: .leading, spacing: ReffiSpace.s4) {
                TextField("Nickname", text: $draft)
                    .reffiType(.body)
                    .foregroundStyle(ReffiColor.ink)
                    .padding(.horizontal, ReffiSpace.s4)
                    .padding(.vertical, ReffiSpace.s3)
                    .background {
                        let s = PaperRect(cornerRadius: ReffiRadius.md, seed: 2)
                        s.fill(ReffiColor.paper).paperEdge(s, tint: ReffiColor.paperEdgeField)
                    }
                    .submitLabel(.done)
                    .onSubmit(commit)

                PaperButton(title: "Save", seed: 1, action: commit)
            }
        }
        .onAppear { draft = profile.nickname }
        .interactiveDismissDisabled(isDirty)   // 룰⑨ — 변경 있으면 스와이프 실수로 닫히지 않는다
        .confirmationDialog(Text("Discard changes?"), isPresented: $showDiscardConfirm,
                            titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
        } message: {
            Text("Your changes won't be saved.")
        }
    }

    /// 미저장 변경이 있으면 즉시 닫지 않고 Discard 확인을 띄운다(룰⑨).
    private func requestClose() {
        if isDirty { showDiscardConfirm = true } else { dismiss() }
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { profile.nickname = trimmed }
        dismiss()
    }
}

/// 요리 스타일 멀티 선택(§5.2) — 사용자 요청 핵심. 여러 스타일 동시 선택/해제.
struct CuisinePickerSheet: View {
    @Environment(ProfileStore.self) private var profile
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: ReffiSpace.s2)]

    var body: some View {
        SheetShell(title: "Cuisines", onClose: { dismiss() }) {
            VStack(alignment: .leading, spacing: ReffiSpace.s4) {
                Text("Pick your favorite cuisines · choose as many as you like")
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2)

                LazyVGrid(columns: columns, alignment: .leading, spacing: ReffiSpace.s2) {
                    ForEach(CuisineStyle.allCases) { c in
                        SelectableChip(text: c.label, selected: profile.cuisines.contains(c),
                                       fullWidth: false) {
                            profile.toggleCuisine(c)
                        }
                    }
                }
            }
        }
    }
}

/// 문자열 태그 편집 시트 — 비선호 재료·알레르기(§5.2)에 공용. 추가/삭제.
struct TagEditorSheet: View {
    let title: LocalizedStringKey
    let placeholder: LocalizedStringKey
    @Binding var tags: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""

    var body: some View {
        SheetShell(title: title, onClose: { dismiss() }) {
            VStack(alignment: .leading, spacing: ReffiSpace.s4) {
                HStack(spacing: ReffiSpace.s2) {
                    TextField(placeholder, text: $draft)
                        .reffiType(.body)
                        .foregroundStyle(ReffiColor.ink)
                        .padding(.horizontal, ReffiSpace.s4)
                        .padding(.vertical, ReffiSpace.s3)
                        .background {
                            let s = PaperRect(cornerRadius: ReffiRadius.md, seed: 2)
                            s.fill(ReffiColor.paper).paperEdge(s, tint: ReffiColor.paperEdgeField)
                        }
                        .submitLabel(.done)
                        .onSubmit(add)
                    QuietButton(title: "Add", icon: ReffiIcon.add, action: add)
                }

                if tags.isEmpty {
                    Text("None yet")
                        .reffiType(.caption).foregroundStyle(ReffiColor.muted)
                        .padding(.top, ReffiSpace.s1)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: ReffiSpace.s2)],
                              alignment: .leading, spacing: ReffiSpace.s2) {
                        ForEach(tags, id: \.self) { tag in
                            Button { remove(tag) } label: {
                                HStack(spacing: ReffiSpace.s1) {
                                    Text(tag)
                                        .font(ReffiTextRole.caption.font)
                                        .tracking(ReffiTextRole.caption.tracking)
                                        .foregroundStyle(ReffiColor.ink).lineLimit(1)
                                    ReffiIcon.close.reffi(11, .bold).foregroundStyle(ReffiColor.ink2)
                                }
                                .padding(.horizontal, ReffiSpace.s3)
                                .padding(.vertical, ReffiSpace.s2)
                                .background(ReffiColor.sub, in: PaperCutRect(seed: 4))   // §13.1 종이컷 8각형(캡슐 금지)
                                .frame(minHeight: 44)          // §7.3 터치 타깃
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.reffiPress)
                            .accessibilityLabel("Remove \(tag)")
                        }
                    }
                }
            }
        }
    }

    private func add() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { draft = ""; return }
        tags.append(trimmed)
        draft = ""
    }
    private func remove(_ tag: String) { tags.removeAll { $0 == tag } }
}

/// 알림 시간 선택(§2.1.2) — 아침 리마인더 시각(시 단위).
/// SSOT는 `ExpiryNotifier.hourKey`(ProfileView 토글과 같은 키). ExpiryNotifier는 정시(:00)에만
/// 발화하므로 시(hour) 단위로 선택한다 — 스케줄에 반영되지 않을 분(minute)은 UI에 노출하지 않는다.
struct NotifyTimeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ExpiryNotifier.hourKey) private var alertHour = ExpiryNotifier.defaultHour

    var body: some View {
        SheetShell(title: "Alert time", onClose: { dismiss() }) {
            Picker("", selection: $alertHour) {
                ForEach(6..<22, id: \.self) { h in
                    Text(verbatim: Self.hourLabel(h)).tag(h)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
        }
    }

    /// 정시 라벨 — "8:00 AM" 형식(로케일 자동).
    static func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}
