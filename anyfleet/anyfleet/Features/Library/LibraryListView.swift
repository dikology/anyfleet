import SwiftUI

struct LibraryListView: View {
    @State private var viewModel: LibraryListViewModel
    @Environment(\.appDependencies) private var dependencies
    
    init(viewModel: LibraryListViewModel? = nil) {
        if let viewModel = viewModel {
            _viewModel = State(initialValue: viewModel)
        } else {
            _viewModel = State(initialValue: LibraryListViewModel(libraryStore: LibraryStore(repository: LocalRepository())))
        }
    }

    var body: some View {
        Text("Library List")
    }
}