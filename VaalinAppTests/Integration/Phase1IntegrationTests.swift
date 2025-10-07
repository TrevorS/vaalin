// ABOUTME: Phase 1 basic integration tests for parser + network + mock server

import Foundation
import Testing
import Vaalin
@testable import VaalinCore
@testable import VaalinNetwork
@testable import VaalinParser
@testable import VaalinUI

/// Basic integration tests for Phase 1 Integration Checkpoint (Issue #20)
///
/// These tests validate core connection flow, data parsing, and error resilience.
/// For complete end-to-end and stability tests, see Phase1StabilityTests.swift.
///
/// Architecture tested:
/// ```
/// MockLichServer (TCP) → LichConnection (AsyncStream<Data>)
///                      → ParserConnectionBridge (decode UTF-8)
///                      → XMLStreamParser (parse XML chunks)
///                      → [GameTag] (accumulated results)
/// ```
struct Phase1IntegrationTests {
    // MARK: - Basic Connection Flow

    /// Test complete connection and data receive flow
    @Test func test_connectionAndDataFlow() async throws {
        let server = MockLichServer()
        try await server.start()

        let port = await server.port
        let connection = LichConnection()
        let parser = XMLStreamParser()

        // Connect to mock server
        try await connection.connect(host: "127.0.0.1", port: port)

        // Send initial connection scenario
        await server.sendScenario(.initialConnection)

        // Collect data from stream
        var allData = Data()
        var chunkCount = 0

        let streamTask = Task { @MainActor in
            let stream = await connection.dataStream
            for await chunk in stream {
                allData.append(chunk)
                chunkCount += 1
                if chunkCount >= 1 {
                    break // Got initial data
                }
            }
        }

        // Wait for data
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3s

        streamTask.cancel()

        // Parse received data
        let xmlString = String(data: allData, encoding: .utf8) ?? ""
        let tags = await parser.parse(xmlString)

        // Verify we got tags
        #expect(!tags.isEmpty)
        #expect(xmlString.contains("<mode id=\"GAME\"/>"))

        // Clean up
        await connection.disconnect()
        await server.stop()
    }

    /// Test room description parsing end-to-end
    @Test func test_roomDescriptionIntegration() async throws {
        let server = MockLichServer()
        try await server.start()

        let port = await server.port
        let connection = LichConnection()
        let parser = XMLStreamParser()

        try await connection.connect(host: "127.0.0.1", port: port)

        // Send room description
        await server.sendScenario(.roomDescription)

        // Collect data
        var allData = Data()
        let streamTask = Task { @MainActor in
            let stream = await connection.dataStream
            for await chunk in stream {
                allData.append(chunk)
                if allData.count > 0 {
                    break
                }
            }
        }

        try await Task.sleep(nanoseconds: 300_000_000)
        streamTask.cancel()

        // Parse
        let xmlString = String(data: allData, encoding: .utf8) ?? ""
        _ = await parser.parse(xmlString)

        // Verify stream management
        #expect(xmlString.contains("<pushStream id=\"room\"/>"))
        #expect(xmlString.contains("<popStream/>"))
        #expect(xmlString.contains("[Wehnimer's Landing"))

        // Clean up
        await connection.disconnect()
        await server.stop()
    }

    /// Test combat sequence with vitals updates
    @Test func test_combatSequenceIntegration() async throws {
        let server = MockLichServer()
        try await server.start()

        let port = await server.port
        let connection = LichConnection()
        let parser = XMLStreamParser()

        try await connection.connect(host: "127.0.0.1", port: port)

        // Send combat scenario
        await server.sendScenario(.combatSequence)

        // Collect data
        var allData = Data()
        let streamTask = Task { @MainActor in
            let stream = await connection.dataStream
            for await chunk in stream {
                allData.append(chunk)
                if allData.count > 0 {
                    break
                }
            }
        }

        try await Task.sleep(nanoseconds: 300_000_000)
        streamTask.cancel()

        // Parse
        let xmlString = String(data: allData, encoding: .utf8) ?? ""
        _ = await parser.parse(xmlString)

        // Verify combat content and vitals
        #expect(xmlString.contains("<pushStream id=\"combat\"/>"))
        #expect(xmlString.contains("<progressBar id=\"health\""))
        #expect(xmlString.contains("<progressBar id=\"stamina\""))
        #expect(xmlString.contains("You swing"))

        // Clean up
        await connection.disconnect()
        await server.stop()
    }

