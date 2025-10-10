// ABOUTME: Preview file for CommandInputView showing empty and prefilled states

import SwiftUI
import VaalinCore

// swiftlint:disable no_print_statements

/// Preview provider for CommandInputView in empty and with-text states.
///
/// Shows both basic input field states:
/// - **Empty**: Clean input field with placeholder text
/// - **With Text**: Input field prefilled with a command to show typing state
///
/// Both previews use the same styling and demonstrate the Liquid Glass input design.
struct CommandInputViewStatesPreview: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview 1: Empty state
            CommandInputView(
                viewModel: makeEmptyViewModel(),
                onSubmit: { command in
                    print("Submitted: \(command)")
                }
            )
            .frame(width: 600, height: 80)
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .previewDisplayName("Empty")
            .preferredColorScheme(.dark)

            // Preview 2: With text - Shows typing state
            CommandInputView(
                viewModel: prefilledViewModel(),
                onSubmit: { command in
                    print("Submitted: \(command)")
                }
            )
            .frame(width: 600, height: 80)
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .previewDisplayName("With Text")
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Sample Data

    /// Creates a view model for empty state previews.
    @MainActor
    private static func makeEmptyViewModel() -> CommandInputViewModel {
        let history = CommandHistory()
        return CommandInputViewModel(commandHistory: history)
    }

    /// Creates a view model with pre-filled text for preview.
    @MainActor
    private static func prefilledViewModel() -> CommandInputViewModel {
        let history = CommandHistory()
        let viewModel = CommandInputViewModel(commandHistory: history)
        viewModel.currentInput = "look at my vultite greatsword"
        return viewModel
    }
}
// swiftlint:enable no_print_statements
