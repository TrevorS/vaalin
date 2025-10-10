// ABOUTME: Custom compass rose component with 8-directional arrows and special exits (up/out/down)

import SwiftUI
import VaalinNetwork

/// Custom compass rose component displaying navigation directions.
///
/// `CompassRose` renders an 8-direction compass with radial arrow positioning
/// plus vertical special exits (up, out, down). Available exits are highlighted
/// in success color (green), while inactive exits appear dimmed.
///
/// ## Visual Design
///
/// Layout follows Illthorn's compass-rose-ui structure:
/// ```
/// ┌────────────────┐
/// │   ↑            │  ← Special exits (left)
/// │   ○      N     │  ← 8-direction compass (right)
/// │   ↓   NW   NE  │
/// │      W     E   │
/// │       SW   SE  │
/// │          S     │
/// └────────────────┘
/// ```
///
/// **Compass Rose** (80x80pt):
/// - 8 arrows positioned radially at cardinal/diagonal angles
/// - Arrow rotations: N=0°, NE=45°, E=90°, SE=135°, S=180°, SW=225°, W=270°, NW=315°
/// - Active exits: opacity 1.0, green color
/// - Inactive exits: opacity 0.3, secondary color
///
/// **Special Exits** (left side):
/// - Up: ↑ arrow pointing up
/// - Out: ○ circle
/// - Down: ↓ arrow pointing down
/// - Same active/inactive styling
///
/// ## Interactivity
///
/// Exits can be tapped to trigger navigation commands via optional `onDirectionTap` closure.
/// When provided, each active exit becomes clickable and sends the direction string.
///
/// ## Accessibility
///
/// - Each exit has accessibility label: "North exit available" / "North exit unavailable"
/// - Active exits include `.accessibilityAddTraits(.isButton)` if tappable
/// - Special exits: "Up exit", "Out exit", "Down exit"
///
/// ## Performance
///
/// - Efficient Set lookups for exit highlighting (O(1))
/// - Minimal re-renders (only when `exits` changes)
/// - Custom Path shapes cached by SwiftUI
///
/// ## Example Usage
///
/// ```swift
/// // Display-only compass
/// CompassRose(exits: ["n", "e", "s"])
///
/// // Interactive compass with CommandSending
/// CompassRose(exits: viewModel.exits) { direction in
///     Task {
///         try? await connection?.send(command: direction)
///     }
/// }
/// ```
///
/// ## Reference
///
/// Based on Illthorn's `compass-rose-ui.lit.ts` SVG implementation,
/// reinterpreted for SwiftUI with native macOS design.
public struct CompassRose: View {
    // MARK: - Properties

    /// Set of available exit directions (e.g., ["n", "e", "up"])
    public let exits: Set<String>

    /// Optional callback when exit is tapped (for sending movement commands)
    public let onDirectionTap: ((String) -> Void)?

    // MARK: - Constants

    /// Compass rose dimensions
    private let compassSize: CGFloat = 80
    private let arrowSize: CGFloat = 24
    private let specialArrowSize: CGFloat = 20

    /// Arrow positioning offsets (from edges)
    private let cornerOffset: CGFloat = 8

    /// Direction definitions with rotation angles
    private let compassDirections: [(direction: String, rotation: Double)] = [
        ("n", 0),
        ("ne", 45),
        ("e", 90),
        ("se", 135),
        ("s", 180),
        ("sw", 225),
        ("w", 270),
        ("nw", 315)
    ]

    /// Color palette for compass exits (Catppuccin Mocha theme)
    private enum CompassColor {
        /// Active exit color - Catppuccin green (#a6e3a1)
        static let activeExit = Color(red: 0.651, green: 0.890, blue: 0.631)
        /// Inactive exit color - system secondary
        static let inactiveExit = Color.secondary
    }

    // MARK: - Initializer

    /// Creates a compass rose with available exits.
    ///
    /// - Parameters:
    ///   - exits: Set of available exit directions
    ///   - onDirectionTap: Optional callback for exit taps (enables interactivity)
    public init(
        exits: Set<String>,
        onDirectionTap: ((String) -> Void)? = nil
    ) {
        self.exits = exits
        self.onDirectionTap = onDirectionTap
    }

    // MARK: - Body

