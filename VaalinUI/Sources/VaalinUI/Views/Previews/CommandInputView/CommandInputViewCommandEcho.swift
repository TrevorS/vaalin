// ABOUTME: Preview file for CommandInputView showing command echo integration with GameLogView

import SwiftUI
import VaalinCore

// swiftlint:disable no_print_statements

/// Preview provider for CommandInputView command echo feature.
///
/// Demonstrates the full command echo workflow (Issue #28):
/// - Commands are echoed to the game log with '›' prefix
/// - Echoed commands appear in dimmed color
/// - Integration between CommandInputView and GameLogViewModel
///
/// This preview shows the complete command input → echo → log flow that
/// users will see when typing commands in the application.
struct CommandInputViewCommandEchoPreview: PreviewProvider {
    static var previews: some View {
        CommandEchoDemo()
            .previewDisplayName("Command Echo Demo")
            .preferredColorScheme(.dark)
    }

    /// Preview demonstrating command echo feature (Issue #28)
    struct CommandEchoDemo: View {
        @State private var viewModel: CommandInputViewModel
        @State private var gameLog: GameLogViewModel

        init() {
            let (vm, log) = Self.makePreviewData()
            _viewModel = State(initialValue: vm)
            _gameLog = State(initialValue: log)
        }

        @MainActor
        private static func makePreviewData() -> (CommandInputViewModel, GameLogViewModel) {
            let history = CommandHistory()
            let gameLog = GameLogViewModel()
            let viewModel = CommandInputViewModel(
                commandHistory: history,
                gameLogViewModel: gameLog,
                settings: .makeDefault()
            )

            // Pre-populate with sample echoed commands
            Task { @MainActor in
                await gameLog.echoCommand("look", prefix: "›")
                await gameLog.echoCommand("inventory", prefix: "›")
                await gameLog.echoCommand("cast 118 at troll", prefix: "›")
            }

            return (viewModel, gameLog)
        }

        var body: some View {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Command Echo Feature")
                        .font(.headline)
                    Text("Commands are echoed with '›' prefix in dimmed color")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                // Game log showing echoed commands
                GameLogView(viewModel: gameLog)
                    .frame(height: 300)

                Divider()

                // Command input
                VStack(spacing: 8) {
                    Text("Type a command and press Enter to see it echo")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    CommandInputView(viewModel: viewModel) { command in
                        print("Submitted: \(command)")
                        // In real app, command would be sent to server here
                    }
                }
                .padding(12)
                .background(Color(nsColor: .windowBackgroundColor))
            }
            .frame(width: 700, height: 500)
        }
    }
}
// swiftlint:enable no_print_statements
