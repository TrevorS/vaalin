// ABOUTME: PanelRegistry actor provides thread-safe panel registration and lookup for HUD panel management
// ABOUTME: PanelInfo model contains panel metadata (id, title, visibility, column, height)

import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - PanelColumn

/// Panel column assignment for left/right layout
///
/// Panels can be assigned to either the left or right column
/// of the main game window layout.
public enum PanelColumn: String, Codable, Sendable, Equatable {
    /// Left column (default: hands, vitals)
    case left

    /// Right column (default: compass, spells)
    case right
}

// MARK: - PanelInfo

/// Panel metadata for registration and layout configuration
///
/// Contains all information needed to display and manage a HUD panel:
/// - Unique ID for lookup and settings persistence
/// - Display title for panel header
/// - Default visibility state
/// - Default column assignment (left/right)
/// - Default height in points
///
/// ## Example
///
/// ```swift
/// let handsPanel = PanelInfo(
///     id: "hands",
///     title: "Hands",
///     defaultVisible: true,
///     defaultColumn: .left,
///     defaultHeight: 140
/// )
/// ```
public struct PanelInfo: Codable, Sendable, Equatable {
    /// Unique panel identifier (e.g., "hands", "vitals", "compass")
    /// Used for settings persistence and lookup
    public let id: String

    /// Display title shown in panel header
    public let title: String

    /// Default visibility state when user hasn't overridden
    public let defaultVisible: Bool

    /// Default column assignment (left or right)
    public let defaultColumn: PanelColumn

    /// Default height in points for panel content area
    public let defaultHeight: CGFloat

    /// Create a panel info instance
    ///
    /// - Parameters:
    ///   - id: Unique panel identifier
    ///   - title: Display title for panel header
    ///   - defaultVisible: Default visibility state
    ///   - defaultColumn: Default column assignment
    ///   - defaultHeight: Default height in points
    public init(
        id: String,
        title: String,
        defaultVisible: Bool,
        defaultColumn: PanelColumn,
        defaultHeight: CGFloat
    ) {
        self.id = id
        self.title = title
        self.defaultVisible = defaultVisible
        self.defaultColumn = defaultColumn
        self.defaultHeight = defaultHeight
    }
}

// MARK: - PanelRegistry

/// Thread-safe panel registry for HUD panel management
///
/// PanelRegistry provides a central location for panels to register themselves
/// with metadata (id, title, visibility, column, height). This enables:
/// - Dynamic panel discovery
/// - Settings-based visibility management
/// - Future panel show/hide toggles
/// - Layout column assignment
///
/// ## Usage
///
/// ```swift
/// let registry = PanelRegistry.shared
///
/// // Panel registers itself on init
/// await registry.register(PanelInfo(
///     id: "hands",
///     title: "Hands",
///     defaultVisible: true,
///     defaultColumn: .left,
///     defaultHeight: 140
/// ))
///
/// // Lookup by ID
/// if let panel = await registry.panel(withID: "hands") {
///     print("Panel: \(panel.title)")
/// }
///
/// // Get all left column panels
/// let leftPanels = await registry.panels(forColumn: .left)
/// ```
///
/// ## Thread Safety
///
/// PanelRegistry is implemented as an actor, ensuring all operations are thread-safe.
/// Multiple components can safely register, lookup, and query concurrently.
public actor PanelRegistry {
    // MARK: - State

    /// Registered panels indexed by ID
    private var panels: [String: PanelInfo] = [:]

    // MARK: - Shared Instance

    /// Shared singleton instance for app-wide panel registry
    public static let shared = PanelRegistry()

    // MARK: - Initialization

    /// Create a new panel registry
    ///
    /// For most use cases, use the shared singleton instance via `PanelRegistry.shared`.
    /// Creating separate instances is useful for testing.
    public init() {}

    // MARK: - Registration

    /// Register a panel with the registry
    ///
    /// - Parameter panel: Panel info to register
    ///
    /// If a panel with the same ID already exists, it will be replaced.
    /// This allows panels to update their metadata at runtime.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let registry = PanelRegistry.shared
    ///
    /// await registry.register(PanelInfo(
    ///     id: "hands",
    ///     title: "Hands",
    ///     defaultVisible: true,
    ///     defaultColumn: .left,
    ///     defaultHeight: 140
    /// ))
    /// ```
    public func register(_ panel: PanelInfo) {
        panels[panel.id] = panel
    }

    // MARK: - Lookup

    /// Retrieve a panel by ID
    ///
    /// - Parameter id: Panel ID to look up
    /// - Returns: Panel info if found, nil otherwise
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let panel = await registry.panel(withID: "hands") {
    ///     print("Found panel: \(panel.title)")
    /// } else {
    ///     print("Panel not found")
    /// }
    /// ```
    public func panel(withID id: String) -> PanelInfo? {
        return panels[id]
    }

    /// Get all registered panels
    ///
    /// - Returns: Array of all panel info instances
    ///
    /// Order is not guaranteed. Sort by ID or other criteria as needed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let allPanels = await registry.allPanels()
    /// for panel in allPanels.sorted(by: { $0.id < $1.id }) {
    ///     print("Panel: \(panel.id) - \(panel.title)")
    /// }
    /// ```
    public func allPanels() -> [PanelInfo] {
        return Array(panels.values)
    }

    /// Get panels assigned to a specific column
    ///
    /// - Parameter column: Column to filter by (.left or .right)
    /// - Returns: Array of panels with matching defaultColumn
    ///
    /// ## Example
    ///
    /// ```swift
    /// let leftPanels = await registry.panels(forColumn: .left)
    /// print("Left column has \(leftPanels.count) panels")
    /// ```
    public func panels(forColumn column: PanelColumn) -> [PanelInfo] {
        return panels.values.filter { $0.defaultColumn == column }
    }
}
