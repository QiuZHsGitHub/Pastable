import Foundation
import os.log

/// Performance monitoring utilities
/// Tracks execution time of critical operations
final class PerformanceMonitor {
    private let logger = Logger(subsystem: "com.example.pastable", category: "Performance")
    private var startTime: CFAbsoluteTime?
    
    /// Log threshold in milliseconds (operations slower than this will be logged)
    private let logThresholdMs: Double
    
    /// Warning threshold in milliseconds (operations slower than this will be logged as warning)
    private let warningThresholdMs: Double = 100.0
    
    /// Initialize a new performance monitor
    /// - Parameter logThresholdMs: Threshold for logging operations (default: 40ms)
    init(logThresholdMs: Double = 40.0) {
        self.logThresholdMs = logThresholdMs
    }
    
    /// Start measuring an operation
    func start() {
        startTime = CFAbsoluteTimeGetCurrent()
    }
    
    /// Stop measuring and log the duration
    /// - Parameters:
    ///   - operation: Name of the operation being measured
    ///   - logThreshold: Override default log threshold for this operation
    /// - Returns: The duration in milliseconds
    @discardableResult
    func stop(operation: String, logThreshold: Double? = nil) -> Double {
        guard let start = startTime else {
            logger.warning("Performance monitor stopped without starting for operation: \(operation)")
            return 0
        }
        
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
        startTime = nil
        
        let threshold = logThreshold ?? logThresholdMs
        
        if duration > warningThresholdMs {
            logger.warning("⚠️ [Performance] \(operation) took \(String(format: "%.1f", duration))ms (threshold: \(threshold)ms)")
        } else if duration > threshold {
            logger.notice("⏱ [Performance] \(operation) took \(String(format: "%.1f", duration))ms")
        } else {
            logger.debug("✓ [Performance] \(operation) took \(String(format: "%.1f", duration))ms")
        }
        
        return duration
    }
    
    /// Measure a synchronous operation
    /// - Parameters:
    ///   - operation: Name of the operation
    ///   - block: The operation to measure
    /// - Returns: The result of the operation
    func measure<T>(_ operation: String, _ block: () throws -> T) rethrows -> T {
        start()
        let result = try block()
        stop(operation: operation)
        return result
    }
    
    /// Measure an asynchronous operation
    /// - Parameters:
    ///   - operation: Name of the operation
    ///   - block: The async operation to measure
    /// - Returns: The result of the operation
    func measureAsync<T>(_ operation: String, _ block: () async throws -> T) async rethrows -> T {
        start()
        let result = try await block()
        stop(operation: operation)
        return result
    }
}
