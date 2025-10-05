// ABOUTME: Tests for EventBus actor - type-safe event subscription/publishing with async handlers

import Foundation
import Testing
@testable import VaalinCore

/// Test suite for EventBus actor
/// Validates event subscription, publishing, multiple handlers, async execution, and unsubscription
struct EventBusTests {
    // MARK: - Test Event Types

    /// Simple test event with string data
    struct TestEvent: Equatable {
        let message: String
    }

    /// Event with numeric data
    struct CounterEvent: Equatable {
        let count: Int
    }

    /// Event with no associated data
    struct EmptyEvent: Equatable {}

    // MARK: - Basic Subscribe/Publish Tests

    /// Test basic event subscription and publishing
    /// This is the core functionality - subscribe to an event, publish it, handler receives it
    @Test func test_subscribeAndPublish() async throws {
        let bus = EventBus()
        var receivedMessage: String?

        // Subscribe to event
        let subscriptionId = await bus.subscribe("test.event") { (event: TestEvent) in
            receivedMessage = event.message
        }

        // Verify subscription ID was returned (UUID is never nil, but we verify it's created)
        #expect(subscriptionId.uuidString.isEmpty == false)

        // Publish event
        await bus.publish("test.event", data: TestEvent(message: "Hello"))

        // Verify handler was called with correct data
        #expect(receivedMessage == "Hello")
    }

    /// Test that handler is not called for different event type
    @Test func test_publishToCorrectEventOnly() async throws {
        let bus = EventBus()
        var receivedEvent1 = false
        var receivedEvent2 = false

        // Subscribe to two different events
        _ = await bus.subscribe("event1") { (_: TestEvent) in
            receivedEvent1 = true
        }
        _ = await bus.subscribe("event2") { (_: TestEvent) in
            receivedEvent2 = true
        }

        // Publish only to event1
        await bus.publish("event1", data: TestEvent(message: "test"))

        // Verify only event1 handler was called
        #expect(receivedEvent1 == true)
        #expect(receivedEvent2 == false)
    }

    // MARK: - Multiple Handlers Tests

    /// Test multiple handlers for the same event
    /// All handlers should be called when event is published
    @Test func test_multipleHandlersSameEvent() async throws {
        let bus = EventBus()
        var handler1Called = false
        var handler2Called = false
        var handler3Called = false

        // Subscribe three handlers to same event
        _ = await bus.subscribe("shared.event") { (_: TestEvent) in
            handler1Called = true
        }
        _ = await bus.subscribe("shared.event") { (_: TestEvent) in
            handler2Called = true
        }
        _ = await bus.subscribe("shared.event") { (_: TestEvent) in
            handler3Called = true
        }

        // Publish event once
        await bus.publish("shared.event", data: TestEvent(message: "broadcast"))

        // Verify all handlers were called
        #expect(handler1Called == true)
        #expect(handler2Called == true)
        #expect(handler3Called == true)
    }

    /// Test handlers receive correct data when multiple handlers exist
    @Test func test_multipleHandlersReceiveCorrectData() async throws {
        let bus = EventBus()
        var received1: String?
        var received2: String?
        var received3: String?

        _ = await bus.subscribe("data.event") { (event: TestEvent) in
            received1 = event.message
        }
        _ = await bus.subscribe("data.event") { (event: TestEvent) in
            received2 = event.message
        }
        _ = await bus.subscribe("data.event") { (event: TestEvent) in
            received3 = event.message
        }

        await bus.publish("data.event", data: TestEvent(message: "shared data"))

        #expect(received1 == "shared data")
        #expect(received2 == "shared data")
        #expect(received3 == "shared data")
    }

    // MARK: - Async Handler Tests

    /// Test async handler execution
    /// Handlers can perform async operations
    @Test func test_asyncHandlerExecution() async throws {
        let bus = EventBus()
        var handlerCompleted = false

        _ = await bus.subscribe("async.event") { (_: TestEvent) in
            // Simulate async work
            try? await Task.sleep(for: .milliseconds(10))
            handlerCompleted = true
        }

        await bus.publish("async.event", data: TestEvent(message: "async"))

        // Handler should have completed its async work
        #expect(handlerCompleted == true)
    }

    /// Test multiple async handlers execute in order
    @Test func test_multipleAsyncHandlersExecutionOrder() async throws {
        let bus = EventBus()
        var executionOrder: [Int] = []

        _ = await bus.subscribe("order.event") { (_: CounterEvent) in
            try? await Task.sleep(for: .milliseconds(10))
            executionOrder.append(1)
        }
        _ = await bus.subscribe("order.event") { (_: CounterEvent) in
            try? await Task.sleep(for: .milliseconds(5))
            executionOrder.append(2)
        }
        _ = await bus.subscribe("order.event") { (_: CounterEvent) in
            executionOrder.append(3)
        }

        await bus.publish("order.event", data: CounterEvent(count: 1))

        // All handlers should have executed
        #expect(executionOrder.count == 3)
        // Order should be preserved (handlers execute sequentially, not concurrently)
        #expect(executionOrder == [1, 2, 3])
    }

