import SwiftUI

struct MenuEmptyStateView: View {
    let icon: String
    let title: String
    let message: String?

    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))

            Text(title)
                .font(.subheadline)
                .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted).opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
