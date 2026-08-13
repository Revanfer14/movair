import SwiftUI

struct MapSearchSheet: View {
    @ObservedObject var viewModel: MapSearchViewModel

    @FocusState private var searchFieldFocused: Bool
    
    @State private var showClearConfirmation = false
    
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            MapSearchComponent(
                text: $viewModel.searchText,
                placeholder: "Search for routes",
                isFocused: $searchFieldFocused,
                showsCloseButton: true,
                onClose: onClose
            )
            .padding(.horizontal)
            .padding(.top, 8)

            sectionHeader

            List {
                if viewModel.searchText.isEmpty {
                    ForEach(viewModel.recents) { recent in
                        RecentSearchList(
                            title: recent.title,
                            onTap: { viewModel.selectRecent(recent) },
                            onDelete: { viewModel.deleteRecent(recent) }
                        )
                    }
                } else {
                    ForEach(viewModel.results) { result in
                        SearchResultList(
                            title: result.title,
                            subtitle: result.subtitle,
                            onTap: { viewModel.selectResult(result) }
                        )
                    }
                }
            }
            .listStyle(.plain)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            searchFieldFocused = true
        }
        .confirmationDialog(
            "Clear all recent searches?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                viewModel.clearAllRecents()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var sectionHeader: some View {
        if viewModel.searchText.isEmpty {
            if !viewModel.recents.isEmpty {
                Button {
                    showClearConfirmation = true
                } label: {
                    HStack(spacing: 2) {
                        Text("Recents")
                        Image(systemName: "chevron.right")
                            .font(Font.Brand.footnoteBold)
                    }
                    .font(Font.Brand.bodyBold)
                    .foregroundStyle(Color.Brand.blue600)
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text("Results")
                .font(Font.Brand.bodyBold)
                .foregroundStyle(Color.Brand.blue600)
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    MapSearchSheet(viewModel: MapSearchViewModel(), onClose: {})
}
