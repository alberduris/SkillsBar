import SwiftUI

struct InventoryLibraryView: View {
    let skillsStore: SkillsStore

    @State private var viewModel: InventoryViewModel

    init(skillsStore: SkillsStore) {
        self.skillsStore = skillsStore
        _viewModel = State(initialValue: InventoryViewModel(skillsStore: skillsStore))
    }

    var body: some View {
        HSplitView {
            InventoryLibrarySidebarView(viewModel: viewModel)
                .frame(minWidth: 300, idealWidth: 360, maxWidth: 420)

            InventoryLibraryDetailContainerView(viewModel: viewModel)
                .frame(minWidth: 520, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .background(
            LibraryWindowLifecycleObserver(
                onWindowOpen: {
                    AppDelegate.shared?.libraryWindowDidOpen()
                },
                onWindowClose: {
                    AppDelegate.shared?.libraryWindowDidClose()
                }
            )
        )
    }
}
