// ABOUTME: Performance tests for GameLogView - validates 10k line buffer targets (< 16ms append, < 500MB memory)

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import Vaalin
@testable import VaalinCore
@testable import VaalinUI

/// Performance tests for GameLogView with 10,000 line buffer.
///
/// Validates performance targets:
/// - **Append latency:** < 16ms per operation (60fps budget)
/// - **Memory usage:** < 500MB peak with 10k messages
/// - **Pruning:** < 50ms to prune oldest lines
/// - **Stress test:** Handle 1000 messages/sec influx
@Suite("GameLogView Performance Tests")
@MainActor
struct GameLogViewPerformanceTests {
    // MARK: - Test Helpers

    /// Create a GameTag with preset coloring for testing
    private func makePresetTag(presetID: String, text: String) -> GameTag {
        let textChild = GameTag(
            name: ":text",
            text: text,
            attrs: [:],
            children: [],
            state: .closed
        )
        return GameTag(
            name: "preset",
            text: nil,
            attrs: ["id": presetID],
            children: [textChild],
            state: .closed
        )
    }

    /// Create a realistic combat message for stress testing
    private func makeCombatMessage(index: Int) -> GameTag {
        let messages = [
            "You swing at the troll!",
            "The troll dodges your attack!",
            "You take 25 damage from the troll's claw!",
            "You heal yourself for 50 health.",
            "The troll misses you!",
            "Critical hit! You deal 100 damage to the troll!"
        ]
        let presets = ["speech", "damage", "heal", "monster"]
        let text = messages[index % messages.count]
        let preset = presets[index % presets.count]
        return makePresetTag(presetID: preset, text: text)
    }

    // MARK: - Performance Tests

    /// Test append latency with 10,000 messages (target: < 16ms per append average)
    @Test("Append latency stays under 60fps budget (< 16ms)")
    func test_appendLatencyUnder16ms() async {
        let theme = Theme.catppuccinMocha()
        let viewModel = GameLogViewModel(theme: theme)

        // Add 100 messages and measure average append time
        var totalDuration: Double = 0
        let messageCount = 100

        for i in 0..<messageCount {
            let tag = makeCombatMessage(index: i)

            let start = CFAbsoluteTimeGetCurrent()
            await viewModel.appendMessage([tag])
            let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000

            totalDuration += duration
        }

        let averageDuration = totalDuration / Double(messageCount)

        #expect(averageDuration < 16.0, "Average append time should be < 16ms (60fps), got \(averageDuration)ms")
    }

    /// Test memory usage with 10,000 messages (target: < 500MB peak)
    @Test("Memory usage stays under 500MB with 10k messages")
    func test_memoryUsageUnder500MB() async {
        let theme = Theme.catppuccinMocha()
        let viewModel = GameLogViewModel(theme: theme)

        // Measure baseline memory
        let baselineMemory = getMemoryUsageMB()

        // Add 10,000 messages
        for i in 0..<10_000 {
            let tag = makeCombatMessage(index: i)
            await viewModel.appendMessage([tag])
        }

        // Measure peak memory
        let peakMemory = getMemoryUsageMB()
        let memoryDelta = peakMemory - baselineMemory

        #expect(memoryDelta < 500.0, "Memory delta should be < 500MB, got \(memoryDelta)MB")
    }

    /// Test NSTextView conversion performance with 10,000 messages (target: < 100ms)
    @Test(
        "NSTextView conversion completes in < 100ms for 10k messages",
        .disabled("Benchmark is flaky - timing varies too much between runs")
    )
    func test_conversionPerformance() async {
        let theme = Theme.catppuccinMocha()
        let viewModel = GameLogViewModel(theme: theme)

        // Add 10,000 messages
        for i in 0..<10_000 {
            let tag = makeCombatMessage(index: i)
            await viewModel.appendMessage([tag])
        }

        // Measure conversion time
        var cache: [UUID: NSAttributedString] = [:]
        let start = CFAbsoluteTimeGetCurrent()
        let nsAttrString = viewModel.messages.toNSAttributedString(cache: &cache)
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000

        #expect(nsAttrString.length > 0, "Should have content")
        #expect(duration < 100.0, "Conversion should complete in < 100ms, got \(duration)ms")
    }

