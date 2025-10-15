// ABOUTME: Tests for StreamRouter actor - stream content routing with mirror mode support

import Foundation
import Testing
@testable import VaalinCore

/// Comprehensive test suite for StreamRouter actor.
///
/// Tests verify:
/// - Routing stream tags to appropriate StreamBufferManager buffers
/// - Mirror mode ON: stream content appears in BOTH main log and stream buffer
/// - Mirror mode OFF: stream content ONLY in stream buffer
/// - Multiple concurrent streams route independently
/// - Non-stream tags pass through unchanged
/// - Empty tag arrays handled gracefully
@Suite("StreamRouter Tests")
struct StreamRouterTests {
    // MARK: - Basic Routing

    /// Test routing stream tags to appropriate stream buffers.
    ///
    /// Verifies that GameTags with name "stream" and attrs.id="X" are routed
    /// to the correct stream buffer via StreamBufferManager.
    @Test func test_routeToStreamBuffer() async throws {
        let bufferManager = StreamBufferManager()
        let router = StreamRouter(bufferManager: bufferManager)

        // Create a stream tag with child content
        let textTag = GameTag(
            name: ":text",
            text: "You think about magic.",
            state: .closed,
            streamId: "thoughts"
        )
        let streamTag = GameTag(
            name: "stream",
            attrs: ["id": "thoughts"],
            children: [textTag],
            state: .closed,
            streamId: "thoughts"
        )

        // Route with mirror mode OFF (stream only)
        let mainLogTags = await router.route([streamTag], mirrorMode: false)

        // Verify stream content is in buffer
        let bufferMessages = await bufferManager.messages(forStream: "thoughts")
        #expect(bufferMessages.count == 1)
        #expect(bufferMessages[0].streamID == "thoughts")

        // Verify main log is empty (mirror mode OFF)
        #expect(mainLogTags.isEmpty)
    }

    /// Test mirror mode ON: stream content appears in both main log and stream buffer.
    ///
    /// Verifies that when mirrorMode is true, stream tags are:
    /// 1. Routed to stream buffer
    /// 2. Also returned in main log tags for display
    @Test func test_mirrorModeOn() async throws {
        let bufferManager = StreamBufferManager()
        let router = StreamRouter(bufferManager: bufferManager)

        let textTag = GameTag(
            name: ":text",
            text: "You say, \"Hello!\"",
            state: .closed,
            streamId: "speech"
        )
        let streamTag = GameTag(
            name: "stream",
            attrs: ["id": "speech"],
            children: [textTag],
            state: .closed,
            streamId: "speech"
        )

        // Route with mirror mode ON
        let mainLogTags = await router.route([streamTag], mirrorMode: true)

        // Verify stream content is in buffer
        let bufferMessages = await bufferManager.messages(forStream: "speech")
        #expect(bufferMessages.count == 1)
        #expect(bufferMessages[0].streamID == "speech")

        // Verify main log contains the CHILDREN of stream tag (unwrapped)
        // Main log gets the content without the stream wrapper
        #expect(mainLogTags.count == 1)
        #expect(mainLogTags[0].name == ":text")
        #expect(mainLogTags[0].text == "You say, \"Hello!\"")
    }

    /// Test mirror mode OFF: stream content only in stream buffer, not main log.
    ///
    /// Verifies that when mirrorMode is false, stream tags are routed to
    /// buffer only and do NOT appear in main log.
    @Test func test_mirrorModeOff() async throws {
        let bufferManager = StreamBufferManager()
        let router = StreamRouter(bufferManager: bufferManager)

        let textTag = GameTag(
            name: ":text",
            text: "Private thought",
            state: .closed,
            streamId: "thoughts"
        )
        let streamTag = GameTag(
            name: "stream",
            attrs: ["id": "thoughts"],
            children: [textTag],
            state: .closed,
            streamId: "thoughts"
        )

        // Route with mirror mode OFF
        let mainLogTags = await router.route([streamTag], mirrorMode: false)

        // Verify stream content is in buffer
        let bufferMessages = await bufferManager.messages(forStream: "thoughts")
        #expect(bufferMessages.count == 1)

        // Verify main log is empty
        #expect(mainLogTags.isEmpty)
    }

