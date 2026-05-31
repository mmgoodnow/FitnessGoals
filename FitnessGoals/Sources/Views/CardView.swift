import SwiftUI

struct CardView<Content: View>: View {
    let title: String
    var systemImage: String? = nil
    var accentColor: Color = .blue
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                if let img = systemImage {
                    Image(systemName: img)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accentColor)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            content()
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
