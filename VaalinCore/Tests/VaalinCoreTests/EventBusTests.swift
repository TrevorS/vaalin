// ABOUTME: Tests for EventBus actor - type-safe event subscription/publishing with async handlers

import Foundation
import Testing
@testable import VaalinCore

/// Test suite for EventBus actor
/// Validates event subscription, publishing, multiple handlers, async execution, and unsubscription
struct EventBusTests {
    // MARK: - Test Event Types

    /// Simple test event with string data
    struct TestEvent: Equatable, Sendable {
        let message: String
    }

    /// Event with numeric data
    struct CounterEvent: Equatable, Sendable {
        let count: Int
    }

    /// Event with no associated data
    struct EmptyEvent: Equatable, Sendable {}

    // MARK: - Basic Subscribe/Publish Tests

    /// Test basic event subscription and publishing
    /// This is the core functionality - subscribe to an event, publish it, handler receives it
    @Test func test_subscribeAndPublish() async throws {
        actor TestState {
            var receivedMessage: String?

            func setMessage(_ msg: String) {
                receivedMessage = msg
            }

            func getMessage() -> String? {
                receivedMessage
            }
        }

        let state = TestState()
        let bus = EventBus()

        // Subscribe to event
        let subscriptionId = await bus.subscribe("test.event") { (event: TestEvent) in
            await state.setMessage(event.message)
        }

        // Verify subscription ID was returned (UUID is never nil, but we verify it's created)
        #expect(subscriptionId.uuidString.isEmpty == false)

        // Publish event
        await bus.publish("test.event", data: TestEvent(message: "Hello"))

        // Verify handler was called with correct data
        let received = await state.getMessage()
        #expect(received == "Hello")
    }

    /// Test that handler is not called for different event type
    @Test func test_publishToCorrectEventOnly() async throws {
        actor TestState {
            var receivedEvent1 = false
            var receivedEvent2 = false

            func setEvent1() {
                receivedEvent1 = true
            }

            func setEvent2() {
                receivedEvent2 = true
            }

            func getEvent1() -> Bool {
                receivedEvent1
            }

            func getEvent2() -> Bool {
                receivedEvent2
            }
        }

        let state = TestState()
        let bus = EventBus()

        // Subscribe to two different events
        _ = await bus.subscribe("event1") { (_: TestEvent) in
            await state.setEvent1()
        }
        _ = await bus.subscribe("event2") { (_: TestEvent) in
            await state.setEvent2()
        }

        // Publish only to event1
        await bus.publish("event1", data: TestEvent(message: "test"))

        // Verify only event1 handler was called
        let event1 = await state.getEvent1()
        let event2 = await state.getEvent2()
        #expect(event1 == true)
        #expect(event2 == false)
    }

    // MARK: - Multiple Handlers Tests

    /// Test multiple handlers for the same event
    /// All handlers should be called when event is published
    @Test func test_multipleHandlersSameEvent() async throws {
        actor TestState {
            var handler1Called = false
            var handler2Called = false
            var handler3Called = false

            func setHandler1() {
                handler1Called = true
            }

            func setHandler2() {
                handler2Called = true
            }

            func setHandler3() {
                handler3Called = true
            }

            func getResults() -> (Bool, Bool, Bool) {
                (handler1Called, handler2Called, handler3Called)
            }
        }

        let state = TestState()
        let bus = EventBus()

        // Subscribe three handlers to same event
        _ = await bus.subscribe("shared.event") { (_: TestEvent) in
            await state.setHandler1()
        }
        _ = await bus.subscribe("shared.event") { (_: TestEvent) in
            await state.setHandler2()
        }
        _ = await bus.subscribe("shared.event") { (_: TestEvent) in
            await state.setHandler3()
        }

        // Publish event once
        await bus.publish("shared.event", data: TestEvent(message: "broadcast"))

        // Verify all handlers were called
        let (h1, h2, h3) = await state.getResults()
        #expect(h1 == true)
        #expect(h2 == true)
        #expect(h3 == true)
    }

