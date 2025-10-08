// ABOUTME: CommandInputViewModel manages command input state with readline-style editing
// ABOUTME: and command history integration

import Foundation
import Observation
import VaalinCore

/// View model for command input with readline-style text editing and history navigation.
///
/// `CommandInputViewModel` provides state management for the command input field, including
/// cursor position tracking, readline-style text manipulation operations, and integration
/// with the CommandHistory actor for up/down arrow navigation.
///
/// ## Readline Operations
///
/// Supports standard Emacs/Bash-style key bindings:
/// - **Ctrl-A**: Move to beginning of line
/// - **Ctrl-E**: Move to end of line
/// - **Ctrl-U**: Delete to beginning of line
/// - **Ctrl-K**: Delete to end of line
/// - **Ctrl-W**: Delete word backward
/// - **Option-B**: Move word backward
/// - **Option-F**: Move word forward
/// - **Option-Delete**: Delete word backward
///
/// ## History Navigation
///
/// Integrates with CommandHistory actor for command recall:
/// - **Up Arrow**: Navigate to previous command
/// - **Down Arrow**: Navigate to next command
/// - **Enter**: Submit command and add to history
///
/// ## Architecture
///
/// ```
/// CommandInputView (SwiftUI)
///        ↓
/// CommandInputViewModel (@Observable, @MainActor)
///        ↓
/// CommandHistory (actor)
/// ```
///
/// ## Thread Safety
///
/// All properties and methods are isolated to MainActor, ensuring thread-safe access
/// from SwiftUI views. CommandHistory operations are async calls to the actor.
///
/// ## Example Usage
///
/// ```swift
/// let history = CommandHistory()
/// let viewModel = CommandInputViewModel(commandHistory: history)
///
/// // Submit command
/// viewModel.currentInput = "look"
/// await viewModel.submitCommand { command in
///     sendToServer(command)
/// }
///
/// // Navigate history
/// await viewModel.navigateUp()  // Recalls previous command
/// ```
@Observable
@MainActor
public final class CommandInputViewModel {
    // MARK: - Properties

    /// Current text in the input field
    public var currentInput: String = ""

    /// Command history reference for navigation
    private let commandHistory: CommandHistory

    /// Temporary storage for current draft when navigating history
    /// Preserves what user was typing before pressing up arrow
    private var currentDraft: String = ""

    /// Whether we're currently navigating history (vs. typing new command)
    private var isNavigatingHistory: Bool = false

    // MARK: - Initialization

    /// Creates a new CommandInputViewModel with command history integration.
    ///
    /// - Parameter commandHistory: CommandHistory actor for storing and recalling commands
    public init(commandHistory: CommandHistory) {
        self.commandHistory = commandHistory
    }

    // MARK: - Public Methods - Command Submission

    /// Submits the current command and clears the input.
    ///
    /// Adds the command to history, resets navigation state, and invokes the
    /// provided handler to send the command to the game server.
    ///
    /// - Parameter handler: Closure to execute with the submitted command
    ///
    /// ## Example
    /// ```swift
    /// await viewModel.submitCommand { command in
    ///     await connection.send(command)
    /// }
    /// ```
    public func submitCommand(handler: (String) -> Void) async {
        let command = currentInput.trimmingCharacters(in: .whitespaces)

        // Don't submit empty commands
        guard !command.isEmpty else { return }

        // Add to history
        await commandHistory.add(command)

        // Reset state
        currentInput = ""
        currentDraft = ""
        isNavigatingHistory = false

        // Execute handler
        handler(command)
    }

    /// Clears the input field and resets history navigation.
    public func clearInput() async {
        currentInput = ""
        currentDraft = ""
        isNavigatingHistory = false
        await commandHistory.resetPosition()
    }

    // MARK: - Public Methods - History Navigation

    /// Navigates to the previous command in history (up arrow).
    ///
    /// Preserves the current draft (what user was typing) when first entering
    /// history navigation mode, allowing restoration when navigating back down.
    public func navigateUp() async {
        // Save current draft on first navigation
        if !isNavigatingHistory {
            currentDraft = currentInput
            isNavigatingHistory = true
        }

        // Get previous command from history
        let command = await commandHistory.back()
        currentInput = command
    }

