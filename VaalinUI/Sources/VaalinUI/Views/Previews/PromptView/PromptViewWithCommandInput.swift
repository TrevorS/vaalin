// ABOUTME: Preview file for PromptView showing integration with CommandInputView in HStack layout

import SwiftUI
import VaalinCore

/// Preview provider for PromptView integration with CommandInputView.
///
/// Shows the complete command input area layout:
/// - PromptView (44x44 box) on the left
/// - CommandInputView (full-width input) on the right
///
/// This preview demonstrates the actual layout used in the application,
/// verifying that the compact prompt box sits correctly next to the input field.
struct PromptViewWithCommandInputPreview: PreviewProvider {
    static var previews: some View {
        PromptWithInputLayout()
            .previewDisplayName("With Command Input (HStack)")
            .preferredColorScheme(.dark)
    }

    /// Preview showing PromptView positioned to the left of CommandInputView in HStack
    struct PromptWithInputLayout: View {
        @State private var promptViewModel: PromptViewModel
        @State private var inputViewModel: CommandInputViewModel

        init() {
            let (prompt, input) = Self.makePreviewData()
            _promptViewModel = State(initialValue: prompt)
            _inputViewModel = State(initialValue: input)
        }

        @MainActor
        private static func makePreviewData() -> (PromptViewModel, CommandInputViewModel) {
            let eventBus = EventBus()
            let history = CommandHistory()

            let prompt = PromptViewModel(eventBus: eventBus)
            prompt.promptText = ">"

            let input = CommandInputViewModel(commandHistory: history)

            return (prompt, input)
        }

        var body: some View {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Prompt Display Integration")
                        .font(.headline)
                    Text("Compact 44x44 prompt box sits to the LEFT of command input")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                Spacer()

                // Prompt + Input in HStack (positioned at bottom like in real app)
                HStack(spacing: 8) {
                    PromptView(viewModel: promptViewModel)

                    CommandInputView(viewModel: inputViewModel) { command in
                        // In real app, this would send to server
                        // swiftlint:disable:next no_print_statements
                        print("Submitted: \(command)")  // Print acceptable in preview code
                    }
                }
                .padding(12)
                .background(Color(nsColor: .windowBackgroundColor))
            }
            .frame(width: 700, height: 400)
        }
    }
}