    // MARK: - Multiple Streams

    /// Test multiple concurrent streams route independently.
    ///
    /// Verifies that when multiple stream tags are present in the same parse,
    /// each is routed to its correct buffer without interference.
    @Test func test_multipleStreams() async throws {
        let bufferManager = StreamBufferManager()
        let router = StreamRouter(bufferManager: bufferManager)

        // Create tags for different streams
        let thoughtTag = GameTag(
            name: "stream",
            attrs: ["id": "thoughts"],
            children: [
                GameTag(name: ":text", text: "You think.", state: .closed, streamId: "thoughts")
            ],
            state: .closed,
            streamId: "thoughts"
        )
        let speechTag = GameTag(
            name: "stream",
            attrs: ["id": "speech"],
            children: [
                GameTag(name: ":text", text: "You speak.", state: .closed, streamId: "speech")
            ],
            state: .closed,
            streamId: "speech"
        )

        // Route both streams with mirror mode OFF
        let mainLogTags = await router.route([thoughtTag, speechTag], mirrorMode: false)

        // Verify thoughts buffer has only thought content
        let thoughtMessages = await bufferManager.messages(forStream: "thoughts")
        #expect(thoughtMessages.count == 1)
        #expect(thoughtMessages[0].streamID == "thoughts")

        // Verify speech buffer has only speech content
        let speechMessages = await bufferManager.messages(forStream: "speech")
        #expect(speechMessages.count == 1)
        #expect(speechMessages[0].streamID == "speech")

        // Verify main log is empty (mirror mode OFF)
        #expect(mainLogTags.isEmpty)
    }

    // MARK: - Non-Stream Tags

    /// Test non-stream tags pass through to main log unchanged.
    ///
    /// Verifies that tags without name="stream" are not affected by routing
    /// and pass through directly to main log regardless of mirror mode.
    @Test func test_nonStreamTagsPassThrough() async throws {
        let bufferManager = StreamBufferManager()
        let router = StreamRouter(bufferManager: bufferManager)

        // Create regular (non-stream) tags
        let promptTag = GameTag(
            name: "prompt",
            text: ">",
            state: .closed
        )
        let outputTag = GameTag(
            name: "output",
            text: "Welcome to GemStone IV!",
            state: .closed
        )

        // Route with mirror mode ON (shouldn't affect non-stream tags)
        let mainLogTags = await router.route([promptTag, outputTag], mirrorMode: true)

        // Verify all tags pass through to main log
        #expect(mainLogTags.count == 2)
        #expect(mainLogTags[0].name == "prompt")
        #expect(mainLogTags[1].name == "output")

        // Verify no stream buffers were touched
        let thoughtMessages = await bufferManager.messages(forStream: "thoughts")
        #expect(thoughtMessages.isEmpty)
    }

    // MARK: - Mixed Content

    /// Test mixed stream and non-stream tags route correctly.
    ///
    /// Verifies that when a parse contains both stream tags and regular tags,
    /// each is handled appropriately (streams to buffers, regular to main log).
    @Test func test_mixedStreamAndNonStreamTags() async throws {
        let bufferManager = StreamBufferManager()
        let router = StreamRouter(bufferManager: bufferManager)

        // Create mixed tags
        let promptTag = GameTag(name: "prompt", text: ">", state: .closed)
        let streamTag = GameTag(
            name: "stream",
            attrs: ["id": "thoughts"],
            children: [
                GameTag(name: ":text", text: "You think.", state: .closed, streamId: "thoughts")
            ],
            state: .closed,
            streamId: "thoughts"
        )
        let outputTag = GameTag(name: "output", text: "Regular output", state: .closed)

        // Route with mirror mode ON
        let mainLogTags = await router.route([promptTag, streamTag, outputTag], mirrorMode: true)

        // Verify stream content is in buffer
        let thoughtMessages = await bufferManager.messages(forStream: "thoughts")
        #expect(thoughtMessages.count == 1)

        // Verify main log has non-stream tags + mirrored stream content
        // Expected: promptTag, streamTag's children (unwrapped), outputTag
        #expect(mainLogTags.count == 3)
        #expect(mainLogTags[0].name == "prompt")
        #expect(mainLogTags[1].name == ":text") // Unwrapped stream content
        #expect(mainLogTags[2].name == "output")
    }

