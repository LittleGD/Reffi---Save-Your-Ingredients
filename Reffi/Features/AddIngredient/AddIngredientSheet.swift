import SwiftUI
import PhosphorSwift

/// 재료 추가 시트 — 중앙 ＋의 목적지. 영수증 스캔(주), 바코드·사진, 직접 입력(§8.5 스캐너 정합).
struct AddIngredientSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s5) {
            HStack(alignment: .firstTextBaseline) {
                Text("재료 추가")
                    .reffiType(.heading)
                    .foregroundStyle(ReffiColor.ink)
                Spacer()
                Button { dismiss() } label: {
                    ReffiIcon.close.reffi(20, .bold)
                        .foregroundStyle(ReffiColor.ink2)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.reffiPress)
            }

            VStack(spacing: ReffiSpace.s3) {
                option(ReffiIcon.receipt, "영수증 스캔", "장본 영수증을 찍으면 한 번에 등록", primary: true)
                option(ReffiIcon.barcode, "바코드 · 사진", "제품 바코드나 사진으로 인식")
                option(ReffiIcon.manual, "직접 입력", "이름과 유통기한을 직접 입력")
            }

            Spacer(minLength: 0)
        }
        .padding(ReffiSpace.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReffiColor.canvas)
    }

    private func option(_ icon: Ph, _ title: String, _ subtitle: String, primary: Bool = false) -> some View {
        Button { dismiss() } label: {
            HStack(spacing: ReffiSpace.s4) {
                icon.reffi(26)
                    .foregroundStyle(primary ? ReffiColor.blue : ReffiColor.ink2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .reffiType(.subhead)
                        .foregroundStyle(ReffiColor.ink)
                    Text(subtitle)
                        .reffiType(.caption)
                        .foregroundStyle(ReffiColor.ink2)
                }
                Spacer(minLength: ReffiSpace.s2)
                ReffiIcon.chevron.reffi(16)
                    .foregroundStyle(ReffiColor.muted)
            }
            .padding(ReffiSpace.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                primary ? ReffiColor.blueLight : ReffiColor.sub,
                in: RoundedRectangle(cornerRadius: ReffiRadius.lg, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: ReffiRadius.lg, style: .continuous))
        }
        .buttonStyle(.reffiPress)
    }
}
