import SwiftUI
import Vision
import VisionKit
import PhotosUI

/// 영수증 스캔 — 카메라(문서 스캐너) 또는 사진에서 영수증을 읽어(온디바이스 Vision OCR, ko+en)
/// 정본 재료 사전으로 매핑된 후보를 체크리스트로 확인 후 일괄 등록한다.
/// 인식·매핑은 전부 온디바이스 — 네트워크 전송 없음.
///
/// `AddIngredientSheet`가 그대로 감싸는 1차 추가 표면(사용자 결정 2026-08-01) — 픽커·검색·
/// 직접 입력 폴백은 없다. presentationDetents는 여기서 적용한다(호출부 중복 금지).
struct ReceiptScanView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    enum Phase {
        case pick                          // 소스 선택(카메라/사진)
        case processing                    // OCR 진행
        case review                        // 확인 리스트(후보는 `candidates` 상태)
    }

    @State private var phase: Phase = .pick
    @State private var showCamera = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var candidates: [EditableCandidate] = []
    @State private var selected: Set<UUID> = []
    @State private var editingCandidate: EditableCandidate?   // 인라인 편집 시트 대상(연필 아이콘)
    @State private var addedHaptic = 0

    private var cameraAvailable: Bool { VNDocumentCameraViewController.isSupported }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(ReffiColor.canvas)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(ReffiColor.canvas)
        .sensoryFeedback(.success, trigger: addedHaptic)
        .fullScreenCover(isPresented: $showCamera) {
            DocumentCameraView { images in
                showCamera = false
                guard !images.isEmpty else { return }
                recognize(images)
            }
            .ignoresSafeArea()
        }
        .sheet(item: $editingCandidate) { candidate in
            CandidateEditSheet(candidate: candidate) { updated in
                if let idx = candidates.firstIndex(where: { $0.id == updated.id }) {
                    candidates[idx] = updated
                }
            }
        }
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await loadPhotos(items) }
        }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .pick: pickSource
        case .processing: processing
        case .review: review
        }
    }

    /// 시트 헤더 — SheetHeader 공용 컴포넌트(좌측 타이틀·.heading, 룰②③). 이전 중앙정렬·.subhead ZStack을 통일했다.
    private var header: some View {
        SheetHeader(title: "Scan a receipt", showsClose: true) { dismiss() }
    }

    // MARK: - 소스 선택

    private var pickSource: some View {
        VStack(spacing: ReffiSpace.s4) {
            ReffiIcon.receipt.reffi(44).foregroundStyle(ReffiColor.blueDark)
            Text("Snap the receipt. Groceries land in your fridge.")
                .reffiType(.body).foregroundStyle(ReffiColor.ink2)
                .multilineTextAlignment(.center)

            if cameraAvailable {
                PaperButton(title: "Scan with camera") { showCamera = true }
            }
            // Button이 아닌 컨트롤에도 CTA 표면을 공용 킷에서 가져온다(`PaperButtonLabel` + `.paperPress`).
            // 손으로 재조립하던 예전 면은 fill이 `blueLight`(킷 secondary 정본은 `sub`)에 질감·그림자·
            // 눌림이 모두 빠져 있어, 바로 위 "Scan with camera"와 나란히 두면 재질이 어긋났다(감사 R4-2).
            PhotosPicker(selection: $photoItems, maxSelectionCount: 3, matching: .images) {
                PaperButtonLabel(title: "Choose photos", kind: .secondary, seed: 3)
            }
            .buttonStyle(.paperPress)
            Text("Everything is read on this device. Nothing is uploaded.")
                .reffiType(.caption).foregroundStyle(ReffiColor.muted)
        }
        .padding(ReffiSpace.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReffiColor.canvas)
    }

    private var processing: some View {
        VStack(spacing: ReffiSpace.s4) {
            ProgressView()
            Text("Reading receipt…").reffiType(.body).foregroundStyle(ReffiColor.ink2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReffiColor.canvas)
    }

    // MARK: - 확인 리스트

    @ViewBuilder private var review: some View {
        if candidates.isEmpty {
            VStack(spacing: ReffiSpace.s3) {
                Text("Nothing recognized").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
                Text("Try again with a clearer photo.")
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                PaperButton(title: "Try again", kind: .secondary) { phase = .pick }
                    .padding(.top, ReffiSpace.s3)
            }
            .padding(ReffiSpace.s6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ReffiColor.canvas)
        } else {
            VStack(spacing: 0) {
                List {
                    Section {
                        ForEach(candidates) { c in
                            candidateRow(c)
                                .listRowBackground(Color.clear)
                                // 행 구분선은 §6.1 소관이라 종이 단면(`paperEdge`)이 아니다 — 알파가 같아도 역할이 다르다.
                                .listRowSeparatorTint(ReffiColor.ink.opacity(0.06))
                        }
                    } footer: {
                        Text("Use-by dates are filled from the ingredient dictionary. Adjust anytime in Fridge.")
                            .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                PaperButton(title: "Add \(selected.count) items") { add() }
                    .padding(.horizontal, ReffiGrid.margin)
                    .padding(.vertical, ReffiSpace.s3)
                    .disabled(selected.isEmpty)   // 디밍은 PaperButton이 §7.2로 처리 — 여기서 겹치면 곱해진다.
            }
        }
    }

    /// 후보 행 — 좌: 선택 체크(44pt), 가운데: 이름(+추정 배지)·원문·수량, 우: 편집 진입 연필(44pt).
    /// 체크와 연필은 각각 독립 버튼(중첩 Button 대신 분리)이라 VoiceOver·탭 판정이 서로 간섭하지 않는다.
    private func candidateRow(_ c: EditableCandidate) -> some View {
        let isOn = selected.contains(c.id)
        return HStack(spacing: ReffiSpace.s2) {
            Button {
                toggleSelection(c.id)
            } label: {
                // 앱 유일하던 SF Symbol(checkmark.circle)을 걷어내고 Phosphor 체크 글리프 + 종이 상자로.
                // "선택 = 체크 글리프"는 PaperDropdown·To buy 타일과 같은 문법이다.
                let box = PaperRect(cornerRadius: ReffiRadius.sm, seed: 6)
                ReffiIcon.check.reffi(12, .bold)
                    .foregroundStyle(isOn ? Color.white : .clear)
                    .frame(width: 22, height: 22)
                    .background {
                        box.fill(isOn ? ReffiColor.blue : ReffiColor.paper)
                            .paperEdge(box, tint: isOn ? ReffiColor.paperEdgeOnFill
                                                       : ReffiColor.ink.opacity(0.18))
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.paperPress)
            .accessibilityLabel(Text(verbatim: c.name))
            .accessibilityValue(isOn ? Text("Selected") : Text(verbatim: ""))

            // 이름 블록도 체크와 **같은 토글**이라 같은 컨트롤이어야 한다 — 탭 제스처만 얹으면
            // 보조기술엔 그냥 글자로 서고(누를 수 있다는 신호가 없다) 눌림도 없다(§7.5).
            Button { toggleSelection(c.id) } label: {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: ReffiSpace.s2) {
                        Text(verbatim: c.name).reffiType(.body).foregroundStyle(ReffiColor.ink)
                        if c.showsEstimateBadge { estimateBadge }
                    }
                    Text(verbatim: c.rawLine).reffiType(.caption).foregroundStyle(ReffiColor.muted)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.paperPress)
            .accessibilityValue(isOn ? Text("Selected") : Text(verbatim: ""))

            Spacer(minLength: ReffiSpace.s2)

            Text(verbatim: c.quantity.text)
                .reffiType(.caption).foregroundStyle(ReffiColor.ink2)

            Button {
                editingCandidate = c
            } label: {
                ReffiIcon.manual.reffi(14)
                    .foregroundStyle(ReffiColor.ink2)
                    .frame(width: 34, height: 34)
                    .background {
                        let s = PaperRect(cornerRadius: ReffiRadius.sm, seed: 3)
                        s.fill(ReffiColor.paper).paperEdge(s)
                    }
                    .frame(minWidth: 44, minHeight: 44)   // §7.3 터치 타깃
                    .contentShape(Rectangle())
            }
            .buttonStyle(.paperPress)   // §7.5 — 종이 면에는 종이 프레스(.plain은 눌림이 없다)
            .accessibilityLabel(Text("Edit \(c.name)"))
        }
    }

    /// 추정 기한 배지 — 사전 미매칭(D+3 폴백) 또는 매칭돼도 해당 보관 shelfLife 데이터가 없는 항목.
    /// soonDark 톤 종이 칩(§2.6 신선도 팔레트 재사용 + §13.1 종이컷 8각형) — 새 컴포넌트가 아니라 기존 언어의 조합.
    private var estimateBadge: some View {
        Text("Est. date: check")
            .reffiType(.pillLabel)
            .foregroundStyle(ReffiColor.soonDark)
            .padding(.horizontal, ReffiSpace.s2)
            .padding(.vertical, 2)
            .background(ReffiColor.soonLight, in: PaperCutRect(seed: 6))
            .lineLimit(1)
            .fixedSize()
    }

    private func toggleSelection(_ id: UUID) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    // MARK: - OCR 파이프라인

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        phase = .processing
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                images.append(img)
            }
        }
        photoItems = []
        recognize(images)
    }

    /// Vision OCR(ko+en, 온디바이스) → ReceiptParser 후보(+ 상호명). 무거운 인식은 백그라운드에서.
    private func recognize(_ images: [UIImage]) {
        phase = .processing
        Task.detached(priority: .userInitiated) {
            var lines: [String] = []
            for image in images {
                guard let cg = image.cgImage else { continue }
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["ko-KR", "en-US"]
                request.usesLanguageCorrection = true
                let handler = VNImageRequestHandler(cgImage: cg,
                                                    orientation: .init(image.imageOrientation))
                try? handler.perform([request])
                let observed = (request.results ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                lines.append(contentsOf: observed)
            }
            let found = ReceiptParser.candidates(from: lines)
            let placeGuess = ReceiptParser.storeName(from: lines) ?? ""
            await MainActor.run {
                candidates = found.map { EditableCandidate($0, place: placeGuess) }
                selected = Set(candidates.map(\.id))   // 기본 전체 선택 — 빼는 쪽이 마찰이 적다
                phase = .review
            }
        }
    }

    /// 선택 항목 일괄 등록 — 소비기한·보관·구매처는 각 후보의 편집 상태(기본 사전값 또는 사용자 편집)를
    /// 그대로 쓴다. 배치 API로 스냅샷 기록·알림 재스케줄을 1회만 수행한다.
    private func add() {
        let items = candidates.filter { selected.contains($0.id) }.map { c -> Ingredient in
            let glyph = FoodGlyph.match(c.name)   // 편집으로 이름이 바뀌었으면 여기서 새로 해석
            return Ingredient(name: c.name,
                              category: glyph.categoryLabel,
                              expiresAt: c.expiresAt,
                              quantity: c.quantity,
                              glyph: glyph,
                              place: c.place,
                              storage: c.storage,
                              canonicalID: c.canonicalID)
        }
        store.add(contentsOf: items)
        addedHaptic += 1
        dismiss()
    }
}

