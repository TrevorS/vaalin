// ABOUTME: Tests for CommandHistory actor - circular buffer with linear indexing, navigation, persistence

import Foundation
import Testing
@testable import VaalinCore

/// Test suite for CommandHistory actor
/// Validates 500-item circular buffer, linear indexing (0=newest, -1=previous), navigation,
/// prefix search, JSON persistence, and thread safety
struct CommandHistoryTests {
    // MARK: - Test Data

    /// Helper to create temporary directory for persistence tests
    private func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("VaalinCommandHistoryTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    /// Helper to clean up temporary directory
    private func removeTempDirectory(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    // MARK: - Add Command Tests

    /// Test that commands are added to buffer correctly
    /// Commands should be stored newest-first in array
    @Test func test_addCommand() async throws {
        let history = CommandHistory()

        // Add commands
        await history.add("look")
        await history.add("exp")
        await history.add("info")

        // Verify commands stored in newest-first order
        let all = await history.getAll()
        #expect(all == ["info", "exp", "look"])
    }

    /// Test that adding command resets navigation position to newest
    @Test func test_addCommandResetsPosition() async throws {
        let history = CommandHistory()

        // Add initial commands
        await history.add("look")
        await history.add("exp")
        await history.add("info")

        // Navigate back to older command
        _ = await history.back()
        _ = await history.back()

        // Add new command - should reset position to newest
        await history.add("spell")

        // Next navigation should start from newest
        let cmd = await history.back()
        #expect(cmd == "info")
    }

    /// Test empty buffer behavior
    @Test func test_emptyBuffer() async throws {
        let history = CommandHistory()

        let all = await history.getAll()
        #expect(all.isEmpty)

        // Navigation on empty buffer should return empty string
        let back = await history.back()
        #expect(back == "")

        let forward = await history.forward()
        #expect(forward == "")
    }

    /// Test duplicate commands are allowed
    @Test func test_duplicateCommands() async throws {
        let history = CommandHistory()

        await history.add("look")
        await history.add("exp")
        await history.add("look")

        let all = await history.getAll()
        #expect(all == ["look", "exp", "look"])
    }

    /// Test empty strings can be added
    @Test func test_emptyStringCommand() async throws {
        let history = CommandHistory()

        await history.add("")
        await history.add("look")
        await history.add("")

        let all = await history.getAll()
        #expect(all == ["", "look", ""])
    }

    /// Test whitespace-only commands
    @Test func test_whitespaceCommands() async throws {
        let history = CommandHistory()

        await history.add("   ")
        await history.add("look")
        await history.add("\t\t")

        let all = await history.getAll()
        #expect(all == ["\t\t", "look", "   "])
    }

    // MARK: - Navigation Tests

    /// Test up/down navigation with linear indexing
    /// Index 0 = newest, -1 = previous, -2 = older, etc.
    @Test func test_navigateHistory() async throws {
        let history = CommandHistory()

        // Add commands (newest first order)
        await history.add("climb tower")
        await history.add("exp")
        await history.add("info")

        // History is now [info, exp, climb tower] (newest first)
        // Current position should be at index 0 (newest)

        // Navigate back to older commands
        let cmd1 = await history.back()  // Move to -1
        #expect(cmd1 == "exp")

        let cmd2 = await history.back()  // Move to -2
        #expect(cmd2 == "climb tower")

        // At boundary, should stay at oldest
        let cmd3 = await history.back()
        #expect(cmd3 == "climb tower")

        // Navigate forward to newer
        let cmd4 = await history.forward()  // Move to -1
        #expect(cmd4 == "exp")

        let cmd5 = await history.forward()  // Move to 0
        #expect(cmd5 == "info")
    }

    /// Test navigation at buffer limits (oldest/newest)
    @Test func test_boundaryConditions() async throws {
        let history = CommandHistory()

        await history.add("first")
        await history.add("second")
        await history.add("third")

        // Navigate back to oldest
        _ = await history.back()
        _ = await history.back()

        // Should stay at oldest when navigating back
        let atOldest = await history.back()
        #expect(atOldest == "first")

        // Verify still at oldest
        let stillAtOldest = await history.back()
        #expect(stillAtOldest == "first")

        // Navigate forward to newest
        _ = await history.forward()
        _ = await history.forward()

        // Should stay at newest when navigating forward
        let atNewest = await history.forward()
        #expect(atNewest == "third")

        // Verify still at newest
        let stillAtNewest = await history.forward()
        #expect(stillAtNewest == "third")
    }

    /// Test boundary checks
    @Test func test_canNavigateBackAndForward() async throws {
        let history = CommandHistory()

        // Empty buffer - cannot navigate
        var canBack = await history.canNavigateBack()
        var canForward = await history.canNavigateForward()
        #expect(canBack == false)
        #expect(canForward == false)

        // Single command - cannot navigate
        await history.add("look")
        canBack = await history.canNavigateBack()
        canForward = await history.canNavigateForward()
        #expect(canBack == false)
        #expect(canForward == false)

        // Two commands - can navigate back
        await history.add("exp")
        canBack = await history.canNavigateBack()
        canForward = await history.canNavigateForward()
        #expect(canBack == true)
        #expect(canForward == false)

        // Navigate back - can navigate forward
        _ = await history.back()
        canBack = await history.canNavigateBack()
        canForward = await history.canNavigateForward()
        #expect(canBack == false)
        #expect(canForward == true)
    }

    /// Test navigation with three commands
    @Test func test_navigationWithThreeCommands() async throws {
        let history = CommandHistory()

        await history.add("first")
        await history.add("second")
        await history.add("third")

        // At newest - can navigate back only
        var canBack = await history.canNavigateBack()
        var canForward = await history.canNavigateForward()
        #expect(canBack == true)
        #expect(canForward == false)

        // Navigate to middle - can navigate both directions
        _ = await history.back()
        canBack = await history.canNavigateBack()
        canForward = await history.canNavigateForward()
        #expect(canBack == true)
        #expect(canForward == true)

        // Navigate to oldest - can navigate forward only
        _ = await history.back()
        canBack = await history.canNavigateBack()
        canForward = await history.canNavigateForward()
        #expect(canBack == false)
        #expect(canForward == true)
    }

    /// Test read at current position
    @Test func test_readCurrentPosition() async throws {
        let history = CommandHistory()

        await history.add("first")
        await history.add("second")
        await history.add("third")

        // Read at newest (current position)
        let current = await history.read()
        #expect(current == "third")

        // Navigate and read
        _ = await history.back()
        let middle = await history.read()
        #expect(middle == "second")

        _ = await history.back()
        let oldest = await history.read()
        #expect(oldest == "first")
    }

    /// Test read at specific index
    @Test func test_readAtIndex() async throws {
        let history = CommandHistory()

        await history.add("first")
        await history.add("second")
        await history.add("third")

        // Read at specific array indices (not navigation indices)
        let index0 = await history.readAt(index: 0)
        #expect(index0 == "third")

        let index1 = await history.readAt(index: 1)
        #expect(index1 == "second")

        let index2 = await history.readAt(index: 2)
        #expect(index2 == "first")

        // Out of bounds should return empty string
        let outOfBounds = await history.readAt(index: 10)
        #expect(outOfBounds == "")
    }

    // MARK: - Prefix Search Tests

    /// Test prefix-based filtering returns matching commands
    @Test func test_prefixSearch() async throws {
        let history = CommandHistory()

        await history.add("look")
        await history.add("exp")
        await history.add("look north")
        await history.add("look south")
        await history.add("climb tower")
        await history.add("look east")

        // Search for "look" prefix
        let lookMatches = await history.match(prefix: "look")
        #expect(lookMatches.count == 3) // "look north", "look south", "look east" (excludes exact "look")
        #expect(lookMatches.contains("look north"))
        #expect(lookMatches.contains("look south"))
        #expect(lookMatches.contains("look east"))
        #expect(lookMatches.contains("look") == false) // Exact match excluded

        // Search for "climb" prefix
        let climbMatches = await history.match(prefix: "climb")
        #expect(climbMatches.count == 1)
        #expect(climbMatches.contains("climb tower"))

        // Search for non-existent prefix
        let noMatches = await history.match(prefix: "dance")
        #expect(noMatches.isEmpty)
    }

    /// Test prefix search excludes exact matches
    @Test func test_prefixSearchExcludesExactMatch() async throws {
        let history = CommandHistory()

        await history.add("look")
        await history.add("look north")

        let matches = await history.match(prefix: "look")
        #expect(matches.count == 1)
        #expect(matches.contains("look north"))
        #expect(matches.contains("look") == false)
    }

    /// Test prefix search with empty prefix
    @Test func test_prefixSearchEmptyPrefix() async throws {
        let history = CommandHistory()

        await history.add("look")
        await history.add("exp")

        // Empty prefix should return all commands except empty strings
        let matches = await history.match(prefix: "")
        #expect(matches.count == 2)
        #expect(matches.contains("look"))
        #expect(matches.contains("exp"))
    }

    /// Test prefix search case sensitivity
    @Test func test_prefixSearchCaseSensitive() async throws {
        let history = CommandHistory()

        await history.add("Look north")
        await history.add("look south")
        await history.add("LOOK east")

        // Prefix search should be case-sensitive
        let lowerMatches = await history.match(prefix: "look")
        #expect(lowerMatches.count == 1)
        #expect(lowerMatches.contains("look south"))

        let upperMatches = await history.match(prefix: "LOOK")
        #expect(upperMatches.count == 1)
        #expect(upperMatches.contains("LOOK east"))
    }

    /// Test prefix search returns commands in newest-first order
    @Test func test_prefixSearchOrder() async throws {
        let history = CommandHistory()

        await history.add("spell 101")
        await history.add("look")
        await history.add("spell 202")
        await history.add("exp")
        await history.add("spell 303")

        let matches = await history.match(prefix: "spell")
        #expect(matches.count == 3)
        #expect(matches[0] == "spell 303")  // Newest first
        #expect(matches[1] == "spell 202")
        #expect(matches[2] == "spell 101")
    }

    // MARK: - Buffer Pruning Tests

    /// Test 500-item limit with oldest pruning
    @Test func test_bufferPruning() async throws {
        let history = CommandHistory()

        // Add 510 commands
        for i in 0..<510 {
            await history.add("command \(i)")
        }

        // Verify buffer size is capped at 500
        let all = await history.getAll()
        #expect(all.count == 500)

        // Verify oldest commands were pruned (0-9 should be gone)
        #expect(all.contains("command 0") == false)
        #expect(all.contains("command 9") == false)

        // Verify oldest remaining command is "command 10"
        let oldest = all.last
        #expect(oldest == "command 10")

        // Verify newest command is "command 509"
        let newest = all.first
        #expect(newest == "command 509")
    }

    /// Test buffer pruning preserves newest commands
    @Test func test_bufferPruningPreservesNewest() async throws {
        let history = CommandHistory()

        // Add exactly 500 commands
        for i in 0..<500 {
            await history.add("cmd \(i)")
        }

        let before = await history.getAll()
        #expect(before.count == 500)
        #expect(before.first == "cmd 499")
        #expect(before.last == "cmd 0")

        // Add 10 more - should prune oldest 10
        for i in 500..<510 {
            await history.add("cmd \(i)")
        }

        let after = await history.getAll()
        #expect(after.count == 500)
        #expect(after.first == "cmd 509")
        #expect(after.last == "cmd 10")
        #expect(after.contains("cmd 0") == false)
        #expect(after.contains("cmd 9") == false)
    }

    /// Test buffer pruning with small buffer
    @Test func test_bufferPruningSmallBuffer() async throws {
        let history = CommandHistory(maxSize: 3)

        await history.add("first")
        await history.add("second")
        await history.add("third")

        var all = await history.getAll()
        #expect(all.count == 3)
        #expect(all == ["third", "second", "first"])

        // Add fourth - should prune "first"
        await history.add("fourth")

        all = await history.getAll()
        #expect(all.count == 3)
        #expect(all == ["fourth", "third", "second"])
        #expect(all.contains("first") == false)
    }

    // MARK: - Persistence Tests

    /// Test JSON save/load round-trip
    @Test func test_persistenceRoundTrip() async throws {
        let tempDir = try createTempDirectory()
        defer { try? removeTempDirectory(tempDir) }

        let filePath = tempDir.appendingPathComponent("command-history.json")

        let history = CommandHistory()

        // Add commands
        await history.add("look")
        await history.add("exp")
        await history.add("info")
        await history.add("spell list")

        // Save to file
        try await history.save(to: filePath)

        // Verify file exists
        #expect(FileManager.default.fileExists(atPath: filePath.path))

        // Load into new instance
        let loaded = CommandHistory()
        try await loaded.load(from: filePath)

        // Verify loaded data matches original
        let original = await history.getAll()
        let loadedData = await loaded.getAll()
        #expect(loadedData == original)
        #expect(loadedData == ["spell list", "info", "exp", "look"])
    }

    /// Test persistence with empty buffer
    @Test func test_persistenceEmptyBuffer() async throws {
        let tempDir = try createTempDirectory()
        defer { try? removeTempDirectory(tempDir) }

        let filePath = tempDir.appendingPathComponent("empty-history.json")

        let history = CommandHistory()

        // Save empty buffer
        try await history.save(to: filePath)

        // Load into new instance
        let loaded = CommandHistory()
        try await loaded.load(from: filePath)

        let loadedData = await loaded.getAll()
        #expect(loadedData.isEmpty)
    }

    /// Test persistence with full buffer (500 items)
    @Test func test_persistenceFullBuffer() async throws {
        let tempDir = try createTempDirectory()
        defer { try? removeTempDirectory(tempDir) }

        let filePath = tempDir.appendingPathComponent("full-history.json")

        let history = CommandHistory()

        // Add 500 commands
        for i in 0..<500 {
            await history.add("command \(i)")
        }

        try await history.save(to: filePath)

        let loaded = CommandHistory()
        try await loaded.load(from: filePath)

        let original = await history.getAll()
        let loadedData = await loaded.getAll()
        #expect(loadedData.count == 500)
        #expect(loadedData == original)
    }

    /// Test loading from non-existent file
    @Test func test_loadFromNonExistentFile() async throws {
        let tempDir = try createTempDirectory()
        defer { try? removeTempDirectory(tempDir) }

        let filePath = tempDir.appendingPathComponent("nonexistent.json")

        let history = CommandHistory()

        // Loading from non-existent file should succeed with empty buffer
        do {
            try await history.load(from: filePath)
            let data = await history.getAll()
            #expect(data.isEmpty)
        } catch {
            // Or it should throw - either is acceptable
            #expect(Bool(true))
        }
    }

    /// Test loading from corrupt JSON
    @Test func test_loadFromCorruptJSON() async throws {
        let tempDir = try createTempDirectory()
        defer { try? removeTempDirectory(tempDir) }

        let filePath = tempDir.appendingPathComponent("corrupt.json")

        // Write invalid JSON
        let corruptJSON = "{\"commands\": [\"look\", \"exp\","
        try corruptJSON.write(to: filePath, atomically: true, encoding: .utf8)

        let history = CommandHistory()

        // Should throw or return empty
        do {
            try await history.load(from: filePath)
            // If it succeeds, should have empty buffer
            let data = await history.getAll()
            #expect(data.isEmpty)
        } catch {
            // Or it should throw - acceptable
            #expect(Bool(true))
        }
    }

    /// Test persistence preserves command order
    @Test func test_persistencePreservesOrder() async throws {
        let tempDir = try createTempDirectory()
        defer { try? removeTempDirectory(tempDir) }

        let filePath = tempDir.appendingPathComponent("ordered-history.json")

        let history = CommandHistory()

        // Add commands in specific order
        let commands = ["first", "second", "third", "fourth", "fifth"]
        for cmd in commands {
            await history.add(cmd)
        }

        try await history.save(to: filePath)

        let loaded = CommandHistory()
        try await loaded.load(from: filePath)

        let loadedData = await loaded.getAll()
        #expect(loadedData == commands.reversed()) // Newest first
    }

    /// Test multiple save/load cycles
    @Test func test_multipleSaveLoadCycles() async throws {
        let tempDir = try createTempDirectory()
        defer { try? removeTempDirectory(tempDir) }

        let filePath = tempDir.appendingPathComponent("cycles.json")

        let history = CommandHistory()

        // Cycle 1
        await history.add("look")
        try await history.save(to: filePath)

        // Cycle 2
        await history.add("exp")
        try await history.save(to: filePath)

        // Load and verify
        let loaded = CommandHistory()
        try await loaded.load(from: filePath)

        let data = await loaded.getAll()
        #expect(data == ["exp", "look"])

        // Cycle 3 - add more to loaded instance
        await loaded.add("info")
        try await loaded.save(to: filePath)

        // Load again
        let final = CommandHistory()
        try await final.load(from: filePath)

        let finalData = await final.getAll()
        #expect(finalData == ["info", "exp", "look"])
    }

    // MARK: - Thread Safety Tests

    /// Test concurrent access via actor isolation
    @Test func test_concurrentAccess() async throws {
        let history = CommandHistory()

        // Concurrently add commands from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    await history.add("concurrent \(i)")
                }
            }
        }

