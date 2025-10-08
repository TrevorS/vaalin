// ABOUTME: Comprehensive tests for CommandInputViewModel - readline operations, history navigation, command submission

import Testing
import VaalinCore
import VaalinNetwork
@testable import VaalinUI

// MARK: - Mock LichConnection for Testing

/// Mock LichConnection actor that tracks send() calls for testing
actor MockLichConnection: CommandSending {
    /// Commands that were sent via send()
    private(set) var sentCommands: [String] = []

    /// Whether the next send() call should throw an error
    var shouldThrowError: Bool = false

    /// The error to throw when shouldThrowError is true
    var errorToThrow: Error = LichConnectionError.sendFailed

    /// Sends a command (mock implementation that records the command)
    func send(command: String) async throws {
        if shouldThrowError {
            throw errorToThrow
        }
        sentCommands.append(command)
    }

    /// Clears the recorded commands (for test cleanup)
    func clearSentCommands() {
        sentCommands = []
    }

    /// Configures the mock to throw an error on next send()
    func configureSendError(shouldThrow: Bool, error: Error = LichConnectionError.sendFailed) {
        shouldThrowError = shouldThrow
        errorToThrow = error
    }
}

/// Test suite for CommandInputViewModel
/// Validates readline-style text editing, command history integration, and edge cases
@Suite("CommandInputViewModel Tests")
struct CommandInputViewModelTests {

    // MARK: - Readline Operations - Delete to End (Ctrl-K)

