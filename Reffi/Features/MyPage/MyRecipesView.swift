import SwiftUI

/// 내 레시피 — 사용자 커스텀 레시피 목록·추가·편집·삭제. 저장하면 즉시 추천 풀에 합류한다
/// (커스텀이 시드보다 우선). 시드 레시피는 여기 나오지 않는다(편집 불가 데이터).
///
/// 인터랙션 커먼 룰 종이화(룰 ⑤): 시스템 `NavigationStack`+`List`+글래스 툴바를 걷어내고
/// 크림 캔버스(`ReffiColor.canvas`) + `SheetHeader`(좌측 타이틀·X, 룰 ②③④) + 종이 카드 리스트로 재조립한다.
/// ProfileView가 `.sheet`로 여는 하단 시트이므로 헤더는 `SheetHeader`(좌측), detent는 콘텐츠 많음 → `.large`(룰 ⑪).
struct MyRecipesView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var editing: Recipe?
    @State private var creating = false

    var body: some View {
        VStack(spacing: 0) {
            // 룰 ②③④: 시트 헤더는 좌측 타이틀 + 종이 X(핸들이 주 신호, X는 보조). 시스템 Close 툴바 대체.
            SheetHeader(title: "My recipes", showsClose: true) { dismiss() }

            ScrollView {
                VStack(spacing: ReffiSpace.s3) {
                    addCard   // 룰 ⑤: 시스템 ＋ 툴바 → 종이 스타일 "＋ Add recipe" 카드로 대체.

                    if store.userRecipes.isEmpty {
                        emptyHint
                    } else {
                        // 인덱스로 종이 컷 seed를 살짝 흔들어 손으로 오린 듯한 결을 준다(시각 seed는 영속 불필요).
                        ForEach(Array(store.userRecipes.enumerated()), id: \.element.id) { index, recipe in
                            recipeCard(recipe, seed: 3 + index % 6)
                        }
                    }
                }
                .padding(.horizontal, ReffiGrid.margin)
                .padding(.top, ReffiSpace.s2)
                .padding(.bottom, ReffiSpace.s3)
            }
        }
        .background(ReffiColor.canvas)
        .presentationDetents([.large])                    // 룰 ⑪: 긴 목록 → .large
        .presentationDragIndicator(.visible)              // 룰 ④: 핸들이 주 닫기 신호
        .presentationBackground(ReffiColor.canvas)
        .sheet(isPresented: $creating) { RecipeEditorView(recipe: nil) }
        .sheet(item: $editing) { RecipeEditorView(recipe: $0) }
    }

    // MARK: - 추가 카드 (종이 ＋ — 시트 진입이므로 조용한 종이 면, 룰 ⑩)

    private var addCard: some View {
        Button { creating = true } label: {
            HStack(spacing: ReffiSpace.s2) {
                ReffiIcon.add.reffi(15, .bold).foregroundStyle(ReffiColor.ink)
                Text("Add recipe").reffiType(.body).foregroundStyle(ReffiColor.ink)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, ReffiSpace.s5)
            .frame(minHeight: 52)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background {
                let s = PaperRect(cornerRadius: ReffiRadius.md, seed: 2)
                s.fill(ReffiColor.paper).paperEdge(s)
            }
            .reffiShadow1()
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel(Text("Add recipe"))
    }

    // MARK: - 레시피 행 카드 (탭 → 편집 시트, 조용한 chevron으로 예고 · 룰 ⑩)

    private func recipeCard(_ recipe: Recipe, seed: Int) -> some View {
        Button { editing = recipe } label: {
            HStack(spacing: ReffiSpace.s3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: recipe.displayName)
                        .reffiType(.body).foregroundStyle(ReffiColor.ink)
                        .lineLimit(1).truncationMode(.tail)
                    Text(verbatim: recipe.ingredients.map(\.displayName).joined(separator: ", "))
                        .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                        .lineLimit(1).truncationMode(.tail)
                }
                Spacer(minLength: ReffiSpace.s2)
                ReffiIcon.chevron.reffi(13, .bold).foregroundStyle(ReffiColor.ink2)
            }
            .padding(.horizontal, ReffiSpace.s5)
            .frame(minHeight: 60)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background {
                let s = PaperRect(cornerRadius: ReffiRadius.md, seed: seed)
                s.fill(ReffiColor.paper).paperEdge(s)
            }
            .reffiShadow1()
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel(Text(recipe.displayName))
        .accessibilityHint(Text("Edit recipe"))
    }

    private var emptyHint: some View {
        Text("Recipes you add appear in the ticket deck alongside the built-in ones.")
            .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ReffiSpace.s2)
            .padding(.top, ReffiSpace.s2)
    }
}

