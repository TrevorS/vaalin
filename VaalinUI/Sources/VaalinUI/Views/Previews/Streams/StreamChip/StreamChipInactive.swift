// ABOUTME: StreamChip preview - Inactive/disabled state

import SwiftUI
import VaalinCore

#Preview("Inactive/Disabled") {
    VStack(spacing: 20) {
        // Experience stream - inactive, 0 unread
        StreamChip(
            streamInfo: StreamInfo(
                id: "expr",
                label: "Experience",
                defaultOn: false,
                color: "sapphire",
                aliases: ["experience"]
            ),
            unreadCount: 0,
            isActive: false, // Inactive state
            chipColor: Color(hex: "#74c7ec")!, // Catppuccin Mocha sapphire
            onToggle: {
                print("Toggled experience stream")
            }
        )

        // Familiar stream - inactive, has unread (shows but dimmed)
        StreamChip(
            streamInfo: StreamInfo(
                id: "familiar",
                label: "Familiar",
                defaultOn: false,
                color: "mauve",
                aliases: []
            ),
            unreadCount: 3, // Badge still visible even when inactive
            isActive: false, // Inactive state
            chipColor: Color(hex: "#cba6f7")!, // Catppuccin Mocha mauve
            onToggle: {
                print("Toggled familiar stream")
            }
        )

        // Mixed: active and inactive chips together
        HStack(spacing: 12) {
            StreamChip(
                streamInfo: StreamInfo(
                    id: "thoughts",
                    label: "Thoughts",
                    defaultOn: true,
                    color: "green",
                    aliases: []
                ),
                unreadCount: 2,
                isActive: true,
                chipColor: Color(hex: "#a6e3a1")!,
                onToggle: {}
            )

            StreamChip(
                streamInfo: StreamInfo(
                    id: "expr",
                    label: "Experience",
                    defaultOn: false,
                    color: "sapphire",
                    aliases: []
                ),
                unreadCount: 0,
                isActive: false,
                chipColor: Color(hex: "#74c7ec")!,
                onToggle: {}
            )
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(hex: "#1e1e2e")) // Catppuccin Mocha base
}