        // Verify all commands were added
        let all = await history.getAll()
        #expect(all.count == 100)
    }

    /// Test concurrent navigation
    @Test func test_concurrentNavigation() async throws {
        let history = CommandHistory()

        // Add initial commands
        for i in 0..<50 {
            await history.add("cmd \(i)")
        }

        // Concurrently navigate and read
        await withTaskGroup(of: String.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    await history.back()
                }
                group.addTask {
                    await history.forward()
                }
                group.addTask {
                    await history.read()
                }
            }
        }

        // Should not crash - verify buffer is intact
        let all = await history.getAll()
        #expect(all.count == 50)
    }

    /// Test concurrent add and navigation
    @Test func test_concurrentAddAndNavigation() async throws {
        let history = CommandHistory()

        await withTaskGroup(of: Void.self) { group in
            // Add commands
            for i in 0..<50 {
                group.addTask {
                    await history.add("add \(i)")
                }
            }

            // Navigate while adding
            for _ in 0..<20 {
                group.addTask {
                    _ = await history.back()
                }
                group.addTask {
                    _ = await history.forward()
                }
            }
        }

        // Verify state is consistent
        let all = await history.getAll()
        #expect(all.count == 50)
    }

    /// Test concurrent prefix search
    @Test func test_concurrentPrefixSearch() async throws {
        let history = CommandHistory()

        // Add commands
        for i in 0..<100 {
            await history.add("look \(i)")
            await history.add("exp \(i)")
            await history.add("spell \(i)")
        }

        // Concurrent searches
        await withTaskGroup(of: [String].self) { group in
            for _ in 0..<20 {
                group.addTask {
                    await history.match(prefix: "look")
                }
                group.addTask {
                    await history.match(prefix: "exp")
                }
                group.addTask {
                    await history.match(prefix: "spell")
                }
            }
        }

        // Verify buffer is intact
        let all = await history.getAll()
        #expect(all.count == 300)
    }

    // MARK: - Edge Cases

    /// Test very long command strings
    @Test func test_veryLongCommands() async throws {
        let history = CommandHistory()

        let longCommand = String(repeating: "a", count: 10000)
        await history.add(longCommand)

        let all = await history.getAll()
        #expect(all.count == 1)
        #expect(all[0].count == 10000)
    }

    /// Test unicode characters in commands
    @Test func test_unicodeCommands() async throws {
        let history = CommandHistory()

        await history.add("look 北")
        await history.add("say 你好")
        await history.add("emote 🎉")

        let all = await history.getAll()
        #expect(all == ["emote 🎉", "say 你好", "look 北"])
    }

    /// Test newlines in commands
    @Test func test_newlinesInCommands() async throws {
        let history = CommandHistory()

        await history.add("line1\nline2")
        await history.add("single")
        await history.add("multi\nline\ncommand")

        let all = await history.getAll()
        #expect(all.count == 3)
        #expect(all[0] == "multi\nline\ncommand")
    }

    /// Test position tracking across buffer pruning
    @Test func test_positionTrackingAcrossPruning() async throws {
        let history = CommandHistory(maxSize: 5)

        // Add 5 commands
        for i in 1...5 {
            await history.add("cmd \(i)")
        }

        // Navigate to middle
        _ = await history.back()
        _ = await history.back()

        // Current should be "cmd 3"
        let current = await history.read()
        #expect(current == "cmd 3")

        // Add new command - buffer prunes oldest, position should reset
        await history.add("cmd 6")

        // Position should be at newest
        let newCurrent = await history.read()
        #expect(newCurrent == "cmd 6")
    }

    /// Test custom maxSize initialization
    @Test func test_customMaxSize() async throws {
        let history = CommandHistory(maxSize: 10)

        for i in 0..<15 {
            await history.add("cmd \(i)")
        }

        let all = await history.getAll()
        #expect(all.count == 10)
        #expect(all.first == "cmd 14")
        #expect(all.last == "cmd 5")
    }

    // MARK: - Real-World Scenario Tests

    /// Test typical user session pattern
    @Test func test_typicalUserSession() async throws {
        let history = CommandHistory()

        // User enters various commands
        await history.add("look")
        await history.add("exp")
        await history.add("inventory")

        // User navigates history with up arrow
        let up1 = await history.back()
        #expect(up1 == "exp")

        let up2 = await history.back()
        #expect(up2 == "look")

        // User navigates down
        let down1 = await history.forward()
        #expect(down1 == "exp")

        // User submits current command again (adds duplicate)
        await history.add("exp")

        // Position should reset to newest
        let current = await history.read()
        #expect(current == "exp")

        // History should have duplicate
        let all = await history.getAll()
        #expect(all == ["exp", "inventory", "exp", "look"])
    }

    /// Test prefix autocomplete scenario
    @Test func test_prefixAutocompleteScenario() async throws {
        let history = CommandHistory()

        // User has history of spell commands
        await history.add("spell list")
        await history.add("look")
        await history.add("spell active")
        await history.add("exp")
        await history.add("spell 101")

        // User types "spell" and requests autocomplete
        let matches = await history.match(prefix: "spell")

        #expect(matches.count == 3)
        // Should be in newest-first order
        #expect(matches[0] == "spell 101")
        #expect(matches[1] == "spell active")
        #expect(matches[2] == "spell list")
    }

    /// Test session persistence scenario
    @Test func test_sessionPersistenceScenario() async throws {
        let tempDir = try createTempDirectory()
        defer { try? removeTempDirectory(tempDir) }

        let filePath = tempDir.appendingPathComponent("session.json")

        // Session 1: User plays and quits
        let session1 = CommandHistory()
        await session1.add("look")
        await session1.add("exp")
        await session1.add("spell list")
        try await session1.save(to: filePath)

        // Session 2: User launches again
        let session2 = CommandHistory()
        try await session2.load(from: filePath)

        // User should see previous commands
        let loaded = await session2.getAll()
        #expect(loaded == ["spell list", "exp", "look"])

        // User continues playing
        await session2.add("info")

        // Navigate history
        let prev = await session2.back()
        #expect(prev == "spell list")

        // Save on quit
        try await session2.save(to: filePath)

        // Session 3: Verify persistence
        let session3 = CommandHistory()
        try await session3.load(from: filePath)

        let final = await session3.getAll()
        #expect(final == ["info", "spell list", "exp", "look"])
    }
}
