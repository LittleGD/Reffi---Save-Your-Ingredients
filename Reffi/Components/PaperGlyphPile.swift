import SwiftUI

/// 재료 실루엣 더미 — 히어로 뒤에 까는 **장식 면**. 사용자의 냉장고·이력에서 온 글리프를
/// 결정적 시드로 흩뿌려 한 장의 이미지로 굽고(`ImageRenderer`), 그 이미지를 흐리게 깐다.
///
/// **왜 이미지 한 장인가**: `PaperSilhouette`은 전부 `Canvas`다. 스무 개를 살아 있는 채로 두면
/// 스크롤 프레임마다 스무 번의 벡터 드로우가 돈다 — 배경 장식이 앞의 콘텐츠보다 비싸진다.
/// 구성은 시드 고정이라 매번 같은 그림이고, 한 번 구워 두면 그 뒤로는 비트맵 한 장 합성이다.
///
/// 굽는 그림은 **스킴에 무관**하다: `PaperSilhouette`의 팔레트는 재료의 실제 색(고정 oklch)이라
/// 라이트/다크에서 바뀌지 않는다(적응형 토큰을 쓰는 건 아래 바탕·스크림뿐이고 그 둘은 살아 있다).
/// 그래서 스킴이 바뀌어도 다시 굽지 않는다.
///
/// 장식이므로 보조기술에는 존재하지 않는다.
struct PaperGlyphPile: View {
    /// 흩뿌릴 글리프. 비면 `fallback`이 대신 선다.
    var glyphs: [FoodGlyph]
    /// 바탕 — 히어로가 앉는 종이 면.
    var base: Color = ReffiColor.paperPass
    /// 바탕과 **같은 토큰**을 반투명으로 다시 덮어 더미를 뒤로 물린다(위 글자의 대비 확보).
    /// 다른 색을 쓰면 라이트/다크 중 한쪽에서 띠가 두 톤으로 갈린다.
    var scrimOpacity: Double = 0.55
    /// 더미 자체의 농도.
    ///
    /// 이 값과 `1 - scrimOpacity`의 **곱**이 실루엣 색이 바탕에서 벗어나는 폭이다(현재 0.36 × 0.45 ≈ 0.16).
    /// 첫 캡처를 실측했더니 0.5 × 0.45 ≈ 0.225에서 다크 모드의 밝은 실루엣(달걀·우유) 위 캡션이
    /// **4.14:1**까지 떨어졌다 — 14pt Medium은 WCAG 큰 글자가 아니라 4.5:1이 기준선이다.
    /// 0.16으로 조여 최악 대비를 4.5:1 위로 올렸다(§2.6). 더 올리면 더미가 사라지고, 더 내리면 글자가 샌다.
    var pileOpacity: Double = 0.36
    /// 흐림 — 종이 조각으로는 읽히되 형태를 좇지 않을 만큼만.
    var blur: CGFloat = 4
    var seed: UInt64 = 24

    /// 냉장고도 이력도 비었을 때 세우는 고정 세트 — 빈 히어로에 빈 배경까지 겹치면 화면이
    /// 고장 난 것처럼 보인다. 색이 서로 다른 흔한 재료로 골랐다.
    static let fallback: [FoodGlyph] = [.tomato, .leaf, .egg, .milk, .root,
                                        .mushroom, .apple, .cheese, .broccoli, .citrus]

    /// 격자 칸 수 — 이 수만큼 실루엣이 놓인다(5 × 4 = 20).
    private static let columns = 5
    private static let rows = 4

    @State private var baked: Image?

