// ABOUTME: Preview file for PromptView showing all GemStone IV prompt scenarios in a story board grid

import SwiftUI
import VaalinCore

/// Preview provider for PromptView showing all realistic prompt scenarios.
///
/// Story board displays 10 different GemStone IV prompt states in a grid layout:
/// - Normal (>)
/// - Roundtime (R>)
/// - Casting (C>)
/// - Hidden/Invis/RT (HiR>)
/// - Kneel/Sit/Poison (KsP>)
/// - Bleed/Stun/Prone (!Sp>)
/// - Joined/Webbed (JW>)
/// - Disease/Immobile (DI>)
/// - Unconscious (U>)
/// - Kitchen Sink (!DHIJKPRSW>) - all statuses combined
///
/// This single preview shows all prompt variations, making it easy to verify
/// the 44x44px box handles all realistic status combinations correctly.
struct PromptViewStoryBoardPreview: PreviewProvider {
    static var previews: some View {
        PromptStoryBoard()
            .previewDisplayName("📖 Story Board - All Scenarios")
            .preferredColorScheme(.dark)
    }

    /// Story board showing all realistic GemStone IV prompt scenarios in a grid
    struct PromptStoryBoard: View {
        @State private var scenarios: [(label: String, prompt: String)] = [
            ("Normal", ">"),
            ("Roundtime", "R>"),
            ("Casting", "C>"),
            ("Hidden/Invis/RT", "HiR>"),
            ("Kneel/Sit/Poison", "KsP>"),
            ("Bleed/Stun/Prone", "!Sp>"),
            ("Joined/Webbed", "JW>"),
            ("Disease/Immobile", "DI>"),
            ("Unconscious", "U>"),
            ("Kitchen Sink", "!DHIJKPRSW>")
        ]

        var body: some View {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("GemStone IV Prompt Scenarios")
                        .font(.headline)
                    Text("Testing 44x44px box with realistic status combinations")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ],
                        spacing: 20
                    ) {
                        ForEach(scenarios, id: \.label) { scenario in
                            VStack(spacing: 8) {
                                Text(scenario.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                PromptView(viewModel: makeViewModel(scenario.prompt))

                                Text("'\(scenario.prompt)'")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .fontDesign(.monospaced)
                            }
                        }
                    }
                    .padding(20)
                }
                .background(Color(nsColor: .windowBackgroundColor))
            }
            .frame(width: 800, height: 600)
        }
    }

    // MARK: - Sample Data

    /// Creates a view model with specified prompt text
    @MainActor
    private static func makeViewModel(_ promptText: String) -> PromptViewModel {
        let eventBus = EventBus()
        let viewModel = PromptViewModel(eventBus: eventBus)
        viewModel.promptText = promptText
        return viewModel
    }
}
