import SwiftUI

struct InventoryBadgeView: View {
    let badge: InventoryBadge

    var body: some View {
        Text(badge.text)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(color.opacity(0.25))
            .foregroundStyle(color.opacity(0.9))
            .clipShape(Capsule())
    }

    private var color: Color {
        switch badge.style {
        case .neutral:
            return .secondary
        case .blue:
            return .blue
        case .green:
            return .green
        case .orange:
            return .orange
        case .purple:
            return .purple
        }
    }
}