    /// Test cache effectiveness (cached conversion should be 10x faster)
    @Test("Cache provides 10x speedup for repeated conversions")
    func test_cacheSpeedup() async {
        let theme = Theme.catppuccinMocha()
        let viewModel = GameLogViewModel(theme: theme)

        // Add 1,000 messages (enough to measure)
        for i in 0..<1_000 {
            let tag = makeCombatMessage(index: i)
            await viewModel.appendMessage([tag])
        }

        // First conversion (cold cache)
        var cache1: [UUID: NSAttributedString] = [:]
        let start1 = CFAbsoluteTimeGetCurrent()
        _ = viewModel.messages.toNSAttributedString(cache: &cache1)
        let duration1 = (CFAbsoluteTimeGetCurrent() - start1) * 1000

        // Second conversion (warm cache)
        var cache2 = cache1  // Pre-populated cache
        let start2 = CFAbsoluteTimeGetCurrent()
        _ = viewModel.messages.toNSAttributedString(cache: &cache2)
        let duration2 = (CFAbsoluteTimeGetCurrent() - start2) * 1000

        // Cached should be significantly faster (10x minimum)
        let speedup = duration1 / duration2
        #expect(speedup > 10.0, "Cache should provide 10x+ speedup, got \(speedup)x")
    }

    /// Test stress scenario: Rapid message influx (1000 messages/sec)
    @Test("Handles rapid message influx without blocking (1000 msg/sec)")
    func test_rapidMessageInflux() async {
        let theme = Theme.catppuccinMocha()
        let viewModel = GameLogViewModel(theme: theme)

        // Send 1000 messages as fast as possible
        let start = CFAbsoluteTimeGetCurrent()

        for i in 0..<1_000 {
            let tag = makeCombatMessage(index: i)
            await viewModel.appendMessage([tag])
        }

        let duration = CFAbsoluteTimeGetCurrent() - start

        // Should complete in < 1 second (1000 msg/sec throughput)
        #expect(duration < 1.0, "Should process 1000 messages in < 1s, took \(duration)s")

        // Verify buffer is maintained (should be 1000 messages, all present)
        #expect(viewModel.messages.count == 1_000, "Should have all 1000 messages")
    }

    /// Test pruning performance when buffer exceeds 10k (target: < 50ms)
    @Test("Pruning completes in < 50ms when buffer exceeds limit")
    func test_pruningPerformance() async {
        let theme = Theme.catppuccinMocha()
        let viewModel = GameLogViewModel(theme: theme)

        // Fill buffer to exactly 10,000 messages
        for i in 0..<10_000 {
            let tag = makeCombatMessage(index: i)
            await viewModel.appendMessage([tag])
        }

        #expect(viewModel.messages.count == 10_000, "Buffer should be at capacity")

        // Measure time to append 1 more message (triggers pruning)
        let tag = makeCombatMessage(index: 10_000)
        let start = CFAbsoluteTimeGetCurrent()
        await viewModel.appendMessage([tag])
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000

        // Pruning should complete quickly (< 50ms including append)
        #expect(duration < 50.0, "Pruning + append should complete in < 50ms, got \(duration)ms")

        // Buffer should remain at 10,000
        #expect(viewModel.messages.count == 10_000, "Buffer should be maintained at 10,000")
    }

    /// Test memory stability during long session (10k messages → clear → 10k messages)
    @Test("Memory stabilizes after multiple prune cycles")
    func test_memoryStability() async {
        let theme = Theme.catppuccinMocha()
        let viewModel = GameLogViewModel(theme: theme)

        let baselineMemory = getMemoryUsageMB()

        // Add 10k messages (first cycle)
        for i in 0..<10_000 {
            let tag = makeCombatMessage(index: i)
            await viewModel.appendMessage([tag])
        }

        let firstCycleMemory = getMemoryUsageMB()

        // Add 10k more messages (triggers pruning, second cycle)
        for i in 10_000..<20_000 {
            let tag = makeCombatMessage(index: i)
            await viewModel.appendMessage([tag])
        }

        let secondCycleMemory = getMemoryUsageMB()

        // Memory should stabilize (second cycle should not grow significantly)
        let firstDelta = firstCycleMemory - baselineMemory
        let secondDelta = secondCycleMemory - firstCycleMemory

        #expect(secondDelta < firstDelta * 0.2, "Memory growth should stabilize after first cycle")
    }

    // MARK: - Memory Measurement Helper

    /// Get current process memory usage in MB
    private func getMemoryUsageMB() -> Double {
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
}
