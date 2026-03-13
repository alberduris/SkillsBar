import SwiftUI

struct InventoryLibrarySidebarView: View {
    @Bindable var viewModel: InventoryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            Picker("", selection: $viewModel.selectedTab) {
                Text("Skills").tag(InventoryTab.skills)
                Text("MCPs").tag(InventoryTab.mcps)
                Text("Agents").tag(InventoryTab.agents)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 14)

            LibraryFilterField(text: $viewModel.filterText)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 10)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if viewModel.sections.isEmpty && !viewModel.showsNoMatchesState {
                        LibraryEmptySidebarState()
                    } else {
                        ForEach(viewModel.sections) { section in
                            LibrarySidebarSectionView(section: section, selectedItemID: viewModel.selectedItemID) { item in
                                viewModel.select(item)
                            }
                        }

                        if viewModel.showsNoMatchesState {
                            LibraryNoMatchesState()
                        }
                    }
                }
                .padding(.vertical, 10)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Library")
                    .font(.title2.weight(.semibold))
                Text(summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await viewModel.skillsStore.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.body)
            }
            .buttonStyle(.borderless)
            .help("Refresh")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var summaryText: String {
        switch viewModel.selectedTab {
        case .skills:
            return "\(viewModel.skillsStore.totalCount) skills"
        case .mcps:
            return "\(viewModel.skillsStore.mcpCount) MCPs"
        case .agents:
            return "\(viewModel.skillsStore.agentCount) agents"
        }
    }
}

private struct LibraryFilterField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Filter projects", text: $text)
                .textFieldStyle(.plain)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
        )
    }
}

private struct LibrarySidebarSectionView: View {
    let section: InventorySection
    let selectedItemID: String?
    let onSelect: (InventoryItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: section.icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(section.title)
                    .font(.headline)
                if let trailingText = section.trailingText {
                    Text(trailingText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)

            if let note = section.note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            }

            VStack(spacing: 4) {
                ForEach(section.items) { item in
                    LibrarySidebarRowView(item: item, isSelected: item.id == selectedItemID) {
                        onSelect(item)
                    }
                }
            }
        }
        .padding(.bottom, 16)
    }
}

private struct LibrarySidebarRowView: View {
    let item: InventoryItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        ForEach(item.badges.prefix(2), id: \.self) { badge in
                            InventoryBadgeView(badge: badge)
                        }

                        Spacer(minLength: 0)
                    }

                    if let subtitle = item.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else if let description = item.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
    }

    private var statusColor: Color {
        item.isEnabled ? .green : .secondary.opacity(0.7)
    }
}

private struct LibraryEmptySidebarState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing to browse yet")
                .font(.headline)
            Text("Once SkillsBar discovers resources, they will appear here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}

private struct LibraryNoMatchesState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No matching projects")
                .font(.headline)
            Text("Try clearing the filter or switching tabs.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}
