// ABOUTME: Protocol for debug data interception - allows LichConnection to send raw data
// to debug window without creating package dependencies

import Foundation

/// Protocol for intercepting raw data from LichConnection for debugging purposes.
///
/// This protocol allows VaalinNetwork (which can't depend on VaalinUI) to send
/// raw XML chunks to a debug window implementation without creating circular dependencies.
///
/// ## Architecture
///
/// ```
/// VaalinNetwork/LichConnection
///       ↓ (holds optional reference)
/// DebugDataIntercepting protocol (in VaalinCore)
///       ↑ (conforms to)
/// VaalinUI/DebugWindowManager
/// ```
///
/// ## Usage
///
/// ```swift
/// // In VaalinUI
/// extension DebugWindowManager: DebugDataIntercepting {
///     func interceptData(_ data: String, session: String) async {
///         await MainActor.run {
///             self.addEntry(data, session: session)
///         }
///     }
/// }
///
/// // In LichConnection setup
/// await connection.setDebugInterceptor(DebugWindowManager.shared)
/// ```
public protocol DebugDataIntercepting: Sendable {
    /// Intercept raw data from Lich 5
    ///
    /// Called immediately when data is received, before parsing.
    ///
    /// - Parameters:
    ///   - data: Raw XML string
    ///   - session: Session/character name
    func interceptData(_ data: String, session: String) async
}
