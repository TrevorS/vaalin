// ABOUTME: Preview file for GameLogView showing realistic combat scenario

import SwiftUI
import VaalinCore

/// Preview provider for GameLogView with combat log.
///
/// Shows realistic combat sequence with 10 messages:
/// - Player attacks
/// - Enemy reactions
/// - Damage dealt/taken
/// - Combat resolution
struct GameLogViewCombatLogPreview: PreviewProvider {
    static var previews: some View {
        let viewModel = GameLogViewModel(theme: .catppuccinMocha())

        Task { @MainActor in
            await viewModel.appendMessage(
                GameTag(name: ":text", text: "> attack troll", state: .closed)
            )
            await viewModel.appendMessage(
                GameTag(name: ":text", text: "You swing your sword at the troll!", state: .closed)
            )
            await viewModel.appendMessage(
                GameTag(name: ":text", text: "The troll parries your attack with its club!", state: .closed)
            )
            await viewModel.appendMessage(
                GameTag(name: ":text", text: "The troll swings at you!", state: .closed)
            )
            await viewModel.appendMessage(
                GameTag(name: ":text", text: "You take 45 damage!", state: .closed)
            )
            await viewModel.appendMessage(
                GameTag(name: ":text", text: "Health: 155/200", state: .closed)
            )
            await viewModel.appendMessage(
                GameTag(name: ":text", text: "> attack", state: .closed)
            )
            await viewModel.appendMessage(
                GameTag(name: ":text", text: "You strike the troll with your sword!", state: .closed)
            )
            await viewModel.appendMessage(
                GameTag(name: ":text", text: "The troll staggers from the blow!", state: .closed)
            )
            await viewModel.appendMessage(
                GameTag(name: ":text", text: "The troll collapses, defeated.", state: .closed)
            )
        }

        return GameLogView(viewModel: viewModel)
            .frame(width: 800, height: 600)
            .previewDisplayName("Combat Log")
            .preferredColorScheme(.dark)
    }
}
