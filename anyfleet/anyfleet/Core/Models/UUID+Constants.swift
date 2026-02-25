import Foundation

extension UUID {
    /// Placeholder UUID for single-user local content before multi-user support.
    ///
    /// Used as a temporary `creatorID` for library content created locally.
    /// When multi-user auth is fully implemented, this will be replaced with
    /// the authenticated user's actual UUID.
    ///
    /// - Warning: Do not use for any security-sensitive operations.
    // swiftlint:disable:next force_unwrapping
    static let localUserPlaceholder = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
}