/// 커스텀 레시피 편집기 — 이름·재료(쉼표 구분)·단계(줄바꿈 구분)·시간.
/// 재료는 저장 시 정본 사전으로 canonical 매칭돼 추천·발주에 정확히 물린다.
///
/// 표면은 `IngredientEditView`와 같은 종이 문법(룰 ⑤): 크림 캔버스 + `SheetHeader` + 흰 영수증 카드
/// (`ReceiptShape`) + 모노 섹션 라벨 + `DashedRule` + 도킹된 `PaperButton`. 시스템 폼·글래스 툴바를 쓰지 않는다.
/// 저장은 하단 도킹 CTA로 명시적 커밋(룰 ⑥, 생성=Add·편집=Save). 미저장 변경이 있으면 스와이프/닫기에
/// Discard 확인(룰 ⑨). 삭제는 국소 정정 경로라 편집 시에만 노출하며 `.confirmationDialog`(룰 ⑧)+`.warning` 햅틱(룰 ⑦).
struct RecipeEditorView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let recipe: Recipe?   // nil = 새로 만들기

    @State private var name = ""
    @State private var ingredientsText = ""
    @State private var stepsText = ""
    @State private var minutes = 20
    @State private var didLoad = false

    // 룰 ⑨(미저장 보호) — load 시점의 baseline. 현재값과 다르면 isDirty.
    @State private var baseName = ""
    @State private var baseIngredients = ""
    @State private var baseSteps = ""
    @State private var baseMinutes = 20

    @State private var showDiscardConfirm = false
    @State private var showDeleteConfirm = false
    @State private var savedHaptic = 0     // 룰 ⑦: 저장·추가 = .success
    @State private var deleteHaptic = 0    // 룰 ⑦: 파괴 확인 = .warning

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var parsedIngredients: [String] {
        ingredientsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    private var parsedSteps: [String] {
        stepsText.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var canSave: Bool { !trimmedName.isEmpty && !parsedIngredients.isEmpty }
    private var isDirty: Bool {
        name != baseName || ingredientsText != baseIngredients
            || stepsText != baseSteps || minutes != baseMinutes
    }

    var body: some View {
        VStack(spacing: 0) {
            // 룰 ②③: 좌측 타이틀 + 종이 X. X는 미저장 보호를 태워 닫는다(룰 ⑨).
            SheetHeader(title: recipe == nil ? "Add recipe" : "Edit recipe",
                        showsClose: true, onClose: attemptClose)

            ScrollView {
                VStack(spacing: ReffiSpace.s3) {
                    recipeCard
                    ingredientsCard
                    stepsCard
                    if recipe != nil { deleteSection }   // 삭제는 편집 시에만(정정 경로).
                }
                .padding(.horizontal, ReffiGrid.margin)
                .padding(.top, ReffiSpace.s2)
                .padding(.bottom, ReffiSpace.s3)
            }
            .scrollDismissesKeyboard(.interactively)

            actionBar
        }
        .background(ReffiColor.canvas)
        .presentationDetents([.medium, .large])     // 룰 ⑪: 편집 폼 → .medium 진입 + 키보드/긴 내용 시 .large 승격
        .presentationDragIndicator(.visible)
        .presentationBackground(ReffiColor.canvas)
        .interactiveDismissDisabled(isDirty)         // 룰 ⑨: 변경 있으면 스와이프 실수로 닫히지 않음
        .sensoryFeedback(.success, trigger: savedHaptic)
        .sensoryFeedback(.warning, trigger: deleteHaptic)
        .confirmationDialog(Text("Discard changes?"), isPresented: $showDiscardConfirm,
                            titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
        } message: {
            Text("Your edits won't be saved.")
        }
        .confirmationDialog(Text("Delete this recipe?"), isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let existing = recipe { store.deleteUserRecipe(id: existing.id) }
                deleteHaptic += 1
                dismiss()
            }
        } message: {
            Text("Removes it from your recipes. Built-in recipes stay.")
        }
        .onAppear { load() }
    }

    // MARK: - 닫기 (룰 ⑨ — 변경 있으면 Discard 확인, 없으면 평범한 dismiss)

    private func attemptClose() {
        if isDirty { showDiscardConfirm = true } else { dismiss() }
    }

    // MARK: - RECIPE 카드 (이름 · 시간)

    private var recipeCard: some View {
        receiptCard {
            sectionLabel("RECIPE")
            TextField("Recipe name", text: $name,
                      prompt: Text("Recipe name").foregroundStyle(ReffiColor.ink2))
                .reffiType(.body).foregroundStyle(ReffiColor.ink)
                .frame(minHeight: 40)

            DashedRule()

            HStack {
                Text("Time").reffiType(.body).foregroundStyle(ReffiColor.ink)
                Spacer()
                Text("\(minutes) min")
                    .font(.reffiNum(16, relativeTo: .body))
                    .foregroundStyle(ReffiColor.ink)
                Stepper(value: $minutes, in: 5...240, step: 5) { Text("Time") }
                    .labelsHidden()
                    .fixedSize()
                    .tint(ReffiColor.blue)
            }
            .frame(minHeight: 40)
        }
    }

    // MARK: - INGREDIENTS 카드 (쉼표 구분)

    private var ingredientsCard: some View {
        receiptCard {
            sectionLabel("INGREDIENTS")
            TextField("Onion, Egg, Rice…", text: $ingredientsText,
                      prompt: Text("Onion, Egg, Rice…").foregroundStyle(ReffiColor.ink2),
                      axis: .vertical)
                .reffiType(.body).foregroundStyle(ReffiColor.ink)
                .lineLimit(2...4)
            Text("Separate with commas.")
                .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
        }
    }

    // MARK: - STEPS 카드 (한 줄 = 한 단계)

    private var stepsCard: some View {
        receiptCard {
            sectionLabel("STEPS")
            TextField("Chop, stir-fry, season…", text: $stepsText,
                      prompt: Text("Chop, stir-fry, season…").foregroundStyle(ReffiColor.ink2),
                      axis: .vertical)
                .reffiType(.body).foregroundStyle(ReffiColor.ink)
                .lineLimit(3...8)
            Text("One step per line.")
                .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
        }
    }

    // MARK: - 삭제 (편집 시에만 — 이력 없는 정정 경로, Save보다 조용한 면 · 룰 ⑦⑧)

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            Button { showDeleteConfirm = true } label: {
                HStack(spacing: ReffiSpace.s2) {
                    ReffiIcon.delete.reffi(15, .bold).foregroundStyle(ReffiColor.urgentDark)
                    Text("Delete recipe")
                        .reffiType(.body).foregroundStyle(ReffiColor.urgentDark)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, ReffiSpace.s5)
                .frame(minHeight: 46)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .background {
                    // 조용한 종이 면 + urgent 틴트 헤어라인(보더 아님) — 그림자 없이 Save보다 잔잔하게.
                    let s = PaperRect(cornerRadius: ReffiRadius.md, seed: 9)
                    s.fill(ReffiColor.paper).paperEdge(s, tint: ReffiColor.urgentDark.opacity(0.18))
                }
            }
            .buttonStyle(.paperPress)
            .accessibilityLabel("Delete recipe")

            Text("Removes it from your recipes. Built-in recipes stay.")
                .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                .padding(.horizontal, ReffiSpace.s2)
        }
    }

    // MARK: - 저장 (도킹 CTA · 룰 ⑥ — 생성=Add / 편집=Save)

    private var actionBar: some View {
        PaperButton(title: recipe == nil ? "Add" : "Save") { save() }
            .disabled(!canSave)   // 이름·재료가 비면 커밋 불가 — PaperButton이 채도·투명도로 표시.
            .padding(.horizontal, ReffiGrid.margin)
            .padding(.top, ReffiSpace.s2)
            .padding(.bottom, ReffiSpace.s2)
    }

    // MARK: - 로드·저장

    private func load() {
        guard !didLoad else { return }   // onAppear 재호출 방어(중복 로드로 baseline 오염 방지).
        didLoad = true
        if let r = recipe {
            name = r.displayName
            ingredientsText = r.ingredients.map(\.displayName).joined(separator: ", ")
            stepsText = r.displaySteps.joined(separator: "\n")
            minutes = r.minutes
        }
        // baseline = 로드 직후 값. 새 레시피는 기본값 그대로라 시작은 not dirty.
        baseName = name
        baseIngredients = ingredientsText
        baseSteps = stepsText
        baseMinutes = minutes
    }

    private func save() {
        var new = Recipe.userRecipe(name: trimmedName, ingredientNames: parsedIngredients,
                                    minutes: minutes, steps: parsedSteps)
        if let existing = recipe {
            new.id = existing.id
            store.updateUserRecipe(new)
        } else {
            store.addUserRecipe(new)
        }
        savedHaptic += 1
        dismiss()
    }

    // MARK: - 헬퍼 (IngredientEditView와 같은 문법 차용)

    /// 흰 영수증 카드 — `IngredientEditView`·`CustomItemSheet`와 같은 면(오린 톱니 + 헤어라인 + 옅은 그림자).
    private func receiptCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let shape = ReceiptShape(tooth: 7)
        return VStack(alignment: .leading, spacing: ReffiSpace.s3) { content() }
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s5 + 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ReffiColor.oklch(0.985, 0.004, 90), in: shape)
            .paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
            .shadow(color: ReffiColor.ink.opacity(0.06), radius: 5, x: 0, y: 2)
    }

    /// 모노 올캡 섹션 라벨 — 오더 티켓 언어(§13.5). `IngredientEditView`의 헬퍼와 동일 문법.
    private func sectionLabel(_ text: String) -> some View {
        Text(verbatim: text)
            .reffiType(.sectionLabel)
            .foregroundStyle(ReffiColor.ink2)
    }
}
