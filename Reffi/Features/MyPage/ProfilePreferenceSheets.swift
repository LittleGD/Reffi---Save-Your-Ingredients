import SwiftUI

/// 선택 가능한 종이 칩 — 선택 시 Blue 면+화이트, 미선택은 sub 면+ink(§2.6). 칩 패턴은 Chips.swift 계열.
/// 면은 §13.1 종이컷 8각형(`PaperCutRect`)이다 — 완벽한 캡슐은 행동 표면에서 금지다.
/// 칩 비주얼은 작게 유지하되 히트 영역은 44pt 확보(§7.3).
struct SelectableChip: View {
    let text: String
    let selected: Bool
    var fullWidth: Bool = true   // 행 균등 분배(D-N 행)용. 그리드/플로우에선 false로 자연 폭.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(ReffiTextRole.caption.font)
                .tracking(ReffiTextRole.caption.tracking)
                .foregroundStyle(selected ? .white : ReffiColor.ink)
                .lineLimit(1)
                .padding(.horizontal, ReffiSpace.s3)
                .padding(.vertical, ReffiSpace.s2)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .background(selected ? ReffiColor.blue : ReffiColor.sub, in: PaperCutRect(seed: 1))
                .frame(minHeight: 44)          // §7.3 터치 타깃 — 비주얼은 종이 칩, 히트는 44
                .contentShape(Rectangle())
        }
        .buttonStyle(.reffiPress)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// 시트 공통 셸 — 크림 캔버스 + `SheetHeader`(좌측 타이틀 + 종이 X) + 콘텐츠. 편집 시트를 통일한다.
/// 헤더는 인터랙션 커먼 룰 ②③의 단일 공급원 `SheetHeader`에 위임 — 인라인 종이 X 조립을 제거했다.
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
    }
}

/// 닉네임 편집(§5.1.1).
struct NicknameEditSheet: View {
    @Environment(ProfileStore.self) private var profile
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""

    var body: some View {
        SheetShell(title: "Nickname", onClose: { dismiss() }) {
            VStack(alignment: .leading, spacing: ReffiSpace.s4) {
                TextField("Nickname", text: $draft)
                    .reffiType(.body)
                    .foregroundStyle(ReffiColor.ink)
                    .padding(.horizontal, ReffiSpace.s4)
                    .padding(.vertical, ReffiSpace.s3)
                    .background {
                        let s = PaperRect(cornerRadius: ReffiRadius.md, seed: 2)
                        s.fill(ReffiColor.paper).paperEdge(s, tint: ReffiColor.ink.opacity(0.1))
                    }
                    .submitLabel(.done)
                    .onSubmit(commit)

                PaperButton(title: "Save", seed: 1, action: commit)
            }
        }
        .onAppear { draft = profile.nickname }
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
                            s.fill(ReffiColor.paper).paperEdge(s, tint: ReffiColor.ink.opacity(0.1))
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
