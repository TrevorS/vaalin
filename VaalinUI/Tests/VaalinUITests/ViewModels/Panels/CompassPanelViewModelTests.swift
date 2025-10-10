// ABOUTME: Comprehensive tests for CompassPanelViewModel EventBus integration and room data parsing

import Testing
import Foundation
@testable import VaalinUI
@testable import VaalinCore

/// Test suite for CompassPanelViewModel compass panel state functionality
/// Validates EventBus subscription and room navigation updates per Issue #40 acceptance criteria
@MainActor
struct CompassPanelViewModelTests {

    // MARK: - Initialization Tests

    /// Test that CompassPanelViewModel initializes with default values
    ///
    /// Acceptance Criteria:
    /// - roomName defaults to ""
    /// - roomId defaults to 0
    /// - exits defaults to empty Set
    @Test func test_defaults() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Verify defaults
        #expect(viewModel.roomName == "")
        #expect(viewModel.roomId == 0)
        #expect(viewModel.exits.isEmpty)
    }

    /// Test that CompassPanelViewModel initializes correctly
    ///
    /// Acceptance Criteria:
    /// - Initializes with EventBus reference
    @Test func test_initialization() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Verify defaults match acceptance criteria
        #expect(viewModel.roomName == "")
        #expect(viewModel.roomId == 0)
        #expect(viewModel.exits.isEmpty)
    }

    // MARK: - EventBus Subscription Tests

    /// Test that CompassPanelViewModel subscribes to all navigation events
    ///
    /// Acceptance Criteria:
    /// - Subscribes to "metadata/nav" event on initialization
    /// - Subscribes to "metadata/compass" event on initialization
    /// - Subscribes to "metadata/streamWindow/room" event on initialization
    @Test func test_subscribesToNavigationEvents() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Verify all subscriptions exist
        let navHandlerCount = await eventBus.handlerCount(for: "metadata/nav")
        let compassHandlerCount = await eventBus.handlerCount(for: "metadata/compass")
        let roomHandlerCount = await eventBus.handlerCount(for: "metadata/streamWindow/room")

        #expect(navHandlerCount == 1)
        #expect(compassHandlerCount == 1)
        #expect(roomHandlerCount == 1)
    }

    // MARK: - Room ID Update Tests

    /// Test that CompassPanelViewModel updates roomId when receiving metadata/nav events
    ///
    /// Acceptance Criteria:
    /// - Updates roomId when "metadata/nav" event is published
    /// - Extracts room ID from tag.attrs["rm"]
    @Test func test_roomIdUpdate() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Initially has default value
        #expect(viewModel.roomId == 0)

        // Publish a nav event with room ID
        let navTag = GameTag(
            name: "nav",
            text: nil,
            attrs: ["rm": "228"],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/nav", data: navTag)

        // Give the event bus a moment to process (actor isolation)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify room ID updated
        #expect(viewModel.roomId == 228)
    }

    /// Test that roomId handles invalid room ID gracefully
    ///
    /// Acceptance Criteria:
    /// - Handles non-numeric room ID by keeping previous value
    @Test func test_roomIdInvalid() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Set a known value first
        let validTag = GameTag(
            name: "nav",
            text: nil,
            attrs: ["rm": "100"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/nav", data: validTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Now publish invalid room ID
        let invalidTag = GameTag(
            name: "nav",
            text: nil,
            attrs: ["rm": "invalid"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/nav", data: invalidTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify room ID unchanged (still 100)
        #expect(viewModel.roomId == 100)
    }

    /// Test that roomId handles missing attribute
    ///
    /// Acceptance Criteria:
    /// - Handles missing rm attribute by keeping previous value
    @Test func test_roomIdMissing() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Set a known value first
        let validTag = GameTag(
            name: "nav",
            text: nil,
            attrs: ["rm": "100"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/nav", data: validTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Now publish nav event without rm attribute
        let missingTag = GameTag(
            name: "nav",
            text: nil,
            attrs: [:],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/nav", data: missingTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify room ID unchanged (still 100)
        #expect(viewModel.roomId == 100)
    }

    // MARK: - Room Name Update Tests

    /// Test that CompassPanelViewModel updates roomName when receiving metadata/streamWindow/room events
    ///
    /// Acceptance Criteria:
    /// - Updates roomName when "metadata/streamWindow/room" event is published
    /// - Extracts room name from tag.attrs["subtitle"]
    /// - Parses format: " - [Room Name] - 228" → "[Room Name]"
    @Test func test_roomNameUpdate() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Initially has default value
        #expect(viewModel.roomName == "")

        // Publish a streamWindow event with room title
        let streamTag = GameTag(
            name: "streamWindow",
            text: nil,
            attrs: [
                "id": "main",
                "subtitle": " - [Town Square, Market] - 228"
            ],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/streamWindow/room", data: streamTag)

        // Give the event bus a moment to process (actor isolation)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify room name updated (leading " - " and trailing " - 228" removed)
        #expect(viewModel.roomName == "[Town Square, Market]")
    }

    /// Test roomName parsing with various subtitle formats
    ///
    /// Acceptance Criteria:
    /// - Handles " - [Room Name] - {id}" format correctly
    /// - Handles empty subtitle
    /// - Handles subtitle without room ID suffix
    @Test func test_roomNameVariousFormats() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Test format: " - [Moonstone Creek Bridge] - 5024"
        let bridgeTag = GameTag(
            name: "streamWindow",
            text: nil,
            attrs: ["subtitle": " - [Moonstone Creek Bridge] - 5024"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/streamWindow/room", data: bridgeTag)
        try? await Task.sleep(for: .milliseconds(10))
        #expect(viewModel.roomName == "[Moonstone Creek Bridge]")

        // Test format: " - [Temple Courtyard] - 1001"
        let templeTag = GameTag(
            name: "streamWindow",
            text: nil,
            attrs: ["subtitle": " - [Temple Courtyard] - 1001"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/streamWindow/room", data: templeTag)
        try? await Task.sleep(for: .milliseconds(10))
        #expect(viewModel.roomName == "[Temple Courtyard]")

        // Test empty subtitle
        let emptyTag = GameTag(
            name: "streamWindow",
            text: nil,
            attrs: ["subtitle": ""],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/streamWindow/room", data: emptyTag)
        try? await Task.sleep(for: .milliseconds(10))
        #expect(viewModel.roomName == "")

        // Test format without trailing room ID: " - [Room Name]"
        let noIdTag = GameTag(
            name: "streamWindow",
            text: nil,
            attrs: ["subtitle": " - [Room Name]"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/streamWindow/room", data: noIdTag)
        try? await Task.sleep(for: .milliseconds(10))
        #expect(viewModel.roomName == "[Room Name]")
    }

    /// Test roomName parsing with DragonRealms format
    ///
    /// Acceptance Criteria:
    /// - Handles DragonRealms format: "[Room Name] (1234)" → "[Room Name]"
    @Test func test_roomNameDragonRealmsFormat() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // DragonRealms format: "[Bosque Deriel, Hermit's Shacks] (230008)"
        let drTag = GameTag(
            name: "streamWindow",
            text: nil,
            attrs: ["subtitle": "[Bosque Deriel, Hermit's Shacks] (230008)"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/streamWindow/room", data: drTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Should remove trailing " (digits)"
        #expect(viewModel.roomName == "[Bosque Deriel, Hermit's Shacks]")
    }

    /// Test roomName handles malformed subtitle gracefully
    ///
    /// Acceptance Criteria:
    /// - Handles subtitle without brackets
    /// - Handles subtitle with unexpected format
    @Test func test_malformedSubtitle() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Test subtitle without brackets
        let noBracketsTag = GameTag(
            name: "streamWindow",
            text: nil,
            attrs: ["subtitle": " - Room Name - 123"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/streamWindow/room", data: noBracketsTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Should still remove leading " - " and trailing " - 123"
        #expect(viewModel.roomName == "Room Name")

        // Test completely unexpected format
        let weirdTag = GameTag(
            name: "streamWindow",
            text: nil,
            attrs: ["subtitle": "Totally Unexpected Format"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/streamWindow/room", data: weirdTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Should use as-is if no patterns match
        #expect(viewModel.roomName == "Totally Unexpected Format")
    }

    /// Test roomName handles missing subtitle attribute
    ///
    /// Acceptance Criteria:
    /// - Handles missing subtitle by keeping previous value
    @Test func test_roomNameMissingSubtitle() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Set a known value first
        let validTag = GameTag(
            name: "streamWindow",
            text: nil,
            attrs: ["subtitle": " - [Town Square] - 228"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/streamWindow/room", data: validTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Now publish event without subtitle
        let missingTag = GameTag(
            name: "streamWindow",
            text: nil,
            attrs: [:],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/streamWindow/room", data: missingTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify room name unchanged
        #expect(viewModel.roomName == "[Town Square]")
    }

    // MARK: - Exits Update Tests

    /// Test that CompassPanelViewModel updates exits when receiving metadata/compass events
    ///
    /// Acceptance Criteria:
    /// - Updates exits when "metadata/compass" event is published
    /// - Extracts directions from tag.children[].attrs["value"]
    /// - Stores as Set (order doesn't matter, no duplicates)
    @Test func test_exitsUpdate() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Initially has default value
        #expect(viewModel.exits.isEmpty)

        // Publish a compass event with multiple exits
        let dirTags = [
            GameTag(name: "dir", text: nil, attrs: ["value": "n"], children: [], state: .closed),
            GameTag(name: "dir", text: nil, attrs: ["value": "s"], children: [], state: .closed),
            GameTag(name: "dir", text: nil, attrs: ["value": "e"], children: [], state: .closed),
            GameTag(name: "dir", text: nil, attrs: ["value": "w"], children: [], state: .closed)
        ]
        let compassTag = GameTag(
            name: "compass",
            text: nil,
            attrs: [:],
            children: dirTags,
            state: .closed
        )

        await eventBus.publish("metadata/compass", data: compassTag)

        // Give the event bus a moment to process (actor isolation)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify exits updated (Set contains all directions)
        #expect(viewModel.exits == Set(["n", "s", "e", "w"]))
    }

    /// Test that exits Set handles duplicate directions
    ///
    /// Acceptance Criteria:
    /// - Set automatically deduplicates duplicate exits
    @Test func test_exitSet() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Publish a compass event with duplicate exits (malformed server data)
        let dirTags = [
            GameTag(name: "dir", text: nil, attrs: ["value": "n"], children: [], state: .closed),
            GameTag(name: "dir", text: nil, attrs: ["value": "n"], children: [], state: .closed), // Duplicate
            GameTag(name: "dir", text: nil, attrs: ["value": "s"], children: [], state: .closed),
            GameTag(name: "dir", text: nil, attrs: ["value": "s"], children: [], state: .closed)  // Duplicate
        ]
        let compassTag = GameTag(
            name: "compass",
            text: nil,
            attrs: [:],
            children: dirTags,
            state: .closed
        )

        await eventBus.publish("metadata/compass", data: compassTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify Set automatically deduplicated
        #expect(viewModel.exits == Set(["n", "s"]))
        #expect(viewModel.exits.count == 2)
    }

    /// Test that exits handles empty compass
    ///
    /// Acceptance Criteria:
    /// - Handles compass tag with no children (dead end)
    @Test func test_emptyCompass() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Set some exits first
        let dirTags = [
            GameTag(name: "dir", text: nil, attrs: ["value": "n"], children: [], state: .closed)
        ]
        let compassTag = GameTag(
            name: "compass",
            text: nil,
            attrs: [:],
            children: dirTags,
            state: .closed
        )
        await eventBus.publish("metadata/compass", data: compassTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Now publish empty compass (dead end or all exits hidden)
        let emptyCompassTag = GameTag(
            name: "compass",
            text: nil,
            attrs: [:],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/compass", data: emptyCompassTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify exits cleared
        #expect(viewModel.exits.isEmpty)
    }

    /// Test that exits can handle all 11 possible directions
    ///
    /// Acceptance Criteria:
    /// - Correctly parses all standard directions: n, e, s, w, ne, se, sw, nw, up, down, out
    @Test func test_multipleExits() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Test all 11 standard directions
        let allDirections = ["n", "ne", "e", "se", "s", "sw", "w", "nw", "up", "down", "out"]
        let dirTags = allDirections.map { dir in
            GameTag(name: "dir", text: nil, attrs: ["value": dir], children: [], state: .closed)
        }
        let compassTag = GameTag(
            name: "compass",
            text: nil,
            attrs: [:],
            children: dirTags,
            state: .closed
        )

        await eventBus.publish("metadata/compass", data: compassTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify all directions parsed
        #expect(viewModel.exits == Set(allDirections))
        #expect(viewModel.exits.count == 11)
    }

    /// Test that exits handles malformed dir tags gracefully
    ///
    /// Acceptance Criteria:
    /// - Ignores dir tags without value attribute
    /// - Ignores empty value attributes
    @Test func test_exitsMalformedDirTags() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Mix of valid and malformed dir tags
        let dirTags = [
            GameTag(name: "dir", text: nil, attrs: ["value": "n"], children: [], state: .closed),   // Valid
            GameTag(name: "dir", text: nil, attrs: [:], children: [], state: .closed),              // Missing value
            GameTag(name: "dir", text: nil, attrs: ["value": ""], children: [], state: .closed),    // Empty value
            GameTag(name: "dir", text: nil, attrs: ["value": "s"], children: [], state: .closed),   // Valid
            GameTag(name: "wrongTag", text: nil, attrs: ["value": "e"], children: [], state: .closed) // Wrong tag name (should still work)
        ]
        let compassTag = GameTag(
            name: "compass",
            text: nil,
            attrs: [:],
            children: dirTags,
            state: .closed
        )

        await eventBus.publish("metadata/compass", data: compassTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify only valid directions extracted
        // Note: Implementation should extract based on attrs["value"], not tag name
        #expect(viewModel.exits.contains("n"))
        #expect(viewModel.exits.contains("s"))
        // Empty string should be filtered out
        #expect(!viewModel.exits.contains(""))
    }

    // MARK: - Multiple Updates Tests

    /// Test that CompassPanelViewModel handles rapid successive room changes
    ///
    /// Acceptance Criteria:
    /// - Handles rapid room ID changes
    /// - Final value is correct after multiple updates
    @Test func test_multipleRoomChanges() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Publish multiple nav events rapidly
        let roomIds = [228, 229, 230, 231, 232]

        for roomId in roomIds {
            let navTag = GameTag(
                name: "nav",
                text: nil,
                attrs: ["rm": "\(roomId)"],
                children: [],
                state: .closed
            )
            await eventBus.publish("metadata/nav", data: navTag)
            try? await Task.sleep(for: .milliseconds(5))
        }

        // Give final event time to process
        try? await Task.sleep(for: .milliseconds(10))

        // Verify final value is set
        #expect(viewModel.roomId == 232)
    }

    /// Test that all navigation fields can be updated independently
    ///
    /// Acceptance Criteria:
    /// - Each field updates independently
    @Test func test_independentNavigationUpdates() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Update room ID
        let navTag = GameTag(
            name: "nav",
            text: nil,
            attrs: ["rm": "228"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/nav", data: navTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Update room name
        let streamTag = GameTag(
            name: "streamWindow",
            text: nil,
            attrs: ["subtitle": " - [Town Square] - 228"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/streamWindow/room", data: streamTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Update exits
        let dirTags = [
            GameTag(name: "dir", text: nil, attrs: ["value": "n"], children: [], state: .closed),
            GameTag(name: "dir", text: nil, attrs: ["value": "s"], children: [], state: .closed)
        ]
        let compassTag = GameTag(
            name: "compass",
            text: nil,
            attrs: [:],
            children: dirTags,
            state: .closed
        )
        await eventBus.publish("metadata/compass", data: compassTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify all three updated independently
        #expect(viewModel.roomId == 228)
        #expect(viewModel.roomName == "[Town Square]")
        #expect(viewModel.exits == Set(["n", "s"]))
    }

    /// Test complete room transition sequence
    ///
    /// Acceptance Criteria:
    /// - Handles typical server sequence: nav → streamWindow → compass
    @Test func test_completeRoomTransition() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // 1. Room ID established (nav tag)
        let navTag = GameTag(
            name: "nav",
            text: nil,
            attrs: ["rm": "228"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/nav", data: navTag)
        try? await Task.sleep(for: .milliseconds(10))
        #expect(viewModel.roomId == 228)

        // 2. Room title announced (streamWindow tag)
        let streamTag = GameTag(
            name: "streamWindow",
            text: nil,
            attrs: ["subtitle": " - [Town Square, Market] - 228"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/streamWindow/room", data: streamTag)
        try? await Task.sleep(for: .milliseconds(10))
        #expect(viewModel.roomName == "[Town Square, Market]")

        // 3. Available exits announced (compass tag)
        let dirTags = [
            GameTag(name: "dir", text: nil, attrs: ["value": "n"], children: [], state: .closed),
            GameTag(name: "dir", text: nil, attrs: ["value": "s"], children: [], state: .closed),
            GameTag(name: "dir", text: nil, attrs: ["value": "e"], children: [], state: .closed),
            GameTag(name: "dir", text: nil, attrs: ["value": "w"], children: [], state: .closed),
            GameTag(name: "dir", text: nil, attrs: ["value": "up"], children: [], state: .closed)
        ]
        let compassTag = GameTag(
            name: "compass",
            text: nil,
            attrs: [:],
            children: dirTags,
            state: .closed
        )
        await eventBus.publish("metadata/compass", data: compassTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify complete room state
        #expect(viewModel.roomId == 228)
        #expect(viewModel.roomName == "[Town Square, Market]")
        #expect(viewModel.exits == Set(["n", "s", "e", "w", "up"]))
    }

    // MARK: - Lifecycle Tests

    /// Test that CompassPanelViewModel cleans up subscriptions on deinit
    ///
    /// Acceptance Criteria:
    /// - Unsubscribes from all events when deallocated
    @Test func test_eventBusSubscriptionLifecycle() async throws {
        let eventBus = EventBus()

        do {
            let viewModel = CompassPanelViewModel(eventBus: eventBus)
            await viewModel.setup()

            // Verify subscriptions exist
            let navCount = await eventBus.handlerCount(for: "metadata/nav")
            let compassCount = await eventBus.handlerCount(for: "metadata/compass")
            let roomCount = await eventBus.handlerCount(for: "metadata/streamWindow/room")

            #expect(navCount == 1)
            #expect(compassCount == 1)
            #expect(roomCount == 1)
        }

        // CompassPanelViewModel should be deallocated here
        // Give deinit time to execute
        try? await Task.sleep(for: .milliseconds(50))

        // Verify all subscriptions were removed
        let navCountAfter = await eventBus.handlerCount(for: "metadata/nav")
        let compassCountAfter = await eventBus.handlerCount(for: "metadata/compass")
        let roomCountAfter = await eventBus.handlerCount(for: "metadata/streamWindow/room")

        #expect(navCountAfter == 0)
        #expect(compassCountAfter == 0)
        #expect(roomCountAfter == 0)
    }

    /// Test that multiple CompassPanelViewModels can subscribe to same EventBus
    ///
    /// Acceptance Criteria:
    /// - Multiple instances can coexist without conflict
    @Test func test_multipleViewModelsSubscribe() async throws {
        let eventBus = EventBus()
        let viewModel1 = CompassPanelViewModel(eventBus: eventBus)
        let viewModel2 = CompassPanelViewModel(eventBus: eventBus)
        await viewModel1.setup()
        await viewModel2.setup()

        // Verify both subscribed
        let navHandlerCount = await eventBus.handlerCount(for: "metadata/nav")
        #expect(navHandlerCount == 2)

        // Publish event
        let navTag = GameTag(
            name: "nav",
            text: nil,
            attrs: ["rm": "228"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/nav", data: navTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify both updated
        #expect(viewModel1.roomId == 228)
        #expect(viewModel2.roomId == 228)
    }

    // MARK: - Concurrent Event Handling Tests

    /// Test that CompassPanelViewModel handles concurrent events safely
    ///
    /// Acceptance Criteria:
    /// - MainActor isolation prevents race conditions
    /// - Events process in order without data corruption
    @Test func test_concurrentEventHandling() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Publish multiple events concurrently (stress test)
        await withTaskGroup(of: Void.self) { group in
            // Nav events
            for i in 1...10 {
                group.addTask {
                    let navTag = GameTag(
                        name: "nav",
                        text: nil,
                        attrs: ["rm": "\(i)"],
                        children: [],
                        state: .closed
                    )
                    await eventBus.publish("metadata/nav", data: navTag)
                }
            }

            // Room name events
            for i in 1...10 {
                group.addTask {
                    let streamTag = GameTag(
                        name: "streamWindow",
                        text: nil,
                        attrs: ["subtitle": " - [Room \(i)] - \(i)"],
                        children: [],
                        state: .closed
                    )
                    await eventBus.publish("metadata/streamWindow/room", data: streamTag)
                }
            }

            // Compass events
            for _ in 1...10 {
                group.addTask {
                    let dirTags = [
                        GameTag(name: "dir", text: nil, attrs: ["value": "n"], children: [], state: .closed)
                    ]
                    let compassTag = GameTag(
                        name: "compass",
                        text: nil,
                        attrs: [:],
                        children: dirTags,
                        state: .closed
                    )
                    await eventBus.publish("metadata/compass", data: compassTag)
                }
            }
        }

        // Give events time to settle
        try? await Task.sleep(for: .milliseconds(50))

        // Verify state is consistent (no crashes, no corruption)
        // Exact values may vary due to concurrent execution, but types should be correct
        #expect(viewModel.roomId >= 0)  // Should be valid integer
        #expect(!viewModel.exits.isEmpty) // Should have exits
        #expect(viewModel.roomName.contains("Room") || viewModel.roomName.isEmpty) // Should be valid string
    }

    // MARK: - Edge Cases

    /// Test that CompassPanelViewModel handles large room IDs
    ///
    /// Acceptance Criteria:
    /// - Handles room IDs up to Int.max
    @Test func test_largeRoomId() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let largeRoomId = 999999
        let navTag = GameTag(
            name: "nav",
            text: nil,
            attrs: ["rm": "\(largeRoomId)"],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/nav", data: navTag)
        try? await Task.sleep(for: .milliseconds(10))

        #expect(viewModel.roomId == largeRoomId)
    }

    /// Test that CompassPanelViewModel handles special room ID 0
    ///
    /// Acceptance Criteria:
    /// - Handles room ID 0 (disabled room window)
    @Test func test_roomIdZero() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let navTag = GameTag(
            name: "nav",
            text: nil,
            attrs: ["rm": "0"],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/nav", data: navTag)
        try? await Task.sleep(for: .milliseconds(10))

        #expect(viewModel.roomId == 0)
    }

    /// Test that CompassPanelViewModel handles long room names
    ///
    /// Acceptance Criteria:
    /// - Handles room names with 100+ characters
    @Test func test_longRoomName() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let longName = "[This Is A Very Long Room Name That Goes On And On And On To Test How The Parser Handles Extremely Long Room Titles]"
        let streamTag = GameTag(
            name: "streamWindow",
            text: nil,
            attrs: ["subtitle": " - \(longName) - 123"],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/streamWindow/room", data: streamTag)
        try? await Task.sleep(for: .milliseconds(10))

        #expect(viewModel.roomName == longName)
    }

    /// Test that CompassPanelViewModel handles room names with special characters
    ///
    /// Acceptance Criteria:
    /// - Preserves special characters in room names
    /// - Correctly removes trailing room ID from subtitle
    @Test func test_roomNameSpecialCharacters() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Room name with special characters (apostrophes, commas)
        let cleanName = "[Tavern, K'Tavi's Corner]"  // Without room ID
        let streamTag = GameTag(
            name: "streamWindow",
            text: nil,
            attrs: ["subtitle": " - \(cleanName) - 456"],  // Subtitle includes room ID
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/streamWindow/room", data: streamTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Should preserve apostrophe and all special chars, but remove room ID
        #expect(viewModel.roomName == cleanName)
    }

    /// Test that CompassPanelViewModel handles room names with Unicode
    ///
    /// Acceptance Criteria:
    /// - Correctly handles Unicode characters in room names
    /// - Correctly removes trailing room ID from subtitle
    @Test func test_roomNameUnicode() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Room name with Unicode characters (Chinese)
        let unicodeName = "[龙宫殿]"  // Without room ID
        let streamTag = GameTag(
            name: "streamWindow",
            text: nil,
            attrs: ["subtitle": " - \(unicodeName) - 789"],  // Subtitle includes room ID
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/streamWindow/room", data: streamTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Should preserve Unicode characters but remove room ID
        #expect(viewModel.roomName == unicodeName)
    }

    /// Test that exits handles case sensitivity correctly
    ///
    /// Acceptance Criteria:
    /// - All exit directions are lowercase per protocol spec
    @Test func test_exitsLowercase() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Server should always send lowercase, but test for robustness
        let dirTags = [
            GameTag(name: "dir", text: nil, attrs: ["value": "n"], children: [], state: .closed),
            GameTag(name: "dir", text: nil, attrs: ["value": "ne"], children: [], state: .closed),
            GameTag(name: "dir", text: nil, attrs: ["value": "up"], children: [], state: .closed)
        ]
        let compassTag = GameTag(
            name: "compass",
            text: nil,
            attrs: [:],
            children: dirTags,
            state: .closed
        )

        await eventBus.publish("metadata/compass", data: compassTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify all are lowercase
        for exit in viewModel.exits {
            #expect(exit == exit.lowercased())
        }
    }

    /// Test that CompassPanelViewModel handles single exit correctly
    ///
    /// Acceptance Criteria:
    /// - Handles compass with only one exit (e.g., "out")
    @Test func test_singleExit() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let dirTags = [
            GameTag(name: "dir", text: nil, attrs: ["value": "out"], children: [], state: .closed)
        ]
        let compassTag = GameTag(
            name: "compass",
            text: nil,
            attrs: [:],
            children: dirTags,
            state: .closed
        )

        await eventBus.publish("metadata/compass", data: compassTag)
        try? await Task.sleep(for: .milliseconds(10))

        #expect(viewModel.exits == Set(["out"]))
        #expect(viewModel.exits.count == 1)
    }

    /// Test that room state persists correctly across transitions
    ///
    /// Acceptance Criteria:
    /// - Old room state is replaced, not merged
    @Test func test_roomStateReplacement() async throws {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Set initial room state
        let navTag1 = GameTag(name: "nav", text: nil, attrs: ["rm": "100"], children: [], state: .closed)
        await eventBus.publish("metadata/nav", data: navTag1)

        let streamTag1 = GameTag(
            name: "streamWindow",
            text: nil,
            attrs: ["subtitle": " - [Old Room] - 100"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/streamWindow/room", data: streamTag1)

        let dirTags1 = [
            GameTag(name: "dir", text: nil, attrs: ["value": "n"], children: [], state: .closed),
            GameTag(name: "dir", text: nil, attrs: ["value": "s"], children: [], state: .closed)
        ]
        let compassTag1 = GameTag(name: "compass", text: nil, attrs: [:], children: dirTags1, state: .closed)
        await eventBus.publish("metadata/compass", data: compassTag1)

        try? await Task.sleep(for: .milliseconds(10))

        // Verify initial state
        #expect(viewModel.roomId == 100)
        #expect(viewModel.roomName == "[Old Room]")
        #expect(viewModel.exits == Set(["n", "s"]))

        // Move to new room with completely different state
        let navTag2 = GameTag(name: "nav", text: nil, attrs: ["rm": "200"], children: [], state: .closed)
        await eventBus.publish("metadata/nav", data: navTag2)

        let streamTag2 = GameTag(
            name: "streamWindow",
            text: nil,
            attrs: ["subtitle": " - [New Room] - 200"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/streamWindow/room", data: streamTag2)

        let dirTags2 = [
            GameTag(name: "dir", text: nil, attrs: ["value": "e"], children: [], state: .closed),
            GameTag(name: "dir", text: nil, attrs: ["value": "w"], children: [], state: .closed),
            GameTag(name: "dir", text: nil, attrs: ["value": "up"], children: [], state: .closed)
        ]
        let compassTag2 = GameTag(name: "compass", text: nil, attrs: [:], children: dirTags2, state: .closed)
        await eventBus.publish("metadata/compass", data: compassTag2)

        try? await Task.sleep(for: .milliseconds(10))

        // Verify new state completely replaced old state (no merging)
        #expect(viewModel.roomId == 200)
        #expect(viewModel.roomName == "[New Room]")
        #expect(viewModel.exits == Set(["e", "w", "up"]))
        #expect(!viewModel.exits.contains("n")) // Old exits should be gone
        #expect(!viewModel.exits.contains("s"))
    }
}
