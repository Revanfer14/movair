import SwiftUI

struct MapSearchSheet: View {

    @ObservedObject var viewModel: MapSearchViewModel
    var onClose: () -> Void

    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader

                    resultsSection
                        .padding(.horizontal)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
        }
        .searchable(
            text: $viewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search for routes"
        )
        .autocorrectionDisabled()
        .background(Color(.systemGroupedBackground))
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
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
        } else {
            Text("Results")
                .font(Font.Brand.bodyBold)
                .foregroundStyle(Color.Brand.blue600)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if viewModel.searchText.isEmpty {
            SearchRecentList(
                recents: viewModel.recents,
                onSelect: { viewModel.selectRecent($0) },
                onDelete: { viewModel.deleteRecent($0) }
            )
        } else {
            SearchResultList(
                results: viewModel.results,
                onSelect: { viewModel.selectResult($0) }
            )
        }
    }
}

#Preview {
    MapSearchSheet(viewModel: MapSearchViewModel(), onClose: {})
}
