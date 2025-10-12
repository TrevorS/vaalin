// ABOUTME: StreamsBarView is a placeholder for Phase 4 stream filtering with Liquid Glass translucent styling

import SwiftUI

/// Placeholder view for stream filtering bar (Phase 4 feature).
///
/// `StreamsBarView` displays a colored box with "Streams (Phase 4)" text centered,
/// using macOS 26 Liquid Glass translucent material. The full stream filtering
/// implementation (stream chips, active streams, filtering UI) will be added in Phase 4.
///
/// ## Design Specifications
///
/// - **Material**: `.regularMaterial` for translucent background
/// - **Height**: Configurable via `height` parameter from `Settings.layout.streamsHeight`
/// - **Border**: Subtle border matching Liquid Glass aesthetic
/// - **Text**: Centered placeholder text with secondary color
/// - **Shadow**: Subtle depth for visual separation
///
/// ## Layout Integration
///
/// Positioned between GameLogView and CommandInputView in the center column of MainView:
/// ```
/// VStack {
///     StreamsBarView(height: settings.layout.streamsHeight)  // Placeholder
///     GameLogView(...)  // Fills remaining space
///     CommandInputView(...)  // Bottom fixed height
/// }
/// ```
///
/// ## Performance
///
/// - **Rendering**: < 1ms (static placeholder)
/// - **Updates**: None (no dynamic content in Phase 2)
///
/// ## Phase 4 Implementation
///
/// Future enhancements (deferred to Phase 4):
/// - Stream chip rendering (StreamChip.swift)
/// - Active stream toggling
/// - Stream buffer switching
/// - Color-coded stream indicators
/// - Collapsible/expandable height
///
/// ## Example Usage
///
/// ```swift
/// StreamsBarView(height: 200)
///     .frame(width: 800)
/// ```
public struct StreamsBarView: View {
    // MARK: - Properties

    /// Height of the streams bar in points (from Settings.layout.streamsHeight)
    public let height: CGFloat

    // MARK: - Initialization

    /// Creates a streams bar placeholder with the specified height.
    ///
    /// - Parameter height: Height in points (default: 200)
    public init(height: CGFloat = 200) {
        self.height = height
    }

    // MARK: - Body

    @Environment(\.colorScheme) private var colorScheme

    public var body: some View {
        VStack {
            Text("Streams (Phase 4)")
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: height)
        .background(streamsBackground)
    }

    // MARK: - Subviews

    /// Translucent background with Liquid Glass styling
    private var streamsBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.regularMaterial)
            .overlay {
                // Subtle glass highlight
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.03 : 0.05),
                                Color.white.opacity(colorScheme == .dark ? 0.01 : 0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                // Subtle border
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        Color.white.opacity(colorScheme == .dark ? 0.15 : 0.1),
                        lineWidth: 0.5
                    )
            }
            .shadow(
                color: Color.black.opacity(0.08),
                radius: 4,
                y: 2
            )
    }
}