    /// Test handlers receive correct data when multiple handlers exist
    @Test func test_multipleHandlersReceiveCorrectData() async throws {
        actor TestState {
            var received1: String?
            var received2: String?
            var received3: String?

            func setReceived1(_ msg: String) {
                received1 = msg
            }

            func setReceived2(_ msg: String) {
                received2 = msg
            }

            func setReceived3(_ msg: String) {
                received3 = msg
            }

            func getResults() -> (String?, String?, String?) {
                (received1, received2, received3)
            }
        }

        let state = TestState()
        let bus = EventBus()

        _ = await bus.subscribe("data.event") { (event: TestEvent) in
            await state.setReceived1(event.message)
        }
        _ = await bus.subscribe("data.event") { (event: TestEvent) in
            await state.setReceived2(event.message)
        }
        _ = await bus.subscribe("data.event") { (event: TestEvent) in
            await state.setReceived3(event.message)
        }

        await bus.publish("data.event", data: TestEvent(message: "shared data"))

        let (r1, r2, r3) = await state.getResults()
        #expect(r1 == "shared data")
        #expect(r2 == "shared data")
        #expect(r3 == "shared data")
    }

    // MARK: - Async Handler Tests

    /// Test async handler execution
    /// Handlers can perform async operations
    @Test func test_asyncHandlerExecution() async throws {
        actor TestState {
            var handlerCompleted = false

            func setCompleted() {
                handlerCompleted = true
            }

            func getCompleted() -> Bool {
                handlerCompleted
            }
        }

        let state = TestState()
        let bus = EventBus()

        _ = await bus.subscribe("async.event") { (_: TestEvent) in
            // Simulate async work
            try? await Task.sleep(for: .milliseconds(10))
            await state.setCompleted()
        }

        await bus.publish("async.event", data: TestEvent(message: "async"))

        // Handler should have completed its async work
        let completed = await state.getCompleted()
        #expect(completed == true)
    }

    /// Test multiple async handlers execute in order
    @Test func test_multipleAsyncHandlersExecutionOrder() async throws {
        actor TestState {
            var executionOrder: [Int] = []

            func append(_ value: Int) {
                executionOrder.append(value)
            }

            func getOrder() -> [Int] {
                executionOrder
            }
        }

        let state = TestState()
        let bus = EventBus()

        _ = await bus.subscribe("order.event") { (_: CounterEvent) in
            try? await Task.sleep(for: .milliseconds(10))
            await state.append(1)
        }
        _ = await bus.subscribe("order.event") { (_: CounterEvent) in
            try? await Task.sleep(for: .milliseconds(5))
            await state.append(2)
        }
        _ = await bus.subscribe("order.event") { (_: CounterEvent) in
            await state.append(3)
        }

        await bus.publish("order.event", data: CounterEvent(count: 1))

        // All handlers should have executed
        let order = await state.getOrder()
        #expect(order.count == 3)
        // Order should be preserved (handlers execute sequentially, not concurrently)
        #expect(order == [1, 2, 3])
    }

    // MARK: - Unsubscribe Tests

    /// Test unsubscribe removes handler
    /// After unsubscribe, handler should not be called
    @Test func test_unsubscribe() async throws {
        actor TestState {
            var handlerCalled = false

            func setCalled() {
                handlerCalled = true
            }

            func getCalled() -> Bool {
                handlerCalled
            }
        }

        let state = TestState()
        let bus = EventBus()

        // Subscribe and get subscription ID
        let subscriptionId = await bus.subscribe("temp.event") { (_: TestEvent) in
            await state.setCalled()
        }

        // Unsubscribe
        await bus.unsubscribe(subscriptionId)

        // Publish event after unsubscribe
        await bus.publish("temp.event", data: TestEvent(message: "should not receive"))

        // Handler should not have been called
        let called = await state.getCalled()
        #expect(called == false)
    }

    /// Test unsubscribe specific handler among multiple handlers
    @Test func test_unsubscribeSpecificHandler() async throws {
        actor TestState {
            var handler1Called = false
            var handler2Called = false
            var handler3Called = false

            func setHandler1() {
                handler1Called = true
            }

            func setHandler2() {
                handler2Called = true
            }

            func setHandler3() {
                handler3Called = true
            }

            func getResults() -> (Bool, Bool, Bool) {
                (handler1Called, handler2Called, handler3Called)
            }
        }

        let state = TestState()
        let bus = EventBus()

        _ = await bus.subscribe("multi.event") { (_: TestEvent) in
            await state.setHandler1()
        }
        let sub2 = await bus.subscribe("multi.event") { (_: TestEvent) in
            await state.setHandler2()
        }
        _ = await bus.subscribe("multi.event") { (_: TestEvent) in
            await state.setHandler3()
        }

        // Unsubscribe only the second handler
        await bus.unsubscribe(sub2)

        // Publish event
        await bus.publish("multi.event", data: TestEvent(message: "test"))

        // Only handler1 and handler3 should be called
        let (h1, h2, h3) = await state.getResults()
        #expect(h1 == true)
        #expect(h2 == false)
        #expect(h3 == true)
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
        actor TestState {
            var callCount = 0

            func increment() {
                callCount += 1
            }

            func getCount() -> Int {
                callCount
            }
        }

        let state = TestState()
        let bus = EventBus()

        // Subscribe, unsubscribe, subscribe again
        let sub1 = await bus.subscribe("resub.event") { (_: TestEvent) in
            await state.increment()
        }
        await bus.unsubscribe(sub1)

        _ = await bus.subscribe("resub.event") { (_: TestEvent) in
            await state.increment()
        }

        await bus.publish("resub.event", data: TestEvent(message: "test"))

        // Should be called once (only the new subscription)
        let count = await state.getCount()
        #expect(count == 1)
    }