/// 스캔 후보의 편집 가능한 래퍼 — `ReceiptParser.Candidate`는 순수 파서 산출물로 그대로 두고,
/// 뷰 쪽 상태(보관·소비기한·구매처·사용자 편집 여부)만 여기서 얹는다(파서 시그니처 불변).
private struct EditableCandidate: Identifiable {
    let id: UUID
    var rawLine: String
    var name: String
    var canonicalID: String?
    var quantity: Quantity
    var storage: StorageLocation = .fridge
    var expiresAt: Date
    var place: String
    var expiryTouched = false   // 편집 시트에서 소비기한을 직접 만졌으면 재계산·배지를 멈춘다.

    init(_ c: ReceiptParser.Candidate, place: String) {
        id = c.id
        rawLine = c.rawLine
        name = c.name
        canonicalID = c.canonicalID
        quantity = c.quantity
        self.place = place
        expiresAt = IngredientLexicon.shared.defaultExpiry(for: c.name, storage: .fridge)
            ?? Ingredient.day(offset: 3)
    }

    /// 추정 기한 배지 노출 조건 — 미매칭(D+3 폴백) 또는 매칭돼도 해당 보관 shelfLife 데이터가 전혀 없음.
    /// 사용자가 날짜를 직접 편집하면 더는 "추정"이 아니므로 숨긴다.
    var showsEstimateBadge: Bool {
        !expiryTouched && IngredientLexicon.shared.shelfLifeDays(for: name, storage: storage) == nil
    }
}

