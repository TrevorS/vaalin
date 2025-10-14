// ABOUTME: StreamChip is a SwiftUI component for individual stream filtering chips with unread badges

import SwiftUI
import VaalinCore

/// Individual stream filtering chip with Liquid Glass styling.
///
/// StreamChip displays a single stream filter with:
/// - Stream label (from StreamInfo)
/// - Background color from theme palette
/// - Unread count badge (top-right corner)
/// - Toggle state visual feedback
/// - Tap gesture for toggling stream ON/OFF
///
/// ## Design Specifications
///
/// - **Material**: Liquid Glass translucent background
/// - **Color**: Theme palette color for stream type
/// - **Badge**: Circular overlay with count (hidden if 0)
/// - **Active State**: Full opacity, solid border
/// - **Inactive State**: Reduced opacity (0.5), dashed border
/// - **Dimensions**: Height 32pt, width auto-sized to content
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
            .contentShape(RoundedRectangle(cornerRadius: 16))
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
                    .offset(x: 6, y: -6) // Position outside chip bounds
            }
        }
        .opacity(isActive ? 1.0 : 0.5) // Dim inactive chips
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }

    /// Chip background with Liquid Glass styling
    private var chipBackground: some View {
        HStack(spacing: 6) {
            // Stream label text
            Text(streamInfo.label)
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundStyle(textColor)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(height: 32)
        .background(chipBackgroundMaterial)
    }

    /// Liquid Glass material with color and border
    private var chipBackgroundMaterial: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(chipColor.opacity(colorScheme == .dark ? 0.15 : 0.10))
            .background(
                // Translucent glass effect
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            )
            .overlay {
                // Glass highlight
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.08 : 0.12),
                                Color.white.opacity(colorScheme == .dark ? 0.02 : 0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                // Border (solid when active, dashed when inactive)
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        chipColor.opacity(isActive ? 0.6 : 0.3),
                        style: StrokeStyle(
                            lineWidth: isActive ? 1.5 : 1.0,
                            dash: isActive ? [] : [3, 2] // Dashed border when inactive
                        )
                    )
            }
            .shadow(
                color: chipColor.opacity(0.15),
                radius: 4,
                y: 2
            )
    }

    /// Unread count badge (circular overlay)
    private var unreadBadge: some View {
        Text(unreadCountString)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .frame(minWidth: 18, minHeight: 18)
            .background(
                Circle()
                    .fill(chipColor)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            )
            .overlay {
                Circle()
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
            }
    }

    // MARK: - Helpers

    /// Text color for chip label (adapts to color scheme)
    private var textColor: Color {
        // Use chip color for text when active, secondary color when inactive
        isActive ? chipColor : Color.secondary
    }

    /// Formatted unread count string (e.g., "5", "99+")
    private var unreadCountString: String {
        if unreadCount > 99 {
            return "99+"
        } else {
            return "\(unreadCount)"
        }
    }

    /// Accessibility value string describing chip state
    private var accessibilityValueString: String {
        if isActive {
            if unreadCount > 0 {
                return "Active, \(unreadCount) unread"
            } else {
                return "Active"
            }
        } else {
            return "Inactive"
        }
    }
}
