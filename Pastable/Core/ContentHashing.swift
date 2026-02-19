import Foundation

/// Lightweight content hashing utilities
/// Uses FNV-1a64 for text (fast) and MD5 for images (reasonable collision resistance)
final class ContentHashing {
    
    /// Compute a fingerprint for a history item
    /// Returns a string hash that can be used for deduplication
    static func computeFingerprint(for item: HistoryItem) -> String {
        // For text content, use fast FNV-1a64 hash
        if let text = item.text {
            return "text:\(hashText(text))"
        }
        
        // For RTF content
        if let rtf = item.rtfData {
            return "rtf:\(hashData(rtf))
        }
        
        // For images, use MD5 for better collision resistance
        if let image = item.image, let imageData = image.tiffRepresentation {
            return "image:\(hashData(imageData))"
        }
        
        // For URLs/links
        if let url = item.url {
            return "url:\(hashText(url.absoluteString))"
        }
        
        // For files
        if let fileURL = item.fileURL {
            return "file:\(hashText(fileURL.path))"
        }
        
        // Fallback: hash the first non-empty content
        if let firstContent = item.contents.first?.value {
            return "fallback:\(hashData(firstContent))"
        }
        
        return "unknown:\(UUID().uuidString)"
    }
    
    /// FNV-1a64 hash for text (very fast, good for deduplication)
    private static func hashText(_ text: String) -> String {
        let data = Data(text.utf8)
        return hashData(data)
    }
    
    /// FNV-1a64 hash algorithm
    /// FNV-1a64 is a non-cryptographic hash function with good distribution and speed
    /// Perfect for content deduplication where security is not required
    private static func hashData(_ data: Data) -> String {
        let fnvOffsetBasis: UInt64 = 0xcbf29ce484222325
        let fnvPrime: UInt64 = 0x100000001b3
        
        var hash = fnvOffsetBasis
        
        for byte in data {
            hash ^= UInt64(byte)
            hash &=* fnvPrime
        }
        
        return String(format: "%016llx", hash)
    }
    
    /// Quick hash for small strings (for filtering)
    static func quickHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 5381
        for scalar in text.unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ UInt64(scalar.value)
        }
        return hash
    }
    
    /// Hash image data using FNV-1a64
    /// For performance, we hash the first 4096 bytes and the last 4096 bytes
    static func hashImageData(_ data: Data) -> String {
        let sampleSize = min(4096, data.count)
        var hashData = Data()
        
        // First 4KB
        if data.count > 0 {
            hashData.append(data[0..<min(sampleSize, data.count)])
        }
        
        // Last 4KB
        if data.count > sampleSize {
            let start = max(0, data.count - sampleSize)
            hashData.append(data[start..<data.count])
        }
        
        return hashData(hashData)
    }
    
    /// Hash file URLs (for file items)
    static func hashFileURLs(_ urls: [URL]) -> String {
        let paths = urls
            .map { $0.path }
            .sorted()
            .joined(separator: "|")
        return hashText(paths)
    }
}