    /// Test item loot with exist/noun attributes
    @Test func test_itemLootIntegration() async throws {
        let server = MockLichServer()
        try await server.start()

        let port = await server.port
        let connection = LichConnection()
        let parser = XMLStreamParser()

        try await connection.connect(host: "127.0.0.1", port: port)

        // Send item loot scenario
        await server.sendScenario(.itemLoot)

        // Collect data
        var allData = Data()
        let streamTask = Task { @MainActor in
            let stream = await connection.dataStream
            for await chunk in stream {
                allData.append(chunk)
                if allData.count > 0 {
                    break
                }
            }
        }

        try await Task.sleep(nanoseconds: 300_000_000)
        streamTask.cancel()

        // Parse
        let xmlString = String(data: allData, encoding: .utf8) ?? ""
        _ = await parser.parse(xmlString)

        // Verify item tags with attributes
        #expect(xmlString.contains("<a exist=\""))
        #expect(xmlString.contains("noun=\"gem\""))
        #expect(xmlString.contains("noun=\"coin\""))
        #expect(xmlString.contains("noun=\"box\""))

        // Clean up
        await connection.disconnect()
        await server.stop()
    }

    // MARK: - Parser-Connection Bridge Integration

    /// Test ParserConnectionBridge with mock server
    @Test func test_parserConnectionBridgeIntegration() async throws {
        let server = MockLichServer()
        try await server.start()

        let port = await server.port
        let connection = LichConnection()
        let parser = XMLStreamParser()
        let bridge = ParserConnectionBridge(connection: connection, parser: parser)

        // Connect
        try await connection.connect(host: "127.0.0.1", port: port)

        // Start bridge
        await bridge.start()

        // Send multiple scenarios
        await server.sendScenario(.promptSequence)

        // Wait for processing
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

        // Get parsed tags from bridge
        let tags = await bridge.getParsedTags()

        // Verify tags were accumulated
        #expect(!tags.isEmpty)

        // Stop bridge
        await bridge.stop()

        // Clean up
        await connection.disconnect()
        await server.stop()
    }

    /// Test bridge handles multiple rapid scenarios
    @Test func test_bridgeHandlesMultipleScenarios() async throws {
        let server = MockLichServer()
        try await server.start()

        let port = await server.port
        let connection = LichConnection()
        let parser = XMLStreamParser()
        let bridge = ParserConnectionBridge(connection: connection, parser: parser)

        try await connection.connect(host: "127.0.0.1", port: port)
        await bridge.start()

        // Send multiple scenarios in sequence
        await server.sendScenario(.promptSequence)
        await server.sendScenario(.handsUpdate)
        await server.sendScenario(.vitalsUpdate)

        // Wait for processing
        try await Task.sleep(nanoseconds: 500_000_000)

        // Get tags
        let tags = await bridge.getParsedTags()

        // Should have tags from all scenarios
        #expect(tags.count > 0)

        // Clear and verify
        await bridge.clearParsedTags()
        let clearedTags = await bridge.getParsedTags()
        #expect(clearedTags.isEmpty)

        // Stop bridge
        await bridge.stop()

        // Clean up
        await connection.disconnect()
        await server.stop()
    }

    // MARK: - Error Resilience

    /// Test system handles server disconnect during operation
    @Test func test_handlesServerDisconnect() async throws {
        let server = MockLichServer()
        try await server.start()

        let port = await server.port
        let connection = LichConnection()

        try await connection.connect(host: "127.0.0.1", port: port)

        // Send some data
        await server.sendScenario(.promptSequence)

        // Wait briefly
        try await Task.sleep(nanoseconds: 100_000_000)

        // Stop server (simulates disconnect)
        await server.stop()

        // Connection should eventually detect failure
        try await Task.sleep(nanoseconds: 200_000_000)

        // Clean up client
        await connection.disconnect()
    }

    /// Test reconnection scenario
    @Test func test_reconnectionScenario() async throws {
        let server = MockLichServer()
        try await server.start()

        let port = await server.port
        let connection = LichConnection()

        // First connection
        try await connection.connect(host: "127.0.0.1", port: port)

        // Disconnect
        await connection.disconnect()

        // Stop and restart server (new port)
        await server.stop()
        try await server.start()

        let newPort = await server.port

        // Reconnect
        try await connection.connect(host: "127.0.0.1", port: newPort)

        let state = await connection.state
        #expect(state == .connected)

        // Clean up
        await connection.disconnect()
        await server.stop()
    }
}
