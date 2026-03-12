import SwiftUI

struct MenuSectionTitleView: View {
    let title: String
    let isHighlighted: Bool

    private var baseColor: Color {
        MenuHighlightStyle.secondary(isHighlighted)
    }

    var body: some View {
        let parts = title.split(separator: "/").map(String.init)
        if parts.count >= 2 {
            let folder = parts.last ?? title
            let parent = parts.dropLast().joined(separator: "/")
            HStack(spacing: 0) {
                Text(parent + "/")
                    .font(.callout)
                    .foregroundStyle(baseColor.opacity(0.6))
                Text(folder)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(baseColor)
            }
        } else {
            Text(title)
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(baseColor)
        }
    }
}
