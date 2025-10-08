// ABOUTME: CommandSending protocol - abstraction for actors that can send commands to game server

import Foundation

/// Protocol for actors that can send commands to the game server
///
/// This protocol enables dependency injection and testing by allowing
/// both real LichConnection and mock implementations to be used interchangeably.
///
/// ## Usage
///
/// ```swift
/// let connection: any CommandSending = LichConnection()
/// try await connection.send(command: "look")
/// ```
///
/// ## Testing
///
/// ```swift
/// actor MockConnection: CommandSending {
///     var sentCommands: [String] = []
///
///     func send(command: String) async throws {
///         sentCommands.append(command)
///     }
/// }
/// ```
public protocol CommandSending: Actor {
    /// Send a command to the game server
    ///
    /// - Parameter command: Command string to send (e.g., "look")
    /// - Throws: Connection error if send fails
    func send(command: String) async throws
}