    private var source: [FoodGlyph] { glyphs.isEmpty ? Self.fallback : glyphs }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let key = Self.key(source, size, seed)
            // 캐시는 **동기 조회**다 — 탭을 오갈 때마다 한 프레임 빈 밴드가 스치지 않게.
            let image = Self.cached[key] ?? baked
            ZStack {
                base
                if let image {
                    image
                        .resizable()
                        .frame(width: size.width, height: size.height)
                        .blur(radius: blur)
                        .opacity(pileOpacity)
                }
                base.opacity(scrimOpacity)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            // 글리프 구성·실측 크기가 실제로 바뀔 때만 굽는다(스크롤·스킴 전환으로는 돌지 않는다).
            .task(id: key) {
                guard Self.cached[key] == nil, size.width > 1, size.height > 1 else { return }
                baked = Self.image(for: source, size: size, seed: seed)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    /// 굽기 키 — 글리프 **집합**과 실측 크기와 시드. 크기는 1pt 단위로 반올림해 소수점 흔들림으로
    /// 다시 굽지 않게 한다. 두 가지가 키의 함정이었다:
    /// ① **순서를 정렬로 지운다** — 호출부(`pileGlyphs`)는 재고+이력을 이어 붙여 만드는데 판정
    ///   한 번에 재료가 이력으로 넘어가면 같은 구성이 다른 순서로 온다. 순서 민감 키는 그때마다
    ///   캐시를 놓쳐 "구성이 바뀔 때만 굽는다"는 약속이 실사용에서 깨진다. **격자 칸 배정은 배열
    ///   순서를 쓰므로**(`glyphIndex = i % count`) 키만 정렬하면 "같은 키 = 같은 그림"이 깨진다 —
    ///   그래서 `image(for:)`가 **입력도 같은 순서로 정렬**해 굽는다(칸 배치가 어차피 임의였으니
    ///   정렬 순서로 굳혀도 시각 손실이 없다).
    /// ② **시드를 키에 넣는다** — 시드가 다른 두 호출부가 키를 공유하면 뒤에 온 쪽이 앞의 그림을
    ///   그대로 받는다.
    private static func key(_ glyphs: [FoodGlyph], _ size: CGSize, _ seed: UInt64) -> String {
        "\(glyphs.map(\.rawValue).sorted().joined(separator: ","))|\(Int(size.width.rounded()))x\(Int(size.height.rounded()))|\(seed)"
    }

    // MARK: 굽기 캐시 — 뷰 인스턴스보다 오래 산다
    //
    // 냉장고 탭 패인은 `switch`라 History를 떠나면 이 뷰가 **파괴된다**. `@State`에만 담아 두면
    // 탭을 오갈 때마다 실루엣 스무 개를 다시 굽는다. 그림은 글리프 구성과 크기의 함수라
    // 뷰 수명과 무관하게 재사용할 수 있다.
    @MainActor private static var cached: [String: Image] = [:]
    @MainActor private static var cacheOrder: [String] = []
    /// 상한 — 히어로는 한 화면뿐이고 세로 고정이라 크기 변주가 거의 없다. 글리프 구성이 바뀌는
    /// 경우(재료를 담거나 비웠다)만 새 항목이 생긴다.
    private static let cacheLimit = 3

    @MainActor
    private static func image(for glyphs: [FoodGlyph], size: CGSize, seed: UInt64) -> Image? {
        let glyphs = glyphs.sorted { $0.rawValue < $1.rawValue }   // 키와 같은 정렬 — 위 ① 참고
        let k = key(glyphs, size, seed)
        if let hit = cached[k] { return hit }
        guard let made = bake(glyphs, in: size, seed: seed) else { return nil }
        cached[k] = made
        cacheOrder.append(k)
        while cacheOrder.count > cacheLimit {
            cached.removeValue(forKey: cacheOrder.removeFirst())
        }
        return made
    }

    /// 한 칸의 배치 — 격자 칸 중심에서 시드만큼 밀고, 크기·각도도 시드가 정한다.
    /// 완전 난수 산포는 뭉침과 빈 구멍을 만든다(스무 개로는 평균이 안 잡힌다). **흔들린 격자**는
    /// 덮임을 보장하면서도 줄이 보이지 않는다.
    struct Placement: Equatable {
        var center: CGPoint
        var side: CGFloat
        var angle: Double
        var glyphIndex: Int
    }

    /// 배치 계산 — 순수 함수(같은 입력이면 항상 같은 결과).
    static func placements(count: Int, in size: CGSize, seed: UInt64) -> [Placement] {
        guard count > 0, size.width > 0, size.height > 0 else { return [] }
        var rng = SeededGen(seed)
        // 격자 간격은 `칸 수 - 1`로 나눈다 — 바깥 줄의 중심이 밴드의 **가장자리에 앉아** 조각 절반이
        // 밖으로 걸린다. 잘린 조각이 있어야 "더 큰 더미의 일부"로 읽히고, 안쪽에 다 넣으면
        // 가장자리에 빈 띠가 생겨 그림이 액자처럼 보인다.
        let cellW = size.width / CGFloat(columns - 1)
        let cellH = size.height / CGFloat(rows - 1)
        var result: [Placement] = []
        result.reserveCapacity(columns * rows)
        for row in 0..<rows {
            for col in 0..<columns {
                let jx = (CGFloat(rng.unit()) - 0.5) * cellW * 0.55
                let jy = (CGFloat(rng.unit()) - 0.5) * cellH * 0.55
                let side = min(cellW, cellH) * (0.78 + CGFloat(rng.unit()) * 0.5)
                let angle = (rng.unit() - 0.5) * 44                       // ±22°, 종이 조각처럼 제각각
                result.append(Placement(center: CGPoint(x: CGFloat(col) * cellW + jx,
                                                        y: CGFloat(row) * cellH + jy),
                                        side: side,
                                        angle: angle,
                                        glyphIndex: result.count % count))
            }
        }
        return result
    }

    @MainActor
    private static func bake(_ glyphs: [FoodGlyph], in size: CGSize, seed: UInt64) -> Image? {
        let spots = placements(count: glyphs.count, in: size, seed: seed)
        let content = ZStack {
            ForEach(Array(spots.enumerated()), id: \.offset) { _, spot in
                PaperSilhouette(glyph: glyphs[spot.glyphIndex], fresh: .fresh, shadowed: false)
                    .frame(width: spot.side, height: spot.side)
                    .rotationEffect(.degrees(spot.angle))
                    .position(spot.center)
            }
        }
        .frame(width: size.width, height: size.height)
        // 실루엣 팔레트는 고정색이라 스킴에 영향받지 않지만, `ImageRenderer`가 환경을 명시하지 않으면
        // 무조건 라이트로 해석한다는 사실을 못 박아 둔다(이 저장소의 다른 굽기 지점과 같은 규약).
        .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2   // 어차피 흐리게 깔린다 — 3x는 메모리만 2.25배 쓴다
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}