    // MARK: - Type Safety Tests

    /// Test different event types with same name don't interfere
    /// Event bus should be type-safe per event name
    @Test func test_differentEventTypes() async throws {
        actor TestState {
            var receivedTestEvent: String?
            var receivedCounterEvent: Int?

            func setTestEvent(_ msg: String) {
                receivedTestEvent = msg
            }

            func setCounterEvent(_ count: Int) {
                receivedCounterEvent = count
            }

            func getResults() -> (String?, Int?) {
                (receivedTestEvent, receivedCounterEvent)
            }
        }

        let state = TestState()
        let bus = EventBus()

        _ = await bus.subscribe("mixed.event") { (event: TestEvent) in
            await state.setTestEvent(event.message)
        }
        _ = await bus.subscribe("counter.event") { (event: CounterEvent) in
            await state.setCounterEvent(event.count)
        }

        await bus.publish("mixed.event", data: TestEvent(message: "text"))
        await bus.publish("counter.event", data: CounterEvent(count: 42))

        let (testEvent, counterEvent) = await state.getResults()
        #expect(testEvent == "text")
        #expect(counterEvent == 42)
    }

    /// Test event with no associated data
    @Test func test_emptyEvent() async throws {
        actor TestState {
            var eventReceived = false

            func setReceived() {
                eventReceived = true
            }

            func getReceived() -> Bool {
                eventReceived
            }
        }

        let state = TestState()
        let bus = EventBus()

        _ = await bus.subscribe("empty.event") { (_: EmptyEvent) in
            await state.setReceived()
        }

        await bus.publish("empty.event", data: EmptyEvent())

        let received = await state.getReceived()
        #expect(received == true)
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
        actor TestState {
            var handler1Completed = false
            var handler3Completed = false

            func setHandler1() {
                handler1Completed = true
            }

            func setHandler3() {
                handler3Completed = true
            }

            func getResults() -> (Bool, Bool) {
                (handler1Completed, handler3Completed)
            }
        }

        let state = TestState()
        let bus = EventBus()

        _ = await bus.subscribe("error.event") { (_: TestEvent) in
            await state.setHandler1()
        }
        _ = await bus.subscribe("error.event") { (_: TestEvent) in
            // This handler throws
            throw NSError(domain: "test", code: 1)
        }
        _ = await bus.subscribe("error.event") { (_: TestEvent) in
            await state.setHandler3()
        }

        await bus.publish("error.event", data: TestEvent(message: "test"))

        // First handler should complete
        // Third handler should complete despite second handler throwing
        let (h1, h3) = await state.getResults()
        #expect(h1 == true)
        #expect(h3 == true)
    }

    /// Test subscriptions are unique (same handler subscribed twice gets two IDs)
    @Test func test_subscriptionUniqueness() async throws {
        let bus = EventBus()

        let handler: @Sendable (TestEvent) async -> Void = { _ in }

        let sub1 = await bus.subscribe("unique.event", handler: handler)
        let sub2 = await bus.subscribe("unique.event", handler: handler)

        // Should get different subscription IDs
        #expect(sub1 != sub2)
    }

    /// Test high volume of events (performance/stress test)
    @Test func test_highVolumePublishing() async throws {
        actor TestState {
            var eventCount = 0

            func increment() {
                eventCount += 1
            }

            func getCount() -> Int {
                eventCount
            }
        }

        let state = TestState()
        let bus = EventBus()

        _ = await bus.subscribe("volume.event") { (_: CounterEvent) in
            await state.increment()
        }

        // Publish 1000 events
        for i in 0..<1000 {
            await bus.publish("volume.event", data: CounterEvent(count: i))
        }

        let count = await state.getCount()
        #expect(count == 1000)
    }

