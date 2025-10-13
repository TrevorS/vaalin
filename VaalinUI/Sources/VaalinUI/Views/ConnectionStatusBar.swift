// ABOUTME: ConnectionStatusBar - Glass chrome status bar for connection state (Liquid Glass design)
//
// Displays connection status with:
// - Glass material background (.ultraThinMaterial)
// - Status indicator (green/red/yellow circle)
// - Connection info (server name, duration)
// - Accessibility support (Reduce Transparency fallback)
//
// Design: macOS 26 Liquid Glass - glass for CHROME, not content

import SwiftUI

/// Connection status bar with glass material (Liquid Glass chrome layer)
///
/// This component represents the "chrome" layer in Liquid Glass design:
/// - Floats above content with `.ultraThinMaterial`
/// - Provides functional transparency without obscuring content
/// - Responds to accessibility preferences (Reduce Transparency)
public struct ConnectionStatusBar: View {
    // MARK: - Properties

    /// Connection state
    public var isConnected: Bool

    /// Server name (e.g., "Lich 5")
    public var serverName: String

    /// Connection duration in seconds
    public var connectionDuration: TimeInterval

    /// Accessibility environment value
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    // MARK: - Initialization

    public init(
        isConnected: Bool = false,
        serverName: String = "Lich 5",
        connectionDuration: TimeInterval = 0
    ) {
        self.isConnected = isConnected
        self.serverName = serverName
        self.connectionDuration = connectionDuration
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 8) {
            // Connection indicator (colored circle with glow)
            statusIndicator

            // Status text
            Text(isConnected ? "Connected" : "Disconnected")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            // Server name (if connected)
            if isConnected {
                Text("•")
                    .foregroundStyle(.tertiary)
                Text(serverName)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Connection duration (if connected)
            if isConnected {
                Text(formatDuration(connectionDuration))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(height: 28)
        .background(backgroundMaterial)
        .overlay(bottomSeparator, alignment: .bottom)
    }

    // MARK: - Subviews

    /// Status indicator circle with color-coded glow
    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
            .shadow(
                color: statusColor.opacity(0.6),
                radius: 4
            )
    }

    /// Background material with accessibility fallback
    private var backgroundMaterial: some View {
        Group {
            if reduceTransparency {
                // Solid fallback for Reduce Transparency
                Color(red: 24 / 255, green: 24 / 255, blue: 37 / 255)  // Catppuccin Mocha Mantle
            } else {
                // Glass material (Liquid Glass chrome)
                Color.clear
                    .background(.ultraThinMaterial)
            }
        }
    }

    /// Bottom separator line for visual definition
    private var bottomSeparator: some View {
        Rectangle()
            .fill(.white.opacity(0.1))
            .frame(height: 1)
    }

    // MARK: - Computed Properties

    /// Status indicator color based on connection state
    private var statusColor: Color {
        isConnected
            ? Color(red: 166 / 255, green: 227 / 255, blue: 161 / 255)  // Catppuccin Mocha Green
            : Color(red: 243 / 255, green: 139 / 255, blue: 168 / 255)  // Catppuccin Mocha Red
    }

    // MARK: - Helpers

    /// Format connection duration as "Xh Ym"
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Previews

#Preview("Disconnected") {
    ConnectionStatusBar(
        isConnected: false,
        serverName: "Lich 5",
        connectionDuration: 0
    )
    .frame(width: 600)
    .preferredColorScheme(.dark)
}

#Preview("Connected - Short Duration") {
    ConnectionStatusBar(
        isConnected: true,
        serverName: "Lich 5",
        connectionDuration: 185  // 3m 5s
    )
    .frame(width: 600)
    .preferredColorScheme(.dark)
}

#Preview("Connected - Long Duration") {
    ConnectionStatusBar(
        isConnected: true,
        serverName: "Lich 5",
        connectionDuration: 8127  // 2h 15m 27s
    )
    .frame(width: 600)
    .preferredColorScheme(.dark)
}
