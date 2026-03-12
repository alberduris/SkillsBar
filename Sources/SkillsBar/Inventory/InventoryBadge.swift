import Foundation

struct InventoryBadge: Hashable {
    enum Style: Hashable {
        case neutral
        case blue
        case green
        case orange
        case purple
    }

    let text: String
    let style: Style
}
