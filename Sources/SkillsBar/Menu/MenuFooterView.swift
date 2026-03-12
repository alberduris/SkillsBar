import AppKit
import SwiftUI

struct MenuFooterView: View {
    let onOpenSettings: () -> Void

    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        HStack {
            Button(action: onOpenSettings) {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape")
                        .font(.caption)
                    Text("Settings")
                        .font(.subheadline)
                }
                .foregroundStyle(MenuHighlightStyle.primary(isHighlighted))
            }
            .buttonStyle(MenuButtonStyle(isHighlighted: isHighlighted))

            Spacer()

            Button(action: { NSApp.terminate(nil) }) {
                Text("Quit")
                    .font(.subheadline)
                    .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))
            }
            .buttonStyle(MenuButtonStyle(isHighlighted: isHighlighted))
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 8)
    }
}
