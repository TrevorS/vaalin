// ABOUTME: Tests for MockLichServer XML sending and scenario functionality

import Foundation
import Network
import Testing
@testable import VaalinNetwork

/// Test suite for MockLichServer XML broadcasting and scenario validation
///
/// Validates XML sending, scenario content, and performance characteristics.
struct MockLichServerScenarioTests {
    // MARK: - XML Sending Tests

    /// Test server can send XML to connected client
    @Test func test_serverSendsXMLToClient() async throws {
        let server = MockLichServer()
        try await server.start()

        let port = await server.port
        let connection = LichConnection()

        try await connection.connect(host: "127.0.0.1", port: port)

        // Set up data stream consumer (access dataStream from actor context)
        var receivedData: [Data] = []
        let streamTask = Task { @MainActor in
            // Create stream reference in actor context
            let stream = await connection.dataStream
            for await data in stream {
                receivedData.append(data)
                if receivedData.count >= 1 {
                    break // Got what we need
                }
            }
        }

        // Send XML from server
        let testXML = "<prompt>&gt;</prompt>"
        await server.sendXML(testXML)

        // Wait for data
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2s

        streamTask.cancel()

        // Verify data received
        #expect(!receivedData.isEmpty)

        if let firstChunk = receivedData.first,
           let receivedString = String(data: firstChunk, encoding: .utf8) {
            #expect(receivedString.contains("<prompt>"))
        }

        // Clean up
        await connection.disconnect()
        await server.stop()
    }

    /// Test server broadcasts to multiple clients
    @Test func test_serverBroadcastsToMultipleClients() async throws {
        let server = MockLichServer()
        try await server.start()

        let port = await server.port

        let connection1 = LichConnection()
        let connection2 = LichConnection()

        try await connection1.connect(host: "127.0.0.1", port: port)
        try await connection2.connect(host: "127.0.0.1", port: port)

        // Set up data stream consumers
        var received1: [Data] = []
        var received2: [Data] = []

        let task1 = Task { @MainActor in
            let stream = await connection1.dataStream
            for await data in stream {
                received1.append(data)
                if received1.count >= 1 { break }
            }
        }

        let task2 = Task { @MainActor in
            let stream = await connection2.dataStream
            for await data in stream {
                received2.append(data)
                if received2.count >= 1 { break }
            }
        }

        // Send XML from server
        let testXML = "<prompt>&gt;</prompt>"
        await server.sendXML(testXML)

        // Wait for data
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3s

        task1.cancel()
        task2.cancel()

        // Both clients should receive data
        #expect(!received1.isEmpty)
        #expect(!received2.isEmpty)

        // Clean up
        await connection1.disconnect()
        await connection2.disconnect()
        await server.stop()
    }

    /// Test sending XML when server not running
    @Test func test_sendingXMLWhenNotRunning() async throws {
        let server = MockLichServer()

        // Send should be safe (no-op) when not running
        await server.sendXML("<prompt>&gt;</prompt>")

        // Should not crash
        #expect(Bool(true))
    }

    // MARK: - Scenario Tests

    /// Test initial connection scenario contains expected tags
    @Test func test_initialConnectionScenario() async throws {
        let xml = MockLichServer.Scenario.initialConnection.xml

        // Verify key elements present
        #expect(xml.contains("<mode id=\"GAME\"/>"))
        #expect(xml.contains("<settingsInfo"))
        #expect(xml.contains("<streamWindow"))
        #expect(xml.contains("<component"))
        #expect(xml.contains("<prompt"))
    }

    /// Test room description scenario
    @Test func test_roomDescriptionScenario() async throws {
        let xml = MockLichServer.Scenario.roomDescription.xml

        #expect(xml.contains("<pushStream id=\"room\"/>"))
        #expect(xml.contains("<popStream/>"))
        #expect(xml.contains("[Wehnimer's Landing"))
        #expect(xml.contains("<compass>"))
        #expect(xml.contains("<nav/>"))
    }

    /// Test combat sequence scenario
    @Test func test_combatSequenceScenario() async throws {
        let xml = MockLichServer.Scenario.combatSequence.xml

        #expect(xml.contains("<pushStream id=\"combat\"/>"))
        #expect(xml.contains("You swing"))
        #expect(xml.contains("<progressBar id=\"health\""))
        #expect(xml.contains("<progressBar id=\"stamina\""))
    }