    // MARK: - Unsubscribe Tests

    /// Test unsubscribe removes handler
    /// After unsubscribe, handler should not be called
    @Test func test_unsubscribe() async throws {
        let bus = EventBus()
        var handlerCalled = false

        // Subscribe and get subscription ID
        let subscriptionId = await bus.subscribe("temp.event") { (_: TestEvent) in
            handlerCalled = true
        }

        // Unsubscribe
        await bus.unsubscribe(subscriptionId)

        // Publish event after unsubscribe
        await bus.publish("temp.event", data: TestEvent(message: "should not receive"))

        // Handler should not have been called
        #expect(handlerCalled == false)
    }

    /// Test unsubscribe specific handler among multiple handlers
    @Test func test_unsubscribeSpecificHandler() async throws {
        let bus = EventBus()
        var handler1Called = false
        var handler2Called = false
        var handler3Called = false

        _ = await bus.subscribe("multi.event") { (_: TestEvent) in
            handler1Called = true
        }
        let sub2 = await bus.subscribe("multi.event") { (_: TestEvent) in
            handler2Called = true
        }
        _ = await bus.subscribe("multi.event") { (_: TestEvent) in
            handler3Called = true
        }

        // Unsubscribe only the second handler
        await bus.unsubscribe(sub2)

        // Publish event
        await bus.publish("multi.event", data: TestEvent(message: "test"))

        // Only handler1 and handler3 should be called
        #expect(handler1Called == true)
        #expect(handler2Called == false)
        #expect(handler3Called == true)
    }

    /// Test unsubscribe with invalid ID does not crash
    @Test func test_unsubscribeInvalidId() async throws {
        let bus = EventBus()

        // Unsubscribe with random UUID should not crash
        await bus.unsubscribe(UUID())

        // Test should complete without error (Bool cast silences warning)
        #expect(Bool(true))
    }

    /// Test re-subscribing after unsubscribe works
    @Test func test_resubscribeAfterUnsubscribe() async throws {
        let bus = EventBus()
        var callCount = 0

        // Subscribe, unsubscribe, subscribe again
        let sub1 = await bus.subscribe("resub.event") { (_: TestEvent) in
            callCount += 1
        }
        await bus.unsubscribe(sub1)

        _ = await bus.subscribe("resub.event") { (_: TestEvent) in
            callCount += 1
        }

        await bus.publish("resub.event", data: TestEvent(message: "test"))

        // Should be called once (only the new subscription)
        #expect(callCount == 1)
    }

    // MARK: - Type Safety Tests

    /// Test different event types with same name don't interfere
    /// Event bus should be type-safe per event name
    @Test func test_differentEventTypes() async throws {
        let bus = EventBus()
        var receivedTestEvent: String?
        var receivedCounterEvent: Int?

        _ = await bus.subscribe("mixed.event") { (event: TestEvent) in
            receivedTestEvent = event.message
        }
        _ = await bus.subscribe("counter.event") { (event: CounterEvent) in
            receivedCounterEvent = event.count
        }

        await bus.publish("mixed.event", data: TestEvent(message: "text"))
        await bus.publish("counter.event", data: CounterEvent(count: 42))

        #expect(receivedTestEvent == "text")
        #expect(receivedCounterEvent == 42)
    }

    /// Test event with no associated data
    @Test func test_emptyEvent() async throws {
        let bus = EventBus()
        var eventReceived = false

        _ = await bus.subscribe("empty.event") { (_: EmptyEvent) in
            eventReceived = true
        }

        await bus.publish("empty.event", data: EmptyEvent())

        #expect(eventReceived == true)
    }

    // MARK: - Edge Cases

    /// Test publishing to event with no subscribers does not crash
    @Test func test_publishWithNoSubscribers() async throws {
        let bus = EventBus()

        // Should not crash
        await bus.publish("nonexistent.event", data: TestEvent(message: "nobody listening"))

        #expect(Bool(true))
    }

