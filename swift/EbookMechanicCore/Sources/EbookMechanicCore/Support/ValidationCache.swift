import Foundation
import CryptoKit

public actor ValidationCache {
    private var cache: [String: ValidationResult] = [:]
    private let cacheSize: Int
    private var usageOrder: [String] = []

    init(cacheSize: Int = 1000) {
        self.cacheSize = cacheSize
    }

    func get(forKey key: String) -> ValidationResult? {
        if let result = cache[key] {
            // Move key to the end to mark it as recently used
            if let index = usageOrder.firstIndex(of: key) {
                usageOrder.remove(at: index)
                usageOrder.append(key)
            }
            return result
        }
        return nil
    }

    func set(value: ValidationResult, forKey key: String) {
        if cache.count >= cacheSize, let keyToRemove = usageOrder.first {
            cache.removeValue(forKey: keyToRemove)
            usageOrder.removeFirst()
        }
        cache[key] = value
        usageOrder.append(key)
    }

    static func cacheKey(for url: URL, size: Int64, modDate: TimeInterval) -> String {
        let keyString = "\(url.path)-\(size)-\(modDate)"
        let data = Data(keyString.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