    /// Navigates to the next command in history (down arrow).
    ///
    /// When reaching the end of history (newest command), restores the original
    /// draft that the user was typing before navigating history.
    public func navigateDown() async {
        // Check if we can navigate forward
        let canNavigate = await commandHistory.canNavigateForward()

        if canNavigate {
            let command = await commandHistory.forward()
            currentInput = command
        } else {
            // At end of history - restore draft
            currentInput = currentDraft
            currentDraft = ""
            isNavigatingHistory = false
        }
    }

    // MARK: - Public Methods - Readline Operations

    /// Moves cursor to the beginning of the line (Ctrl-A).
    ///
    /// Note: SwiftUI TextField cursor position is managed via TextEditor selection.
    /// This method is called by the view which handles the actual cursor movement.
    public func moveCursorToStart() {
        // Implementation handled by view - this is for semantic clarity
        // View will use @FocusedBinding and NSTextView introspection
    }

    /// Moves cursor to the end of the line (Ctrl-E).
    public func moveCursorToEnd() {
        // Implementation handled by view
    }

    /// Deletes text from cursor to beginning of line (Ctrl-U).
    ///
    /// - Parameter cursorPosition: Current cursor position in the text
    /// - Returns: New cursor position after deletion
    @discardableResult
    public func deleteToStart(cursorPosition: Int) -> Int {
        guard cursorPosition > 0 else { return 0 }

        let index = currentInput.index(currentInput.startIndex, offsetBy: cursorPosition)
        currentInput.removeSubrange(currentInput.startIndex..<index)

        return 0 // Move cursor to start
    }

    /// Deletes text from cursor to end of line (Ctrl-K).
    ///
    /// - Parameter cursorPosition: Current cursor position in the text
    /// - Returns: New cursor position (unchanged)
    @discardableResult
    public func deleteToEnd(cursorPosition: Int) -> Int {
        guard cursorPosition < currentInput.count else { return cursorPosition }

        let index = currentInput.index(currentInput.startIndex, offsetBy: cursorPosition)
        currentInput.removeSubrange(index..<currentInput.endIndex)

        return cursorPosition // Cursor stays in same position
    }

    /// Deletes the previous word (Ctrl-W or Option-Delete).
    ///
    /// - Parameter cursorPosition: Current cursor position in the text
    /// - Returns: New cursor position after deletion
    @discardableResult
    public func deleteWordBackward(cursorPosition: Int) -> Int {
        guard cursorPosition > 0 else { return 0 }

        let wordStart = findWordBoundaryBackward(from: cursorPosition)

        let startIndex = currentInput.index(currentInput.startIndex, offsetBy: wordStart)
        let endIndex = currentInput.index(currentInput.startIndex, offsetBy: cursorPosition)

        currentInput.removeSubrange(startIndex..<endIndex)

        return wordStart
    }

    /// Finds the position of the next word boundary forward (Option-F).
    ///
    /// - Parameter cursorPosition: Current cursor position
    /// - Returns: Position at the start of the next word
    public func findWordBoundaryForward(from cursorPosition: Int) -> Int {
        guard cursorPosition < currentInput.count else { return currentInput.count }

        var position = cursorPosition
        let characters = Array(currentInput)

        // Skip current word characters
        while position < characters.count && !characters[position].isWhitespace {
            position += 1
        }

        // Skip whitespace to start of next word
        while position < characters.count && characters[position].isWhitespace {
            position += 1
        }

        return position
    }

    /// Finds the position of the previous word boundary backward (Option-B).
    ///
    /// - Parameter cursorPosition: Current cursor position
    /// - Returns: Position at the start of the current/previous word
    public func findWordBoundaryBackward(from cursorPosition: Int) -> Int {
        guard cursorPosition > 0 else { return 0 }

        var position = cursorPosition
        let characters = Array(currentInput)

        // Skip whitespace before current position
        while position > 0 && characters[position - 1].isWhitespace {
            position -= 1
        }

        // Skip word characters to find word start
        while position > 0 && !characters[position - 1].isWhitespace {
            position -= 1
        }

        return position
    }
}