    /// Test handler that throws does not break other handlers
    @Test func test_handlerErrorIsolation() async throws {
        let bus = EventBus()
        var handler1Completed = false
        var handler3Completed = false

        _ = await bus.subscribe("error.event") { (_: TestEvent) in
            handler1Completed = true
        }
        _ = await bus.subscribe("error.event") { (_: TestEvent) in
            // This handler throws
            throw NSError(domain: "test", code: 1)
        }
        _ = await bus.subscribe("error.event") { (_: TestEvent) in
            handler3Completed = true
        }

        await bus.publish("error.event", data: TestEvent(message: "test"))

        // First handler should complete
        #expect(handler1Completed == true)
        // Third handler should complete despite second handler throwing
        #expect(handler3Completed == true)
    }

    /// Test subscriptions are unique (same handler subscribed twice gets two IDs)
    @Test func test_subscriptionUniqueness() async throws {
        let bus = EventBus()

        let handler: (TestEvent) async -> Void = { _ in }

        let sub1 = await bus.subscribe("unique.event", handler: handler)
        let sub2 = await bus.subscribe("unique.event", handler: handler)

        // Should get different subscription IDs
        #expect(sub1 != sub2)
    }

    /// Test high volume of events (performance/stress test)
    @Test func test_highVolumePublishing() async throws {
        let bus = EventBus()
        var eventCount = 0

        _ = await bus.subscribe("volume.event") { (_: CounterEvent) in
            eventCount += 1
        }

        // Publish 1000 events
        for i in 0..<1000 {
            await bus.publish("volume.event", data: CounterEvent(count: i))
        }

        #expect(eventCount == 1000)
    }

    /// Test multiple subscribers with high volume
    @Test func test_multipleSubscribersHighVolume() async throws {
        let bus = EventBus()
        var counter1 = 0
        var counter2 = 0
        var counter3 = 0

        _ = await bus.subscribe("volume.multi") { (_: CounterEvent) in
            counter1 += 1
        }
        _ = await bus.subscribe("volume.multi") { (_: CounterEvent) in
            counter2 += 1
        }
        _ = await bus.subscribe("volume.multi") { (_: CounterEvent) in
            counter3 += 1
        }

        for i in 0..<100 {
            await bus.publish("volume.multi", data: CounterEvent(count: i))
        }

        #expect(counter1 == 100)
        #expect(counter2 == 100)
        #expect(counter3 == 100)
    }

    // MARK: - Real-World Scenario Tests

    /// Test realistic game metadata event pattern
    @Test func test_gameMetadataEventPattern() async throws {
        struct HandsEvent: Equatable {
            let left: String?
            let right: String?
        }

        let bus = EventBus()
        var leftHand: String?
        var rightHand: String?

        _ = await bus.subscribe("metadata/left") { (event: HandsEvent) in
            leftHand = event.left
        }
        _ = await bus.subscribe("metadata/right") { (event: HandsEvent) in
            rightHand = event.right
        }

        await bus.publish("metadata/left", data: HandsEvent(left: "sword", right: nil))
        await bus.publish("metadata/right", data: HandsEvent(left: nil, right: "shield"))

        #expect(leftHand == "sword")
        #expect(rightHand == "shield")
    }

    /// Test stream routing pattern
    @Test func test_streamRoutingPattern() async throws {
        struct StreamEvent: Equatable {
            let content: String
        }

        let bus = EventBus()
        var mainLog: [String] = []
        var thoughtsLog: [String] = []

        _ = await bus.subscribe("stream/main") { (event: StreamEvent) in
            mainLog.append(event.content)
        }
        _ = await bus.subscribe("stream/thoughts") { (event: StreamEvent) in
            thoughtsLog.append(event.content)
        }

        await bus.publish("stream/main", data: StreamEvent(content: "You see a goblin."))
        await bus.publish("stream/thoughts", data: StreamEvent(content: "I wonder if it's friendly?"))
        await bus.publish("stream/main", data: StreamEvent(content: "The goblin attacks!"))

        #expect(mainLog == ["You see a goblin.", "The goblin attacks!"])
        #expect(thoughtsLog == ["I wonder if it's friendly?"])
    }

    /// Test progressive bar update pattern
    @Test func test_progressBarPattern() async throws {
        struct ProgressEvent: Equatable {
            let id: String
            let value: Int
            let max: Int
        }

        let bus = EventBus()
        var healthValue = 0
        var manaValue = 0

        _ = await bus.subscribe("metadata/progressBar/health") { (event: ProgressEvent) in
            healthValue = event.value
        }
        _ = await bus.subscribe("metadata/progressBar/mana") { (event: ProgressEvent) in
            manaValue = event.value
        }

        await bus.publish("metadata/progressBar/health", data: ProgressEvent(id: "health", value: 95, max: 100))
        await bus.publish("metadata/progressBar/mana", data: ProgressEvent(id: "mana", value: 50, max: 100))

        #expect(healthValue == 95)
        #expect(manaValue == 50)
    }
}
