// ABOUTME: StreamChip is a SwiftUI component for individual stream filtering chips with unread badges

import SwiftUI
import VaalinCore

/// Individual stream filtering chip with minimal frosted styling.
///
/// StreamChip displays a single stream filter with:
/// - Stream label (from StreamInfo)
/// - Background color from theme palette
/// - Unread indicator dot (top-right corner, shows when unread)
/// - Toggle state visual feedback
/// - Tap gesture for toggling stream ON/OFF
///
/// ## Design Specifications
///
/// - **Material**: Minimal frosted glass background (.ultraThinMaterial)
/// - **Color**: Theme palette color for stream type
/// - **Badge**: Tiny dot indicator (8pt, hidden if 0 unread)
/// - **Active State**: Full opacity, subtle border
/// - **Inactive State**: Reduced opacity (0.5), dashed border
/// - **Dimensions**: Height 19pt, width auto-sized to content
///
/// ## Usage
///
/// ```swift
/// StreamChip(
///     streamInfo: StreamInfo(id: "thoughts", label: "Thoughts", ...),
///     unreadCount: 5,
///     isActive: true,
///     chipColor: .green,
///     onToggle: {
///         viewModel.toggleStream("thoughts")
///     }
/// )
/// ```
///
/// ## Accessibility
///
/// - Label: "\(streamInfo.label) stream chip"
/// - Hint: "Double tap to toggle stream filtering"
/// - Value: "Active, 5 unread" or "Inactive"
public struct StreamChip: View {
    // MARK: - Constants

    private enum Constants {
        static let chipHeight: CGFloat = 19
        static let cornerRadius: CGFloat = 10
        static let horizontalPadding: CGFloat = 8
        static let verticalPadding: CGFloat = 3
        static let contentSpacing: CGFloat = 4
        static let badgeOffsetX: CGFloat = 4
        static let badgeOffsetY: CGFloat = -4
        static let badgeDiameter: CGFloat = 8
        static let inactiveOpacity: CGFloat = 0.5
        static let animationDuration: CGFloat = 0.2
        static let fontSize: CGFloat = 10
    }

    // MARK: - Properties

    /// Stream metadata (id, label, etc.)
    public let streamInfo: StreamInfo

    /// Number of unread messages in this stream
    public let unreadCount: Int

    /// Whether this stream is currently active/enabled
    public let isActive: Bool

    /// Theme color for this chip (from palette)
    public let chipColor: Color

    /// Callback when chip is tapped to toggle state
    public let onToggle: () -> Void

    // MARK: - Initialization

    /// Creates a new stream chip with the specified properties.
    ///
    /// - Parameters:
    ///   - streamInfo: Stream metadata
    ///   - unreadCount: Number of unread messages (default: 0)
    ///   - isActive: Whether stream is active (default: true)
    ///   - chipColor: Theme color for chip background
    ///   - onToggle: Callback when chip is tapped
    public init(
        streamInfo: StreamInfo,
        unreadCount: Int = 0,
        isActive: Bool = true,
        chipColor: Color,
        onToggle: @escaping () -> Void
    ) {
        self.streamInfo = streamInfo
        self.unreadCount = unreadCount
        self.isActive = isActive
        self.chipColor = chipColor
        self.onToggle = onToggle
    }

    // MARK: - Body

    @Environment(\.colorScheme) private var colorScheme

    public var body: some View {
        chipContent
            .contentShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
            .onTapGesture {
                onToggle()
            }
            .accessibilityLabel("\(streamInfo.label) stream chip")
            .accessibilityHint("Double tap to toggle stream filtering")
            .accessibilityValue(accessibilityValueString)
    }

    // MARK: - Subviews

    /// Main chip content with background, label, and badge
    private var chipContent: some View {
        ZStack(alignment: .topTrailing) {
            // Chip background and label
            chipBackground

            // Unread badge overlay (top-right)
            if unreadCount > 0 {
                unreadBadge
                    .offset(x: Constants.badgeOffsetX, y: Constants.badgeOffsetY) // Position outside chip bounds
            }
        }
        .opacity(isActive ? 1.0 : Constants.inactiveOpacity) // Dim inactive chips
        .animation(.easeInOut(duration: Constants.animationDuration), value: isActive)
    }

    /// Chip background with minimal styling
    private var chipBackground: some View {
        HStack(spacing: Constants.contentSpacing) {
            // Stream label text
            Text(streamInfo.label)
                .font(.system(size: Constants.fontSize, weight: .medium, design: .default))
                .foregroundStyle(textColor)
                .lineLimit(1)
        }
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.vertical, Constants.verticalPadding)
        .frame(height: Constants.chipHeight)
        .background(chipBackgroundMaterial)
    }

    /// Minimal frosted glass material with subtle styling
    private var chipBackgroundMaterial: some View {
        RoundedRectangle(cornerRadius: Constants.cornerRadius)
            .fill(.ultraThinMaterial)
            .overlay {
                // Border (solid when active, dashed when inactive)
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .strokeBorder(
                        chipColor.opacity(isActive ? 0.4 : 0.2),
                        lineWidth: 0.75
                    )
            }
            .shadow(
                color: chipColor.opacity(0.06),
                radius: 1.5,
                y: 1
            )
    }

    /// Unread indicator dot (tiny circle when unread)
    private var unreadBadge: some View {
        Circle()
            .fill(chipColor)
            .frame(width: Constants.badgeDiameter, height: Constants.badgeDiameter)
            .shadow(color: .black.opacity(0.15), radius: 1, y: 0.5)
    }

    // MARK: - Helpers

    /// Text color for chip label (adapts to color scheme)
    private var textColor: Color {
        // Use chip color for text when active, secondary color when inactive
        isActive ? chipColor : Color.secondary
    }

    /// Accessibility value string describing chip state
    private var accessibilityValueString: String {
        if isActive {
            if unreadCount > 0 {
                return "Active, unread"
            } else {
                return "Active"
            }
        } else {
            return "Inactive"
        }
    }
}
