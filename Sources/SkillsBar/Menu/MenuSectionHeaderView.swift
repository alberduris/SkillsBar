import SwiftUI

struct MenuSectionHeaderView: View {
    let title: String
    let icon: String
    let trailingText: String?

    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))

            MenuSectionTitleView(title: title, isHighlighted: isHighlighted)

            if let trailingText {
                Text(trailingText)
                    .font(.footnote)
                    .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted).opacity(0.7))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(MenuHighlightStyle.progressTrack(isHighlighted).opacity(0.5))
    }
}
