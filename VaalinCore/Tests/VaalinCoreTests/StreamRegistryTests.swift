// ABOUTME: Tests for StreamRegistry actor - stream registration, lookup by ID/alias, and thread-safety

import Testing
import Foundation
import VaalinCore

/// Test suite for StreamRegistry actor
///
/// Tests stream registration, lookup by ID and alias, concurrent access for thread safety,
/// and JSON deserialization. Follows TDD approach - these tests will fail until StreamRegistry is implemented.
///
/// **Coverage Target**: >80% (business logic)
struct StreamRegistryTests {
    // MARK: - Helper Functions

    /// Creates sample valid JSON data for testing
    private func sampleStreamConfigJSON() -> Data {
        """
        {
          "streams": [
            {
              "id": "thoughts",
              "label": "Thoughts",
              "defaultOn": true,
              "color": "subtext1",
              "aliases": []
            },
            {
              "id": "whispers",
              "label": "Whispers",
              "defaultOn": true,
              "color": "teal",
              "aliases": ["whisper"]
            },
            {
              "id": "logons",
              "label": "Logons",
              "defaultOn": true,
              "color": "yellow",
              "aliases": ["logon", "logoff", "death"]
            },
            {
              "id": "expr",
              "label": "Experience",
              "defaultOn": false,
              "color": "sapphire",
              "aliases": ["experience"]
            }
          ]
        }
        """.data(using: .utf8)!
    }

    /// Creates minimal valid JSON with one stream
    private func minimalStreamConfigJSON() -> Data {
        """
        {
          "streams": [
            {
              "id": "test",
              "label": "Test Stream",
              "defaultOn": true,
              "color": "green",
              "aliases": []
            }
          ]
        }
        """.data(using: .utf8)!
    }

    /// Creates empty but valid JSON
    private func emptyStreamConfigJSON() -> Data {
        """
        {
          "streams": []
        }
        """.data(using: .utf8)!
    }

    /// Creates malformed JSON (missing required field)
    private func malformedStreamConfigJSON() -> Data {
        """
        {
          "streams": [
            {
              "id": "broken",
              "label": "Broken Stream"
            }
          ]
        }
        """.data(using: .utf8)!
    }

    /// Creates invalid JSON (not valid JSON syntax)
    private func invalidJSON() -> Data {
        "{ this is not valid JSON }".data(using: .utf8)!
    }

    // MARK: - JSON Loading Tests

    /// Test loading valid stream configuration from JSON data
    @Test func loadStreamConfig() async throws {
        let registry = StreamRegistry()
        let jsonData = sampleStreamConfigJSON()

        // Should not throw
        try await registry.load(from: jsonData)

        // Verify streams were loaded
        let allStreams = await registry.allStreams()
        #expect(allStreams.count == 4)

        // Verify specific streams exist
        let thoughts = await registry.stream(withID: "thoughts")
        #expect(thoughts != nil)
        #expect(thoughts?.label == "Thoughts")

        let whispers = await registry.stream(withID: "whispers")
        #expect(whispers != nil)
        #expect(whispers?.label == "Whispers")
    }

    /// Test loading minimal valid JSON
    @Test func loadMinimalJSON() async throws {
        let registry = StreamRegistry()
        let jsonData = minimalStreamConfigJSON()

        try await registry.load(from: jsonData)

        let allStreams = await registry.allStreams()
        #expect(allStreams.count == 1)

        let stream = await registry.stream(withID: "test")
        #expect(stream?.id == "test")
        #expect(stream?.label == "Test Stream")
        #expect(stream?.defaultOn == true)
        #expect(stream?.color == "green")
        #expect(stream?.aliases.isEmpty == true)
    }

    /// Test loading empty JSON (valid but no streams)
    @Test func loadEmptyJSON() async throws {
        let registry = StreamRegistry()
        let jsonData = emptyStreamConfigJSON()

        try await registry.load(from: jsonData)

        let allStreams = await registry.allStreams()
        #expect(allStreams.isEmpty)
    }

