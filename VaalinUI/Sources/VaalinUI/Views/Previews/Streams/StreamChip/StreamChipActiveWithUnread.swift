// ABOUTME: StreamChip preview - Active state with unread count

import SwiftUI
import VaalinCore

#Preview("Active with Unread") {
    VStack(spacing: 20) {
        // Thoughts stream - green, 5 unread
        StreamChip(
            streamInfo: StreamInfo(
                id: "thoughts",
                label: "Thoughts",
                defaultOn: true,
                color: "green",
                aliases: []
            ),
            unreadCount: 5,
            isActive: true,
            chipColor: Color(hex: "#a6e3a1")!, // Catppuccin Mocha green
            onToggle: {
                print("Toggled thoughts stream")
            }
        )

        // Speech stream - green, 12 unread
        StreamChip(
            streamInfo: StreamInfo(
                id: "speech",
                label: "Speech",
                defaultOn: true,
                color: "green",
                aliases: []
            ),
            unreadCount: 12,
            isActive: true,
            chipColor: Color(hex: "#a6e3a1")!, // Catppuccin Mocha green
            onToggle: {
                print("Toggled speech stream")
            }
        )

        // Whispers stream - teal, 99+ unread
        StreamChip(
            streamInfo: StreamInfo(
                id: "whispers",
                label: "Whispers",
                defaultOn: true,
                color: "teal",
                aliases: ["whisper"]
            ),
            unreadCount: 150, // Should display as "99+"
            isActive: true,
            chipColor: Color(hex: "#94e2d5")!, // Catppuccin Mocha teal
            onToggle: {
                print("Toggled whispers stream")
            }
        )
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(hex: "#1e1e2e")) // Catppuccin Mocha base
}
