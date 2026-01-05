import Foundation

/// A least-recently-used (LRU) cache implementation with size-based eviction.
/// This cache automatically removes the oldest entries when the size limit is exceeded.
///
/// Thread-safe for concurrent access using a serial dispatch queue.
final class LRUCache<Key: Hashable, Value> {
    private struct CacheEntry {
        let value: Value
        var lastAccessed: Date
    }

    private var storage: [Key: CacheEntry] = [:]
    private let maxSize: Int
    private let accessQueue = DispatchQueue(label: "com.anyfleet.LRUCache", qos: .userInitiated)

    /// Initialize a new LRU cache with a maximum size.
    /// - Parameter maxSize: The maximum number of entries to keep in the cache.
    init(maxSize: Int) {
        self.maxSize = maxSize
    }

    /// Retrieve a value from the cache and update its access time.
    /// - Parameter key: The key to look up.
    /// - Returns: The cached value, or nil if not found.
    func get(_ key: Key) -> Value? {
        accessQueue.sync {
            guard var entry = storage[key] else { return nil }
            entry.lastAccessed = Date()
            storage[key] = entry
            return entry.value
        }
    }

    /// Store a value in the cache, evicting the least recently used entry if necessary.
    /// - Parameters:
    ///   - value: The value to store.
    ///   - key: The key to associate with the value.
    func set(_ value: Value, forKey key: Key) {
        accessQueue.sync {
            if storage.count >= maxSize {
                evictLeastRecentlyUsed()
            }
            storage[key] = CacheEntry(value: value, lastAccessed: Date())
        }
    }

    /// Remove a specific entry from the cache.
    /// - Parameter key: The key to remove.
    func removeValue(forKey key: Key) {
        accessQueue.sync {
            storage.removeValue(forKey: key)
        }
    }

    /// Remove all entries from the cache.
    func removeAll() {
        accessQueue.sync {
            storage.removeAll()
        }
    }

    /// Get the current number of entries in the cache.
    var count: Int {
        accessQueue.sync {
            storage.count
        }
    }

    /// Check if the cache contains a key.
    /// - Parameter key: The key to check.
    /// - Returns: True if the key exists in the cache.
    func contains(_ key: Key) -> Bool {
        accessQueue.sync {
            storage[key] != nil
        }
    }

    private func evictLeastRecentlyUsed() {
        guard let oldest = storage.min(by: { $0.value.lastAccessed < $1.value.lastAccessed }) else {
            return
        }
        storage.removeValue(forKey: oldest.key)
    }
}