    /// Test loading malformed JSON throws error
    @Test func loadMalformedJSON() async throws {
        let registry = StreamRegistry()
        let jsonData = malformedStreamConfigJSON()

        // Should throw decoding error
        await #expect(throws: Error.self) {
            try await registry.load(from: jsonData)
        }
    }

    /// Test loading invalid JSON throws error
    @Test func loadInvalidJSON() async throws {
        let registry = StreamRegistry()
        let jsonData = invalidJSON()

        // Should throw decoding error
        await #expect(throws: Error.self) {
            try await registry.load(from: jsonData)
        }
    }

    /// Test loading replaces existing streams (duplicate load)
    @Test func loadReplacesExisting() async throws {
        let registry = StreamRegistry()

        // Load first config
        try await registry.load(from: sampleStreamConfigJSON())
        let firstCount = await registry.allStreams().count
        #expect(firstCount == 4)

        // Load different config (minimal with 1 stream)
        try await registry.load(from: minimalStreamConfigJSON())
        let secondCount = await registry.allStreams().count
        #expect(secondCount == 1)

        // Only the new stream should exist
        let test = await registry.stream(withID: "test")
        #expect(test != nil)

        let thoughts = await registry.stream(withID: "thoughts")
        #expect(thoughts == nil)
    }

    // MARK: - Stream Lookup Tests

    /// Test looking up stream by ID
    @Test func streamLookup() async throws {
        let registry = StreamRegistry()
        try await registry.load(from: sampleStreamConfigJSON())

        // Test existing streams
        let thoughts = await registry.stream(withID: "thoughts")
        #expect(thoughts != nil)
        #expect(thoughts?.id == "thoughts")
        #expect(thoughts?.label == "Thoughts")
        #expect(thoughts?.defaultOn == true)
        #expect(thoughts?.color == "subtext1")
        #expect(thoughts?.aliases.isEmpty == true)

        let whispers = await registry.stream(withID: "whispers")
        #expect(whispers != nil)
        #expect(whispers?.id == "whispers")
        #expect(whispers?.label == "Whispers")
        #expect(whispers?.aliases == ["whisper"])

        let expr = await registry.stream(withID: "expr")
        #expect(expr != nil)
        #expect(expr?.defaultOn == false)
    }

    /// Test looking up non-existent stream returns nil
    @Test func unknownStreamReturnsNil() async throws {
        let registry = StreamRegistry()
        try await registry.load(from: sampleStreamConfigJSON())

        let result = await registry.stream(withID: "nonexistent")
        #expect(result == nil)

        let empty = await registry.stream(withID: "")
        #expect(empty == nil)
    }

    /// Test that looking up unknown stream is logged (for debugging)
    ///
    /// Note: This test verifies the contract - unknown streams should return nil.
    /// Actual logging verification would require capturing log output, which is
    /// implementation-specific. The important behavior is returning nil.
    @Test func unknownStreamLogged() async throws {
        let registry = StreamRegistry()
        try await registry.load(from: sampleStreamConfigJSON())

        // Looking up unknown stream should return nil
        let result = await registry.stream(withID: "unknown_stream")
        #expect(result == nil)

        // The implementation should log this lookup for debugging purposes
        // (actual log verification is implementation-specific)
    }

    // MARK: - Alias Lookup Tests

    /// Test looking up stream by alias
    @Test func aliasLookup() async throws {
        let registry = StreamRegistry()
        try await registry.load(from: sampleStreamConfigJSON())

        // Lookup by single alias
        let whisper = await registry.stream(withAlias: "whisper")
        #expect(whisper != nil)
        #expect(whisper?.id == "whispers")
        #expect(whisper?.label == "Whispers")

        // Lookup by one of multiple aliases
        let logon = await registry.stream(withAlias: "logon")
        #expect(logon != nil)
        #expect(logon?.id == "logons")

        let logoff = await registry.stream(withAlias: "logoff")
        #expect(logoff != nil)
        #expect(logoff?.id == "logons")

        let death = await registry.stream(withAlias: "death")
        #expect(death != nil)
        #expect(death?.id == "logons")

        // All three aliases should return same stream
        #expect(logon?.id == logoff?.id)
        #expect(logoff?.id == death?.id)
    }

    /// Test looking up stream by alias when stream has no aliases
    @Test func noAliasesReturnsNil() async throws {
        let registry = StreamRegistry()
        try await registry.load(from: sampleStreamConfigJSON())

        // "thoughts" has empty aliases array
        let result = await registry.stream(withAlias: "thoughts")
        #expect(result == nil)
    }

    /// Test looking up non-existent alias returns nil
    @Test func unknownAliasReturnsNil() async throws {
        let registry = StreamRegistry()
        try await registry.load(from: sampleStreamConfigJSON())

        let result = await registry.stream(withAlias: "nonexistent")
        #expect(result == nil)

        let empty = await registry.stream(withAlias: "")
        #expect(empty == nil)
    }

    /// Test multiple aliases for same stream
    @Test func multipleAliasesSameStream() async throws {
        let registry = StreamRegistry()
        try await registry.load(from: sampleStreamConfigJSON())

        // "logons" has three aliases
        let logons = await registry.stream(withID: "logons")
        #expect(logons?.aliases.count == 3)

        // All aliases should resolve to same stream
        let alias1 = await registry.stream(withAlias: "logon")
        let alias2 = await registry.stream(withAlias: "logoff")
        let alias3 = await registry.stream(withAlias: "death")

        #expect(alias1?.id == "logons")
        #expect(alias2?.id == "logons")
        #expect(alias3?.id == "logons")
    }

    /// Test experience stream with single alias
    @Test func experienceAlias() async throws {
        let registry = StreamRegistry()
        try await registry.load(from: sampleStreamConfigJSON())

        let byID = await registry.stream(withID: "expr")
        let byAlias = await registry.stream(withAlias: "experience")

        #expect(byID?.id == "expr")
        #expect(byAlias?.id == "expr")
        #expect(byID?.id == byAlias?.id)
    }

    // MARK: - All Streams Tests

    /// Test retrieving all registered streams
    @Test func allStreams() async throws {
        let registry = StreamRegistry()
        try await registry.load(from: sampleStreamConfigJSON())

        let all = await registry.allStreams()
        #expect(all.count == 4)

        let ids = all.map { $0.id }.sorted()
        #expect(ids == ["expr", "logons", "thoughts", "whispers"])
    }

    /// Test filtering streams by defaultOn state
    @Test func filterByDefaultOn() async throws {
        let registry = StreamRegistry()
        try await registry.load(from: sampleStreamConfigJSON())

        let all = await registry.allStreams()

        let defaultOn = all.filter { $0.defaultOn }
        #expect(defaultOn.count == 3) // thoughts, whispers, logons

        let defaultOff = all.filter { !$0.defaultOn }
        #expect(defaultOff.count == 1) // expr
        #expect(defaultOff.first?.id == "expr")
    }

    // MARK: - Empty Registry Tests

    /// Test empty registry returns nil/empty arrays
    @Test func emptyRegistry() async throws {
        let registry = StreamRegistry()

        // Before loading any data
        let all = await registry.allStreams()
        #expect(all.isEmpty)

        let byID = await registry.stream(withID: "anything")
        #expect(byID == nil)

        let byAlias = await registry.stream(withAlias: "anything")
        #expect(byAlias == nil)
    }

    /// Test registry after loading empty JSON
    @Test func emptyJSONRegistry() async throws {
        let registry = StreamRegistry()
        try await registry.load(from: emptyStreamConfigJSON())

        let all = await registry.allStreams()
        #expect(all.isEmpty)

        let byID = await registry.stream(withID: "test")
        #expect(byID == nil)

        let byAlias = await registry.stream(withAlias: "test")
        #expect(byAlias == nil)
    }

    // MARK: - Duplicate ID Tests

    /// Test that registering a duplicate ID overwrites the previous stream
    @Test func duplicateID() async throws {
        let registry = StreamRegistry()

        // Create JSON with duplicate IDs
        let duplicateJSON = """
        {
          "streams": [
            {
              "id": "test",
              "label": "First",
              "defaultOn": true,
              "color": "red",
              "aliases": ["first"]
            },
            {
              "id": "test",
              "label": "Second",
              "defaultOn": false,
              "color": "blue",
              "aliases": ["second"]
            }
          ]
        }
        """.data(using: .utf8)!

        try await registry.load(from: duplicateJSON)

        // Should have only one stream
        let all = await registry.allStreams()
        #expect(all.count == 1)

        // Should be the second (last) definition
        let stream = await registry.stream(withID: "test")
        #expect(stream?.label == "Second")
        #expect(stream?.defaultOn == false)
        #expect(stream?.color == "blue")
        #expect(stream?.aliases == ["second"])

        // First alias should not resolve
        let firstAlias = await registry.stream(withAlias: "first")
        #expect(firstAlias == nil)

        // Second alias should resolve
        let secondAlias = await registry.stream(withAlias: "second")
        #expect(secondAlias?.id == "test")
    }

    /// Test alias collision behavior (last-wins, with logging)
    @Test func aliasCollisionBehavior() async throws {
        let registry = StreamRegistry()

        // Two different streams sharing the same alias
        let json = """
        {
          "streams": [
            {
              "id": "first",
              "label": "First Stream",
              "defaultOn": true,
              "color": "red",
              "aliases": ["shared", "first-only"]
            },
            {
              "id": "second",
              "label": "Second Stream",
              "defaultOn": true,
              "color": "blue",
              "aliases": ["shared", "second-only"]
            }
          ]
        }
        """.data(using: .utf8)!

        try await registry.load(from: json)

        // Last-wins behavior: "shared" should resolve to "second"
        let sharedResult = await registry.stream(withAlias: "shared")
        #expect(sharedResult?.id == "second")

        // Unique aliases should still work
        let firstOnly = await registry.stream(withAlias: "first-only")
        #expect(firstOnly?.id == "first")

        let secondOnly = await registry.stream(withAlias: "second-only")
        #expect(secondOnly?.id == "second")
    }

    // MARK: - Concurrent Access Tests

    /// Test concurrent access to registry (thread safety)
    @Test func concurrentAccess() async throws {
        let registry = StreamRegistry()
        try await registry.load(from: sampleStreamConfigJSON())

        // Read concurrently from multiple tasks
        await withTaskGroup(of: StreamInfo?.self) { group in
            // Lookup by ID concurrently
            for _ in 0..<20 {
                group.addTask {
                    await registry.stream(withID: "thoughts")
                }
                group.addTask {
                    await registry.stream(withID: "whispers")
                }
                group.addTask {
                    await registry.stream(withID: "logons")
                }
            }

            var results: [StreamInfo?] = []
            for await result in group {
                results.append(result)
            }

            // All lookups should succeed
            #expect(results.count == 60)
            #expect(results.compactMap { $0 }.count == 60)
        }

        // Read by alias concurrently
        await withTaskGroup(of: StreamInfo?.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    await registry.stream(withAlias: "whisper")
                }
                group.addTask {
                    await registry.stream(withAlias: "logon")
                }
                group.addTask {
                    await registry.stream(withAlias: "experience")
                }
            }

            var results: [StreamInfo?] = []
            for await result in group {
                results.append(result)
            }

            // All lookups should succeed
            #expect(results.count == 60)
            #expect(results.compactMap { $0 }.count == 60)
        }

        // Mix ID and alias lookups with allStreams calls
        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    let _ = await registry.stream(withID: "thoughts")
                    return 1
                }
                group.addTask {
                    let _ = await registry.stream(withAlias: "whisper")
                    return 1
                }
                group.addTask {
                    let all = await registry.allStreams()
                    return all.count
                }
            }

            var totalCount = 0
            for await count in group {
                totalCount += count
            }

            // 10 ID lookups (1 each) + 10 alias lookups (1 each) + 10 allStreams (4 each) = 60
            #expect(totalCount == 60)
        }
    }

    /// Test concurrent loading (last load wins)
    @Test func concurrentLoading() async throws {
        let registry = StreamRegistry()

        // Load concurrently with different data
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask {
                    let json = """
                    {
                      "streams": [
                        {
                          "id": "stream\(i)",
                          "label": "Stream \(i)",
                          "defaultOn": true,
                          "color": "color\(i)",
                          "aliases": []
                        }
                      ]
                    }
                    """.data(using: .utf8)!

                    try? await registry.load(from: json)
                }
            }
        }

        // One of the loads should have won
        let all = await registry.allStreams()
        #expect(all.count == 1)

        // The winning stream should be one of the loaded ones
        let stream = all.first
        #expect(stream?.id.hasPrefix("stream") == true)
    }
}