    /// Test stream sequence scenario
    @Test func test_streamSequenceScenario() async throws {
        let xml = MockLichServer.Scenario.streamSequence.xml

        #expect(xml.contains("<pushStream id=\"thoughts\"/>"))
        #expect(xml.contains("<pushStream id=\"speech\"/>"))
        #expect(xml.contains("You think to yourself"))
    }

    /// Test item loot scenario
    @Test func test_itemLootScenario() async throws {
        let xml = MockLichServer.Scenario.itemLoot.xml

        #expect(xml.contains("<a exist=\""))
        #expect(xml.contains("noun=\"gem\""))
        #expect(xml.contains("noun=\"coin\""))
        #expect(xml.contains("noun=\"box\""))
    }

    /// Test hands update scenario
    @Test func test_handsUpdateScenario() async throws {
        let xml = MockLichServer.Scenario.handsUpdate.xml

        #expect(xml.contains("<left exist=\""))
        #expect(xml.contains("<right exist=\""))
        #expect(xml.contains("noun=\"shield\""))
        #expect(xml.contains("noun=\"sword\""))
    }

    /// Test vitals update scenario
    @Test func test_vitalsUpdateScenario() async throws {
        let xml = MockLichServer.Scenario.vitalsUpdate.xml

        #expect(xml.contains("<progressBar id=\"health\""))
        #expect(xml.contains("<progressBar id=\"mana\""))
        #expect(xml.contains("<progressBar id=\"stamina\""))
        #expect(xml.contains("<progressBar id=\"spirit\""))
        #expect(xml.contains("<progressBar id=\"concentration\""))
        #expect(xml.contains("<progressBar id=\"encumbrance\""))
    }

    /// Test prompt sequence scenario
    @Test func test_promptSequenceScenario() async throws {
        let xml = MockLichServer.Scenario.promptSequence.xml

        // Count prompts
        let promptCount = xml.components(separatedBy: "<prompt").count - 1
        #expect(promptCount == 3)
    }

    /// Test complex nested scenario
    @Test func test_complexNestedScenario() async throws {
        let xml = MockLichServer.Scenario.complexNested.xml

        #expect(xml.contains("<pushBold/>"))
        #expect(xml.contains("<popBold/>"))
        #expect(xml.contains("<preset id=\"whisper\">"))
        #expect(xml.contains("<d cmd=\""))
        #expect(xml.contains("<a exist=\""))
    }

    /// Test server can send scenario
    @Test func test_serverCanSendScenario() async throws {
        let server = MockLichServer()
        try await server.start()

        let port = await server.port
        let connection = LichConnection()

        try await connection.connect(host: "127.0.0.1", port: port)

        var receivedData: [Data] = []
        let streamTask = Task { @MainActor in
            let stream = await connection.dataStream
            for await data in stream {
                receivedData.append(data)
                if receivedData.count >= 1 { break }
            }
        }

        // Send scenario
        await server.sendScenario(.roomDescription)

        // Wait for data
        try await Task.sleep(nanoseconds: 200_000_000)

        streamTask.cancel()

        // Verify scenario received
        #expect(!receivedData.isEmpty)

        if let firstChunk = receivedData.first,
           let receivedString = String(data: firstChunk, encoding: .utf8) {
            #expect(receivedString.contains("<pushStream id=\"room\"/>"))
        }

        // Clean up
        await connection.disconnect()
        await server.stop()
    }

    // MARK: - Performance Tests

    /// Test server can handle rapid XML sends
    @Test func test_rapidXMLSends() async throws {
        let server = MockLichServer()
        try await server.start()

        let start = Date()

        // Send 100 XML chunks rapidly
        for _ in 0..<100 {
            await server.sendXML("<prompt>&gt;</prompt>")
        }

        let duration = Date().timeIntervalSince(start)

        // Should complete quickly (< 1 second for 100 sends)
        #expect(duration < 1.0)

        await server.stop()
    }

    /// Test server starts quickly
    @Test func test_serverStartsQuickly() async throws {
        let server = MockLichServer()

        let start = Date()
        try await server.start()
        let duration = Date().timeIntervalSince(start)

        // Should start in < 1 second
        #expect(duration < 1.0)

        await server.stop()
    }
}
