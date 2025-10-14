// ABOUTME: Preview file for GameLogView showing Liquid Glass design (disconnected state)

import SwiftUI
import VaalinCore

/// Preview provider for GameLogView with Liquid Glass design (disconnected).
///
/// Shows the same three-layer hierarchy in disconnected state:
/// - LAYER 1: Window background (.ultraThinMaterial - subtle glass)
/// - LAYER 2: Game log content (OPAQUE #1e1e2e - solid anchor)
/// - LAYER 3: ConnectionStatusBar with red indicator (disconnected)
///
/// Use for:
/// - Comparing connected vs disconnected status bar states
/// - Validating red status indicator visibility
/// - Empty log state with glass chrome
struct GameLogViewLiquidGlassDisconnectedPreview: PreviewProvider {
    static var previews: some View {
        let viewModel = GameLogViewModel()

        // Note: Empty state - no need to wait for theme
        return VStack(spacing: 0) {
            // LAYER 3: Glass status bar (chrome layer - disconnected state)
            ConnectionStatusBar(
                isConnected: false,
                serverName: "Lich 5",
                connectionDuration: 0
            )

            // LAYER 2: Opaque game log (content layer - empty with visual depth)
            GameLogView(viewModel: viewModel)
                .background(Color(red: 30 / 255, green: 30 / 255, blue: 46 / 255))  // Catppuccin Mocha Base
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(
                    color: .black.opacity(0.5),
                    radius: 8,
                    x: 0,
                    y: 4
                )
                .overlay(
                    // Inset border for subtle 3D depth effect
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.05),  // Top highlight
                                    .clear                 // Fade out
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .padding(16)  // Breathing room around content
        }
        .frame(width: 800, height: 600)
        .background(
            // LAYER 1: Subtle window background (very light glass)
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
        )
        .previewDisplayName("Liquid Glass - Disconnected")
        .preferredColorScheme(.dark)
    }
}
