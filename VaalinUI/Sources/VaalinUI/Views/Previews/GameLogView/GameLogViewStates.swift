// ABOUTME: Preview file for GameLogView showing empty and populated states

import SwiftUI
import VaalinCore

/// Preview provider for GameLogView in empty and populated states.
///
/// Shows both states to test game log rendering:
/// - **Empty**: Disconnected with no messages
/// - **Populated**: Connected with sample styled messages showing Catppuccin Mocha theme colors
///
/// The populated preview demonstrates realistic game output with damage, speech, whisper,
/// healing, and loot messages using the actual theme color palette.
struct GameLogViewStatesPreview: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview 1: Empty state
            GameLogView(
                viewModel: GameLogViewModel(),
                isConnected: false
            )
            .frame(width: 600, height: 400)
            .previewDisplayName("Empty")
            .preferredColorScheme(.dark)

            // Preview 2: Populated state with sample messages
            GameLogView(
                viewModel: sampleViewModel(),
                isConnected: true
            )
            .frame(width: 600, height: 400)
            .previewDisplayName("Populated")
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Sample Data

    /// Creates a view model with sample game messages for preview.
    ///
    /// Demonstrates Catppuccin Mocha theme colors with realistic game output.
    /// Manually creates AttributedString with theme colors to show what actual
    /// TagRenderer + ThemeManager output looks like.
    private static func sampleViewModel() -> GameLogViewModel {
        let viewModel = GameLogViewModel()

        // Catppuccin Mocha colors from centralized theme
        let colors = (
            text: CatppuccinMocha.text,      // #cdd6f4 - text
            red: CatppuccinMocha.red,        // #f38ba8 - damage
            green: CatppuccinMocha.green,    // #a6e3a1 - speech/heal
            teal: CatppuccinMocha.teal,      // #94e2d5 - whisper
            yellow: CatppuccinMocha.peach    // #fab387 - warning (peach, not yellow)
        )

        // Sample messages with theme colors (damage = red, speech = green, etc.)
        let messages: [(String, Color)] = [
            ("You swing a vultite greatsword at a hobgoblin!", colors.red),
            ("  AS: +125 vs DS: +89 with AvD: +35 + d100 roll: +42 = +113", colors.text),
            ("   ... and hit for 23 points of damage!", colors.red),
            (">", colors.text),
            ("You say, \"Nice hit!\"", colors.green),
            ("Xanlin whispers, \"Watch out behind you!\"", colors.teal),
            ("The hobgoblin swings a short sword at you!", colors.text),
            ("  AS: +95 vs DS: +105 with AvD: +12 + d100 roll: +15 = +17", colors.text),
            ("   A clean miss.", colors.text),
            (">", colors.text),
            ("A warm feeling washes over you as your wounds heal!", colors.green),
            ("You search the hobgoblin.", colors.text),
            ("You discard the hobgoblin's useless equipment.", colors.text),
            ("He had 124 silvers on him.", colors.yellow),
            ("You gather the remaining 124 coins.", colors.yellow),
            (">", colors.text),
            ("Roundtime: 3 sec.", colors.text),
            ("[Wehnimer's Landing, Town Square]", colors.text),
            ("The bustling town comes alive around you.", colors.text),
            ("Obvious exits: north, south, east, west", colors.text),
            (">", colors.text)
        ]

        // Populate with styled messages showing theme colors
        for (text, color) in messages {
            var attributed = AttributedString(text)
            attributed.foregroundColor = color
            let tag = GameTag(name: "output", state: .closed)
            viewModel.messages.append(Message(attributedText: attributed, tags: [tag], streamID: nil))
        }

        return viewModel
    }
}