// MARK: - StreamInfo Tests

/// Test suite for StreamInfo model
struct StreamInfoTests {
    // MARK: - Codable Tests

    /// Test StreamInfo Codable encoding/decoding
    @Test func codableRoundTrip() throws {
        let original = StreamInfo(
            id: "thoughts",
            label: "Thoughts",
            defaultOn: true,
            color: "subtext1",
            aliases: []
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(StreamInfo.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.label == original.label)
        #expect(decoded.defaultOn == original.defaultOn)
        #expect(decoded.color == original.color)
        #expect(decoded.aliases == original.aliases)
    }

    /// Test StreamInfo with aliases
    @Test func codableWithAliases() throws {
        let original = StreamInfo(
            id: "logons",
            label: "Logons",
            defaultOn: true,
            color: "yellow",
            aliases: ["logon", "logoff", "death"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(StreamInfo.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.aliases.count == 3)
        #expect(decoded.aliases == original.aliases)
    }

    /// Test decoding StreamInfo from actual JSON format
    @Test func decodeFromJSON() throws {
        let json = """
        {
          "id": "whispers",
          "label": "Whispers",
          "defaultOn": true,
          "color": "teal",
          "aliases": ["whisper"]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let stream = try decoder.decode(StreamInfo.self, from: json)

        #expect(stream.id == "whispers")
        #expect(stream.label == "Whispers")
        #expect(stream.defaultOn == true)
        #expect(stream.color == "teal")
        #expect(stream.aliases == ["whisper"])
    }

    /// Test decoding StreamInfo with missing optional fields fails
    @Test func decodeMissingRequiredField() throws {
        let json = """
        {
          "id": "broken",
          "label": "Broken Stream"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()

        #expect(throws: Error.self) {
            let _ = try decoder.decode(StreamInfo.self, from: json)
        }
    }

    // MARK: - Equatable Tests

    /// Test StreamInfo Equatable conformance
    @Test func equality() throws {
        let stream1 = StreamInfo(
            id: "thoughts",
            label: "Thoughts",
            defaultOn: true,
            color: "subtext1",
            aliases: []
        )

        let stream2 = StreamInfo(
            id: "thoughts",
            label: "Thoughts",
            defaultOn: true,
            color: "subtext1",
            aliases: []
        )

        let stream3 = StreamInfo(
            id: "whispers",
            label: "Whispers",
            defaultOn: true,
            color: "teal",
            aliases: ["whisper"]
        )

        #expect(stream1 == stream2)
        #expect(stream1 != stream3)
    }

    /// Test equality with different aliases
    @Test func equalityWithAliases() throws {
        let stream1 = StreamInfo(
            id: "test",
            label: "Test",
            defaultOn: true,
            color: "green",
            aliases: ["a", "b"]
        )

        let stream2 = StreamInfo(
            id: "test",
            label: "Test",
            defaultOn: true,
            color: "green",
            aliases: ["a", "b"]
        )

        let stream3 = StreamInfo(
            id: "test",
            label: "Test",
            defaultOn: true,
            color: "green",
            aliases: ["a", "b", "c"]
        )

        #expect(stream1 == stream2)
        #expect(stream1 != stream3)
    }

    // MARK: - Property Tests

    /// Test StreamInfo with empty aliases
    @Test func emptyAliases() throws {
        let stream = StreamInfo(
            id: "test",
            label: "Test",
            defaultOn: true,
            color: "green",
            aliases: []
        )

        #expect(stream.aliases.isEmpty)
    }

    /// Test StreamInfo with defaultOn false
    @Test func defaultOff() throws {
        let stream = StreamInfo(
            id: "expr",
            label: "Experience",
            defaultOn: false,
            color: "sapphire",
            aliases: ["experience"]
        )

        #expect(stream.defaultOn == false)
    }
}

// MARK: - StreamConfig Tests

/// Test suite for StreamConfig wrapper
struct StreamConfigTests {
    /// Test StreamConfig Codable decoding
    @Test func decodeStreamConfig() throws {
        let json = """
        {
          "streams": [
            {
              "id": "thoughts",
              "label": "Thoughts",
              "defaultOn": true,
              "color": "subtext1",
              "aliases": []
            },
            {
              "id": "whispers",
              "label": "Whispers",
              "defaultOn": true,
              "color": "teal",
              "aliases": ["whisper"]
            }
          ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let config = try decoder.decode(StreamConfig.self, from: json)

        #expect(config.streams.count == 2)
        #expect(config.streams[0].id == "thoughts")
        #expect(config.streams[1].id == "whispers")
    }

    /// Test StreamConfig with empty streams array
    @Test func emptyStreams() throws {
        let json = """
        {
          "streams": []
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let config = try decoder.decode(StreamConfig.self, from: json)

        #expect(config.streams.isEmpty)
    }

    /// Test StreamConfig Codable round-trip
    @Test func codableRoundTrip() throws {
        let original = StreamConfig(streams: [
            StreamInfo(
                id: "test1",
                label: "Test 1",
                defaultOn: true,
                color: "red",
                aliases: []
            ),
            StreamInfo(
                id: "test2",
                label: "Test 2",
                defaultOn: false,
                color: "blue",
                aliases: ["alias1", "alias2"]
            )
        ])

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(StreamConfig.self, from: data)

        #expect(decoded.streams.count == original.streams.count)
        #expect(decoded.streams[0].id == original.streams[0].id)
        #expect(decoded.streams[1].id == original.streams[1].id)
        #expect(decoded.streams[1].aliases == original.streams[1].aliases)
    }
}