    /// Test multiple subscribers with high volume
    @Test func test_multipleSubscribersHighVolume() async throws {
        actor TestState {
            var counter1 = 0
            var counter2 = 0
            var counter3 = 0

            func incrementCounter1() {
                counter1 += 1
            }

            func incrementCounter2() {
                counter2 += 1
            }

            func incrementCounter3() {
                counter3 += 1
            }

            func getResults() -> (Int, Int, Int) {
                (counter1, counter2, counter3)
            }
        }

        let state = TestState()
        let bus = EventBus()

        _ = await bus.subscribe("volume.multi") { (_: CounterEvent) in
            await state.incrementCounter1()
        }
        _ = await bus.subscribe("volume.multi") { (_: CounterEvent) in
            await state.incrementCounter2()
        }
        _ = await bus.subscribe("volume.multi") { (_: CounterEvent) in
            await state.incrementCounter3()
        }

        for i in 0..<100 {
            await bus.publish("volume.multi", data: CounterEvent(count: i))
        }

        let (c1, c2, c3) = await state.getResults()
        #expect(c1 == 100)
        #expect(c2 == 100)
        #expect(c3 == 100)
    }

    // MARK: - Real-World Scenario Tests

    /// Test realistic game metadata event pattern
    @Test func test_gameMetadataEventPattern() async throws {
        struct HandsEvent: Equatable, Sendable {
            let left: String?
            let right: String?
        }

        actor TestState {
            var leftHand: String?
            var rightHand: String?

            func setLeftHand(_ hand: String?) {
                leftHand = hand
            }

            func setRightHand(_ hand: String?) {
                rightHand = hand
            }

            func getResults() -> (String?, String?) {
                (leftHand, rightHand)
            }
        }

        let state = TestState()
        let bus = EventBus()

        _ = await bus.subscribe("metadata/left") { (event: HandsEvent) in
            await state.setLeftHand(event.left)
        }
        _ = await bus.subscribe("metadata/right") { (event: HandsEvent) in
            await state.setRightHand(event.right)
        }

        await bus.publish("metadata/left", data: HandsEvent(left: "sword", right: nil))
        await bus.publish("metadata/right", data: HandsEvent(left: nil, right: "shield"))

        let (left, right) = await state.getResults()
        #expect(left == "sword")
        #expect(right == "shield")
    }

    /// Test stream routing pattern
    @Test func test_streamRoutingPattern() async throws {
        struct StreamEvent: Equatable, Sendable {
            let content: String
        }

        actor TestState {
            var mainLog: [String] = []
            var thoughtsLog: [String] = []

            func appendMain(_ content: String) {
                mainLog.append(content)
            }

            func appendThoughts(_ content: String) {
                thoughtsLog.append(content)
            }

            func getResults() -> ([String], [String]) {
                (mainLog, thoughtsLog)
            }
        }

        let state = TestState()
        let bus = EventBus()

        _ = await bus.subscribe("stream/main") { (event: StreamEvent) in
            await state.appendMain(event.content)
        }
        _ = await bus.subscribe("stream/thoughts") { (event: StreamEvent) in
            await state.appendThoughts(event.content)
        }

        await bus.publish("stream/main", data: StreamEvent(content: "You see a goblin."))
        await bus.publish("stream/thoughts", data: StreamEvent(content: "I wonder if it's friendly?"))
        await bus.publish("stream/main", data: StreamEvent(content: "The goblin attacks!"))

        let (main, thoughts) = await state.getResults()
        #expect(main == ["You see a goblin.", "The goblin attacks!"])
        #expect(thoughts == ["I wonder if it's friendly?"])
    }

    /// Test progressive bar update pattern
    @Test func test_progressBarPattern() async throws {
        struct ProgressEvent: Equatable, Sendable {
            let id: String
            let value: Int
            let max: Int
        }

        actor TestState {
            var healthValue = 0
            var manaValue = 0

            func setHealth(_ value: Int) {
                healthValue = value
            }

            func setMana(_ value: Int) {
                manaValue = value
            }

            func getResults() -> (Int, Int) {
                (healthValue, manaValue)
            }
        }

        let state = TestState()
        let bus = EventBus()

        _ = await bus.subscribe("metadata/progressBar/health") { (event: ProgressEvent) in
            await state.setHealth(event.value)
        }
        _ = await bus.subscribe("metadata/progressBar/mana") { (event: ProgressEvent) in
            await state.setMana(event.value)
        }

        await bus.publish("metadata/progressBar/health", data: ProgressEvent(id: "health", value: 95, max: 100))
        await bus.publish("metadata/progressBar/mana", data: ProgressEvent(id: "mana", value: 50, max: 100))

        let (health, mana) = await state.getResults()
        #expect(health == 95)
        #expect(mana == 50)
    }
}
