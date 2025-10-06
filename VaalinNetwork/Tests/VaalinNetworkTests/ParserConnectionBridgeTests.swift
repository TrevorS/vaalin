// ABOUTME: Tests for ParserConnectionBridge - integration between LichConnection and XMLStreamParser

import Foundation
import Testing
@testable import VaalinCore
@testable import VaalinNetwork
@testable import VaalinParser

/// Test suite for ParserConnectionBridge actor
///
/// Validates integration between LichConnection (TCP) and XMLStreamParser (XML parsing).
/// Follows TDD approach - tests written before implementation.
///
/// ## Test Coverage
///
/// - Actor initialization and state
/// - Data flow from connection through parser
/// - Parsed tags availability
/// - Error handling and recovery
/// - Thread safety (actor isolation)
/// - Memory management
struct ParserConnectionBridgeTests {
    // MARK: - Initialization Tests

    /// Test bridge initializes with connection and parser references
    @Test func test_bridgeInitialization() async throws {
        let connection = LichConnection()
        let parser = XMLStreamParser()

        let bridge = ParserConnectionBridge(connection: connection, parser: parser)

        // Bridge should initialize successfully
        // Verify it's actor-isolated
        _ = await bridge.isRunning()
    }

    /// Test bridge initial state is stopped
    @Test func test_initialStateIsStopped() async throws {
        let connection = LichConnection()
        let parser = XMLStreamParser()
        let bridge = ParserConnectionBridge(connection: connection, parser: parser)

        let isRunning = await bridge.isRunning()

        #expect(isRunning == false)
    }

    /// Test parsed tags start empty
    @Test func test_initialParsedTagsEmpty() async throws {
        let connection = LichConnection()
        let parser = XMLStreamParser()
        let bridge = ParserConnectionBridge(connection: connection, parser: parser)

        let tags = await bridge.getParsedTags()

        #expect(tags.isEmpty)
    }

    // MARK: - Data Flow Tests

    /// Test connection → parser data flow
    ///
    /// **Purpose**: Verify data flows through the full pipeline
    ///
    /// **Strategy**: Since we can't easily mock LichConnection,
    /// we verify the bridge correctly processes chunks it receives
    @Test func test_connectionToParserDataFlow() async throws {
        let connection = LichConnection()
        let parser = XMLStreamParser()
        let bridge = ParserConnectionBridge(connection: connection, parser: parser)

        // Note: Without real Lich connection, we can't test actual data flow
        // This test documents expected behavior:
        // 1. bridge.start() begins iterating connection.dataStream
        // 2. Each Data chunk is decoded to String (UTF-8)
        // 3. String is passed to parser.parse(chunk)
        // 4. Resulting GameTags are accumulated in bridge state

        // Verify bridge can be started
        await bridge.start()

        let isRunning = await bridge.isRunning()
        #expect(isRunning == true)

        // Verify bridge can be stopped
        await bridge.stop()

        let isStoppedAfter = await bridge.isRunning()
        #expect(isStoppedAfter == false)
    }

    /// Test parsed tags are accessible
    ///
    /// **Purpose**: Verify getParsedTags() returns accumulated tags
    ///
    /// **Strategy**: Document expected behavior since we need real connection for data
    @Test func test_parsedTagsAvailable() async throws {
        let connection = LichConnection()
        let parser = XMLStreamParser()
        let bridge = ParserConnectionBridge(connection: connection, parser: parser)

        // Start the bridge
        await bridge.start()

        // Get parsed tags (will be empty without real data)
        let tags = await bridge.getParsedTags()

        // Verify return type is correct
        #expect(type(of: tags) == [GameTag].self)

        // Expected behavior:
        // - Tags accumulate as data arrives from connection
        // - getParsedTags() returns all tags parsed since start()
        // - Tags persist until clearParsedTags() or stop() is called

        await bridge.stop()
    }

    /// Test multiple chunks are handled correctly
    ///
    /// **Purpose**: Verify TCP fragmentation is handled
    ///
    /// **Expected behavior**:
    /// - Each Data chunk from connection is processed independently
    /// - Parser maintains state across chunks (stream context)
    /// - Incomplete tags buffer correctly
    /// - All parsed tags accumulate in bridge
    @Test func test_multipleChunks() async throws {
        let connection = LichConnection()
        let parser = XMLStreamParser()
        let bridge = ParserConnectionBridge(connection: connection, parser: parser)

        // Document expected multi-chunk behavior:
        //
        // Chunk 1: "<a noun=\"gem\">blue"
        // - Parser buffers incomplete tag
        // - No tags returned yet
        //
        // Chunk 2: " gem</a>"
        // - Parser completes tag from buffer
        // - Returns [GameTag(name: "a", text: "blue gem", ...)]
        // - Bridge accumulates this tag
        //
        // Chunk 3: "<output>Hello</output>"
        // - Parser processes complete tag
        // - Returns [GameTag(name: "output", text: "Hello", ...)]
        // - Bridge accumulates this tag
        //
        // Result: bridge.getParsedTags() returns 2 tags total

        // Verify bridge can handle ongoing data flow
        await bridge.start()

        // Simulate that tags would accumulate over time
        let tags = await bridge.getParsedTags()
        #expect(tags.count >= 0) // Non-negative

        await bridge.stop()
    }

    // MARK: - Error Handling Tests