    public var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Special exits (left side)
            VStack(alignment: .center, spacing: 10) {
                specialExitButton(direction: "up", shape: ArrowShape.up)
                    .accessibilityLabel(accessibilityLabel(for: "up", name: "Up"))

                specialExitButton(direction: "out", shape: CircleShape())
                    .accessibilityLabel(accessibilityLabel(for: "out", name: "Out"))

                specialExitButton(direction: "down", shape: ArrowShape.down)
                    .accessibilityLabel(accessibilityLabel(for: "down", name: "Down"))
            }
            .frame(width: specialArrowSize)
            .padding(.top, 8)

            // 8-direction compass rose (right side)
            ZStack {
                // Radially positioned arrows
                ForEach(compassDirections, id: \.direction) { dir, rotation in
                    compassArrow(direction: dir, rotation: rotation)
                }
            }
            .frame(width: compassSize, height: compassSize)
            .padding(.top, 8)
        }
    }

    // MARK: - Subviews

    /// Special exit button (up, out, down) with custom shape.
    ///
    /// - Parameters:
    ///   - direction: Exit direction string
    ///   - shape: SwiftUI Shape to render (arrow or circle)
    /// - Returns: View with shape, styling, and optional tap gesture
    private func specialExitButton<S: Shape>(
        direction: String,
        shape: S
    ) -> some View {
        let isActive = exits.contains(direction)
        let isTappable = isActive && onDirectionTap != nil

        return shape
            .fill(isActive ? CompassColor.activeExit : CompassColor.inactiveExit)
            .opacity(isActive ? 0.95 : 0.3)
            .animation(.easeInOut(duration: 0.2), value: isActive)
            .shadow(
                color: isActive ? CompassColor.activeExit.opacity(0.4) : .clear,
                radius: 3,
                x: 0,
                y: 1
            )
            .frame(width: specialArrowSize, height: specialArrowSize)
            .contentShape(Rectangle()) // Ensure full tap area
            .onTapGesture {
                if isTappable {
                    onDirectionTap?(direction)
                }
            }
            .if(isTappable) { view in
                view.accessibilityAddTraits(.isButton)
                    .accessibilityHint("Double tap to move \(direction)")
            }
    }

    /// Compass arrow for 8 cardinal/diagonal directions.
    ///
    /// - Parameters:
    ///   - direction: Exit direction string (e.g., "n", "ne")
    ///   - rotation: Arrow rotation angle in degrees
    /// - Returns: Positioned arrow view with styling and optional tap gesture
    private func compassArrow(direction: String, rotation: Double) -> some View {
        let isActive = exits.contains(direction)
        let isTappable = isActive && onDirectionTap != nil

        return ArrowShape.up
            .fill(isActive ? CompassColor.activeExit : CompassColor.inactiveExit)
            .opacity(isActive ? 0.95 : 0.3)
            .animation(.easeInOut(duration: 0.2), value: isActive)
            .shadow(
                color: isActive ? CompassColor.activeExit.opacity(0.4) : .clear,
                radius: 3,
                x: 0,
                y: 1
            )
            .frame(width: arrowSize, height: arrowSize)
            .rotationEffect(.degrees(rotation))
            .position(arrowPosition(for: direction))
            .contentShape(Rectangle())
            .onTapGesture {
                if isTappable {
                    onDirectionTap?(direction)
                }
            }
            .accessibilityLabel(accessibilityLabel(for: direction))
            .if(isTappable) { view in
                view.accessibilityAddTraits(.isButton)
                    .accessibilityHint("Double tap to move \(directionName(for: direction))")
            }
    }

    // MARK: - Helper Methods

    /// Calculates position for compass arrow based on direction.
    ///
    /// - Parameter direction: Direction string (n, ne, e, se, s, sw, w, nw)
    /// - Returns: CGPoint position within 80x80pt compass frame
    private func arrowPosition(for direction: String) -> CGPoint {
        let center = compassSize / 2

        switch direction {
        case "n":
            return CGPoint(x: center, y: arrowSize / 2)
        case "ne":
            return CGPoint(x: compassSize - cornerOffset - arrowSize / 2, y: cornerOffset + arrowSize / 2)
        case "e":
            return CGPoint(x: compassSize - arrowSize / 2, y: center)
        case "se":
            return CGPoint(x: compassSize - cornerOffset - arrowSize / 2, y: compassSize - cornerOffset - arrowSize / 2)
        case "s":
            return CGPoint(x: center, y: compassSize - arrowSize / 2)
        case "sw":
            return CGPoint(x: cornerOffset + arrowSize / 2, y: compassSize - cornerOffset - arrowSize / 2)
        case "w":
            return CGPoint(x: arrowSize / 2, y: center)
        case "nw":
            return CGPoint(x: cornerOffset + arrowSize / 2, y: cornerOffset + arrowSize / 2)
        default:
            return CGPoint(x: center, y: center)
        }
    }

    /// Generates accessibility label for exit.
    ///
    /// - Parameters:
    ///   - direction: Exit direction string
    ///   - name: Optional readable name (defaults to capitalized direction)
    /// - Returns: Accessibility label string
    private func accessibilityLabel(for direction: String, name: String? = nil) -> String {
        let exitName = name ?? direction.capitalized
        let isActive = exits.contains(direction)
        let status = isActive ? "available" : "unavailable"
        return "\(exitName) exit \(status)"
    }

    /// Converts direction abbreviation to full name for accessibility.
    ///
    /// - Parameter direction: Direction abbreviation (e.g., "n", "ne", "up")
    /// - Returns: Full direction name (e.g., "north", "northeast", "up")
    private func directionName(for direction: String) -> String {
        switch direction {
        case "n": return "north"
        case "ne": return "northeast"
        case "e": return "east"
        case "se": return "southeast"
        case "s": return "south"
        case "sw": return "southwest"
        case "w": return "west"
        case "nw": return "northwest"
        case "up": return "up"
        case "down": return "down"
        case "out": return "out"
        default: return direction
        }
    }
}