/// 후보 한 건만 고치는 컴팩트 편집 시트 — 종이 언어 재사용(크림 캔버스 + 흰 영수증 카드 + ReffiRule +
/// 모노 라벨 없이 라벨 좌/컨트롤 우 행). 새 컴포넌트가 아니라 `AddIngredientSheet`와 같은 문법.
private struct CandidateEditSheet: View {
    /// 이 시트에서 열릴 수 있는 종이 드롭다운 — 한 번에 하나만 연다(`DropdownAnchorKey` 전제).
    private enum OpenDropdown { case unit, storage }

    @State var candidate: EditableCandidate
    var onSave: (EditableCandidate) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var openDropdown: OpenDropdown?

    /// applySmartExpiry와 같은 결정론 가드 — 대입 전 기록한 값과 다르면만 사용자 터치로 인정.
    @State private var lastProgrammaticExpiry: Date?

    // 미저장 보호(룰⑨) — 편집 시트라 값이 하나라도 바뀌면 스와이프/닫기에 Discard 확인을 띄운다.
    @State private var isDirty = false
    @State private var showDiscardConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                fieldsCard
                    .padding(.horizontal, ReffiGrid.margin)
                    .padding(.top, ReffiSpace.s3)
                    .padding(.bottom, ReffiSpace.s4)
            }
            actionBar
        }
        .background(ReffiColor.canvas)
        // 종이 드롭다운 오버레이 2종 — 열린 트리거만 앵커를 올리므로 동시에 하나만 뜬다.
        // `.medium` 시트라 세로 여유가 좁다: 모디파이어가 아래/위 공간을 재 뒤집고 높이를 캡한다.
        .paperDropdownOverlay(isPresented: openDropdown == .unit,
                              options: IngredientUnit.allCases,
                              selected: candidate.quantity.unit,
                              label: { $0.label }, seed: 5,
                              onDismiss: { closeDropdown() },
                              onSelect: { candidate.quantity.unit = $0 })
        .paperDropdownOverlay(isPresented: openDropdown == .storage,
                              options: StorageLocation.allCases,
                              selected: candidate.storage,
                              label: { $0.label }, seed: 3,
                              onDismiss: { closeDropdown() },
                              onSelect: { candidate.storage = $0 })
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(ReffiColor.canvas)
        .interactiveDismissDisabled(isDirty)
        .onChange(of: candidate.name) { _, newName in
            candidate.canonicalID = IngredientLexicon.shared.canonicalID(for: newName)
            recomputeExpiryIfNeeded()
            isDirty = true
        }
        .onChange(of: candidate.storage) { _, _ in
            recomputeExpiryIfNeeded()
            isDirty = true
        }
        .onChange(of: candidate.expiresAt) { _, newValue in
            if newValue != lastProgrammaticExpiry {
                candidate.expiryTouched = true
                isDirty = true
            }
        }
        .onChange(of: candidate.quantity.value) { _, _ in isDirty = true }
        .onChange(of: candidate.quantity.unit) { _, _ in isDirty = true }
        .onChange(of: candidate.place) { _, _ in isDirty = true }
        .confirmationDialog(Text("Discard changes?"), isPresented: $showDiscardConfirm,
                            titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
        } message: {
            Text("Your changes won't be saved.")
        }
    }

    private var header: some View {
        SheetHeader(title: "Edit item", showsClose: true) { requestClose() }
    }

    private func toggle(_ which: OpenDropdown) {
        let opening = openDropdown != which
        withAnimation(ReffiMotion.gated(opening ? ReffiMotion.pop : ReffiMotion.exit,
                                        reduce: reduceMotion)) {
            openDropdown = opening ? which : nil
        }
    }

    private func closeDropdown() {
        withAnimation(ReffiMotion.gated(ReffiMotion.exit, reduce: reduceMotion)) { openDropdown = nil }
    }

    /// 미저장 변경이 있으면 즉시 닫지 않고 Discard 확인을 띄운다(룰⑨).
    private func requestClose() {
        if isDirty {
            showDiscardConfirm = true
        } else {
            dismiss()
        }
    }

    private var fieldsCard: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s3) {
            TextField("Name", text: $candidate.name,
                      prompt: Text("Name").foregroundStyle(ReffiColor.ink2))
                .reffiType(.body).foregroundStyle(ReffiColor.ink)
                .frame(minHeight: 44)

            ReffiRule(.ticket)

            HStack {
                Text("Quantity").reffiType(.body).foregroundStyle(ReffiColor.ink)
                Spacer()
                TextField("1", value: $candidate.quantity.value, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    // §3.4 숫자는 tabular·lining — 같은 역할의 `IngredientEditView` 수량 필드와 같은 롤.
                    .font(.reffiNum(.body))
                    .foregroundStyle(ReffiColor.ink)
                    .frame(width: 64)
                // 스톡 시스템 팝업 대신 앱 커스텀 종이 드롭다운(커먼 룰 H) — IngredientEditView와 같은 문법.
                PaperDropdownTrigger(label: candidate.quantity.unit.label,
                                     isOpen: openDropdown == .unit, seed: 5) { toggle(.unit) }
                    .accessibilityLabel(Text("Unit"))
                    .accessibilityValue(Text(verbatim: candidate.quantity.unit.label))
            }
            .frame(minHeight: 44)

            ReffiRule(.ticket)

            HStack {
                Text("Storage").reffiType(.body).foregroundStyle(ReffiColor.ink)
                Spacer()
                // 저장값은 영문 식별자 그대로, 표시만 로컬라이즈(`StorageLocation.label`).
                PaperDropdownTrigger(label: candidate.storage.label,
                                     isOpen: openDropdown == .storage, seed: 3) { toggle(.storage) }
                    .accessibilityLabel(Text("Storage"))
                    .accessibilityValue(Text(verbatim: candidate.storage.label))
            }
            .frame(minHeight: 44)

            ReffiRule(.ticket)

            HStack {
                Text("Use by").reffiType(.body).foregroundStyle(ReffiColor.ink)
                Spacer()
                DatePicker("", selection: $candidate.expiresAt,
                           in: Ingredient.day(offset: -30)...Ingredient.day(offset: 365),
                           displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(ReffiColor.blue)
            }
            .frame(minHeight: 44)

            ReffiRule(.ticket)

            TextField("Where you bought it", text: $candidate.place,
                      prompt: Text("Where you bought it").foregroundStyle(ReffiColor.ink2))
                .reffiType(.body).foregroundStyle(ReffiColor.ink)
                .frame(minHeight: 44)
        }
        .receiptSurface()
    }

    private var actionBar: some View {
        PaperButton(title: "Save") {
            onSave(candidate)
            dismiss()
        }
        .padding(.horizontal, ReffiGrid.margin)
        .padding(.top, ReffiSpace.s3)
        .padding(.bottom, ReffiSpace.s3)
    }

    /// 이름·보관이 바뀔 때마다, 사용자가 날짜를 만지기 전까지만 사전 기본값으로 재계산.
    /// AddIngredientSheet.applySmartExpiry와 같은 결 — 값 비교로 자동채움/사용자 터치를 구분한다.
    private func recomputeExpiryIfNeeded() {
        guard !candidate.expiryTouched else { return }
        let smart = IngredientLexicon.shared.defaultExpiry(for: candidate.name, storage: candidate.storage)
            ?? Ingredient.day(offset: 3)
        lastProgrammaticExpiry = smart
        candidate.expiresAt = smart
    }
}

/// VisionKit 문서 스캐너 래퍼 — 영수증에 최적(자동 크롭·다중 페이지).
private struct DocumentCameraView: UIViewControllerRepresentable {
    var onFinish: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onFinish: ([UIImage]) -> Void
        init(onFinish: @escaping ([UIImage]) -> Void) { self.onFinish = onFinish }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            onFinish((0..<scan.pageCount).map(scan.imageOfPage(at:)))
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onFinish([])
        }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            onFinish([])
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
