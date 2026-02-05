// ABOUTME: PromptView displays the last server prompt as a compact box to the left of command input

import SwiftUI
import VaalinCore

/// SwiftUI view displaying the current game prompt with translucent Liquid Glass styling.
///
/// `PromptView` renders the prompt text (e.g., ">", "$") in a compact badge-style box
/// positioned to the LEFT of the command input. It uses macOS 26 Liquid Glass translucent
/// materials and matches the visual style of CommandInputView but in a smaller, compact form.
///
/// ## Design Specifications
///
/// - **Material**: `.ultraThinMaterial` for translucent background
/// - **Font**: Monospace, size 14 (matches input)
/// - **Color**: `.secondary` for dimmed appearance
/// - **Size**: 44x44pt (compact square, matches input height)
/// - **Layout**: Positioned in HStack to left of command input
/// - **Border**: Subtle border matching Liquid Glass aesthetic
///
/// ## Performance
///
/// - **Rendering**: < 1ms per update (lightweight Text view)
/// - **Updates**: Driven by @Observable PromptViewModel changes
///
/// ## Example Usage
///
/// ```swift
/// let eventBus = EventBus()
/// let viewModel = PromptViewModel(eventBus: eventBus)
/// await viewModel.setup()
///
/// HStack(spacing: 8) {
///     PromptView(viewModel: viewModel)  // Compact 44x44 box
///     CommandInputView(viewModel: inputViewModel) { ... }  // Full-width input
/// }
/// ```
public struct PromptView: View {
    // MARK: - Properties

    /// View model managing prompt text and EventBus subscription
    @Bindable public var viewModel: PromptViewModel

    // MARK: - Initialization

    public init(viewModel: PromptViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    @Environment(\.colorScheme) private var colorScheme

    public var body: some View {
        Text(viewModel.promptText)
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(width: 44, height: 44)
            .background(promptBackground)
    }

    // MARK: - Subviews

    /// Compact translucent background matching Liquid Glass aesthetic
    private var promptBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.ultraThinMaterial)
            .overlay {
                // Very subtle glass highlight (less pronounced than input)
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.08),
                                Color.white.opacity(colorScheme == .dark ? 0.01 : 0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                // Very subtle border
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        Color.white.opacity(colorScheme == .dark ? 0.08 : 0.05),
                        lineWidth: 0.5
                    )
            }
            .shadow(
                color: Color.black.opacity(0.05),
                radius: 3,
                y: 1
            )
    }
}

// MARK: - Previews

// swiftlint:disable no_print_statements

#Preview("Story Board - All Scenarios") {
    PromptStoryBoard()
}

#Preview("With Command Input") {
    PromptWithInputLayout()
}

/// Story board showing all realistic GemStone IV prompt scenarios in a grid
private struct PromptStoryBoard: View {
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
    
    private func makeViewModel(_ promptText: String) -> PromptViewModel {
        let eventBus = EventBus()
        let viewModel = PromptViewModel(eventBus: eventBus)
        viewModel.promptText = promptText
        return viewModel
    }
}

/// Preview showing PromptView positioned to the left of CommandInputView in HStack
private struct PromptWithInputLayout: View {
    @State private var promptViewModel: PromptViewModel
    @State private var inputViewModel: CommandInputViewModel
    
    init() {
        let eventBus = EventBus()
        let history = CommandHistory()
        
        let prompt = PromptViewModel(eventBus: eventBus)
        prompt.promptText = ">"
        
        let input = CommandInputViewModel(commandHistory: history)
        
        _promptViewModel = State(initialValue: prompt)
        _inputViewModel = State(initialValue: input)
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
                    print("Submitted: \(command)")
                }
            }
            .padding(12)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 700, height: 400)
    }
}

// swiftlint:enable no_print_statements