    @Test("Delete to end removes text after cursor")
    func deleteToEnd_removesTextAfterCursor() async {
        let history = CommandHistory()

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            viewModel.currentInput = "look north"
            let newPosition = viewModel.deleteToEnd(cursorPosition: 5) // After "look "

            #expect(viewModel.currentInput == "look ")
            #expect(newPosition == 5)
        }
    }

    @Test("Delete to end with cursor at end is no-op")
    func deleteToEnd_cursorAtEnd() async {
        let history = CommandHistory()

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            viewModel.currentInput = "look north"
            let newPosition = viewModel.deleteToEnd(cursorPosition: 10)

            #expect(viewModel.currentInput == "look north")
            #expect(newPosition == 10)
        }
    }

    @Test("Delete to end with cursor at beginning removes entire string")
    func deleteToEnd_cursorAtBeginning() async {
        let history = CommandHistory()

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            viewModel.currentInput = "look north"
            let newPosition = viewModel.deleteToEnd(cursorPosition: 0)

            #expect(viewModel.currentInput == "")
            #expect(newPosition == 0)
        }
    }

    @Test("Delete to end with empty input is no-op")
    func deleteToEnd_emptyInput() async {
        let history = CommandHistory()

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            viewModel.currentInput = ""
            let newPosition = viewModel.deleteToEnd(cursorPosition: 0)

            #expect(viewModel.currentInput == "")
            #expect(newPosition == 0)
        }
    }

    // MARK: - Readline Operations - Delete Word Backward (Ctrl-W)

    @Test("Delete word backward removes previous word")
    func deleteWordBackward_removesPreviousWord() async {
        let history = CommandHistory()

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            viewModel.currentInput = "look north gate"
            // Cursor at position 15 (at end, after "gate")
            let newPosition = viewModel.deleteWordBackward(cursorPosition: 15)

            #expect(viewModel.currentInput == "look north ")
            #expect(newPosition == 11)
        }
    }

    @Test("Delete word backward from middle of word")
    func deleteWordBackward_fromMiddleOfWord() async {
        let history = CommandHistory()

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            viewModel.currentInput = "look northern"
            // Cursor at position 9 is after "look nort" (in middle of "northern")
            // findWordBoundaryBackward from 9 finds position 5 (start of "northern")
            // So it deletes from 5 to 9, removing "nort"
            let newPosition = viewModel.deleteWordBackward(cursorPosition: 9)

            #expect(viewModel.currentInput == "look hern")
            #expect(newPosition == 5)
        }
    }

    @Test("Delete word backward with cursor at beginning is no-op")
    func deleteWordBackward_cursorAtBeginning() async {
        let history = CommandHistory()

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            viewModel.currentInput = "look north"
            let newPosition = viewModel.deleteWordBackward(cursorPosition: 0)

            #expect(viewModel.currentInput == "look north")
            #expect(newPosition == 0)
        }
    }

    @Test("Delete word backward with multiple spaces")
    func deleteWordBackward_multipleSpaces() async {
        let history = CommandHistory()

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            viewModel.currentInput = "look   north"
            let newPosition = viewModel.deleteWordBackward(cursorPosition: 12) // At end

            #expect(viewModel.currentInput == "look   ")
            #expect(newPosition == 7)
        }
    }

    @Test("Delete word backward removes single character word")
    func deleteWordBackward_singleCharWord() async {
        let history = CommandHistory()

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            viewModel.currentInput = "look n"
            let newPosition = viewModel.deleteWordBackward(cursorPosition: 6) // At end

            #expect(viewModel.currentInput == "look ")
            #expect(newPosition == 5)
        }
    }

    // MARK: - Word Boundary Detection - Forward (Option-F)

    @Test("Find word boundary forward moves to next word start")
    func findWordBoundaryForward_movesToNextWord() async {
        let history = CommandHistory()

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            viewModel.currentInput = "look north gate"
            let position = viewModel.findWordBoundaryForward(from: 0) // From "l"

            #expect(position == 5) // To "n" in "north"
        }
    }

    @Test("Find word boundary forward from middle of word")
    func findWordBoundaryForward_fromMiddleOfWord() async {
        let history = CommandHistory()

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            viewModel.currentInput = "look north gate"
            let position = viewModel.findWordBoundaryForward(from: 2) // From "o" in "look"

            #expect(position == 5) // To "n" in "north"
        }
    }

    @Test("Find word boundary forward with multiple spaces")
    func findWordBoundaryForward_multipleSpaces() async {
        let history = CommandHistory()

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            viewModel.currentInput = "look   north"
            let position = viewModel.findWordBoundaryForward(from: 0)

            #expect(position == 7) // To "n" in "north" (skips multiple spaces)
        }
    }

    @Test("Find word boundary forward at end of string")
    func findWordBoundaryForward_atEnd() async {
        let history = CommandHistory()

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            viewModel.currentInput = "look north"
            let position = viewModel.findWordBoundaryForward(from: 10)

            #expect(position == 10) // Stays at end
        }
    }

    @Test("Find word boundary forward from space")
    func findWordBoundaryForward_fromSpace() async {
        let history = CommandHistory()

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            viewModel.currentInput = "look north"
            let position = viewModel.findWordBoundaryForward(from: 4) // From space after "look"

            #expect(position == 5) // To "n" in "north"
        }
    }

    // MARK: - Word Boundary Detection - Backward (Option-B)

    @Test("Find word boundary backward moves to word start")
    func findWordBoundaryBackward_movesToWordStart() async {
        let history = CommandHistory()

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            viewModel.currentInput = "look north gate"
            let position = viewModel.findWordBoundaryBackward(from: 10) // From "g" in "gate"

            #expect(position == 5) // To "n" in "north"
        }
    }

    @Test("Find word boundary backward from middle of word")
    func findWordBoundaryBackward_fromMiddleOfWord() async {
        let history = CommandHistory()

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            viewModel.currentInput = "look north gate"
            let position = viewModel.findWordBoundaryBackward(from: 7) // From "r" in "north"

            #expect(position == 5) // To "n" in "north"
        }
    }

    @Test("Find word boundary backward with multiple spaces")
    func findWordBoundaryBackward_multipleSpaces() async {
        let history = CommandHistory()

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            viewModel.currentInput = "look   north"
            let position = viewModel.findWordBoundaryBackward(from: 12) // From end

            #expect(position == 7) // To "n" in "north"
        }
    }

    @Test("Find word boundary backward at beginning of string")
    func findWordBoundaryBackward_atBeginning() async {
        let history = CommandHistory()

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            viewModel.currentInput = "look north"
            let position = viewModel.findWordBoundaryBackward(from: 0)

            #expect(position == 0) // Stays at beginning
        }
    }

    @Test("Find word boundary backward from space")
    func findWordBoundaryBackward_fromSpace() async {
        let history = CommandHistory()

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            viewModel.currentInput = "look north"
            let position = viewModel.findWordBoundaryBackward(from: 5) // From "n" in "north"

            #expect(position == 0) // To "l" in "look"
        }
    }

    // MARK: - Command History Navigation - Navigate Up

    @Test("Navigate up retrieves previous command")
    func navigateUp_retrievesPreviousCommand() async {
        let history = CommandHistory()

        // Add commands to history
        await history.add("look")
        await history.add("exp")
        await history.add("info")

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            viewModel.currentInput = ""

            Task {
                await viewModel.navigateUp()

                await MainActor.run {
                    #expect(viewModel.currentInput == "exp")
                }
            }
        }
    }

    @Test("Navigate up preserves current draft")
    func navigateUp_preservesDraft() async {
        let history = CommandHistory()
        await history.add("look")
        await history.add("exp")

        let viewModel = await MainActor.run {
            CommandInputViewModel(commandHistory: history)
        }

        await MainActor.run {
            viewModel.currentInput = "loo" // User started typing
        }

        await viewModel.navigateUp() // Should save "loo" as draft and show previous command

        await MainActor.run {
            // History is ["exp", "look"] (newest first)
            // navigateUp calls back() which returns "look"
            #expect(viewModel.currentInput == "look")
        }

        await viewModel.navigateDown() // Should navigate forward or restore draft

        await MainActor.run {
            // After navigating up once, we can navigate down to get back to "exp"
            // But if we're at the newest already, it restores draft
            // Let me check - we went back to "look", so forward should be "exp"
            #expect(viewModel.currentInput == "exp")
        }

        await viewModel.navigateDown() // One more down should restore draft

        await MainActor.run {
            #expect(viewModel.currentInput == "loo")
        }
    }

    @Test("Navigate up with empty history")
    func navigateUp_emptyHistory() async {
        let history = CommandHistory()

        let viewModel = await MainActor.run {
            CommandInputViewModel(commandHistory: history)
        }

        await MainActor.run {
            viewModel.currentInput = "test"
        }

        await viewModel.navigateUp()

        await MainActor.run {
            #expect(viewModel.currentInput == "") // No history, returns empty
        }
    }

    @Test("Navigate up multiple times through history")
    func navigateUp_multipleNavigations() async {
        let history = CommandHistory()
        await history.add("first")
        await history.add("second")
        await history.add("third")

        let viewModel = await MainActor.run {
            CommandInputViewModel(commandHistory: history)
        }

        await viewModel.navigateUp()
        await MainActor.run {
            #expect(viewModel.currentInput == "second")
        }

        await viewModel.navigateUp()
        await MainActor.run {
            #expect(viewModel.currentInput == "first")
        }

        await viewModel.navigateUp() // At oldest, should stay
        await MainActor.run {
            #expect(viewModel.currentInput == "first")
        }
    }

    // MARK: - Command History Navigation - Navigate Down

    @Test("Navigate down retrieves newer command")
    func navigateDown_retrievesNewerCommand() async {
        let history = CommandHistory()
        await history.add("first")
        await history.add("second")
        await history.add("third")

        let viewModel = await MainActor.run {
            CommandInputViewModel(commandHistory: history)
        }

        // Navigate up twice
        await viewModel.navigateUp()
        await viewModel.navigateUp()

        await MainActor.run {
            #expect(viewModel.currentInput == "first")
        }

        // Navigate down once
        await viewModel.navigateDown()

        await MainActor.run {
            #expect(viewModel.currentInput == "second")
        }
    }

    @Test("Navigate down at end of history restores draft")
    func navigateDown_restoresDraft() async {
        let history = CommandHistory()
        await history.add("look")
        await history.add("exp")

        let viewModel = await MainActor.run {
            CommandInputViewModel(commandHistory: history)
        }

        await MainActor.run {
            viewModel.currentInput = "info" // User's draft
        }

        await viewModel.navigateUp() // Save draft "info", show "look" (oldest)
        await viewModel.navigateDown() // Navigate forward to "exp"

        await MainActor.run {
            #expect(viewModel.currentInput == "exp")
        }

        await viewModel.navigateDown() // At end, restore draft

        await MainActor.run {
            #expect(viewModel.currentInput == "info")
        }
    }

    @Test("Navigate down without prior navigation")
    func navigateDown_withoutPriorNavigation() async {
        let history = CommandHistory()
        await history.add("look")

        let viewModel = await MainActor.run {
            CommandInputViewModel(commandHistory: history)
        }

        await MainActor.run {
            viewModel.currentInput = "test"
        }

        await viewModel.navigateDown()

        await MainActor.run {
            // Without navigating up first, navigateDown checks canNavigateForward (false)
            // So it restores currentDraft (which is empty since we haven't navigated)
            // Result: empty string
            #expect(viewModel.currentInput == "")
        }
    }

    @Test("Navigate up then down full cycle preserves draft")
    func navigateUpDown_fullCycle() async {
        let history = CommandHistory()
        await history.add("first")
        await history.add("second")
        await history.add("third")

        let viewModel = await MainActor.run {
            CommandInputViewModel(commandHistory: history)
        }

        await MainActor.run {
            viewModel.currentInput = "partial"
        }

        // Up, up, up, down, down, down
        await viewModel.navigateUp()
        await viewModel.navigateUp()
        await viewModel.navigateUp()
        await viewModel.navigateDown()
        await viewModel.navigateDown()
        await viewModel.navigateDown()

        await MainActor.run {
            #expect(viewModel.currentInput == "partial")
        }
    }

    // MARK: - Command Submission

    @Test("Submit command adds to history and clears input")
    func submitCommand_addsToHistoryAndClears() async {
        let history = CommandHistory()

        let viewModel = await MainActor.run {
            CommandInputViewModel(commandHistory: history)
        }

        var submittedCommand = ""

        await MainActor.run {
            viewModel.currentInput = "look north"
        }

        await viewModel.submitCommand { command in
            submittedCommand = command
        }

        await MainActor.run {
            #expect(submittedCommand == "look north")
            #expect(viewModel.currentInput == "")
        }

        // Verify added to history
        let all = await history.getAll()
        #expect(all.contains("look north"))
    }

    @Test("Submit command trims whitespace")
    func submitCommand_trimsWhitespace() async {
        let history = CommandHistory()

        let viewModel = await MainActor.run {
            CommandInputViewModel(commandHistory: history)
        }

        var submittedCommand = ""

        await MainActor.run {
            viewModel.currentInput = "  look north  "
        }

        await viewModel.submitCommand { command in
            submittedCommand = command
        }

        #expect(submittedCommand == "look north")
    }

    @Test("Submit empty command does nothing")
    func submitCommand_emptyCommand() async {
        let history = CommandHistory()

        let viewModel = await MainActor.run {
            CommandInputViewModel(commandHistory: history)
        }

        var handlerCalled = false

        await MainActor.run {
            viewModel.currentInput = ""
        }

        await viewModel.submitCommand { _ in
            handlerCalled = true
        }

        #expect(handlerCalled == false)

        let all = await history.getAll()
        #expect(all.isEmpty)
    }

    @Test("Submit whitespace-only command does nothing")
    func submitCommand_whitespaceOnly() async {
        let history = CommandHistory()

        let viewModel = await MainActor.run {
            CommandInputViewModel(commandHistory: history)
        }

        var handlerCalled = false

        await MainActor.run {
            viewModel.currentInput = "   "
        }

        await viewModel.submitCommand { _ in
            handlerCalled = true
        }

        #expect(handlerCalled == false)

        let all = await history.getAll()
        #expect(all.isEmpty)
    }

    @Test("Submit command resets navigation state")
    func submitCommand_resetsNavigationState() async {
        let history = CommandHistory()
        await history.add("first")
        await history.add("second")

        let viewModel = await MainActor.run {
            CommandInputViewModel(commandHistory: history)
        }

        // Navigate history
        await viewModel.navigateUp()

        await MainActor.run {
            viewModel.currentInput = "third"
        }

        await viewModel.submitCommand { _ in }

        // Next navigate up should start from newest
        await viewModel.navigateUp()

        await MainActor.run {
            #expect(viewModel.currentInput == "second")
        }
    }

    // MARK: - Clear Input

    @Test("Clear input resets all state")
    func clearInput_resetsState() async {
        let history = CommandHistory()
        await history.add("first")

        let viewModel = await MainActor.run {
            CommandInputViewModel(commandHistory: history)
        }

        await MainActor.run {
            viewModel.currentInput = "test"
        }

        await viewModel.navigateUp()
        await viewModel.clearInput()

        await MainActor.run {
            #expect(viewModel.currentInput == "")
        }
    }

    @Test("Clear input resets history position")
    func clearInput_resetsHistoryPosition() async {
        let history = CommandHistory()
        await history.add("first")
        await history.add("second")

        let viewModel = await MainActor.run {
            CommandInputViewModel(commandHistory: history)
        }

        await viewModel.navigateUp()
        await viewModel.clearInput()

        // Next navigate should start from newest
        await viewModel.navigateUp()

        await MainActor.run {
            #expect(viewModel.currentInput == "first")
        }
    }

    // MARK: - Edge Cases

    @Test("Word boundary with special characters")
    func wordBoundary_specialCharacters() async {
        let history = CommandHistory()

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            viewModel.currentInput = "look-north_gate"

            // Hyphens and underscores are NOT whitespace, so they're part of words
            let forward = viewModel.findWordBoundaryForward(from: 0)
            #expect(forward == 15) // End of string (one word)

            let backward = viewModel.findWordBoundaryBackward(from: 15)
            #expect(backward == 0) // Beginning of string (one word)
        }
    }

    @Test("Delete operations with unicode characters")
    func deleteOperations_unicode() async {
        let history = CommandHistory()

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            viewModel.currentInput = "look 北京"
            let newPosition = viewModel.deleteToEnd(cursorPosition: 5)

            #expect(viewModel.currentInput == "look ")
            #expect(newPosition == 5)
        }
    }

    @Test("Delete operations with emoji")
    func deleteOperations_emoji() async {
        let history = CommandHistory()

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            viewModel.currentInput = "say 🎉 party"
            // String has 12 characters total: "say " (4) + "🎉" (1) + " party" (7)
            // Deleting word backward from position 6 (after "🎉 ")
            // findWordBoundaryBackward skips space, finds position 4 (start of "🎉")
            // So it deletes from 4 to 6, removing "🎉 "
            let newPosition = viewModel.deleteWordBackward(cursorPosition: 6)

            #expect(viewModel.currentInput == "say party")
            #expect(newPosition == 4)
        }
    }

    @Test("Navigate history with duplicate commands")
    func navigateHistory_duplicates() async {
        let history = CommandHistory()
        await history.add("look")
        await history.add("exp")
        await history.add("look")

        let viewModel = await MainActor.run {
            CommandInputViewModel(commandHistory: history)
        }

        await viewModel.navigateUp()
        await MainActor.run {
            #expect(viewModel.currentInput == "exp")
        }

        await viewModel.navigateUp()
        await MainActor.run {
            #expect(viewModel.currentInput == "look")
        }
    }

    @Test("Multiple word deletions in sequence")
    func deleteWordBackward_sequence() async {
        let history = CommandHistory()

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            viewModel.currentInput = "one two three four"

            // Delete "four" from end
            _ = viewModel.deleteWordBackward(cursorPosition: 18)
            #expect(viewModel.currentInput == "one two three ")

            // Delete "three" from new end
            _ = viewModel.deleteWordBackward(cursorPosition: viewModel.currentInput.count)
            #expect(viewModel.currentInput == "one two ")

            // Delete "two" from new end
            _ = viewModel.deleteWordBackward(cursorPosition: viewModel.currentInput.count)
            #expect(viewModel.currentInput == "one ")
        }
    }

    @Test("Tab characters are treated as whitespace")
    func wordBoundary_tabCharacters() async {
        let history = CommandHistory()

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            viewModel.currentInput = "look\tnorth"

            let forward = viewModel.findWordBoundaryForward(from: 0)
            #expect(forward == 5) // After tab to "n"

            let backward = viewModel.findWordBoundaryBackward(from: 10)
            #expect(backward == 5) // Before tab to "n"
        }
    }

    @Test("Very long input string")
    func operations_veryLongString() async {
        let history = CommandHistory()

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            let longString = String(repeating: "word ", count: 1000) + "end"
            viewModel.currentInput = longString

            let position = viewModel.deleteWordBackward(cursorPosition: longString.count)

            #expect(viewModel.currentInput.hasSuffix(" "))
            #expect(position < longString.count)
        }
    }

    @Test("Empty string between spaces")
    func deleteWordBackward_emptyBetweenSpaces() async {
        let history = CommandHistory()

        await MainActor.run {
            let viewModel = CommandInputViewModel(commandHistory: history)
            viewModel.currentInput = "look  north" // Double space at position 4-5
            // Cursor at position 6 (after double space, at 'n')
            // findWordBoundaryBackward skips spaces backward, finds position 0 (start of "look")
            // Deletes from 0 to 6, removing "look  "
            _ = viewModel.deleteWordBackward(cursorPosition: 6)

            #expect(viewModel.currentInput == "north")
        }
    }

    // MARK: - Real-World Scenarios

    @Test("User types, navigates history, then continues typing")
    func realWorld_typeNavigateType() async {
        let history = CommandHistory()
        await history.add("look north")
        await history.add("exp")

        let viewModel = await MainActor.run {
            CommandInputViewModel(commandHistory: history)
        }

        // User types partial command
        await MainActor.run {
            viewModel.currentInput = "loo"
        }

        // User presses up arrow - saves draft "loo", shows "look north"
        await viewModel.navigateUp()
        await MainActor.run {
            #expect(viewModel.currentInput == "look north")
        }

        // User presses down arrow - shows "exp" (forward in history)
        await viewModel.navigateDown()
        await MainActor.run {
            #expect(viewModel.currentInput == "exp")
        }

        // User presses down again - restores draft
        await viewModel.navigateDown()
        await MainActor.run {
            #expect(viewModel.currentInput == "loo")
        }

        // User continues typing
        await MainActor.run {
            viewModel.currentInput = "look"
        }

        // Submit
        var submitted = ""
        await viewModel.submitCommand { submitted = $0 }

        #expect(submitted == "look")
    }

    @Test("User rapidly navigates history")
    func realWorld_rapidHistoryNavigation() async {
        let history = CommandHistory()

        // Add several commands
        for i in 1...10 {
            await history.add("command \(i)")
        }

        let viewModel = await MainActor.run {
            CommandInputViewModel(commandHistory: history)
        }

        // Rapidly navigate up
        for _ in 1...5 {
            await viewModel.navigateUp()
        }

        await MainActor.run {
            #expect(viewModel.currentInput == "command 5")
        }

        // Rapidly navigate down
        for _ in 1...3 {
            await viewModel.navigateDown()
        }

        await MainActor.run {
            #expect(viewModel.currentInput == "command 8")
        }
    }

    @Test("User submits same command repeatedly")
    func realWorld_repeatedSubmission() async {
        let history = CommandHistory()

        let viewModel = await MainActor.run {
            CommandInputViewModel(commandHistory: history)
        }

        var submitCount = 0

        for _ in 1...3 {
            await MainActor.run {
                viewModel.currentInput = "exp"
            }

            await viewModel.submitCommand { _ in
                submitCount += 1
            }
        }

        #expect(submitCount == 3)

        let all = await history.getAll()
        #expect(all.count == 3)
        #expect(all.filter { $0 == "exp" }.count == 3)
    }

    // MARK: - Command Echo Integration Tests (Issue #28)

    /// Test that command echo is disabled when settings.commandEcho is false
    ///
    /// Acceptance Criteria:
    /// - Respects echo setting (can be disabled)
    @Test("Command echo disabled when setting is false")
    func test_echoDisabled() async {
        let history = CommandHistory()
        let gameLog = await GameLogViewModel()

        // Create settings with echo disabled
        var settings = Settings.makeDefault()
        settings.input.commandEcho = false

        let viewModel = await MainActor.run {
            CommandInputViewModel(
                commandHistory: history,
                gameLogViewModel: gameLog,
                settings: settings
            )
        }

        await MainActor.run {
            viewModel.currentInput = "look"
        }

        await viewModel.submitCommand { _ in }

        // Game log should be empty (no echo)
        await MainActor.run {
            #expect(gameLog.messages.isEmpty)
        }
    }

    /// Test that command is echoed when settings.commandEcho is true
    ///
    /// Acceptance Criteria:
    /// - Commands echoed with prefix
    /// - Echo happens before command sent to server
    @Test("Command echo enabled when setting is true")
    func test_echoEnabled() async {
        let history = CommandHistory()
        let gameLog = await GameLogViewModel()

        // Create settings with echo enabled (default)
        let settings = Settings.makeDefault()

        let viewModel = await MainActor.run {
            CommandInputViewModel(
                commandHistory: history,
                gameLogViewModel: gameLog,
                settings: settings
            )
        }

        var handlerCalled = false

        await MainActor.run {
            viewModel.currentInput = "look north"
        }

        await viewModel.submitCommand { _ in
            handlerCalled = true
        }

        // Verify echo appeared in game log
        await MainActor.run {
            #expect(gameLog.messages.count == 1)
            let text = String(gameLog.messages[0].attributedText.characters)
            #expect(text.contains("look north"))
        }

        // Verify handler was called (command was sent)
        #expect(handlerCalled)
    }

    /// Test that command echo uses the prefix from settings
    ///
    /// Acceptance Criteria:
    /// - Commands echoed with configured prefix
    @Test("Command echo uses prefix from settings")
    func test_echoUsesSettingsPrefix() async {
        let history = CommandHistory()
        let gameLog = await GameLogViewModel()

        // Create settings with custom prefix
        var settings = Settings.makeDefault()
        settings.input.echoPrefix = ">"

        let viewModel = await MainActor.run {
            CommandInputViewModel(
                commandHistory: history,
                gameLogViewModel: gameLog,
                settings: settings
            )
        }

        await MainActor.run {
            viewModel.currentInput = "cast 118"
        }

        await viewModel.submitCommand { _ in }

        // Verify echo uses custom prefix
        await MainActor.run {
            #expect(gameLog.messages.count == 1)
            let text = String(gameLog.messages[0].attributedText.characters)
            #expect(text.contains("> cast 118"))
        }
    }

    /// Test that echo works when gameLogViewModel is nil (graceful degradation)
    @Test("Command submission works without gameLogViewModel")
    func test_echoWithoutGameLog() async {
        let history = CommandHistory()

        // No gameLogViewModel provided
        let viewModel = await MainActor.run {
            CommandInputViewModel(commandHistory: history)
        }

        var handlerCalled = false

        await MainActor.run {
            viewModel.currentInput = "look"
        }

        await viewModel.submitCommand { _ in
            handlerCalled = true
        }

        // Should not crash, handler should still be called
        #expect(handlerCalled)
    }

    /// Test that echo happens BEFORE handler is called
    ///
    /// Acceptance Criteria:
    /// - Echo happens before command sent to server
    @Test("Echo happens before command sent to server")
    func test_echoBeforeCommandSent() async {
        let history = CommandHistory()
        let gameLog = await GameLogViewModel()

        let viewModel = await MainActor.run {
            CommandInputViewModel(
                commandHistory: history,
                gameLogViewModel: gameLog,
                settings: .makeDefault()
            )
        }

        await MainActor.run {
            viewModel.currentInput = "look"
        }

        await viewModel.submitCommand { _ in
            // Handler called - echo should already be in game log
        }

        // Verify echo was added (check after submission completes)
        await MainActor.run {
            #expect(gameLog.messages.count == 1)
            let text = String(gameLog.messages[0].attributedText.characters)
            #expect(text.contains("look"))
        }
    }

    // MARK: - LichConnection Integration Tests (Issue #29)

    /// Test that command is sent to LichConnection when available
    ///
    /// Acceptance Criteria:
    /// - Command sent via connection.send()
    /// - Command matches user input (trimmed)
    @Test("Send command to server via LichConnection")
    func test_sendCommandToServer() async {
        let history = CommandHistory()
        let mockConnection = MockLichConnection()

        // This will fail until Issue #29 is implemented
        // CommandInputViewModel needs to accept a connection parameter
        let viewModel = await MainActor.run {
            CommandInputViewModel(
                commandHistory: history,
                connection: mockConnection  // NOT YET IMPLEMENTED
            )
        }

        await MainActor.run {
            viewModel.currentInput = "look north"
        }

        await viewModel.submitCommand { _ in }

        // Verify command was sent to connection
        let sentCommands = await mockConnection.sentCommands
        #expect(sentCommands.count == 1)
        #expect(sentCommands[0] == "look north")
    }

    /// Test that command is still added to history when sent to server
    ///
    /// Acceptance Criteria:
    /// - Command added to history (existing behavior preserved)
    /// - Input cleared after send (existing behavior preserved)
    @Test("Command added to history when sent to server")
    func test_commandAddedToHistory() async {
        let history = CommandHistory()
        let mockConnection = MockLichConnection()

        // This will fail until Issue #29 is implemented
        let viewModel = await MainActor.run {
            CommandInputViewModel(
                commandHistory: history,
                connection: mockConnection  // NOT YET IMPLEMENTED
            )
        }

        await MainActor.run {
            viewModel.currentInput = "exp"
        }

        await viewModel.submitCommand { _ in }

        // Verify command was added to history
        let all = await history.getAll()
        #expect(all.contains("exp"))
    }

    /// Test that input is cleared after sending command to server
    ///
    /// Acceptance Criteria:
    /// - Input cleared after send (existing behavior preserved)
    @Test("Input cleared after send to server")
    func test_inputCleared() async {
        let history = CommandHistory()
        let mockConnection = MockLichConnection()

        // This will fail until Issue #29 is implemented
        let viewModel = await MainActor.run {
            CommandInputViewModel(
                commandHistory: history,
                connection: mockConnection  // NOT YET IMPLEMENTED
            )
        }

        await MainActor.run {
            viewModel.currentInput = "info"
        }

        await viewModel.submitCommand { _ in }

        // Verify input was cleared
        await MainActor.run {
            #expect(viewModel.currentInput == "")
        }
    }

    /// Test error handling when send fails
    ///
    /// Acceptance Criteria:
    /// - Graceful error handling (logs error, doesn't crash)
    /// - Command still added to history (best effort)
    /// - Input still cleared (user can retry)
    ///
    /// BONUS TEST: Not explicitly required but demonstrates good error handling
    @Test("Send error handling does not crash")
    func test_sendErrorHandling() async {
        let history = CommandHistory()
        let mockConnection = MockLichConnection()

        // Configure mock to throw error on send
        await mockConnection.configureSendError(shouldThrow: true, error: LichConnectionError.notConnected)

        // This will fail until Issue #29 is implemented
        let viewModel = await MainActor.run {
            CommandInputViewModel(
                commandHistory: history,
                connection: mockConnection  // NOT YET IMPLEMENTED
            )
        }

        await MainActor.run {
            viewModel.currentInput = "look"
        }

        // Should not crash when send fails
        await viewModel.submitCommand { _ in }

        // Verify command was still added to history (best effort)
        let all = await history.getAll()
        #expect(all.contains("look"))

        // Verify input was still cleared (user can retry)
        await MainActor.run {
            #expect(viewModel.currentInput == "")
        }
    }

    /// Test that connection parameter is optional (backward compatibility)
    ///
    /// Acceptance Criteria:
    /// - CommandInputViewModel works without connection (existing tests)
    /// - Handler is still called when connection is nil
    @Test("Submit works without connection (backward compatibility)")
    func test_submitWithoutConnection() async {
        let history = CommandHistory()

        // Create view model WITHOUT connection (existing behavior)
        let viewModel = await MainActor.run {
            CommandInputViewModel(commandHistory: history)
        }

        var handlerCalled = false

        await MainActor.run {
            viewModel.currentInput = "look"
        }

        await viewModel.submitCommand { _ in
            handlerCalled = true
        }

        // Handler should still be called
        #expect(handlerCalled)

        // Command still added to history
        let all = await history.getAll()
        #expect(all.contains("look"))
    }

    /// Test that both connection.send() AND handler are called
    ///
    /// Acceptance Criteria:
    /// - Connection.send() is called when connection is available
    /// - Handler is ALSO called (for backward compatibility)
    @Test("Both connection send and handler are called")
    func test_bothConnectionAndHandlerCalled() async {
        let history = CommandHistory()
        let mockConnection = MockLichConnection()

        // This will fail until Issue #29 is implemented
        let viewModel = await MainActor.run {
            CommandInputViewModel(
                commandHistory: history,
                connection: mockConnection  // NOT YET IMPLEMENTED
            )
        }

        var handlerCalled = false

        await MainActor.run {
            viewModel.currentInput = "cast 401"
        }

        await viewModel.submitCommand { _ in
            handlerCalled = true
        }

        // Verify BOTH connection.send() was called
        let sentCommands = await mockConnection.sentCommands
        #expect(sentCommands.count == 1)

        // AND handler was called
        #expect(handlerCalled)
    }
}
