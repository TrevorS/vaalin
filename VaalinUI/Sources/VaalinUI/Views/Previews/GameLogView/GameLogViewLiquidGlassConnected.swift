// ABOUTME: Preview file for GameLogView showing complete Liquid Glass design (connected state)

import SwiftUI
import VaalinCore

/// Preview provider for GameLogView with complete Liquid Glass design.
///
/// Shows the three-layer visual hierarchy:
/// - LAYER 1: Window background (.ultraThinMaterial - subtle glass)
/// - LAYER 2: Game log content (OPAQUE #1e1e2e - solid anchor)
/// - LAYER 3: ConnectionStatusBar (.ultraThinMaterial - glass chrome)
///
/// This is the final design showcase demonstrating:
/// - Opaque content for readability (critical requirement)
/// - Glass chrome floating above content
/// - Catppuccin Mocha color palette
/// - macOS 26 Liquid Glass compliance
struct GameLogViewLiquidGlassConnectedPreview: PreviewProvider {
    static var previews: some View {
        let viewModel = GameLogViewModel(theme: .catppuccinMocha())

        Task { @MainActor in
            await viewModel.appendMessage(
                GameTag(name: ":text", text: "Connecting to GemStone IV...", state: .closed)
            )
            await viewModel.appendMessage(
                GameTag(name: ":text", text: "Connected successfully!", state: .closed)
            )
            await viewModel.appendMessage(
                GameTag(name: ":text", text: "> look", state: .closed)
            )
            await viewModel.appendMessage(
                GameTag(name: ":text", text: "[Abandoned Tower, Ruins]", state: .closed)
            )
            await viewModel.appendMessage(
                GameTag(
                    name: ":text",
                    text: """
                    Crumbling stone walls surround you. The ceiling has long since collapsed, \
                    leaving only jagged remnants reaching toward the sky. Rubble covers most of the floor, \
                    making passage difficult.
                    """,
                    state: .closed
                )
            )
            await viewModel.appendMessage(
                GameTag(name: ":text", text: "Obvious exits: north, south, east", state: .closed)
            )
            await viewModel.appendMessage(
                GameTag(name: ":text", text: "> attack troll", state: .closed)
            )
            await viewModel.appendMessage(
                GameTag(name: ":text", text: "You swing your sword at the troll!", state: .closed)
            )
            await viewModel.appendMessage(
                GameTag(name: ":text", text: "The troll parries your attack!", state: .closed)
            )
        }

        return VStack(spacing: 0) {
            // LAYER 3: Glass status bar (chrome layer - floats above content)
            ConnectionStatusBar(
                isConnected: true,
                serverName: "Lich 5",
                connectionDuration: 3661  // 1h 1m 1s
            )

            // LAYER 2: Opaque game log (content layer - solid anchor with visual depth)
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
        .previewDisplayName("Liquid Glass - Connected")
        .preferredColorScheme(.dark)
    }
}