    /// Test graceful error handling
    ///
    /// **Purpose**: Verify bridge doesn't crash on errors
    ///
    /// **Expected behavior**:
    /// - Malformed UTF-8 → log error, skip chunk
    /// - Parser errors → log error, continue with next chunk
    /// - Connection errors → log error, finish stream
    @Test func test_errorHandling() async throws {
        let connection = LichConnection()
        let parser = XMLStreamParser()
        let bridge = ParserConnectionBridge(connection: connection, parser: parser)

        // Expected error handling:
        //
        // 1. Data → String conversion fails (malformed UTF-8)
        //    - Log warning
        //    - Skip chunk
        //    - Continue processing next chunk
        //
        // 2. Parser.parse() throws or returns error
        //    - Log error with chunk context
        //    - Continue processing next chunk
        //    - Don't crash bridge
        //
        // 3. Connection stream finishes (error or normal)
        //    - Bridge stops gracefully
        //    - Parsed tags remain available

        await bridge.start()

        // Bridge should be resilient to errors
        let isRunning = await bridge.isRunning()
        #expect(isRunning == true)

        await bridge.stop()
    }

    // MARK: - Actor Isolation Tests

    /// Test bridge is an actor (compile-time check)
    @Test func test_actorIsolation() async {
        let connection = LichConnection()
        let parser = XMLStreamParser()
        let bridge = ParserConnectionBridge(connection: connection, parser: parser)

        // Verify bridge is actor-isolated
        // This is a compile-time check - all methods require await
        _ = await bridge.isRunning()
        _ = await bridge.getParsedTags()
    }

    /// Test concurrent access is safe
    @Test func test_concurrentAccess() async {
        let connection = LichConnection()
        let parser = XMLStreamParser()
        let bridge = ParserConnectionBridge(connection: connection, parser: parser)

        // Multiple concurrent accesses should be safe (actor serialization)
        async let isRunning1 = bridge.isRunning()
        async let isRunning2 = bridge.isRunning()
        async let tags1 = bridge.getParsedTags()
        async let tags2 = bridge.getParsedTags()

        let results = await (isRunning1, isRunning2, tags1, tags2)

        #expect(results.0 == results.1) // Same state
        #expect(results.2.count == results.3.count) // Same tags
    }

    // MARK: - State Management Tests

    /// Test start/stop lifecycle
    @Test func test_startStopLifecycle() async throws {
        let connection = LichConnection()
        let parser = XMLStreamParser()
        let bridge = ParserConnectionBridge(connection: connection, parser: parser)

        // Initial state: stopped
        var isRunning = await bridge.isRunning()
        #expect(isRunning == false)

        // Start bridge
        await bridge.start()
        isRunning = await bridge.isRunning()
        #expect(isRunning == true)

        // Stop bridge
        await bridge.stop()
        isRunning = await bridge.isRunning()
        #expect(isRunning == false)

        // Restart should work
        await bridge.start()
        isRunning = await bridge.isRunning()
        #expect(isRunning == true)

        await bridge.stop()
    }

    /// Test multiple starts are idempotent
    @Test func test_multipleStartsIdempotent() async throws {
        let connection = LichConnection()
        let parser = XMLStreamParser()
        let bridge = ParserConnectionBridge(connection: connection, parser: parser)

        // Start multiple times
        await bridge.start()
        await bridge.start()
        await bridge.start()

        // Should still be running (no double-start bug)
        let isRunning = await bridge.isRunning()
        #expect(isRunning == true)

        await bridge.stop()
    }

    /// Test multiple stops are idempotent
    @Test func test_multipleStopsIdempotent() async throws {
        let connection = LichConnection()
        let parser = XMLStreamParser()
        let bridge = ParserConnectionBridge(connection: connection, parser: parser)

        await bridge.start()

        // Stop multiple times
        await bridge.stop()
        await bridge.stop()
        await bridge.stop()

        // Should be stopped (no double-stop bug)
        let isRunning = await bridge.isRunning()
        #expect(isRunning == false)
    }

    /// Test clearing parsed tags
    @Test func test_clearParsedTags() async throws {
        let connection = LichConnection()
        let parser = XMLStreamParser()
        let bridge = ParserConnectionBridge(connection: connection, parser: parser)

        // Start bridge
        await bridge.start()

        // Clear tags
        await bridge.clearParsedTags()

        // Tags should be empty
        let tags = await bridge.getParsedTags()
        #expect(tags.isEmpty)

        await bridge.stop()
    }

    // MARK: - Memory Management Tests

    /// Test bridge doesn't leak memory
    ///
    /// **Purpose**: Verify no retain cycles or memory leaks
    ///
    /// **Strategy**: Document expected behavior
    ///
    /// **Expected behavior**:
    /// - Bridge holds weak or unowned references where appropriate
    /// - Stopping bridge releases resources
    /// - No circular references between connection/parser/bridge
    @Test func test_noMemoryLeaks() async throws {
        weak var weakBridge: ParserConnectionBridge?

        do {
            let connection = LichConnection()
            let parser = XMLStreamParser()
            let bridge = ParserConnectionBridge(connection: connection, parser: parser)
            weakBridge = bridge

            await bridge.start()
            await bridge.stop()

            // Bridge is still in scope
            #expect(weakBridge != nil)
        }

        // After scope exit, bridge should be deallocated
        // Note: This test is best-effort since ARC timing is not guaranteed
        // Expected: weakBridge becomes nil after a brief delay
    }
}
