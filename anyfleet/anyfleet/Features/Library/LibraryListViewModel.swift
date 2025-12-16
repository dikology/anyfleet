import Foundation
import Observation

@MainActor
@Observable
final class LibraryListViewModel {
    private let libraryStore: LibraryStore

    var isLoading = false
    var loadError: Error?
    var library: [LibraryModel] {
        libraryStore.library
    }
    
    init(libraryStore: LibraryStore) {
        self.libraryStore = libraryStore
    }
}