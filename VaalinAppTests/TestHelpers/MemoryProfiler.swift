// ABOUTME: Memory profiling utilities for performance testing - measures peak memory, deltas, and detects leaks

import Foundation

/// Memory profiling utilities for performance and leak detection testing.
///
/// Provides helpers for:
/// - Measuring current memory usage in MB
/// - Calculating memory deltas before/after operations
/// - Detecting memory leaks through repeated operation stability testing
///
/// ## Example Usage
/// ```swift
/// let profiler = MemoryProfiler()
/// let baseline = profiler.currentMemoryMB()
///
/// // Perform operation
/// for i in 0..<10_000 {
///     await viewModel.appendMessage(tag)
/// }
///
/// let peak = profiler.currentMemoryMB()
/// let delta = peak - baseline
/// #expect(delta < 500.0, "Memory usage should be < 500MB")
/// ```
public struct MemoryProfiler {
    /// Initializes a new memory profiler
    public init() {}

    // MARK: - Memory Measurement

    /// Get current process memory usage in megabytes (MB)
    ///
    /// Uses `mach_task_basic_info` to measure resident memory (RSS), which represents
    /// the actual physical RAM used by the process. This is the most accurate metric
    /// for memory consumption.
    ///
    /// - Returns: Current memory usage in MB, or 0 if measurement fails
    ///
    /// ## Example
    /// ```swift
    /// let profiler = MemoryProfiler()
    /// let currentMB = profiler.currentMemoryMB()
    /// print("Current memory: \(currentMB) MB")
    /// ```
    public func currentMemoryMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return 0
        }

        let memoryMB = Double(info.resident_size) / 1024 / 1024
        return memoryMB
    }

    /// Measure memory delta before and after a synchronous operation
    ///
    /// Captures baseline memory, executes operation, measures peak memory,
    /// and returns the delta (peak - baseline).
    ///
    /// - Parameter operation: Synchronous operation to measure
    /// - Returns: Memory delta in MB (peak - baseline)
    ///
    /// ## Example
    /// ```swift
    /// let profiler = MemoryProfiler()
    /// let delta = profiler.measureDelta {
    ///     // Synchronous operation
    ///     let data = Data(count: 100_000_000)  // Allocate 100MB
    /// }
    /// print("Memory delta: \(delta) MB")
    /// ```
    public func measureDelta(operation: () -> Void) -> Double {
        let baseline = currentMemoryMB()
        operation()
        let peak = currentMemoryMB()
        return peak - baseline
    }

    /// Measure memory delta before and after an async operation
    ///
    /// Captures baseline memory, executes async operation, measures peak memory,
    /// and returns the delta (peak - baseline).
    ///
    /// - Parameter operation: Async operation to measure
    /// - Returns: Memory delta in MB (peak - baseline)
    ///
    /// ## Example
    /// ```swift
    /// let profiler = MemoryProfiler()
    /// let delta = await profiler.measureDeltaAsync {
    ///     await viewModel.appendMessage(tag)
    /// }
    /// print("Memory delta: \(delta) MB")
    /// ```
    public func measureDeltaAsync(operation: () async -> Void) async -> Double {
        let baseline = currentMemoryMB()
        await operation()
        let peak = currentMemoryMB()
        return peak - baseline
    }

    // MARK: - Leak Detection

    /// Test for memory leaks by repeatedly executing an operation
    ///
    /// Executes the operation `iterations` times, measuring memory before and after.
    /// If memory grows linearly with iterations, a leak is likely present.
    /// If memory stabilizes after initial allocation, no leak is detected.
    ///
    /// - Parameters:
    ///   - iterations: Number of times to repeat the operation (default: 10)
    ///   - operation: Async operation to test for leaks
    /// - Returns: Tuple of (initialDelta, finalDelta, ratio)
    ///   - `initialDelta`: Memory growth after first iteration (MB)
    ///   - `finalDelta`: Total memory growth after all iterations (MB)
    ///   - `ratio`: finalDelta / initialDelta (should be ~1.0 if no leak, >> 1.0 if leaking)
    ///
    /// ## Interpretation
    /// - **ratio ≈ 1.0:** No leak (memory stabilized after first allocation)
    /// - **ratio >> 1.0:** Likely leak (memory grows linearly with iterations)
    ///
    /// ## Example
    /// ```swift
    /// let profiler = MemoryProfiler()
    /// let (initial, final, ratio) = await profiler.detectLeaks(iterations: 10) {
    ///     await viewModel.appendMessage(tag)
    /// }
    ///
    /// // Expect ratio < 2.0 (allows for some growth, but not linear)
    /// #expect(ratio < 2.0, "Memory should stabilize, not grow linearly")
    /// ```
    public func detectLeaks(
        iterations: Int = 10,
        operation: () async -> Void
    ) async -> (initialDelta: Double, finalDelta: Double, ratio: Double) {
        let baseline = currentMemoryMB()

        // First iteration (initial allocation)
        await operation()
        let afterFirst = currentMemoryMB()
        let initialDelta = afterFirst - baseline

        // Remaining iterations (should not grow proportionally if no leak)
        for _ in 1..<iterations {
            await operation()
        }

        let afterAll = currentMemoryMB()
        let finalDelta = afterAll - baseline

        // Calculate ratio (finalDelta / initialDelta)
        // If no leak: ratio ≈ 1.0 (memory stabilized after first)
        // If leaking: ratio ≈ iterations (linear growth)
        let ratio = initialDelta > 0 ? (finalDelta / initialDelta) : 0

        return (initialDelta, finalDelta, ratio)
    }

    // MARK: - Utilities

    /// Format memory size in human-readable form (MB, GB)
    ///
    /// - Parameter megabytes: Memory size in MB
    /// - Returns: Formatted string with appropriate unit
    ///
    /// ## Example
    /// ```swift
    /// let profiler = MemoryProfiler()
    /// let formatted = profiler.formatMemory(1536.5)  // "1.5 GB"
    /// ```
    public func formatMemory(_ megabytes: Double) -> String {
        if megabytes >= 1024 {
            let gigabytes = megabytes / 1024
            return String(format: "%.1f GB", gigabytes)
        } else {
            return String(format: "%.1f MB", megabytes)
        }
    }
}
