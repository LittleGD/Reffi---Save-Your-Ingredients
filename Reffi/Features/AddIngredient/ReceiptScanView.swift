import SwiftUI
import Vision
import VisionKit
import PhotosUI

/// 영수증 스캔 — 카메라(문서 스캐너) 또는 사진에서 영수증을 읽어(온디바이스 Vision OCR, ko+en)
/// 정본 재료 사전으로 매핑된 후보를 체크리스트로 확인 후 일괄 등록한다.
/// 인식·매핑은 전부 온디바이스 — 네트워크 전송 없음.
///
/// `AddIngredientSheet`가 그대로 감싸는 1차 추가 표면(사용자 결정 2026-08-01) — 일러스트 픽커·
/// 검색은 없다. 다만 **직접 입력은 조용한 링크 한 줄로 남긴다**(사용자 결정 2026-08-19): 영수증이
/// 없거나 스캔이 안 잡히는 날에도 재료 하나를 넣을 길은 있어야 한다. 그 길은 전용 폼이 아니라
/// 후보 편집 시트(`CandidateEditSheet`)를 빈 초안으로 여는 것이다.
/// presentationDetents는 여기서 적용한다(호출부 중복 금지).
struct ReceiptScanView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    enum Phase {
        case pick                          // 소스 선택(카메라/사진)
        case processing                    // OCR 진행
        case review                        // 확인 리스트(후보는 `candidates` 상태)
    }

    @State private var phase: Phase = .pick
    /// 시트 높이를 **단계에 맨다**(49차 → 61차 재조정). 소스 선택은 결정이 셋뿐이라 `.large`는 절반이 빈
    /// 크림이었고(49차), `.medium`은 화면의 절반이라는 뜻일 뿐 콘텐츠와 무관해 이번엔 반대로 **넘쳤다** —
    /// 캡션 둘째 줄이 말줄임으로 사라지고 푸터가 바닥에 붙었다(61차 오너 지적). 그래서 소스 선택은
    /// **콘텐츠 맞춤 높이**(`ReffiSheet.fitDetent`, §14.5)로 서고, 확인 단계만 후보가 열댓 줄이라 `.large`다.
    /// 읽는 중(`processing`)은 소스 선택과 같은 높이를 유지한다 — 결과가 오기 전에 시트가 먼저 커지면
    /// 스피너 하나가 700pt 빈 캔버스 한가운데 서고, 빈 결과면 그 높이가 그대로 남았다(61차 감사).
    @State private var detent: PresentationDetent = .medium
    /// 소스 선택 화면(헤더 포함)의 고유 높이 실측 — `sheetFitHeight`가 채운다.
    @State private var fitHeight: CGFloat = 0
    @State private var showCamera = false
    /// 카메라가 오류로 닫힌 직후 — 취소와 달리 화면이 한 줄로 말한다(42차·F24).
    @State private var scanFailed = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var candidates: [EditableCandidate] = []
    @State private var selected: Set<UUID> = []
    @State private var editingCandidate: EditableCandidate?   // 인라인 편집 시트 대상(연필 아이콘)
    @State private var addedHaptic = 0

    private var cameraAvailable: Bool { VNDocumentCameraViewController.isSupported }

    var body: some View {
        content
            .background(ReffiColor.canvas)
            // 단계별 detent 집합은 **하나씩**이다 — 소스 선택·읽는 중은 맞춤 높이, 확인은 `.large`. 두 값을
            // 한 집합에 두면 소스 선택에서 손으로 `.large`로 끌어올릴 수 있는데, 맞춤 본문은 고유 높이라
            // 그 아래가 빈 크림으로 남는다(볼 것이 없는 높이를 열어 두지 않는다).
            .presentationDetents(phase == .review ? [.large] : [ReffiSheet.fitDetent(fitHeight)],
                                 selection: $detent)
            .onChange(of: phase) { _, p in detent = p == .review ? .large : ReffiSheet.fitDetent(fitHeight) }
            // 실측이 첫 프레임 뒤에 도착하므로 선택값도 따라간다(집합에 없는 선택은 시스템이 무시한다).
            .onChange(of: fitHeight) { _, h in if phase != .review { detent = ReffiSheet.fitDetent(h) } }
            .presentationDragIndicator(.visible)
            .presentationBackground(ReffiColor.canvas)
            .reffiFeedback(.success, trigger: addedHaptic)
            .fullScreenCover(isPresented: $showCamera) {
                DocumentCameraView { images in
                    showCamera = false
                    scanFailed = false
                    guard !images.isEmpty else { return }
                    recognize(images, source: .camera)
                } onFail: {
                    showCamera = false
                    scanFailed = true
                    ReffiAnnounce.say(AppLanguage.localizedNow("The camera closed unexpectedly.\nTry again or add by hand."))
                }
                .ignoresSafeArea()
            }
            // 편집 시트는 하나다 — 스캔 후보 고치기와 직접 입력이 **같은 폼**을 쓴다(초안이 자기 출처를
            // 안고 온다). 직접 입력 전용 폼을 또 세우면 같은 다섯 칸이 두 벌이 되고 규칙도 두 벌이 된다.
            .sheet(item: $editingCandidate) { candidate in
                CandidateEditSheet(candidate: candidate,
                                   title: candidate.isManual ? "Add by hand" : "Edit item") { updated in
                    if updated.isManual {
                        addManual(updated)
                    } else if let idx = candidates.firstIndex(where: { $0.id == updated.id }) {
                        candidates[idx] = updated
                    }
                }
            }
            .onChange(of: photoItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await loadPhotos(items) }
            }
            // 단계 전환은 화면을 통째로 갈아 끼우면서도 포커스를 옮기지 않는다 — 고지가 없으면 스캔을
            // 누른 뒤 무슨 일이 벌어지는지, 끝났는지, 몇 개를 찾았는지가 전부 침묵이다.
            .onChange(of: phase) { _, newPhase in
                switch newPhase {
                case .pick:
                    break   // 되돌아온 자리는 화면이 스스로 말한다(제목·버튼이 다시 선다)
                case .processing:
                    ReffiAnnounce.say(AppLanguage.localizedNow("Reading receipt…"))
                case .review:
                    // 결과 요약까지 말한다 — "끝났다"만으로는 다시 찍어야 하는지 알 수 없다.
                    ReffiAnnounce.say(candidates.isEmpty
                                      ? AppLanguage.localizedNow("No items found")
                                      : AppLanguage.localizedNow("\(candidates.count) items recognized"))
                }
            }
    }

    /// 단계별 본문 — 헤더는 세 단계가 같은 `SheetHeader`다. 소스 선택만 헤더까지 묶어 고유 높이를 잰다
    /// (`sheetFitHeight` — 안에서 `fixedSize`로 세로를 고정하므로 시트 높이에 되먹임되지 않는다).
    @ViewBuilder private var content: some View {
        switch phase {
        case .pick:
            VStack(spacing: 0) {
                header
                pickSource
            }
            .sheetFitHeight($fitHeight)
        case .processing:
            VStack(spacing: 0) {
                header
                processing
            }
        case .review:
            VStack(spacing: 0) {
                header
                review
            }
        }
    }

    /// 시트 헤더 — SheetHeader 공용 컴포넌트(좌측 타이틀·.heading, 룰②③). 이전 중앙정렬·.subhead ZStack을 통일했다.
    private var header: some View {
        SheetHeader(title: "Scan a receipt", showsClose: true) { dismiss() }
    }

    // MARK: - 소스 선택

    /// 소스 선택 — 모티프·캡션·CTA·직접 입력 링크는 중앙 축의 표지형 블록이다(§9.4 ②).
    /// 바닥의 프라이버시 안내는 읽는 문장으로 좌측 정렬한다(62차). 모든 블록의 가로 여백은
    /// 바깥 `sheetInset`이 맡는다.
    ///
    /// 세로는 Spacer가 아니라 **시트 토큰 간격**으로 선다(§14.8): 헤더 → 모티프 묶음(아이콘·캡션 `itemGap`) →
    /// `blockGap` → CTA 묶음(`ctaGap`) → `blockGap` → 조용한 링크 → `blockGap` → 고지 → `bottom`.
    /// 시트 높이가 이 합 그대로라(`sheetFitHeight`) Spacer로 나눌 남는 세로 자체가 없다.
    private var pickSource: some View {
        VStack(spacing: ReffiSheet.blockGap) {
            VStack(spacing: ReffiSheet.itemGap) {
                ReffiIcon.receipt.reffi(44).foregroundStyle(ReffiColor.blueDark)
                Text("Scan your receipt.\nCheck the items, then add them.")
                    .reffiType(.body).foregroundStyle(ReffiColor.ink2)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: ReffiSheet.ctaGap) {
                if cameraAvailable {
                    // 라벨은 짧게(62차 owner), 전체 뜻은 accessibilityLabel이 맡는다(`CookingStepsView`
                    // "Videos" 선례와 같은 문법).
                    PaperButton(title: "Scan") { showCamera = true }
                        .accessibilityLabel(Text("Scan with camera"))
                }
                // Button이 아닌 컨트롤에도 CTA 표면을 공용 킷에서 가져온다(`PaperButtonLabel` + `.paperPress`).
                // 손으로 재조립하던 예전 면은 fill이 `blueLight`(킷 secondary 정본은 `sub`)에 질감·그림자·
                // 눌림이 모두 빠져 있어, 바로 위 "Scan"과 나란히 두면 재질이 어긋났다(감사 R4-2).
                // 라벨은 위 버튼과 같은 이유로 짧게(62차) — 서술은 accessibilityLabel로 남긴다.
                PhotosPicker(selection: $photoItems, maxSelectionCount: 3, matching: .images) {
                    PaperButtonLabel(title: "Photos", kind: .secondary, seed: 3)
                }
                .buttonStyle(.paperPress)
                .accessibilityLabel(Text("Choose photos"))
            }

            VStack(spacing: ReffiSheet.itemGap) {
                // 영수증이 없거나 스캔이 안 잡히는 날의 탈출구 — 면 없는 조용한 링크로 둔다.
                // 종이 CTA로 세우면 스캔과 같은 무게가 돼, 이 화면이 무엇을 권하는지가 흐려진다.
                // 라벨은 목적지 시트 제목("Add by hand")과 같은 낱말이다(42차) — 진입점과 도착지가
                // 다른 이름이면 누를 때마다 화면이 스스로를 개명하는 것으로 읽힌다.
                QuietButton(title: "Add by hand", icon: ReffiIcon.manual) {
                    editingCandidate = EditableCandidate(manualDraft: true)
                }
                if scanFailed {
                    // 표지형 블록 안의 문장이라 중앙이다(61차 — 옛 "페이지 마진 컬럼의 읽는 문장 = 좌측"은
                    // 이 시트에 축을 하나 더 세우는 판정이었다). 링크 바로 아래에 붙는 것은 "다시 시도하거나
                    // 직접 입력"이라는 문장의 두 행동이 정확히 그 위 두 컨트롤이기 때문이다.
                    Text("The camera closed unexpectedly.\nTry again or add by hand.")
                        .reffiType(.caption)
                        .foregroundStyle(ReffiColor.urgentDark)
                        .multilineTextAlignment(.center)
                }
            }

            privacyNote
        }
        .frame(maxWidth: .infinity)
        .sheetInset()
        .padding(.bottom, ReffiSheet.bottom)
    }

    /// 온디바이스 고지 — 시트의 **바닥 문장**이다(버튼 옆에 붙으면 선택을 방해한다). 위의 표지형 블록과
    /// 달리 실제로 읽어야 하는 안내 문장이라 페이지의 좌측 축을 따른다(§9.4 본칙, 62차). 가로 여백과
    /// 바닥 간격은 바깥 `sheetInset`·`ReffiSheet.bottom`이 맡는다. 잉크는 muted 대신 ink2로 한 단
    /// 어둡게 둔다(캡션 크기에서 muted는 캔버스 위 대비가 얕다).
    private var privacyNote: some View {
        Text("Everything is read on this device.\nNothing is uploaded.")
            .reffiType(.caption)
            .foregroundStyle(ReffiColor.ink2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var processing: some View {
        VStack(spacing: ReffiSpace.s4) {
            // 라벨 없는 스피너는 보조기술에서 이름 없는 점 하나다 — 아래 문장과 **같은 말**을 준다.
            ProgressView()
                .accessibilityLabel(Text("Reading receipt…"))
            Text("Reading receipt…").reffiType(.body).foregroundStyle(ReffiColor.ink2)
                // 그 문장이 곧 스피너의 이름이라 두 번 읽을 이유가 없다(화면에는 그대로 남는다).
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 확인 리스트

    @ViewBuilder private var review: some View {
        if candidates.isEmpty {
            VStack(spacing: ReffiSheet.blockGap) {
                VStack(spacing: ReffiSpace.s3) {
                    Text("No items found").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
                    Text("Try a clearer photo of the whole receipt.")
                        .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                }
                PaperButton(title: "Try again", kind: .secondary) { phase = .pick }
            }
            .sheetInset()   // 표지형 빈 상태(§9.4 ②) — 축은 중앙, 인셋은 시트 한 선(§14.8)
            .padding(.vertical, ReffiSheet.blockGap)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                Section {
                    ForEach(candidates) { c in
                        candidateRow(c)
                            .listRowBackground(Color.clear)
                            // 행 구분선은 §6.1 소관이라 종이 단면(`paperEdge`)이 아니다 — 알파가 같아도 역할이 다르다.
                            .listRowSeparatorTint(ReffiColor.paperEdge)
                            // 시스템 plain 행 인셋(≈20)이 아니라 시트 인셋(§14.8) — 체크 상자가 제목과 같은 선에 선다.
                            .listRowInsets(EdgeInsets(top: ReffiSpace.s2, leading: ReffiSheet.inset,
                                                      bottom: ReffiSpace.s2, trailing: ReffiSheet.inset))
                    }
                } footer: {
                    Text("Use-by dates are estimates.\nCheck the packaging and adjust them in Fridge.")
                        .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                        .listRowInsets(EdgeInsets(top: ReffiSpace.s3, leading: ReffiSheet.inset,
                                                  bottom: ReffiSheet.blockGap, trailing: ReffiSheet.inset))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            // 확정 CTA는 도킹한다(§14.4) — 목록 꼬리에 딸리지 않고 safe-area 하단에 붙어 본문만 스크롤한다.
            // 옛 구성(맨 패딩 12/12)은 마지막 행이 버튼 바로 위에서 딱 끊겼다.
            .dockedCTA(over: ReffiColor.canvas, inset: ReffiSheet.inset, bottomInset: ReffiSheet.bottom) {
                PaperButton(title: "Add \(selected.count) items") { add() }
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
                    .foregroundStyle(isOn ? ReffiColor.onAccent : .clear)   // blue 면 위 콘텐츠(§2.7)
                    .frame(width: 22, height: 22)
                    .background {
                        box.fill(isOn ? ReffiColor.blue : ReffiColor.paper)
                            // 미체크 경계는 상태 정본 토큰(§2.7·42차) — α .18은 3:1 미달이었다.
                            .paperEdge(box, tint: isOn ? ReffiColor.paperEdgeOnFill
                                                       : ReffiColor.paperEdgeState)
                    }
                    .frame(width: ReffiChrome.tapMin, height: ReffiChrome.tapMin)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.paperPress)
            .accessibilityLabel(Text(verbatim: c.name))
            .accessibilityValue(isOn ? Text("Checked") : Text("Not checked"))

            // 이름 블록도 체크와 **같은 토글**이라 같은 컨트롤이어야 한다 — 탭 제스처만 얹으면
            // 보조기술엔 그냥 글자로 서고(누를 수 있다는 신호가 없다) 눌림도 없다(§7.5).
            Button { toggleSelection(c.id) } label: {
                // **수량 레일**(49차) — 수량이 `Spacer` 건너 연필 옆에 앉아 있어 이름 길이에 따라
                // x가 매 행 달라졌고, 세로로 열이 서지 않아 "무엇을 몇 개"가 한눈에 안 읽혔다.
                // 이름 왼쪽 44pt trailing 레일로 옮기면 `reffiNum`이 tabular라 숫자가 자릿수에
                // 관계없이 정확히 정렬된다(§3.4) — 그게 곧 종이 영수증의 수량 열이다.
                HStack(alignment: .firstTextBaseline, spacing: ReffiSpace.s2) {
                Text(verbatim: c.quantity.text)
                    .font(.reffiNum(.meta))
                    .foregroundStyle(ReffiColor.ink2)
                    .frame(width: 44, alignment: .trailing)
                VStack(alignment: .leading, spacing: ReffiSpace.s0) {
                    HStack(spacing: ReffiSpace.s2) {
                        Text(verbatim: c.name).reffiType(.body).foregroundStyle(ReffiColor.ink)
                        // 미매칭(44차)은 전용 배지 하나만 — 추정 배지까지 겹치면 칩 둘이 다툰다
                        // (미매칭이면 기한이 추정인 건 자명하다).
                        if c.canonicalID == nil { unknownBadge }
                        else if c.showsEstimateBadge { estimateBadge }
                    }
                    Text(verbatim: c.rawLine).reffiType(.caption).foregroundStyle(ReffiColor.muted)
                        .lineLimit(1)
                }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.paperPress)
            .accessibilityValue(isOn ? Text("Checked") : Text("Not checked"))

            Spacer(minLength: ReffiSpace.s2)

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
                    .frame(minWidth: ReffiChrome.tapMin, minHeight: ReffiChrome.tapMin)   // §7.3 터치 타깃
                    .contentShape(Rectangle())
            }
            .buttonStyle(.paperPress)   // §7.5 — 종이 면에는 종이 프레스(.plain은 눌림이 없다)
            .accessibilityLabel(Text("Edit \(c.name)"))
        }
    }

    /// 추정 기한 배지 — 사전 미매칭(D+3 폴백) 또는 매칭돼도 해당 보관 shelfLife 데이터가 없는 항목.
    /// soonDark 톤 종이 칩(§2.6 신선도 팔레트 재사용 + §13.1 종이컷 8각형) — 새 컴포넌트가 아니라 기존 언어의 조합.
    private var estimateBadge: some View {
        // 배지는 **무엇인지만** 말한다 — "확인 필요"라는 요청은 이미 카드 푸터가 한 번 하고 있어,
        // 칩에 다시 얹으면 같은 화면에서 같은 부탁이 두 번 선다(어느 쪽을 따라야 하는지가 흐려진다).
        Text("Estimated date")
            .reffiType(.pillLabel)
            .foregroundStyle(ReffiColor.soonDark)
            .padding(.horizontal, ReffiSpace.s2)
            .padding(.vertical, ReffiSpace.s0)
            .background(ReffiColor.soonLight, in: PaperCutRect(seed: 6))
            .lineLimit(1)
            .fixedSize()
    }

    /// 사전 미매칭 배지(44차) — 이 줄이 왜 기본 꺼짐인지 행 스스로 말한다. 등록하면 자유 표기
    /// 재고가 된다(캐논 없음). 추정 배지와 같은 문법(soon 팔레트 종이 칩) — 새 컴포넌트 아님.
    private var unknownBadge: some View {
        Text("Not in dictionary")
            .reffiType(.pillLabel)
            .foregroundStyle(ReffiColor.soonDark)
            .padding(.horizontal, ReffiSpace.s2)
            .padding(.vertical, ReffiSpace.s0)
            .background(ReffiColor.soonLight, in: PaperCutRect(seed: 4))
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
        recognize(images, source: .photos)
    }

    /// Vision OCR(ko+en, 온디바이스) → ReceiptParser 후보(+ 상호명). 무거운 인식은 백그라운드에서.
    private func recognize(_ images: [UIImage], source: AnalyticsEvent.ScanSource) {
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
                // 기본 선택은 **사전 매칭 후보만**(빼는 쪽이 마찰이 적다) — 미매칭 라인(44차)은
                // OCR 파편일 수 있어 기본 꺼짐으로 두고, 사용자가 배지("사전에 없음")를 보고 켠다.
                selected = Set(candidates.filter { $0.canonicalID != nil }.map(\.id))
                phase = .review
                // 스캔 품질(64차) — 후보 수 대비 사전 매칭 수. 이후 `ingredient_add{source: receipt}`의
                // count가 실제 등록 수라, 둘의 비가 "OCR·파서가 쓸 만한가"의 지표다.
                Analytics.shared.track(.receiptScan(source: source, pages: images.count,
                                                    candidates: candidates.count, matched: selected.count))
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
        store.add(contentsOf: items, source: .receipt)
        addedHaptic += 1
        dismiss()
    }

    /// 직접 입력 한 건 등록 — 일괄 스캔과 달리 단건 `store.add`다(작업대 상한을 잠시 넘겨서라도
    /// 방금 적은 하나를 바로 보이게 한다). 피드백·닫힘은 스캔 경로와 같은 두 줄.
    private func addManual(_ draft: EditableCandidate) {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }   // 저장 버튼이 이미 막지만, 등록 경로도 스스로 지킨다
        let glyph = FoodGlyph.match(name)
        store.add(Ingredient(name: name,
                             category: glyph.categoryLabel,
                             expiresAt: draft.expiresAt,
                             quantity: draft.quantity,
                             glyph: glyph,
                             place: draft.place,
                             storage: draft.storage,
                             canonicalID: draft.canonicalID))
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
    /// 스캔이 아니라 손으로 적기 시작한 초안인가 — 저장이 목록 갱신이 아니라 **바로 등록**으로 간다.
    var isManual = false

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

    /// 손으로 적는 빈 초안 — 원문도 매칭도 없는 상태로 시작한다. 이름을 치는 순간 편집 시트가
    /// canonicalID와 소비기한을 사전에서 다시 잡으므로(recomputeExpiryIfNeeded), 여기 기한은
    /// 사전이 침묵할 때 쓰이는 폴백(D+3)일 뿐이다.
    init(manualDraft: Bool) {
        id = UUID()
        rawLine = ""
        name = ""
        canonicalID = nil
        quantity = Quantity(value: 1, unit: .piece)
        place = ""
        expiresAt = Ingredient.day(offset: 3)
        isManual = manualDraft
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
    /// 같은 폼이 두 일을 한다 — 스캔 후보 고치기("Edit item")와 직접 입력("Add by hand").
    /// 제목만 출처를 말하고, 칸·규칙·저장 버튼은 한 벌 그대로다.
    var title: LocalizedStringKey = "Edit item"
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
        // 시트 골격은 `SheetShell`(§14.8) — 헤더·도킹 Save·핸들·캔버스 배경을 셸이 세운다.
        SheetShell(title: title, onClose: { requestClose() }) {
            ScrollView {
                fieldsCard
                    .sheetInset()
                    .padding(.bottom, ReffiSheet.blockGap)
            }
            // decimalPad엔 리턴 키가 없다 — 쌍둥이 폼(IngredientEditView)과 같은 탈출구(42차·F23).
            .scrollDismissesKeyboard(.interactively)
        } bar: {
            saveButton
        }
        // 종이 드롭다운 오버레이 2종 — 열린 트리거만 앵커를 올리므로 동시에 하나만 뜬다.
        // 모디파이어가 아래/위 공간을 재 뒤집고 높이를 캡한다.
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
        // 다섯 칸 + Save가 `.medium`(≈392pt 가용)에 568pt라 'Use by'·'Where'가 접힌 채 열렸다(61차 감사) —
        // 쌍둥이 폼(`IngredientEditView`)과 같은 `.large`. 편집 폼의 §14.5 "`.medium` 진입"은 폼이
        // 절반 화면에 **들어갈 때**의 규칙이다.
        .presentationDetents([.large])
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
        // 40차 — 팝업 전수 종이화(§14.7 개정).
        .paperDialog(isPresented: $showDiscardConfirm, title: "Discard changes?",
                    message: "Your changes won't be saved.",
                    seed: 1, backdropDismisses: true,
                    primary: PaperDialogAction("Discard", role: .destructive) { dismiss() },
                    secondary: PaperDialogAction("Cancel", role: .cancel) {})
    }

    /// 진입 `.enter` / 이탈 `.exit`(§7.1) — 메뉴는 읽으러 여는 것이라 예산이 짧다.
    /// `pop`(§7.5)은 종이컷 표면이 튀어 오르는 문법이라 340ms + 오버슈트로 그 예산을 깬다
    /// (냉장고 정렬 메뉴·재료 편집 시트와 같은 판단 — 드롭다운은 앱 전체에서 한 문법이다).
    private func toggle(_ which: OpenDropdown) {
        let opening = openDropdown != which
        withAnimation(ReffiMotion.gated(opening ? ReffiMotion.enter : ReffiMotion.exit,
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
                .frame(minHeight: ReffiChrome.tapMin)

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
                    .frame(minWidth: 64)   // 고정 폭이면 AX 글자에서 세 자리+소수점이 잘린다(42차·F20)
                // 스톡 시스템 팝업 대신 앱 커스텀 종이 드롭다운(커먼 룰 H) — IngredientEditView와 같은 문법.
                // 라벨이 현재 값까지 안고 간다 — 값 자리는 트리거가 펼침/접힘을 말하는 데 쓴다
                // (정렬 칩의 "Filter: …"와 같은 문법).
                PaperDropdownTrigger(label: candidate.quantity.unit.label,
                                     isOpen: openDropdown == .unit, seed: 5) { toggle(.unit) }
                    .accessibilityLabel(Text("Unit: \(candidate.quantity.unit.label)"))
            }
            .frame(minHeight: ReffiChrome.tapMin)

            ReffiRule(.ticket)

            HStack {
                Text("Storage").reffiType(.body).foregroundStyle(ReffiColor.ink)
                Spacer()
                // 저장값은 영문 식별자 그대로, 표시만 로컬라이즈(`StorageLocation.label`).
                PaperDropdownTrigger(label: candidate.storage.label,
                                     isOpen: openDropdown == .storage, seed: 3) { toggle(.storage) }
                    .accessibilityLabel(Text("Storage: \(candidate.storage.label)"))
            }
            .frame(minHeight: ReffiChrome.tapMin)

            ReffiRule(.ticket)

            HStack {
                Text("Use by").reffiType(.body).foregroundStyle(ReffiColor.ink)
                Spacer()
                // 날짜 휠·달력 표기는 기기 로케일을 따른다(38차 — 앱 언어 선택과 분리).
                DatePicker("", selection: $candidate.expiresAt,
                           in: Ingredient.day(offset: -30)...Ingredient.day(offset: 365),
                           displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(ReffiColor.blue)
                    .environment(\.locale, .autoupdatingCurrent)
            }
            .frame(minHeight: ReffiChrome.tapMin)

            ReffiRule(.ticket)

            // 필드 이름은 `IngredientEditView`의 구매처 행과 **같은 한 단어**("Where")다 — 같은 값을
            // 고치는 두 폼이 서로 다른 이름을 쓰면 어느 쪽이 무엇을 담는 칸인지 매번 다시 읽어야 한다.
            // 비어 있을 때 보이는 자리표시자는 이름을 되풀이하지 않고 **예시**를 준다(무엇을 치면 되는지).
            TextField("Where", text: $candidate.place,
                      prompt: Text("e.g. Emart").foregroundStyle(ReffiColor.ink2))
                .reffiType(.body).foregroundStyle(ReffiColor.ink)
                .frame(minHeight: ReffiChrome.tapMin)
        }
        .receiptSurface()
    }

    /// 도킹 Save(§14.4) — 인셋·페이드·바닥 여백은 `SheetShell`이 세운다.
    private var saveButton: some View {
        PaperButton(title: "Save") {
            onSave(candidate)
            dismiss()
        }
        // 이름 없는 재료는 냉장고에서 이름 없는 칸이 된다 — 빈 초안으로 시작하는 직접 입력에서
        // 특히 도달 가능한 상태라, 저장 자체를 막는다(디밍은 PaperButton이 §7.2로 처리).
        .disabled(candidate.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
    /// 실패는 취소와 **다른 사건**이다(42차·F24) — 같은 `onFinish([])`로 접으면 카메라가 오류로
    /// 죽어도 화면이 아무 말도 하지 않아, 사용자가 자기 행동을 의심하게 된다.
    var onFail: () -> Void = {}

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish, onFail: onFail) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onFinish: ([UIImage]) -> Void
        let onFail: () -> Void
        init(onFinish: @escaping ([UIImage]) -> Void, onFail: @escaping () -> Void) {
            self.onFinish = onFinish
            self.onFail = onFail
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            onFinish((0..<scan.pageCount).map(scan.imageOfPage(at:)))
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onFinish([])
        }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            onFail()
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
