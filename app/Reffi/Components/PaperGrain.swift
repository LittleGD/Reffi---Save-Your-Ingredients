import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// 인쇄/리소그래프풍 종이 그레인 텍스처.
/// Core Image로 흑백 노이즈 타일을 1회 생성해 캐시하고, 평면 색 위에 낮은 불투명도로 얹어
/// "인쇄된 종이" 질감을 준다(레퍼: refer/texture 그레인 오버레이).
enum PaperGrain {
    /// 타일링 가능한 흑백 그레인 이미지(앱 수명 동안 1회 생성).
    static let image: Image = {
        let dim = 180
        let context = CIContext(options: [.useSoftwareRenderer: false])

        // 무작위 컬러 노이즈 → 채도 0(흑백) + 대비 강화 → 알갱이.
        let noise = CIFilter.randomGenerator().outputImage ?? CIImage.empty()
        let controls = CIFilter.colorControls()
        controls.inputImage = noise
        controls.saturation = 0
        controls.contrast = 1.35
        controls.brightness = 0
        let mono = controls.outputImage ?? noise

        let rect = CGRect(x: 0, y: 0, width: dim, height: dim)
        if let cg = context.createCGImage(mono, from: rect) {
            return Image(uiImage: UIImage(cgImage: cg)).resizable(resizingMode: .tile)
        }
        // 폴백 — 텍스처 없이 투명.
        return Image(uiImage: UIImage())
    }()
}

extension View {
    /// 종이 그레인 오버레이를 주어진 도형으로 클립해 얹는다.
    /// `.overlay` 블렌드라 밝고 어두운 알갱이가 색을 거의 바꾸지 않고 질감만 더한다.
    func paperGrain<S: Shape>(_ shape: S, opacity: Double = 0.20) -> some View {
        overlay {
            PaperGrain.image
                .opacity(opacity)
                .blendMode(.overlay)
                .clipShape(shape)
                .allowsHitTesting(false)
        }
    }
}
