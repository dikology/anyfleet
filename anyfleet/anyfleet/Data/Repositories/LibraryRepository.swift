import Foundation

/// Protocol for repository operations to enable mocking and testing
protocol LibraryRepository: Sendable {
}

/// Make LocalRepository conform to the protocol
extension LocalRepository: LibraryRepository {}
