// ABOUTME: StreamRouter actor provides thread-safe routing of stream content to buffers with mirror mode support

import Foundation
import OSLog

/// Thread-safe stream router for directing stream content to appropriate buffers.
///
/// StreamRouter takes parsed GameTag arrays from XMLStreamParser and routes stream-tagged
/// content to the correct StreamBufferManager buffers. It implements mirror mode logic:
/// when enabled, stream content appears in BOTH the stream buffer AND the main game log.
///
/// ## Architecture
///
/// The parser creates synthetic `stream` wrapper tags for content between `<pushStream>` and
/// `<popStream>` tags. StreamRouter:
/// 1. Identifies stream tags by name="stream" and attrs.id
/// 2. Converts stream tags to Message objects
/// 3. Routes messages to StreamBufferManager.append(_, toStream: streamId)
/// 4. Optionally returns stream content for main log (mirror mode)
///
/// ## Mirror Mode
///
/// - **ON** (default): Stream content appears in BOTH stream buffer and main log
/// - **OFF**: Stream content ONLY in stream buffer (filtered from main log)
///
/// ## Usage
///
/// ```swift
/// let router = StreamRouter(bufferManager: streamBufferManager)
///
/// // Route parsed tags
/// let mainLogTags = await router.route(parsedTags, mirrorMode: settings.mirrorFilteredToMain)
///
/// // mainLogTags contains:
/// // - All non-stream tags (unchanged)
/// // - Stream tag children (unwrapped) if mirror mode ON
/// ```
///
/// ## Performance
///
/// - **Throughput**: Handles > 10,000 tags/minute (matches parser target)
/// - **Memory**: O(1) per tag (no accumulation)
/// - **Latency**: < 1ms average per route() call
public actor StreamRouter {
    // MARK: - Dependencies

    /// Stream buffer manager for routing messages to stream-specific buffers
    private let bufferManager: StreamBufferManager

    /// Logger for debugging and error reporting
    private let logger = Logger(subsystem: "com.vaalin.core", category: "StreamRouter")

    // MARK: - Initialization

    /// Creates a new stream router with the specified buffer manager.
    ///
    /// - Parameter bufferManager: StreamBufferManager for routing stream messages
    public init(bufferManager: StreamBufferManager) {
        self.bufferManager = bufferManager
    }

    // MARK: - Public API

    /// Routes parsed tags to appropriate destinations based on stream content.
    ///
    /// This method processes an array of GameTags and:
    /// 1. Identifies stream tags (name="stream", has attrs.id)
    /// 2. Routes stream content to StreamBufferManager
    /// 3. Returns tags for main log based on mirror mode
    ///
    /// ## Routing Rules
    ///
    /// **Non-stream tags**: Pass through unchanged to main log
    ///
    /// **Stream tags**:
    /// - Always routed to stream buffer
    /// - If mirror mode ON: children unwrapped and returned for main log
    /// - If mirror mode OFF: filtered from main log
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Parse result contains stream and non-stream tags
    /// let tags = [
    ///     GameTag(name: "prompt", text: ">", ...),
    ///     GameTag(name: "stream", attrs: ["id": "thoughts"], children: [...], ...),
    ///     GameTag(name: "output", text: "Regular output", ...)
    /// ]
    ///
    /// // Route with mirror mode ON
    /// let mainLogTags = await router.route(tags, mirrorMode: true)
    /// // mainLogTags = [prompt, ...stream children..., output]
    ///
    /// // Route with mirror mode OFF
    /// let mainLogTags = await router.route(tags, mirrorMode: false)
    /// // mainLogTags = [prompt, output] (stream filtered)
    /// ```
    ///
    /// - Parameters:
    ///   - tags: Array of GameTags from parser
    ///   - mirrorMode: Whether to mirror stream content to main log
    /// - Returns: Array of tags for main game log display
    public func route(_ tags: [GameTag], mirrorMode: Bool) async -> [GameTag] {
        var mainLogTags: [GameTag] = []

        for tag in tags {
            // Check if this is a stream tag
            if tag.name == "stream" {
                // Verify stream tag has valid id attribute
                guard tag.attrs["id"] != nil else {
                    logger.warning("Stream tag missing 'id' attribute, skipping entirely")
                    continue // Skip malformed stream tags completely
                }

                // Route stream content to buffer
                await routeStreamTag(tag)

                // If mirror mode ON, unwrap stream children for main log
                if mirrorMode {
                    mainLogTags.append(contentsOf: tag.children)
                }
                // If mirror mode OFF, stream content is filtered from main log
            } else {
                // Non-stream tag: pass through to main log
                mainLogTags.append(tag)
            }
        }

        return mainLogTags
    }

    // MARK: - Private Helpers

    /// Routes a stream tag's content to the appropriate stream buffer.
    ///
    /// Extracts stream ID from tag attributes, converts to Message, and appends
    /// to StreamBufferManager. Logs warning if stream ID is missing.
    ///
    /// - Parameter tag: Stream tag with name="stream" and children
    private func routeStreamTag(_ tag: GameTag) async {
        // Extract stream ID from attributes
        guard let streamId = tag.attrs["id"] else {
            logger.warning("Stream tag missing 'id' attribute, skipping routing")
            return
        }

        // Convert stream tag to Message for buffer storage
        // Use Message(from:streamID:) convenience initializer
        let message = Message(
            from: tag.children, // Store children, not the wrapper
            streamID: streamId,
            timestamp: Date()
        )

        // Route to appropriate stream buffer
        await bufferManager.append(message, toStream: streamId)

        logger.debug("Routed stream content to buffer: \(streamId, privacy: .public)")
    }
}
