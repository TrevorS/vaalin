// ABOUTME: CommandHistory actor provides thread-safe command history with 500-item circular buffer,
// ABOUTME: linear indexing (0=newest, -1=previous), prefix search, and JSON persistence

import Foundation

/// Thread-safe command history manager with circular buffer and persistence.
///
/// CommandHistory maintains a rolling buffer of user commands with navigation,
/// prefix-based search, and automatic JSON persistence. Commands are stored
/// newest-first with linear indexing (0 = most recent, -1 = previous, etc.).
///
/// ## Usage
///
/// ```swift
/// let history = CommandHistory(maxSize: 500)
///
/// // Add commands
/// await history.add("look")
/// await history.add("north")
/// await history.add("exp")
///
/// // Navigate (like arrow keys)
/// let older = await history.back()    // Returns "north"
/// let newer = await history.forward() // Returns "exp"
///
/// // Prefix search (for autocomplete)
/// let matches = await history.match(prefix: "lo") // Returns ["look"]
///
/// // Persistence
/// let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
///     .appendingPathComponent("Vaalin")
///     .appendingPathComponent("command-history.json")
/// try await history.save(to: url)
/// try await history.load(from: url)
/// ```
///
/// ## Linear Indexing
///
/// Commands are accessed using linear indices:
/// - Index 0 = most recent command
/// - Index -1 = previous command
/// - Index -2 = command before that
/// - etc.
///
/// Navigation maintains current position:
/// - `back()` moves to older commands (decrements index)
/// - `forward()` moves to newer commands (increments index)
/// - `resetPosition()` returns to index 0
///
/// ## Buffer Management
///
/// The buffer is circular with a configurable maximum size (default 500).
/// When the buffer is full, the oldest command is removed when a new one is added.
///
/// ## Thread Safety
///
/// CommandHistory is implemented as an actor, ensuring all operations are thread-safe.
/// Multiple components can safely add commands, navigate, and search concurrently.
///
public actor CommandHistory {
    // MARK: - Properties

    /// Maximum number of commands to store (default: 500)
    public let maxSize: Int

    /// Commands stored newest-first
    /// Index 0 = most recent, increasing indices = older commands
    private var commands: [String] = []

    /// Current position in history using linear indexing
    /// 0 = newest (commands[0]), -1 = previous (commands[1]), -2 = older (commands[2]), etc.
    private var currentIndex: Int = 0

    // MARK: - Codable Support

    /// Internal structure for encoding/decoding
    private struct CodableData: Codable {
        let maxSize: Int
        let commands: [String]
    }

    // MARK: - Initialization

    /// Creates a new command history with specified maximum size
    /// - Parameter maxSize: Maximum number of commands to store (default: 500)
    public init(maxSize: Int = 500) {
        self.maxSize = maxSize
    }

    // MARK: - Adding Commands

    /// Adds a new command to the history
    ///
    /// The command is inserted at the beginning (index 0) and the current position
    /// is reset to 0. If the buffer is full, the oldest command is removed.
    ///
    /// - Parameter command: Command string to add
    public func add(_ command: String) {
        // Insert at beginning (newest first)
        commands.insert(command, at: 0)

        // Prune oldest if over maxSize
        if commands.count > maxSize {
            commands.removeLast()
        }

        // Reset position to newest
        resetPosition()
    }

    // MARK: - Navigation

    /// Moves to the next older command in history
    ///
    /// Decrements the current index (makes it more negative) to access older commands.
    /// If already at the oldest command, stays at that position.
    ///
    /// - Returns: The command at the new position
    public func back() -> String {
        if canNavigateBack() {
            currentIndex -= 1
        }
        return read()
    }

    /// Moves to the next newer command in history
    ///
    /// Increments the current index (makes it less negative) to access newer commands.
    /// If already at the newest command, stays at that position.
    ///
    /// - Returns: The command at the new position
    public func forward() -> String {
        if canNavigateForward() {
            currentIndex += 1
        }
        return read()
    }

    /// Checks if navigation to older commands is possible
    /// - Returns: True if not at the oldest command
    public func canNavigateBack() -> Bool {
        let arrayIndex = abs(currentIndex)
        return arrayIndex < commands.count - 1
    }

    /// Checks if navigation to newer commands is possible
    /// - Returns: True if not at the newest command (index 0)
    public func canNavigateForward() -> Bool {
        return currentIndex < 0
    }

    /// Resets navigation position to the newest command
    public func resetPosition() {
        currentIndex = 0
    }

    // MARK: - Reading

    /// Reads the command at the current position
    /// - Returns: Command string, or empty string if history is empty
    public func read() -> String {
        let arrayIndex = abs(currentIndex)
        guard arrayIndex < commands.count else {
            return ""
        }
        return commands[arrayIndex]
    }

    /// Reads the command at a specific array index
    /// - Parameter index: Array index (0 = newest)
    /// - Returns: Command string, or empty string if index out of bounds
    public func readAt(index: Int) -> String {
        guard index >= 0 && index < commands.count else {
            return ""
        }
        return commands[index]
    }

    /// Returns all commands in newest-first order
    /// - Returns: Array of all commands
    public func getAll() -> [String] {
        return commands
    }

    /// Returns the current position as a positive array index
    /// - Returns: Absolute value of currentIndex (0 = newest, 1 = previous, etc.)
    public func position() -> Int {
        return abs(currentIndex)
    }

    /// Returns the count of commands in history
    /// - Returns: Number of commands stored
    public func count() -> Int {
        return commands.count
    }

    // MARK: - Prefix Search

    /// Finds all commands that start with the given prefix
    ///
    /// Returns commands in newest-first order. Exact matches are excluded
    /// (prefix must be shorter than the command).
    ///
    /// - Parameter prefix: Prefix string to search for
    /// - Returns: Array of matching commands in newest-first order
    public func match(prefix: String) -> [String] {
        return commands.filter { command in
            command.hasPrefix(prefix) && command.count > prefix.count
        }
    }

    // MARK: - Persistence

    /// Saves command history to a JSON file
    ///
    /// Creates parent directories if they don't exist. Writes atomically
    /// using a temporary file and rename to prevent corruption.
    ///
    /// - Parameter url: File URL to save to
    /// - Throws: EncodingError or file system errors
    public func save(to url: URL) throws {
        // Create codable snapshot
        let snapshot = CodableData(maxSize: maxSize, commands: commands)

        // Create parent directory if needed
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)

        // Atomic write: temp file + rename
        let tempURL = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).tmp")

        try data.write(to: tempURL, options: .atomic)

        // Replace existing file
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tempURL, to: url)
    }

    /// Loads command history from a JSON file
    ///
    /// If the file doesn't exist or contains invalid JSON, the history remains unchanged.
    /// The current position is reset to the newest command after loading.
    ///
    /// - Parameter url: File URL to load from
    /// - Throws: DecodingError or file system errors (except file not found)
    public func load(from url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            // Silently ignore missing file
            return
        }

        let data = try Data(contentsOf: url)

        // Try to decode
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(CodableData.self, from: data) else {
            // Invalid JSON - ignore and keep current state
            return
        }

        // Load decoded state
        self.commands = decoded.commands
        self.resetPosition()
    }
}
