// ABOUTME: ConnectionState enum - Connection state machine for Lich TCP connection

import Foundation

/// Represents the connection state of a LichConnection
///
/// This is a simple state machine matching NWConnection.State semantics
/// but simplified for our use case.
///
/// ## State Transitions
///
/// ```
/// disconnected → connecting → connected
///       ↑            ↓            ↓
///       ←────────────────────────←
///              (failed)
/// ```
///
/// ## States
///
/// - `disconnected`: No active connection
/// - `connecting`: Connection attempt in progress
/// - `connected`: Successfully connected and ready to send/receive
/// - `failed`: Connection failed (will retry with backoff)
public enum ConnectionState: Equatable, Sendable {
    /// No active connection to Lich
    case disconnected

    /// Connection attempt in progress
    case connecting

    /// Successfully connected and ready to send/receive data
    case connected

    /// Connection failed (includes error information)
    case failed(Error)

    // MARK: - Equatable Conformance

    /// Compare states for equality
    ///
    /// Note: For `.failed` cases, we only compare the case, not the error
    /// This is because Error is not Equatable by default
    public static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected):
            return true
        case (.connecting, .connecting):
            return true
        case (.connected, .connected):
            return true
        case (.failed, .failed):
            // Two failed states are considered equal regardless of error
            return true
        default:
            return false
        }
    }
}
