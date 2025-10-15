// ABOUTME: StreamChip preview - Long label edge case

import SwiftUI
import VaalinCore

#Preview("Long Labels") {
    VStack(spacing: 20) {
        // Normal length label for comparison
        StreamChip(
            streamInfo: StreamInfo(
                id: "speech",
                label: "Speech",
                defaultOn: true,
                color: "green",
                aliases: []
            ),
            unreadCount: 5,
            isActive: true,
            chipColor: Color(hex: "#a6e3a1")!,
            onToggle: {}
        )

        // Long label (should truncate with lineLimit(1))
        StreamChip(
            streamInfo: StreamInfo(
                id: "verylongstream",
                label: "Very Long Stream Name That Should Truncate",
                defaultOn: true,
                color: "teal",
                aliases: []
            ),
            unreadCount: 12,
            isActive: true,
            chipColor: Color(hex: "#94e2d5")!,
            onToggle: {}
        )

        // Multiple words
        StreamChip(
            streamInfo: StreamInfo(
                id: "combat",
                label: "Combat Events",
                defaultOn: true,
                color: "red",
                aliases: []
            ),
            unreadCount: 0,
            isActive: true,
            chipColor: Color(hex: "#f38ba8")!, // Catppuccin Mocha red
            onToggle: {}
        )

        // All caps
        StreamChip(
            streamInfo: StreamInfo(
                id: "system",
                label: "SYSTEM MESSAGES",
                defaultOn: true,
                color: "yellow",
                aliases: []
            ),
            unreadCount: 99,
            isActive: true,
            chipColor: Color(hex: "#f9e2af")!, // Catppuccin Mocha yellow
            onToggle: {}
        )

        // Horizontal layout with long labels
        HStack(spacing: 12) {
            StreamChip(
                streamInfo: StreamInfo(
                    id: "a",
                    label: "A",
                    defaultOn: true,
                    color: "green",
                    aliases: []
                ),
                unreadCount: 1,
                isActive: true,
                chipColor: Color(hex: "#a6e3a1")!,
                onToggle: {}
            )

            StreamChip(
                streamInfo: StreamInfo(
                    id: "medium",
                    label: "Medium Label",
                    defaultOn: true,
                    color: "teal",
                    aliases: []
                ),
                unreadCount: 10,
                isActive: true,
                chipColor: Color(hex: "#94e2d5")!,
                onToggle: {}
            )

            StreamChip(
                streamInfo: StreamInfo(
                    id: "longest",
                    label: "Extremely Long Label Text",
                    defaultOn: true,
                    color: "sapphire",
                    aliases: []
                ),
                unreadCount: 100,
                isActive: true,
                chipColor: Color(hex: "#74c7ec")!,
                onToggle: {}
            )
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(hex: "#1e1e2e")) // Catppuccin Mocha base
}
