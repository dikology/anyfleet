import Foundation

/// A simple cache wrapper around LRUCache for content models.
/// Provides type-safe caching with LRU eviction for expensive content fetches.
@MainActor
final class ContentCache<Key: Hashable, Value> {
    private var cache = LRUCache<Key, Value>(maxSize: 50)

    /// Retrieve a value from the cache.
    /// - Parameter key: The key to look up.
    /// - Returns: The cached value, or nil if not found.
    func get(_ key: Key) -> Value? {
        cache.get(key)
    }

    /// Store a value in the cache.
    /// - Parameters:
    ///   - key: The key to associate with the value.
    ///   - value: The value to store.
    func set(_ key: Key, value: Value) {
        cache.set(value, forKey: key)
    }

    /// Remove a specific entry from the cache.
    /// - Parameter key: The key to remove.
    func remove(_ key: Key) {
        cache.removeValue(forKey: key)
    }

    /// Remove all entries from the cache.
    func clear() {
        cache.removeAll()
    }

    /// Get the current number of entries in the cache.
    var count: Int {
        cache.count
    }
}