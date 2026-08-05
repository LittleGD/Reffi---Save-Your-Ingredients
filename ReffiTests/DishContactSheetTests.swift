import Testing
import Foundation
import SwiftUI
import UIKit
@testable import Reffi

/// 요리 아이콘 **콘택트 시트 툴** — 갤러리(`-dishGallery`)는 스크롤이라 스크린샷이 첫 판밖에 못 담는다.
/// 여기서 오프스크린 `ImageRenderer`로 80개를 한 장에 몰아 찍어 전수 대조를 가능하게 한다
/// (`WiltRenderTests`의 오프스크린 래스터 선례).
///
/// 검증이 아니라 **산출물 생성**이 목적이라, 실패시키는 대신 저장 경로를 출력한다.
/// 실행:
/// ```sh
/// xcodebuild test -project Reffi.xcodeproj -scheme Reffi \
///   -destination 'platform=iOS Simulator,name=iPhone 17' \
///   -only-testing:ReffiTests/DishContactSheetTests
/// ```
@MainActor
struct DishContactSheetTests {

    /// 시트를 쓸 디렉터리 — 환경변수 `DISH_SHEET_DIR`이 있으면 그쪽, 없으면 시뮬레이터 tmp.
    /// 어느 쪽이든 최종 경로를 출력하므로 호스트에서 그대로 복사할 수 있다.
    private func outputDirectory() -> URL {
        if let raw = ProcessInfo.processInfo.environment["DISH_SHEET_DIR"], !raw.isEmpty {
            let url = URL(fileURLWithPath: raw, isDirectory: true)
            if (try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)) != nil {
                return url
            }
        }
        return FileManager.default.temporaryDirectory
    }

    private func write(_ view: some View, size: CGSize, to name: String) throws {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 2
        // 라이트 모드 고정 — 시트는 인쇄물처럼 읽혀야 하고, 요리 팔레트는 어차피 고정색이다.
        renderer.proposedSize = ProposedViewSize(size)
        guard let image = renderer.uiImage, let png = image.pngData() else {
            Issue.record("\(name) 렌더 실패"); return
        }
        let url = outputDirectory().appendingPathComponent(name)
        try png.write(to: url)
        print("DISH_SHEET_WRITTEN \(url.path) (\(png.count) bytes, \(image.size))")
    }

    @Test func renderAllDishesContactSheet() throws {
        let recipes = seedRecipesForTests()
        #expect(recipes.count == 80)
        let sheet = DishContactSheet(recipes: recipes)
        try write(sheet, size: DishContactSheet.size(for: recipes.count), to: "dish-contact-sheet.png")
    }

    @Test func renderArchetypeSheet() throws {
        // 원형별 대표 1개 — 원형 시스템(15종)을 설명하는 줌 시트.
        let recipes = seedRecipesForTests()
        var reps: [(DishArchetype, Recipe)] = []
        for a in DishArchetype.allCases {
            if let r = recipes.first(where: { DishGlyphCatalog.look(for: $0).archetype == a }) {
                reps.append((a, r))
            }
        }
        #expect(reps.count == DishArchetype.allCases.count, "대표를 못 찾은 원형이 있다")
        let sheet = DishArchetypeSheet(reps: reps)
        try write(sheet, size: DishArchetypeSheet.size(for: reps.count), to: "dish-archetypes.png")
    }
}

// MARK: - 시트 레이아웃

/// 80개 전체를 8열 그리드 한 장으로. 라벨은 한글 요리명.
private struct DishContactSheet: View {
    let recipes: [Recipe]

    static let columns = 8
    static let cell = CGSize(width: 112, height: 146)
    static let padding: CGFloat = 28
    static let header: CGFloat = 64

    static func size(for count: Int) -> CGSize {
        let rows = Int(ceil(Double(count) / Double(columns)))
        return CGSize(width: CGFloat(columns) * cell.width + padding * 2,
                      height: header + CGFloat(rows) * cell.height + padding)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "Reffi 요리 아이콘 — 시드 레시피 \(recipes.count)종")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(ReffiColor.oklch(0.28, 0.012, 80))
                Text(verbatim: "원형 \(DishArchetype.allCases.count)종 × 색·고명 변주 · 종이컷 스타일")
                    .font(.system(size: 14))
                    .foregroundStyle(ReffiColor.oklch(0.48, 0.012, 80))
            }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(Self.cell.width), spacing: 0),
                                     count: Self.columns), spacing: 0) {
                ForEach(recipes) { recipe in
                    VStack(spacing: 6) {
                        DishSilhouette(look: DishGlyphCatalog.look(for: recipe))
                            .frame(width: 92, height: 92)
                            .background(ReffiColor.oklch(0.99, 0.006, 90),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        Text(verbatim: recipe.name.ko ?? recipe.name.en)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ReffiColor.oklch(0.35, 0.012, 80))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(width: Self.cell.width - 8)
                    }
                    .frame(width: Self.cell.width, height: Self.cell.height, alignment: .top)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Self.padding)
        .background(ReffiColor.oklch(0.96, 0.012, 90))
        .environment(\.colorScheme, .light)
    }
}

/// 원형별 대표 하나씩 — 크게 그려 원형 시스템을 설명하는 시트.
private struct DishArchetypeSheet: View {
    let reps: [(DishArchetype, Recipe)]

    static let columns = 5
    static let cell = CGSize(width: 190, height: 226)
    static let padding: CGFloat = 32
    static let header: CGFloat = 70

    static func size(for count: Int) -> CGSize {
        let rows = Int(ceil(Double(count) / Double(columns)))
        return CGSize(width: CGFloat(columns) * cell.width + padding * 2,
                      height: header + CGFloat(rows) * cell.height + padding)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "요리 원형 \(reps.count)종")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(ReffiColor.oklch(0.28, 0.012, 80))
                Text(verbatim: "80개 레시피는 이 원형에 색·고명 변주만 얹는다")
                    .font(.system(size: 14))
                    .foregroundStyle(ReffiColor.oklch(0.48, 0.012, 80))
            }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(Self.cell.width), spacing: 0),
                                     count: Self.columns), spacing: 0) {
                ForEach(Array(reps.enumerated()), id: \.offset) { _, pair in
                    VStack(spacing: 8) {
                        DishSilhouette(look: DishGlyphCatalog.look(for: pair.1))
                            .frame(width: 150, height: 150)
                            .background(ReffiColor.oklch(0.99, 0.006, 90),
                                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        Text(verbatim: pair.0.koreanLabel)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ReffiColor.oklch(0.30, 0.012, 80))
                        Text(verbatim: "예: \(pair.1.name.ko ?? pair.1.name.en)")
                            .font(.system(size: 12))
                            .foregroundStyle(ReffiColor.oklch(0.50, 0.012, 80))
                    }
                    .frame(width: Self.cell.width, height: Self.cell.height, alignment: .top)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Self.padding)
        .background(ReffiColor.oklch(0.96, 0.012, 90))
        .environment(\.colorScheme, .light)
    }
}
