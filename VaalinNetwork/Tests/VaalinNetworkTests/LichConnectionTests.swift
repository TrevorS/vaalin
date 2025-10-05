// ABOUTME: Tests for LichConnection actor - TCP connection to Lich detachable client

import Testing
@testable import VaalinNetwork

/// Tests for LichConnection actor
///
/// Covers connection lifecycle, state transitions, data streaming, and error handling
struct LichConnectionTests {
    // MARK: - Initialization Tests

    @Test func test_initialState() async {
        let connection = LichConnection()

        let state = await connection.state
        #expect(state == .disconnected)
    }

    // MARK: - Connection State Transition Tests

    @Test func test_connectionStateTransitions() async throws {
        let connection = LichConnection()

        // Initial state
        let state = await connection.state
        #expect(state == .disconnected)

        // Note: Actual connection tests require mocking NWConnection
        // For now, verify the state accessor works
    }

    @Test func test_connectToLocalhost() async throws {
        let connection = LichConnection()

        // Attempt connection to localhost:8000
        // This will fail if Lich is not running, which is expected
        do {
            try await connection.connect(host: "127.0.0.1", port: 8000)

            // If we get here, connection succeeded
            let state = await connection.state
            #expect(state == .connected || state == .connecting)
        } catch {
            // Expected if Lich is not running
            // Verify we're in failed or disconnected state
            let state = await connection.state
            switch state {
            case .failed, .disconnected:
                break // Expected
            default:
                Issue.record("Expected failed or disconnected state, got \(state)")
            }
        }
    }

    @Test func test_connectionFailure() async throws {
        let connection = LichConnection()

        // Try connecting to port that's unlikely to be listening
        do {
            try await connection.connect(host: "127.0.0.1", port: 19999)

            // Should not succeed
            Issue.record("Connection to invalid port should fail")
        } catch {
            // Expected failure
            let state = await connection.state
            switch state {
            case .failed, .disconnected:
                break // Expected
            default:
                Issue.record("Expected failed or disconnected state, got \(state)")
            }
        }
    }

    // MARK: - Disconnect Tests

    @Test func test_disconnect() async throws {
        let connection = LichConnection()

        // Disconnect should work even if not connected
        await connection.disconnect()

        let state = await connection.state
        #expect(state == .disconnected)
    }

    @Test func test_disconnectAfterConnection() async throws {
        let connection = LichConnection()

        // Try to connect
        do {
            try await connection.connect(host: "127.0.0.1", port: 8000)
        } catch {
            // Ignore connection errors for this test
        }

        // Disconnect
        await connection.disconnect()

        let state = await connection.state
        #expect(state == .disconnected)
    }

    // MARK: - Command Sending Tests

    @Test func test_sendCommand() async throws {
        let connection = LichConnection()

        // Sending command while disconnected should fail gracefully
        do {
            try await connection.send(command: "look")

            // If this succeeds, we're connected (unlikely in tests)
        } catch let error as LichConnectionError {
            // Expected when not connected
            #expect(error == .notConnected)
        } catch {
            Issue.record("Expected LichConnectionError, got \(error)")
        }
    }

    @Test func test_sendEmptyCommand() async throws {
        let connection = LichConnection()

        do {
            try await connection.send(command: "")
            Issue.record("Empty command should fail")
        } catch let error as LichConnectionError {
            // Expected
            #expect(error == .invalidCommand)
        } catch {
            Issue.record("Expected LichConnectionError, got \(error)")
        }
    }

    // MARK: - State Observation Tests

    @Test func test_stateUpdates() async throws {
        let connection = LichConnection()

        // Subscribe to state updates
        var stateHistory: [ConnectionState] = []

        // Get initial state
        stateHistory.append(await connection.state)

        // Try connecting (will likely fail without Lich running)
        do {
            try await connection.connect(host: "127.0.0.1", port: 8000)
        } catch {
            // Expected
        }

        stateHistory.append(await connection.state)

        // Verify we tracked state changes
        #expect(stateHistory.count == 2)
        #expect(stateHistory[0] == .disconnected)
    }

    // MARK: - Actor Isolation Tests

    @Test func test_actorIsolation() async {
        let connection = LichConnection()

        // Verify connection is an actor
        // This is a compile-time check, but we can verify behavior
        _ = await connection.state
    }

    @Test func test_concurrentStateAccess() async {
        let connection = LichConnection()

        // Multiple concurrent state accesses should be safe
        async let state1 = connection.state
        async let state2 = connection.state
        async let state3 = connection.state

        let states = await [state1, state2, state3]

        // All should be disconnected initially
        #expect(states.allSatisfy { $0 == .disconnected })
    }
}
