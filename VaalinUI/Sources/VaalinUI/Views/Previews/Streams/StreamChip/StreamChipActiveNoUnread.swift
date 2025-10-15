// ABOUTME: StreamChip preview - Active state with no unread messages

import SwiftUI
import VaalinCore

#Preview("Active, No Unread") {
    VStack(spacing: 20) {
        // Thoughts stream - active, 0 unread
        StreamChip(
            streamInfo: StreamInfo(
                id: "thoughts",
                label: "Thoughts",
                defaultOn: true,
                color: "green",
                aliases: []
            ),
            unreadCount: 0,
            isActive: true,
            chipColor: Color(hex: "#a6e3a1")!, // Catppuccin Mocha green
            onToggle: { }
        )

        // Speech stream - active, 0 unread
        StreamChip(
            streamInfo: StreamInfo(
                id: "speech",
                label: "Speech",
                defaultOn: true,
                color: "green",
                aliases: []
            ),
            unreadCount: 0,
            isActive: true,
            chipColor: Color(hex: "#a6e3a1")!, // Catppuccin Mocha green
            onToggle: { }
        )

        // Logons stream - yellow, active, 0 unread
        StreamChip(
            streamInfo: StreamInfo(
                id: "logons",
                label: "Logons",
                defaultOn: true,
                color: "yellow",
                aliases: ["logon", "logoff", "death"]
            ),
            unreadCount: 0,
            isActive: true,
            chipColor: Color(hex: "#f9e2af")!, // Catppuccin Mocha yellow
            onToggle: { }
        )
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(hex: "#1e1e2e")) // Catppuccin Mocha base
}
