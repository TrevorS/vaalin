// ABOUTME: Reusable panel container with Liquid Glass styling and collapse/expand functionality
// ABOUTME: Provides collapsible chrome for HUD panels with persistent state via Settings

import SwiftUI
import VaalinCore

/// Reusable panel container with Liquid Glass header and collapsible content.
///
/// `PanelContainer` provides a consistent panel chrome for all HUD panels (hands, vitals, compass, etc.).
/// Features a translucent Liquid Glass header with centered title and collapse/expand toggle button.
///
/// ## Liquid Glass Design
/// Uses `.ultraThinMaterial` background for the header to achieve macOS 26 Liquid Glass aesthetic:
/// - Translucent blur effect adapts to content behind panel
/// - Subtle depth separation from panel content
/// - Native macOS appearance matching system design language
///
/// ## Collapse State Persistence
/// Collapsed state persists via `Settings.layout.collapsed[panelID]`:
/// - Parent view binds to settings: `@Binding<Bool>` passed to container
/// - Toggle updates binding → triggers SettingsManager auto-save
/// - State restored on app restart
///
/// ## Fixed Height Behavior
/// Panels use fixed heights per requirements (FR-3.1):
/// - Hands: 140pt, Room: 160pt, Vitals: 160pt, Injuries: 180pt, Spells: 180pt
/// - Height applied to content area when expanded
/// - Collapsed: Shows header only (fixed ~30pt height)
///
/// ## Example Usage
/// ```swift
/// @State private var isCollapsed = false
///
/// PanelContainer(
///     title: "Hands",
///     isCollapsed: $isCollapsed,
///     height: 140
/// ) {
///     // Panel content goes here
///     VStack {
///         Text("Left: Empty")
///         Text("Right: Empty")
///     }
/// }
/// ```
///
/// ## Reference
/// Replaces Illthorn's `panel.lit.ts` HTML `<details>` element with native SwiftUI.
public struct PanelContainer<Content: View>: View {
    // MARK: - Properties

    /// Panel title displayed in header (e.g., "Hands", "Vitals").
    public let title: String

    /// Binding to collapsed state for persistence via Settings.
    @Binding public var isCollapsed: Bool

    /// Fixed height of panel content when expanded (in points).
    public let height: CGFloat

    /// Panel content view (provided via @ViewBuilder).
    private let content: () -> Content

    /// Tracks hover state for collapse button visual feedback.
    @State private var isHovering: Bool = false

    // MARK: - Constants

    /// Header height including padding (title + padding + border).
    private let headerHeight: CGFloat = 30

    // MARK: - Initializer

    /// Creates a panel container with collapse/expand functionality.
    ///
    /// - Parameters:
    ///   - title: Panel title for header
    ///   - isCollapsed: Binding to collapsed state (persisted via Settings)
    ///   - height: Fixed height of content area when expanded
    ///   - content: Panel content view (via @ViewBuilder)
    public init(
        title: String,
        isCollapsed: Binding<Bool>,
        height: CGFloat,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self._isCollapsed = isCollapsed
        self.height = height
        self.content = content
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Header with Liquid Glass material
            header

            // Collapsible content area
            if !isCollapsed {
                content()
                    .frame(height: height)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .transition(.move(edge: .bottom))
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    // MARK: - Subviews

    /// Panel header with Liquid Glass material, title, and collapse toggle.
    ///
    /// Layout: `[Title (centered)] [Chevron Button (right)]`
    ///
    /// **Liquid Glass**: `.ultraThinMaterial` provides translucent blur matching macOS 26 design.
    /// **Animation**: Smooth chevron rotation on collapse/expand (0.3s ease-in-out).
    /// **Accessibility**: VoiceOver announces collapse state and toggle action.
    private var header: some View {
        HStack(spacing: 0) {
            // Centered title
            Spacer()

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(1.0) // Letter spacing for uppercase title

            Spacer()

            // Collapse/expand toggle button (chevron)
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isCollapsed.toggle()
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color(nsColor: .controlColor))
                            .opacity(isHovering ? 0.5 : 0.35)
                            .frame(width: 20, height: 20)
                    )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovering = hovering
            }
            .accessibilityLabel(isCollapsed ? "Expand \(title)" : "Collapse \(title)")
            .accessibilityAddTraits(.isButton)
            .padding(.trailing, 8)
        }
        .frame(height: headerHeight)
        .background(.ultraThinMaterial) // Liquid Glass effect
        .overlay(
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Previews

#Preview("Expanded") {
    StatefulPreviewWrapper(isCollapsed: false) { isCollapsed in
        PanelContainer(
            title: "Hands",
            isCollapsed: isCollapsed,
            height: 140
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Left: Empty")
                    .font(.system(size: 13, design: .monospaced))
                Text("Right: Empty")
                    .font(.system(size: 13, design: .monospaced))
                Text("Prepared: None")
                    .font(.system(size: 13, design: .monospaced))
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
    .frame(width: 300, height: 200)
    .padding()
}

#Preview("Collapsed") {
    StatefulPreviewWrapper(isCollapsed: true) { isCollapsed in
        PanelContainer(
            title: "Vitals",
            isCollapsed: isCollapsed,
            height: 160
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Health:")
                        .font(.system(size: 11, weight: .medium))
                    Text("100/100")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.green)
                }
                HStack {
                    Text("Mana:")
                        .font(.system(size: 11, weight: .medium))
                    Text("85/85")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
    .frame(width: 300, height: 200)
    .padding()
}

// MARK: - Preview Helpers

/// Wrapper to provide stateful binding for previews
private struct StatefulPreviewWrapper<Content: View>: View {
    @State private var isCollapsed: Bool
    private let content: (Binding<Bool>) -> Content
    
    init(isCollapsed: Bool, @ViewBuilder content: @escaping (Binding<Bool>) -> Content) {
        self._isCollapsed = State(initialValue: isCollapsed)
        self.content = content
    }
    
    var body: some View {
        content($isCollapsed)
    }
}