// MARK: - Arrow Shapes

/// Custom arrow shape for compass directions and special exits.
///
/// Provides static shapes for up and down arrows matching Illthorn's SVG paths:
/// - Up: Arrow pointing upward
/// - Down: Arrow pointing downward
///
/// The shape is designed to be rotated for different directions.
private struct ArrowShape: Shape {
    enum Direction {
        case up, down
    }

    let direction: Direction

    static var up: ArrowShape { ArrowShape(direction: .up) }
    static var down: ArrowShape { ArrowShape(direction: .down) }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height

        switch direction {
        case .up:
            // Up arrow (based on Illthorn SVG: M10 2 L15 8 L12 8 L12 18 L8 18 L8 8 L5 8 Z)
            // Scaled to rect dimensions
            path.move(to: CGPoint(x: width * 0.5, y: height * 0.1))  // Top point
            path.addLine(to: CGPoint(x: width * 0.75, y: height * 0.4))  // Right shoulder
            path.addLine(to: CGPoint(x: width * 0.6, y: height * 0.4))  // Right shaft top
            path.addLine(to: CGPoint(x: width * 0.6, y: height * 0.9))  // Right shaft bottom
            path.addLine(to: CGPoint(x: width * 0.4, y: height * 0.9))  // Left shaft bottom
            path.addLine(to: CGPoint(x: width * 0.4, y: height * 0.4))  // Left shaft top
            path.addLine(to: CGPoint(x: width * 0.25, y: height * 0.4))  // Left shoulder
            path.closeSubpath()

        case .down:
            // Down arrow (based on Illthorn SVG: M10 18 L15 12 L12 12 L12 2 L8 2 L8 12 L5 12 Z)
            // Scaled to rect dimensions
            path.move(to: CGPoint(x: width * 0.5, y: height * 0.9))  // Bottom point
            path.addLine(to: CGPoint(x: width * 0.75, y: height * 0.6))  // Right shoulder
            path.addLine(to: CGPoint(x: width * 0.6, y: height * 0.6))  // Right shaft bottom
            path.addLine(to: CGPoint(x: width * 0.6, y: height * 0.1))  // Right shaft top
            path.addLine(to: CGPoint(x: width * 0.4, y: height * 0.1))  // Left shaft top
            path.addLine(to: CGPoint(x: width * 0.4, y: height * 0.6))  // Left shaft bottom
            path.addLine(to: CGPoint(x: width * 0.25, y: height * 0.6))  // Left shoulder
            path.closeSubpath()
        }

        return path
    }
}

// MARK: - Circle Shape

/// Simple circle shape for "out" exit.
///
/// Based on Illthorn SVG circle element (cx="10" cy="10" r="8").
private struct CircleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) * 0.4  // 80% diameter (r=8 out of 10)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.addEllipse(in: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        return path
    }
}
