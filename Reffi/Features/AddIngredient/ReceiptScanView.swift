import SwiftUI
import Vision
import VisionKit
import PhotosUI

/// 영수증 스캔 — 카메라(문서 스캐너) 또는 사진에서 영수증을 읽어(온디바이스 Vision OCR, ko+en)
/// 정본 재료 사전으로 매핑된 후보를 체크리스트로 확인 후 일괄 등록한다.
/// 인식·매핑은 전부 온디바이스 — 네트워크 전송 없음.
struct ReceiptScanView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    enum Phase {
        case pick                          // 소스 선택(카메라/사진)
        case processing                    // OCR 진행
        case review([ReceiptParser.Candidate])
    }

    @State private var phase: Phase = .pick
    @State private var showCamera = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var selected: Set<UUID> = []
    @State private var addedHaptic = 0

    private var cameraAvailable: Bool { VNDocumentCameraViewController.isSupported }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(Text("Scan a receipt"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
        .sensoryFeedback(.success, trigger: addedHaptic)
        .fullScreenCover(isPresented: $showCamera) {
            DocumentCameraView { images in
                showCamera = false
                guard !images.isEmpty else { return }
                recognize(images)
            }
            .ignoresSafeArea()
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
        case .review(let candidates): review(candidates)
        }
    }

    // MARK: - 소스 선택

    private var pickSource: some View {
        VStack(spacing: ReffiSpace.s4) {
            ReffiIcon.receipt.reffi(44).foregroundStyle(ReffiColor.blueDark)
            Text("Snap the receipt — groceries land in your fridge.")
                .reffiType(.body).foregroundStyle(ReffiColor.ink2)
                .multilineTextAlignment(.center)

            if cameraAvailable {
                PaperButton(title: "Scan with camera") { showCamera = true }
            }
            PhotosPicker(selection: $photoItems, maxSelectionCount: 3, matching: .images) {
                Text("Choose photos")
                    .font(ReffiTextRole.subhead.font).tracking(ReffiTextRole.subhead.tracking)
                    .foregroundStyle(ReffiColor.blueDark)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background {
                        let s = PaperCutRect(seed: 3)
                        s.fill(ReffiColor.blueLight).paperEdge(s, tint: ReffiColor.ink.opacity(0.06))
                    }
            }
            Text("Everything is read on this device — nothing is uploaded.")
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

    @ViewBuilder private func review(_ candidates: [ReceiptParser.Candidate]) -> some View {
        if candidates.isEmpty {
            VStack(spacing: ReffiSpace.s3) {
                Text("Nothing recognized").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
                Text("Try a clearer photo, or add items manually.")
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
                        ForEach(candidates) { c in candidateRow(c) }
                    } footer: {
                        Text("Use-by dates are filled from the ingredient dictionary — adjust anytime in Fridge.")
                    }
                }
                PaperButton(title: "Add \(selected.count) items") { add(candidates) }
                    .padding(.horizontal, ReffiGrid.margin)
                    .padding(.vertical, ReffiSpace.s3)
                    .disabled(selected.isEmpty)
                    .opacity(selected.isEmpty ? 0.5 : 1)
            }
        }
    }

    private func candidateRow(_ c: ReceiptParser.Candidate) -> some View {
        let isOn = selected.contains(c.id)
        return Button {
            if isOn { selected.remove(c.id) } else { selected.insert(c.id) }
        } label: {
            HStack(spacing: ReffiSpace.s3) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? ReffiColor.blue : ReffiColor.muted)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: c.name).reffiType(.body).foregroundStyle(ReffiColor.ink)
                    Text(verbatim: c.rawLine).reffiType(.caption).foregroundStyle(ReffiColor.muted)
                        .lineLimit(1)
                }
                Spacer()
                Text(verbatim: c.quantity.text)
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOn ? Text("Selected") : Text(verbatim: ""))
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

    /// Vision OCR(ko+en, 온디바이스) → ReceiptParser 후보. 무거운 인식은 백그라운드에서.
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
            await MainActor.run {
                selected = Set(found.map(\.id))   // 기본 전체 선택 — 빼는 쪽이 마찰이 적다
                phase = .review(found)
            }
        }
    }

    /// 선택 항목 일괄 등록 — 소비기한은 사전 기본값(냉장), 없으면 D+3.
    /// 배치 API로 스냅샷 기록·알림 재스케줄을 1회만 수행한다.
    private func add(_ candidates: [ReceiptParser.Candidate]) {
        let lexicon = IngredientLexicon.shared
        let items = candidates.filter { selected.contains($0.id) }.map { c in
            let glyph = FoodGlyph.match(c.name)
            let expiry = lexicon.defaultExpiry(for: c.name, storage: .fridge)
                ?? Ingredient.day(offset: 3)
            return Ingredient(name: c.name,
                              category: glyph.categoryLabel,
                              expiresAt: expiry,
                              quantity: c.quantity,
                              glyph: glyph)
        }
        store.add(contentsOf: items)
        addedHaptic += 1
        dismiss()
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