    // MARK: - Edge Cases

    /// Test empty tag array handled gracefully.
    ///
    /// Verifies that routing an empty array returns empty result and doesn't crash.
    @Test func test_emptyTagArray() async throws {
        let bufferManager = StreamBufferManager()
        let router = StreamRouter(bufferManager: bufferManager)

        let mainLogTags = await router.route([], mirrorMode: true)

        #expect(mainLogTags.isEmpty)
    }

    /// Test stream tag without id attribute handled gracefully.
    ///
    /// Verifies that malformed stream tags (missing id) are logged and skipped
    /// but don't crash the routing process.
    @Test func test_streamTagWithoutId() async throws {
        let bufferManager = StreamBufferManager()
        let router = StreamRouter(bufferManager: bufferManager)

        // Create stream tag without id attribute (malformed)
        let streamTag = GameTag(
            name: "stream",
            attrs: [:], // Missing id!
            children: [
                GameTag(name: ":text", text: "Orphaned content", state: .closed)
            ],
            state: .closed
        )

        // Route with mirror mode ON
        let mainLogTags = await router.route([streamTag], mirrorMode: true)

        // Malformed stream tag should be skipped (not routed to any buffer)
        // But in mirror mode, content might still appear in main log
        // For now, we'll skip malformed tags entirely
        #expect(mainLogTags.isEmpty)
    }

    /// Test nested stream tags handled correctly.
    ///
    /// Verifies that stream tags with complex nested children (bold tags,
    /// links, etc.) are routed with their full structure intact.
    @Test func test_nestedStreamContent() async throws {
        let bufferManager = StreamBufferManager()
        let router = StreamRouter(bufferManager: bufferManager)

        // Create stream tag with nested structure
        let boldTag = GameTag(
            name: "b",
            children: [
                GameTag(name: ":text", text: "important", state: .closed, streamId: "speech")
            ],
            state: .closed,
            streamId: "speech"
        )
        let streamTag = GameTag(
            name: "stream",
            attrs: ["id": "speech"],
            children: [
                GameTag(name: ":text", text: "This is ", state: .closed, streamId: "speech"),
                boldTag,
                GameTag(name: ":text", text: "!", state: .closed, streamId: "speech")
            ],
            state: .closed,
            streamId: "speech"
        )

        // Route with mirror mode ON
        let mainLogTags = await router.route([streamTag], mirrorMode: true)

        // Verify stream content is in buffer with full structure
        let speechMessages = await bufferManager.messages(forStream: "speech")
        #expect(speechMessages.count == 1)

        // Verify main log contains unwrapped children with structure preserved
        #expect(mainLogTags.count == 3) // :text, b, :text
        #expect(mainLogTags[1].name == "b")
        #expect(mainLogTags[1].children.count == 1)
    }

    // MARK: - Performance

    /// Test performance with large number of stream tags.
    ///
    /// Verifies that routing can handle high-throughput scenarios
    /// (matching parser's > 10k lines/min target).
    @Test func test_performanceWithManyTags() async throws {
        let bufferManager = StreamBufferManager()
        let router = StreamRouter(bufferManager: bufferManager)

        // Create 1000 stream tags (simulating high-volume output)
        var tags: [GameTag] = []
        for i in 0..<1000 {
            let streamTag = GameTag(
                name: "stream",
                attrs: ["id": "thoughts"],
                children: [
                    GameTag(name: ":text", text: "Thought \(i)", state: .closed, streamId: "thoughts")
                ],
                state: .closed,
                streamId: "thoughts"
            )
            tags.append(streamTag)
        }

        let start = Date()
        let mainLogTags = await router.route(tags, mirrorMode: true)
        let duration = Date().timeIntervalSince(start)

        // Should complete in < 1 second for 1000 tags
        #expect(duration < 1.0)

        // Verify all tags were routed
        let thoughtMessages = await bufferManager.messages(forStream: "thoughts")
        #expect(thoughtMessages.count == 1000)

        // With mirror mode, all content should be in main log too
        #expect(mainLogTags.count == 1000)
    }
}
